MERGE INTO sectors trg
     USING (SELECT 1 AS id, 'Basic Materials' AS name FROM DUAL
            UNION ALL
            SELECT 2 AS id, 'Communication' AS name FROM DUAL
            UNION ALL
            SELECT 3 AS id, 'Consumer Cyclical' AS name FROM DUAL
            UNION ALL
            SELECT 4 AS id, 'Consumer Defensive' AS name FROM DUAL
            UNION ALL
            SELECT 5 AS id, 'Energy' AS name FROM DUAL
            UNION ALL
            SELECT 6 AS id, 'Financial Services' AS name FROM DUAL
            UNION ALL
            SELECT 7 AS id, 'Healthcare' AS name FROM DUAL
            UNION ALL
            SELECT 8 AS id, 'Industrials' AS name FROM DUAL
            UNION ALL
            SELECT 9 AS id, 'Real Estate' AS name FROM DUAL
            UNION ALL
            SELECT 10 AS id, 'Technology' AS name FROM DUAL
            UNION ALL
            SELECT 11 AS id, 'Utilities' AS name FROM DUAL) src
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