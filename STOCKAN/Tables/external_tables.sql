BEGIN
  FOR i IN (SELECT *
              FROM user_tables
             WHERE table_name = 'GDAXI')
  LOOP
    EXECUTE IMMEDIATE 'DROP TABLE ' || i.table_name || ' PURGE';
  END LOOP;
END;
/

CREATE TABLE gdaxi
(
  date_       VARCHAR2(32 CHAR)
, open_       VARCHAR2(32 CHAR)
, high_       VARCHAR2(32 CHAR)
, low_        VARCHAR2(32 CHAR)
, close_      VARCHAR2(32 CHAR)
, adj_close_  VARCHAR2(32 CHAR)
, volume_     VARCHAR2(32 CHAR)
)
ORGANIZATION EXTERNAL
  (TYPE oracle_loader
   DEFAULT DIRECTORY index_dax30
   ACCESS PARAMETERS(RECORDS DELIMITED BY '\n'
                     FIELDS
                       TERMINATED BY ',')
   LOCATION('^GDAXI.csv'));