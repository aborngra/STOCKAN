MERGE INTO symbol_types trg
     USING (SELECT 1 AS id, 'Stock' AS name FROM DUAL
            UNION ALL
            SELECT 2 AS id, 'Index' AS name FROM DUAL
            UNION ALL
            SELECT 3 AS id, 'Commodity' AS name FROM DUAL) src
        ON (trg.id = src.id)
WHEN NOT MATCHED
THEN
  INSERT     (id
            , name
            , creation_usr
            , creation_dt)
      VALUES (src.id
            , src.name
            , SYS_CONTEXT('USERENV', 'OS_USER')
            , SYSDATE)
WHEN MATCHED
THEN
  UPDATE SET trg.name = src.name, modification_usr = SYS_CONTEXT('USERENV', 'OS_USER'), modification_dt = SYSDATE;

COMMIT;