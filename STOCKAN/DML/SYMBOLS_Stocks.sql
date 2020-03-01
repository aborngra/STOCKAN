DECLARE
  v_symbol_type_id symbol_types.id%TYPE;
BEGIN
  v_symbol_type_id := symbol_types_api.read_row(p_name => 'Index');

  MERGE INTO symbols trg
       USING (SELECT 'DAX' AS name
                   , '^GDAXI' AS symbol
                   , v_symbol_type_id AS symbol_type_id
                   , 'DE0008469008' AS isin
                   , 'INDEX_DAX30' AS directory
                   , '^GDAXI.csv' AS file
                   , 'GDAXI' AS ext_table_name
                   , 'DE' AS country_code
                FROM DUAL) src
          ON (trg.symbol = src.symbol)
  WHEN NOT MATCHED
  THEN
    INSERT     (name
              , symbol
              , symbol_type_id
              , isin
              , directory
              , "FILE"
              , ext_table_name
              , country_code
              , creation_usr
              , creation_dt)
        VALUES (src.name
              , src.symbol
              , src.symbol_type_id
              , src.isin
              , src."DIRECTORY"
              , src."FILE"
              , src.ext_table_name
              , src.country_code
              , SYS_CONTEXT('USERENV', 'OS_USER')
              , SYSDATE)
  WHEN MATCHED
  THEN
    UPDATE SET name             = name
             , symbol           = symbol
             , symbol_type_id   = symbol_type_id
             , isin             = isin
             , directory        = directory
             , "FILE"           = "FILE"
             , ext_table_name   = ext_table_name
             , country_code     = country_code
             , modification_usr = SYS_CONTEXT('USERENV', 'OS_USER')
             , modification_dt  = SYSDATE;
END;
/

COMMIT;