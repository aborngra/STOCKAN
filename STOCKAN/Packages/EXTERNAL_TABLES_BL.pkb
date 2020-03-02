CREATE OR REPLACE PACKAGE BODY "EXTERNAL_TABLES_BL"
IS
  PROCEDURE create_external_tables
  IS
  BEGIN
    FOR i IN (SELECT *
                FROM symbols
                     LEFT OUTER JOIN user_tables
                       ON symbols.ext_table_name = user_tables.table_name
                      AND user_tables.external = 'YES'
               -----------------------------------------------------------------
               -- create table only, if not already exists
               -----------------------------------------------------------------
               WHERE user_tables.table_name IS NULL)
    LOOP
      EXECUTE IMMEDIATE 'CREATE TABLE ' || i.ext_table_name || '
                         (
                           date_       VARCHAR2(32 CHAR)
                         , open_       VARCHAR2(32 CHAR)
                         , high_       VARCHAR2(32 CHAR)
                         , low_        VARCHAR2(32 CHAR)
                         , close_      VARCHAR2(32 CHAR)
                         , adj_close_  VARCHAR2(32 CHAR)
                         , volume_     VARCHAR2(32 CHAR)
                         ) ORGANIZATION EXTERNAL
                        (
                           TYPE oracle_loader
                           DEFAULT DIRECTORY ' || i."DIRECTORY" || '
                           ACCESS PARAMETERS(
                             RECORDS DELIMITED BY ''\n''
                             SKIP 1
                             FIELDS TERMINATED BY '',''
                           ) 
                           LOCATION(''' || i."FILE" || ''')
                        )';
    END LOOP;
  END create_external_tables;
END "EXTERNAL_TABLES_BL";
/