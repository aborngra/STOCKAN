CREATE OR REPLACE PACKAGE BODY partition_control_bl
IS
  PROCEDURE list_partition_rename(p_table_owner          IN all_tab_partitions.table_owner%TYPE DEFAULT USER
                                , p_table_name           IN all_tab_partitions.table_name%TYPE
                                , p_partition_name_new   IN all_tab_partitions.partition_name%TYPE
                                , p_partition_high_value IN VARCHAR2)
  IS
    v_sql VARCHAR2(4000 CHAR);
  BEGIN
    FOR i
      --------------------------------------------------------------------------
      -- XML handling is required here, because the high_value column is
      -- a long column in the dictionary and is hard to handle
      --------------------------------------------------------------------------
      IN (SELECT *
            FROM (WITH
                    xml
                    AS
                      (SELECT DBMS_XMLGEN.getxmltype(
                                   'SELECT table_name
                                                     , partition_name
                                                     , high_value 
                                                  FROM all_tab_partitions
                                                 WHERE table_owner = '''
                                || p_table_owner
                                || ''' AND table_name = '''
                                || p_table_name
                                || '''')
                                AS x
                         FROM DUAL)
                  SELECT EXTRACTVALUE(rws.object_value, '/ROW/TABLE_NAME') table_name
                       , EXTRACTVALUE(rws.object_value, '


                                             /ROW/PARTITION_NAME') partition_name
                       , EXTRACTVALUE(rws.object_value, '/ROW/HIGH_VALUE') high_value
                    FROM xml x CROSS JOIN TABLE(XMLSEQUENCE(EXTRACT(x.x, '/ROWSET/ROW'))) rws)
           WHERE high_value = p_partition_high_value)
    LOOP
      --------------------------------------------------------------------------
      -- only rename partition, when it's not done yet (restartable)
      --------------------------------------------------------------------------
      IF (i.partition_name <> p_partition_name_new)
      THEN
        v_sql :=
             'ALTER TABLE '
          || p_table_owner
          || '.'
          || p_table_name
          || ' RENAME PARTITION '
          || i.partition_name
          || ' TO '
          || p_partition_name_new;

        EXECUTE IMMEDIATE v_sql;
      END IF;
    END LOOP;
  END list_partition_rename;

  PROCEDURE list_partition_stats(p_table_owner    IN all_tab_partitions.table_owner%TYPE DEFAULT USER
                               , p_table_name     IN all_tab_partitions.table_name%TYPE
                               , p_partition_name IN all_tab_partitions.partition_name%TYPE)
  IS
  BEGIN
    ----------------------------------------------------------------------------
    -- do it only for existing partition to be more stable
    ----------------------------------------------------------------------------
    FOR i IN (SELECT *
                FROM all_tab_partitions
               WHERE table_owner = p_table_owner
                 AND table_name = p_table_name
                 AND partition_name = p_partition_name)
    LOOP
      --------------------------------------------------------------------------
      -- create statistics for defined table and defined partition
      --------------------------------------------------------------------------
      DBMS_STATS.gather_table_stats(ownname          => p_table_owner
                                  , tabname          => p_table_name
                                  , partname         => p_partition_name
                                  , estimate_percent => 1
                                  , granularity      => 'PARTITION'
                                  , degree           => DBMS_STATS.default_degree);
    END LOOP;
  END list_partition_stats;
END partition_control_bl;
/