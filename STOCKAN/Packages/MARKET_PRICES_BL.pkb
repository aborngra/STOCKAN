CREATE OR REPLACE PACKAGE BODY "MARKET_PRICES_BL"
IS
  PROCEDURE import_marketprices(p_symbol IN symbols.symbol%TYPE DEFAULT NULL)
  IS
    ----------------------------------------------------------------------------
    -- ref cursor is used to load data from different tables
    ----------------------------------------------------------------------------
    TYPE t_weak_ref_cur IS REF CURSOR;
    v_weak_ref_cur        t_weak_ref_cur;

    ----------------------------------------------------------------------------
    -- all these tables have same structure
    ----------------------------------------------------------------------------
    TYPE t_marketprice_rec IS RECORD
    (
      date_       DATE
    , open_       NUMBER
    , high_       NUMBER
    , low_        NUMBER
    , close_      NUMBER
    , adj_close_  NUMBER
    , volume_     NUMBER
    );
    TYPE t_marketprice_tab IS TABLE OF t_marketprice_rec;
    v_marketprice_tab     t_marketprice_tab;

    c_bulk_limit CONSTANT PLS_INTEGER := 20000;
    v_partition_name      all_tab_partitions.partition_name%TYPE;
    v_sql                 VARCHAR2(4000 CHAR);
  BEGIN
    ----------------------------------------------------------------------------
    -- ensure right nls_numeric_characters
    ----------------------------------------------------------------------------
    EXECUTE IMMEDIATE 'ALTER SESSION SET nls_numeric_characters = ''.,''';

    FOR i IN (SELECT *
                FROM symbols s INNER JOIN user_tables t ON s.ext_table_name = t.table_name
               -----------------------------------------------------------------
               -- optional filter a special symbol or take all symbols
               -----------------------------------------------------------------
               WHERE s.symbol = COALESCE(p_symbol, s.symbol))
    LOOP
      v_sql            := 'WITH last_import AS (SELECT COALESCE(MAX("DATE"), TO_DATE(''01.01.1900'', ''dd.mm.yyyy'')) AS max_date
                                       FROM marketprices
                                      WHERE symbol_id = ' || i.id || ')
                SELECT TO_DATE(date_, ''yyyy-mm-dd'') AS date_
                     , TO_NUMBER(open_)
                     , TO_NUMBER(high_)
                     , TO_NUMBER(low_)
                     , TO_NUMBER(close_)
                     , TO_NUMBER(adj_close_)
                     , TO_NUMBER(volume_)
                  FROM "' || i.ext_table_name || '" CROSS JOIN last_import 
                 WHERE TO_DATE(date_, ''yyyy-mm-dd'') > last_import.max_date
                   AND open_ <> ''null''
                   AND high_ <> ''null''
                   AND low_  <> ''null''';

      OPEN v_weak_ref_cur FOR v_sql;

      LOOP
        FETCH v_weak_ref_cur BULK COLLECT INTO v_marketprice_tab LIMIT c_bulk_limit;

        EXIT WHEN v_marketprice_tab.COUNT = 0;

        FORALL idx IN INDICES OF v_marketprice_tab
          INSERT INTO marketprices(symbol_id
                                 , "DATE"
                                 , open
                                 , high
                                 , low
                                 , close
                                 , adjusted_close
                                 , volume
                                 , creation_usr
                                 , creation_dt)
               VALUES (i.id
                     , v_marketprice_tab(idx).date_
                     , v_marketprice_tab(idx).open_
                     , v_marketprice_tab(idx).high_
                     , v_marketprice_tab(idx).low_
                     , v_marketprice_tab(idx).close_
                     , v_marketprice_tab(idx).adj_close_
                     , v_marketprice_tab(idx).volume_
                     , SYS_CONTEXT('USERENV', 'OS_USER')
                     , SYSDATE);
      END LOOP;

      --------------------------------------------------------------------------
      -- commit each symbol_id
      --------------------------------------------------------------------------
      COMMIT;

      --------------------------------------------------------------------------
      -- maintain the symbol_id partition: rename and stats
      --------------------------------------------------------------------------
      v_partition_name := 'P_SYMBOL_ID_' || LPAD(i.id, 7, 0);

      tools.partition_control_bl.list_partition_rename(p_table_owner          => USER
                                                     , p_table_name           => 'MARKETPRICES'
                                                     , p_partition_name_new   => v_partition_name
                                                     , p_partition_high_value => i.id);

      tools.partition_control_bl.list_partition_stats(p_table_owner    => USER
                                                    , p_table_name     => 'MARKETPRICES'
                                                    , p_partition_name => v_partition_name);

      CLOSE v_weak_ref_cur;
    END LOOP;
  END import_marketprices;
END "MARKET_PRICES_BL";
/