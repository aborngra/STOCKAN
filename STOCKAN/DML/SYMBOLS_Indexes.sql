DECLARE
  v_symbol_type_id symbol_types.id%TYPE;
BEGIN
  v_symbol_type_id := symbol_types_api.get_pk_by_unique_cols(p_name => 'Index');

  MERGE INTO symbols trg
       USING (SELECT 'DAX' AS name
                   , '^GDAXI' AS symbol
                   , 'DE0008469008' AS isin
                   , 'INDEX_DAX30' AS "DIRECTORY"
                   , '^GDAXI.csv' AS "FILE"
                   , 'GDAXI' AS ext_table_name
                   , 'DE' AS country_code
                FROM DUAL
              UNION ALL
              SELECT 'MDAX' AS name
                   , '^MDAXI' AS symbol
                   , 'DE0008467416' AS isin
                   , 'INDEX_MDAX50' AS "DIRECTORY"
                   , '^MDAXI.csv' AS "FILE"
                   , 'MDAXI' AS ext_table_name
                   , 'DE' AS country_code
                FROM DUAL) src
          ON (trg.symbol = src.symbol)
  WHEN NOT MATCHED
  THEN
    INSERT     (name
              , symbol
              , symbol_type_id
              , isin
              , "DIRECTORY"
              , "FILE"
              , ext_table_name
              , country_code
              , creation_usr
              , creation_dt)
        VALUES (src.name
              , src.symbol
              , v_symbol_type_id
              , src.isin
              , src."DIRECTORY"
              , src."FILE"
              , src.ext_table_name
              , src.country_code
              , SYS_CONTEXT('USERENV', 'OS_USER')
              , SYSDATE)
  WHEN MATCHED
  THEN
    UPDATE SET name             = src.name
             , symbol_type_id   = v_symbol_type_id
             , isin             = src.isin
             , "DIRECTORY"      = src."DIRECTORY"
             , "FILE"           = src."FILE"
             , ext_table_name   = src.ext_table_name
             , country_code     = src.country_code
             , modification_usr = SYS_CONTEXT('USERENV', 'OS_USER')
             , modification_dt  = SYSDATE;
END;
/

COMMIT;