DECLARE
  v_symbol_type_id symbol_types.id%TYPE;
BEGIN
  v_symbol_type_id := symbol_types_api.get_pk_by_unique_cols(p_name => 'Stock');

  MERGE INTO symbols trg
       USING (SELECT 'Covestro' AS name
                   , '1COV.DE' AS symbol
                   , 'DE0006062144' AS isin
                   , 'STOCKS_DAX30' AS "DIRECTORY"
                   , '1COV.DE.csv' AS "FILE"
                   , 'EXT_1COV.DE' AS ext_table_name
                   , 'DE' AS country_code
                FROM DUAL
              UNION ALL
              SELECT 'adidas' AS name
                   , 'ADS.DE' AS symbol
                   , 'DE000A1EWWW0' AS isin
                   , 'STOCKS_DAX30' AS "DIRECTORY"
                   , 'ADS.DE.csv' AS "FILE"
                   , 'EXT_ADS.DE' AS ext_table_name
                   , 'DE' AS country_code
                FROM DUAL
              UNION ALL
              SELECT 'Allianz' AS name
                   , 'ALV.DE' AS symbol
                   , 'DE0008404005' AS isin
                   , 'STOCKS_DAX30' AS "DIRECTORY"
                   , 'ALV.DE.csv' AS "FILE"
                   , 'EXT_ALV.DE' AS ext_table_name
                   , 'DE' AS country_code
                FROM DUAL
              UNION ALL
              SELECT 'BASF' AS name
                   , 'BAS.DE' AS symbol
                   , 'DE000BASF111' AS isin
                   , 'STOCKS_DAX30' AS "DIRECTORY"
                   , 'BAS.DE.csv' AS "FILE"
                   , 'EXT_BAS.DE' AS ext_table_name
                   , 'DE' AS country_code
                FROM DUAL
              UNION ALL
              SELECT 'Bayer' AS name
                   , 'BAYN.DE' AS symbol
                   , 'DE000BAY0017' AS isin
                   , 'STOCKS_DAX30' AS "DIRECTORY"
                   , 'BAYN.DE.csv' AS "FILE"
                   , 'EXT_BAYN.DE' AS ext_table_name
                   , 'DE' AS country_code
                FROM DUAL
              UNION ALL
              SELECT 'Beiersdorf' AS name
                   , 'BEI.DE' AS symbol
                   , 'DE0005200000' AS isin
                   , 'STOCKS_DAX30' AS "DIRECTORY"
                   , 'BEI.DE.csv' AS "FILE"
                   , 'EXT_BEI.DE' AS ext_table_name
                   , 'DE' AS country_code
                FROM DUAL
              UNION ALL
              SELECT 'BMW' AS name
                   , 'BMW.DE' AS symbol
                   , 'DE0005190003' AS isin
                   , 'STOCKS_DAX30' AS "DIRECTORY"
                   , 'BMW.DE.csv' AS "FILE"
                   , 'EXT_BMW.DE' AS ext_table_name
                   , 'DE' AS country_code
                FROM DUAL
              UNION ALL
              SELECT 'Continental' AS name
                   , 'CON.DE' AS symbol
                   , 'DE0005439004' AS isin
                   , 'STOCKS_DAX30' AS "DIRECTORY"
                   , 'CONTI.DE.csv' AS "FILE" -- CON.DE.csv name not working
                   , 'EXT_CONTI.DE' AS ext_table_name
                   , 'DE' AS country_code
                FROM DUAL
              UNION ALL
              SELECT 'Daimler' AS name
                   , 'DAI.DE' AS symbol
                   , 'DE0007100000' AS isin
                   , 'STOCKS_DAX30' AS "DIRECTORY"
                   , 'DAI.DE.csv' AS "FILE"
                   , 'EXT_DAI.DE' AS ext_table_name
                   , 'DE' AS country_code
                FROM DUAL
              UNION ALL
              SELECT 'Deutsche Bank' AS name
                   , 'DBK.DE' AS symbol
                   , 'DE0005140008' AS isin
                   , 'STOCKS_DAX30' AS "DIRECTORY"
                   , 'DBK.DE.csv' AS "FILE"
                   , 'EXT_DBK.DE' AS ext_table_name
                   , 'DE' AS country_code
                FROM DUAL
              UNION ALL
              SELECT 'Deutsche Börse' AS name
                   , 'DB1.DE' AS symbol
                   , 'DE0005810055' AS isin
                   , 'STOCKS_DAX30' AS "DIRECTORY"
                   , 'DB1.DE.csv' AS "FILE"
                   , 'EXT_DB1.DE' AS ext_table_name
                   , 'DE' AS country_code
                FROM DUAL
              UNION ALL
              SELECT 'Deutsche Post' AS name
                   , 'DPW.DE' AS symbol
                   , 'DE0005552004' AS isin
                   , 'STOCKS_DAX30' AS "DIRECTORY"
                   , 'DPW.DE.csv' AS "FILE"
                   , 'EXT_DPW.DE' AS ext_table_name
                   , 'DE' AS country_code
                FROM DUAL
              UNION ALL
              SELECT 'Deutsche Telekom' AS name
                   , 'DTE.DE' AS symbol
                   , 'DE0005557508' AS isin
                   , 'STOCKS_DAX30' AS "DIRECTORY"
                   , 'DTE.DE.csv' AS "FILE"
                   , 'EXT_DTE.DE' AS ext_table_name
                   , 'DE' AS country_code
                FROM DUAL
              UNION ALL
              SELECT 'E.ON' AS name
                   , 'EOAN.DE' AS symbol
                   , 'DE000ENAG999' AS isin
                   , 'STOCKS_DAX30' AS "DIRECTORY"
                   , 'EOAN.DE.csv' AS "FILE"
                   , 'EXT_EOAN.DE' AS ext_table_name
                   , 'DE' AS country_code
                FROM DUAL
              UNION ALL
              SELECT 'Fresenius' AS name
                   , 'FRE.DE' AS symbol
                   , 'DE0005785604' AS isin
                   , 'STOCKS_DAX30' AS "DIRECTORY"
                   , 'FRE.DE.csv' AS "FILE"
                   , 'EXT_FRE.DE' AS ext_table_name
                   , 'DE' AS country_code
                FROM DUAL
              UNION ALL
              SELECT 'Fresenius Medical Care' AS name
                   , 'FME.DE' AS symbol
                   , 'DE0005785802' AS isin
                   , 'STOCKS_DAX30' AS "DIRECTORY"
                   , 'FME.DE.csv' AS "FILE"
                   , 'EXT_FME.DE' AS ext_table_name
                   , 'DE' AS country_code
                FROM DUAL
              UNION ALL
              SELECT 'HeidelbergCement' AS name
                   , 'HEI.DE' AS symbol
                   , 'DE0006047004' AS isin
                   , 'STOCKS_DAX30' AS "DIRECTORY"
                   , 'HEI.DE.csv' AS "FILE"
                   , 'EXT_HEI.DE' AS ext_table_name
                   , 'DE' AS country_code
                FROM DUAL
              UNION ALL
              SELECT 'Henkel vz.' AS name
                   , 'HEN3.DE' AS symbol
                   , 'DE0006048432' AS isin
                   , 'STOCKS_DAX30' AS "DIRECTORY"
                   , 'HEN3.DE.csv' AS "FILE"
                   , 'EXT_HEN3.DE' AS ext_table_name
                   , 'DE' AS country_code
                FROM DUAL
              UNION ALL
              SELECT 'Infineon' AS name
                   , 'IFX.DE' AS symbol
                   , 'DE0006231004' AS isin
                   , 'STOCKS_DAX30' AS "DIRECTORY"
                   , 'IFX.DE.csv' AS "FILE"
                   , 'EXT_IFX.DE' AS ext_table_name
                   , 'DE' AS country_code
                FROM DUAL
              UNION ALL
              SELECT 'Linde' AS name
                   , 'LIN.DE' AS symbol
                   , 'IE00BZ12WP82' AS isin
                   , 'STOCKS_DAX30' AS "DIRECTORY"
                   , 'LIN.DE.csv' AS "FILE"
                   , 'EXT_LIN.DE' AS ext_table_name
                   , 'DE' AS country_code
                FROM DUAL
              UNION ALL
              SELECT 'Lufthansa' AS name
                   , 'LHA.DE' AS symbol
                   , 'DE0008232125' AS isin
                   , 'STOCKS_DAX30' AS "DIRECTORY"
                   , 'LHA.DE.csv' AS "FILE"
                   , 'EXT_LHA.DE' AS ext_table_name
                   , 'DE' AS country_code
                FROM DUAL
              UNION ALL
              SELECT 'Merck' AS name
                   , 'MRK.DE' AS symbol
                   , 'DE0006599905' AS isin
                   , 'STOCKS_DAX30' AS "DIRECTORY"
                   , 'MRK.DE.csv' AS "FILE"
                   , 'EXT_MRK.DE' AS ext_table_name
                   , 'DE' AS country_code
                FROM DUAL
              UNION ALL
              SELECT 'MTU Aero Engines' AS name
                   , 'MTX.DE' AS symbol
                   , 'DE000A0D9PT0' AS isin
                   , 'STOCKS_DAX30' AS "DIRECTORY"
                   , 'MTX.DE.csv' AS "FILE"
                   , 'EXT_MTX.DE' AS ext_table_name
                   , 'DE' AS country_code
                FROM DUAL
              UNION ALL
              SELECT 'Münchener Rückversicherungs-Gesellschaft' AS name
                   , 'MUV2.DE' AS symbol
                   , 'DE0008430026' AS isin
                   , 'STOCKS_DAX30' AS "DIRECTORY"
                   , 'MUV2.DE.csv' AS "FILE"
                   , 'EXT_MUV2.DE' AS ext_table_name
                   , 'DE' AS country_code
                FROM DUAL
              UNION ALL
              SELECT 'RWE' AS name
                   , 'RWE.DE' AS symbol
                   , 'DE0007037129' AS isin
                   , 'STOCKS_DAX30' AS "DIRECTORY"
                   , 'RWE.DE.csv' AS "FILE"
                   , 'EXT_RWE.DE' AS ext_table_name
                   , 'DE' AS country_code
                FROM DUAL
              UNION ALL
              SELECT 'SAP' AS name
                   , 'SAP.DE' AS symbol
                   , 'DE0007164600' AS isin
                   , 'STOCKS_DAX30' AS "DIRECTORY"
                   , 'SAP.DE.csv' AS "FILE"
                   , 'EXT_SAP.DE' AS ext_table_name
                   , 'DE' AS country_code
                FROM DUAL
              UNION ALL
              SELECT 'Siemens' AS name
                   , 'SIE.DE' AS symbol
                   , 'DE0007236101' AS isin
                   , 'STOCKS_DAX30' AS "DIRECTORY"
                   , 'SIE.DE.csv' AS "FILE"
                   , 'EXT_SIE.DE' AS ext_table_name
                   , 'DE' AS country_code
                FROM DUAL
              UNION ALL
              SELECT 'Volkswagen (VW) vz.' AS name
                   , 'VNA.DE' AS symbol
                   , 'DE0007664039' AS isin
                   , 'STOCKS_DAX30' AS "DIRECTORY"
                   , 'VNA.DE.csv' AS "FILE"
                   , 'EXT_VNA.DE' AS ext_table_name
                   , 'DE' AS country_code
                FROM DUAL
              UNION ALL
              SELECT 'Vonovia' AS name
                   , 'VOW3.DE' AS symbol
                   , 'DE000A1ML7J1' AS isin
                   , 'STOCKS_DAX30' AS "DIRECTORY"
                   , 'VOW3.DE.csv' AS "FILE"
                   , 'EXT_VOW3.DE' AS ext_table_name
                   , 'DE' AS country_code
                FROM DUAL
              UNION ALL
              SELECT 'Wirecard' AS name
                   , 'WDI.DE' AS symbol
                   , 'DE0007472060' AS isin
                   , 'STOCKS_DAX30' AS "DIRECTORY"
                   , 'WDI.DE.csv' AS "FILE"
                   , 'EXT_WDI.DE' AS ext_table_name
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