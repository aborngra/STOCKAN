SET DEFINE OFF;

MERGE INTO meta_code_template a
     USING (SELECT 8
                     AS id
                 , 'DB_LINK'
                     AS object
                 ,    '--------------------------------------------------------------------------------'
                   || CHR(13)
                   || CHR(10)
                   || '-- This anonymous block creates a database link named ###DB_LINK### in'
                   || CHR(13)
                   || CHR(10)
                   || '-- schema ###OWNER###. PL/SQL Block is restartable, so it can be '
                   || CHR(13)
                   || CHR(10)
                   || '-- executed n times, but only creates the database link if it does not exist.'
                   || CHR(13)
                   || CHR(10)
                   || '--------------------------------------------------------------------------------'
                   || CHR(13)
                   || CHR(10)
                   || 'BEGIN'
                   || CHR(13)
                   || CHR(10)
                   || '  FOR i IN (SELECT ''###DB_LINK###'' AS db_link FROM DUAL'
                   || CHR(13)
                   || CHR(10)
                   || '            MINUS'
                   || CHR(13)
                   || CHR(10)
                   || '            SELECT db_link'
                   || CHR(13)
                   || CHR(10)
                   || '              FROM all_db_links'
                   || CHR(13)
                   || CHR(10)
                   || '             WHERE db_link = ''###DB_LINK###'''
                   || CHR(13)
                   || CHR(10)
                   || '               AND owner = ''###OWNER###'')'
                   || CHR(13)
                   || CHR(10)
                   || '  LOOP'
                   || CHR(13)
                   || CHR(10)
                   || '    EXECUTE IMMEDIATE q''{###GENERATED_CODE###'
                   || CHR(13)
                   || CHR(10)
                   || '                        }'';'
                   || CHR(13)
                   || CHR(10)
                   || '  END LOOP;'
                   || CHR(13)
                   || CHR(10)
                   || 'END;'
                   || CHR(13)
                   || CHR(10)
                   || '/'
                     AS script_template
              FROM DUAL) b
        ON (a.id = b.id)
WHEN NOT MATCHED
THEN
  INSERT     (id, object, script_template)
      VALUES (b.id, b.object, b.script_template)
WHEN MATCHED
THEN
  UPDATE SET a.object = b.object, a.script_template = b.script_template;

MERGE INTO meta_code_template a
     USING (SELECT 9
                     AS id
                 , 'FK_CONSTRAINT'
                     AS object
                 ,    '--------------------------------------------------------------------------------'
                   || CHR(13)
                   || CHR(10)
                   || '-- This anonymous block creates a FK constraint named ###FK_CONSTRAINT### in'
                   || CHR(13)
                   || CHR(10)
                   || '-- schema ###OWNER###. PL/SQL Block is restartable, so it can be '
                   || CHR(13)
                   || CHR(10)
                   || '-- executed n times, but only creates the constraint if it does not exist.'
                   || CHR(13)
                   || CHR(10)
                   || '--------------------------------------------------------------------------------'
                   || CHR(13)
                   || CHR(10)
                   || 'BEGIN'
                   || CHR(13)
                   || CHR(10)
                   || '  FOR i IN (SELECT ''###FK_CONSTRAINT###'' AS constraint_name FROM DUAL'
                   || CHR(13)
                   || CHR(10)
                   || '            MINUS'
                   || CHR(13)
                   || CHR(10)
                   || '            SELECT constraint_name'
                   || CHR(13)
                   || CHR(10)
                   || '              FROM all_constraints'
                   || CHR(13)
                   || CHR(10)
                   || '             WHERE constraint_name = ''###FK_CONSTRAINT###'''
                   || CHR(13)
                   || CHR(10)
                   || '               AND owner = ''###OWNER###'')'
                   || CHR(13)
                   || CHR(10)
                   || '  LOOP'
                   || CHR(13)
                   || CHR(10)
                   || '    EXECUTE IMMEDIATE q''{###GENERATED_CODE###'
                   || CHR(13)
                   || CHR(10)
                   || '                        }'';'
                   || CHR(13)
                   || CHR(10)
                   || '  END LOOP;'
                   || CHR(13)
                   || CHR(10)
                   || 'END;'
                   || CHR(13)
                   || CHR(10)
                   || '/'
                   || CHR(13)
                   || CHR(10)
                   || CHR(13)
                   || CHR(10)
                   || ''
                     AS script_template
              FROM DUAL) b
        ON (a.id = b.id)
WHEN NOT MATCHED
THEN
  INSERT     (id, object, script_template)
      VALUES (b.id, b.object, b.script_template)
WHEN MATCHED
THEN
  UPDATE SET a.object = b.object, a.script_template = b.script_template;

MERGE INTO meta_code_template a
     USING (SELECT 10
                     AS id
                 , 'INDEX'
                     AS object
                 ,    '--------------------------------------------------------------------------------'
                   || CHR(13)
                   || CHR(10)
                   || '-- This anonymous block creates a index named ###INDEX_NAME### in'
                   || CHR(13)
                   || CHR(10)
                   || '-- schema ###OWNER###. PL/SQL Block is restartable, so it can be '
                   || CHR(13)
                   || CHR(10)
                   || '-- executed n times, but only creates the index if it does not exist.'
                   || CHR(13)
                   || CHR(10)
                   || '--------------------------------------------------------------------------------'
                   || CHR(13)
                   || CHR(10)
                   || 'BEGIN'
                   || CHR(13)
                   || CHR(10)
                   || '  FOR i IN (SELECT ''###INDEX_NAME###'' FROM DUAL'
                   || CHR(13)
                   || CHR(10)
                   || '            MINUS'
                   || CHR(13)
                   || CHR(10)
                   || '            SELECT index_name'
                   || CHR(13)
                   || CHR(10)
                   || '              FROM all_indexes'
                   || CHR(13)
                   || CHR(10)
                   || '             WHERE index_name = ''###INDEX_NAME###'''
                   || CHR(13)
                   || CHR(10)
                   || '               AND owner = ''###OWNER###'')'
                   || CHR(13)
                   || CHR(10)
                   || '  LOOP'
                   || CHR(13)
                   || CHR(10)
                   || '    EXECUTE IMMEDIATE q''{###GENERATED_CODE###'
                   || CHR(13)
                   || CHR(10)
                   || '                        }'';'
                   || CHR(13)
                   || CHR(10)
                   || '  END LOOP;'
                   || CHR(13)
                   || CHR(10)
                   || 'END;'
                   || CHR(13)
                   || CHR(10)
                   || '/'
                     AS script_template
              FROM DUAL) b
        ON (a.id = b.id)
WHEN NOT MATCHED
THEN
  INSERT     (id, object, script_template)
      VALUES (b.id, b.object, b.script_template)
WHEN MATCHED
THEN
  UPDATE SET a.object = b.object, a.script_template = b.script_template;

MERGE INTO meta_code_template a
     USING (SELECT 11
                     AS id
                 , 'MATERIALIZED_VIEW'
                     AS object
                 ,    '--------------------------------------------------------------------------------'
                   || CHR(13)
                   || CHR(10)
                   || '-- This anonymous block creates a materialized view named ###MVIEW_NAME### in'
                   || CHR(13)
                   || CHR(10)
                   || '-- schema ###OWNER###. PL/SQL Block is restartable, so it can be '
                   || CHR(13)
                   || CHR(10)
                   || '-- executed n times, but only creates the materialized view if it '
                   || CHR(13)
                   || CHR(10)
                   || '-- does not exist.'
                   || CHR(13)
                   || CHR(10)
                   || '--------------------------------------------------------------------------------'
                   || CHR(13)
                   || CHR(10)
                   || 'BEGIN'
                   || CHR(13)
                   || CHR(10)
                   || '  FOR i IN (SELECT ''###MVIEW_NAME###'' AS mview_name FROM DUAL'
                   || CHR(13)
                   || CHR(10)
                   || '            MINUS'
                   || CHR(13)
                   || CHR(10)
                   || '            SELECT mview_name'
                   || CHR(13)
                   || CHR(10)
                   || '              FROM all_mviews'
                   || CHR(13)
                   || CHR(10)
                   || '             WHERE mview_name = ''###MVIEW_NAME###'''
                   || CHR(13)
                   || CHR(10)
                   || '               AND owner = ''###OWNER###'')'
                   || CHR(13)
                   || CHR(10)
                   || '  LOOP'
                   || CHR(13)
                   || CHR(10)
                   || '    EXECUTE IMMEDIATE q''{###GENERATED_CODE###'
                   || CHR(13)
                   || CHR(10)
                   || '                        }'';'
                   || CHR(13)
                   || CHR(10)
                   || '  END LOOP;'
                   || CHR(13)
                   || CHR(10)
                   || 'END;'
                   || CHR(13)
                   || CHR(10)
                   || '/'
                     AS script_template
              FROM DUAL) b
        ON (a.id = b.id)
WHEN NOT MATCHED
THEN
  INSERT     (id, object, script_template)
      VALUES (b.id, b.object, b.script_template)
WHEN MATCHED
THEN
  UPDATE SET a.object = b.object, a.script_template = b.script_template;

MERGE INTO meta_code_template a
     USING (SELECT 12
                     AS id
                 , 'TYPE_SPEC'
                     AS object
                 ,    '--------------------------------------------------------------------------------'
                   || CHR(13)
                   || CHR(10)
                   || '-- This anonymous block drops a type named ###TYPE_NAME### in'
                   || CHR(13)
                   || CHR(10)
                   || '-- schema ###OWNER###. Types can cause trouble when they exists even though'
                   || CHR(13)
                   || CHR(10)
                   || '-- there is the "CREATE OR REPLACE" command, so they will be droped and '
                   || CHR(13)
                   || CHR(10)
                   || '-- recrated again. PL/SQL Block is restartable, so it can be '
                   || CHR(13)
                   || CHR(10)
                   || '-- executed n times, but only drops the type if it does exist.'
                   || CHR(13)
                   || CHR(10)
                   || '--------------------------------------------------------------------------------'
                   || CHR(13)
                   || CHR(10)
                   || 'BEGIN'
                   || CHR(13)
                   || CHR(10)
                   || '  FOR i IN (SELECT type_name'
                   || CHR(13)
                   || CHR(10)
                   || '              FROM all_types'
                   || CHR(13)
                   || CHR(10)
                   || '             WHERE type_name = ''###TYPE_NAME###'''
                   || CHR(13)
                   || CHR(10)
                   || '               AND owner = ''###OWNER###'')'
                   || CHR(13)
                   || CHR(10)
                   || '  LOOP'
                   || CHR(13)
                   || CHR(10)
                   || '    EXECUTE IMMEDIATE ''DROP TYPE '' || i.type_name || '' FORCE '';'
                   || CHR(13)
                   || CHR(10)
                   || '  END LOOP;'
                   || CHR(13)
                   || CHR(10)
                   || 'END;'
                   || CHR(13)
                   || CHR(10)
                   || '/'
                   || CHR(13)
                   || CHR(10)
                   || CHR(13)
                   || CHR(10)
                   || '--------------------------------------------------------------------------------'
                   || CHR(13)
                   || CHR(10)
                   || '-- Here comes type Spec Code.'
                   || CHR(13)
                   || CHR(10)
                   || '--------------------------------------------------------------------------------'
                   || CHR(13)
                   || CHR(10)
                   || '###GENERATED_CODE###'
                   || CHR(13)
                   || CHR(10)
                   || ''
                     AS script_template
              FROM DUAL) b
        ON (a.id = b.id)
WHEN NOT MATCHED
THEN
  INSERT     (id, object, script_template)
      VALUES (b.id, b.object, b.script_template)
WHEN MATCHED
THEN
  UPDATE SET a.object = b.object, a.script_template = b.script_template;

MERGE INTO meta_code_template a
     USING (SELECT 1
                     AS id
                 , 'TABLE'
                     AS object
                 ,    '--------------------------------------------------------------------------------'
                   || CHR(13)
                   || CHR(10)
                   || '-- This anonymous block creates a table named ###TABLE_NAME### in'
                   || CHR(13)
                   || CHR(10)
                   || '-- schema ###OWNER###. PL/SQL Block is restartable, so it can be '
                   || CHR(13)
                   || CHR(10)
                   || '-- executed n times, but only creates the table if it does not exist.'
                   || CHR(13)
                   || CHR(10)
                   || '--------------------------------------------------------------------------------'
                   || CHR(13)
                   || CHR(10)
                   || 'BEGIN'
                   || CHR(13)
                   || CHR(10)
                   || '  FOR i IN (SELECT ''###TABLE_NAME###'' AS table_name FROM DUAL'
                   || CHR(13)
                   || CHR(10)
                   || '            MINUS'
                   || CHR(13)
                   || CHR(10)
                   || '            SELECT table_name'
                   || CHR(13)
                   || CHR(10)
                   || '              FROM all_tables'
                   || CHR(13)
                   || CHR(10)
                   || '             WHERE table_name = ''###TABLE_NAME###'''
                   || CHR(13)
                   || CHR(10)
                   || '               AND owner = ''###OWNER###'')'
                   || CHR(13)
                   || CHR(10)
                   || '  LOOP'
                   || CHR(13)
                   || CHR(10)
                   || '    EXECUTE IMMEDIATE q''{###GENERATED_CODE###'
                   || CHR(13)
                   || CHR(10)
                   || '                        }'';'
                   || CHR(13)
                   || CHR(10)
                   || '  END LOOP;'
                   || CHR(13)
                   || CHR(10)
                   || 'END;'
                   || CHR(13)
                   || CHR(10)
                   || '/'
                   || CHR(13)
                   || CHR(10)
                   || CHR(13)
                   || CHR(10)
                   || '--------------------------------------------------------------------------------'
                   || CHR(13)
                   || CHR(10)
                   || '-- Table and column comments of ###TABLE_NAME###'
                   || CHR(13)
                   || CHR(10)
                   || '--------------------------------------------------------------------------------'
                   || CHR(13)
                   || CHR(10)
                   || '###TABLE_AND_COLUMN_COMMENTS###'
                   || CHR(13)
                   || CHR(10)
                   || CHR(13)
                   || CHR(10)
                   || '--------------------------------------------------------------------------------'
                   || CHR(13)
                   || CHR(10)
                   || '-- This is an example of adding a new column, you can just'
                   || CHR(13)
                   || CHR(10)
                   || '-- copy and paste the code and adjust it for new columns'
                   || CHR(13)
                   || CHR(10)
                   || '--------------------------------------------------------------------------------'
                   || CHR(13)
                   || CHR(10)
                   || 'BEGIN'
                   || CHR(13)
                   || CHR(10)
                   || '  FOR i IN (SELECT ''###COLUMN_NAME###'' AS column_name FROM DUAL'
                   || CHR(13)
                   || CHR(10)
                   || '            MINUS'
                   || CHR(13)
                   || CHR(10)
                   || '            SELECT column_name'
                   || CHR(13)
                   || CHR(10)
                   || '              FROM all_tab_cols'
                   || CHR(13)
                   || CHR(10)
                   || '             WHERE table_name = ''###TABLE_NAME###'''
                   || CHR(13)
                   || CHR(10)
                   || '               AND column_name = ''###COLUMN_NAME###'''
                   || CHR(13)
                   || CHR(10)
                   || '               AND owner = ''###OWNER###'')'
                   || CHR(13)
                   || CHR(10)
                   || '  LOOP'
                   || CHR(13)
                   || CHR(10)
                   || '    EXECUTE IMMEDIATE   ''ALTER TABLE ###TABLE_NAME### ADD '''
                   || CHR(13)
                   || CHR(10)
                   || '                     || i.column_name'
                   || CHR(13)
                   || CHR(10)
                   || '                     || '' ###COLUMN_DATA_TYPE###'';'
                   || CHR(13)
                   || CHR(10)
                   || '  END LOOP;'
                   || CHR(13)
                   || CHR(10)
                   || 'END;'
                   || CHR(13)
                   || CHR(10)
                   || '/'
                     AS script_template
              FROM DUAL) b
        ON (a.id = b.id)
WHEN NOT MATCHED
THEN
  INSERT     (id, object, script_template)
      VALUES (b.id, b.object, b.script_template)
WHEN MATCHED
THEN
  UPDATE SET a.object = b.object, a.script_template = b.script_template;

MERGE INTO meta_code_template a
     USING (SELECT 2
                     AS id
                 , 'SEQUENCE'
                     AS object
                 ,    '--------------------------------------------------------------------------------'
                   || CHR(13)
                   || CHR(10)
                   || '-- This anonymous block creates a sequence named ###SEQUENCE_NAME### in'
                   || CHR(13)
                   || CHR(10)
                   || '-- schema ###OWNER###. PL/SQL Block is restartable, so it can be'
                   || CHR(13)
                   || CHR(10)
                   || '-- executed n times, but only creates the sequence if it does not exist.'
                   || CHR(13)
                   || CHR(10)
                   || '--------------------------------------------------------------------------------'
                   || CHR(13)
                   || CHR(10)
                   || 'BEGIN'
                   || CHR(13)
                   || CHR(10)
                   || '  FOR i IN (SELECT ''###SEQUENCE_NAME###'' AS sequence_name FROM DUAL'
                   || CHR(13)
                   || CHR(10)
                   || '            MINUS'
                   || CHR(13)
                   || CHR(10)
                   || '            SELECT sequence_name'
                   || CHR(13)
                   || CHR(10)
                   || '              FROM all_sequences'
                   || CHR(13)
                   || CHR(10)
                   || '             WHERE sequence_name = ''###SEQUENCE_NAME###'''
                   || CHR(13)
                   || CHR(10)
                   || '               AND sequence_owner = ''###OWNER###'')'
                   || CHR(13)
                   || CHR(10)
                   || '  LOOP'
                   || CHR(13)
                   || CHR(10)
                   || '    EXECUTE IMMEDIATE q''{###GENERATED_CODE###'
                   || CHR(13)
                   || CHR(10)
                   || '                        }'';'
                   || CHR(13)
                   || CHR(10)
                   || '  END LOOP;'
                   || CHR(13)
                   || CHR(10)
                   || 'END;'
                   || CHR(13)
                   || CHR(10)
                   || '/'
                     AS script_template
              FROM DUAL) b
        ON (a.id = b.id)
WHEN NOT MATCHED
THEN
  INSERT     (id, object, script_template)
      VALUES (b.id, b.object, b.script_template)
WHEN MATCHED
THEN
  UPDATE SET a.object = b.object, a.script_template = b.script_template;

MERGE INTO meta_code_template a
     USING (SELECT 3
                     AS id
                 , 'INSTALL_BAT'
                     AS object
                 ,    'SET NLS_LANG=GERMAN_GERMANY.AL32UTF8'
                   || CHR(13)
                   || CHR(10)
                   || CHR(13)
                   || CHR(10)
                   || 'SQLPLUS /nolog @install_###OWNER###.sql'
                     AS script_template
              FROM DUAL) b
        ON (a.id = b.id)
WHEN NOT MATCHED
THEN
  INSERT     (id, object, script_template)
      VALUES (b.id, b.object, b.script_template)
WHEN MATCHED
THEN
  UPDATE SET a.object = b.object, a.script_template = b.script_template;

MERGE INTO meta_code_template a
     USING (SELECT 4
                     AS id
                 , 'INSTALL_SQL'
                     AS object
                 ,    '--------------------------------------------------------------------------------'
                   || CHR(13)
                   || CHR(10)
                   || '-- accept parameters for DB Connection'
                   || CHR(13)
                   || CHR(10)
                   || '--------------------------------------------------------------------------------'
                   || CHR(13)
                   || CHR(10)
                   || 'ACCEPT hostname DEFAULT liono-db.gema.de PROMPT "machine description or IP to install the release [LIONO-DB.GEMA.DE]: "'
                   || CHR(13)
                   || CHR(10)
                   || 'ACCEPT servicename DEFAULT srv_user_it_e PROMPT "machine servicename to install the release [SRV_USER_IT_E]: "'
                   || CHR(13)
                   || CHR(10)
                   || 'ACCEPT username DEFAULT ###OWNER### PROMPT "enter target username [###OWNER###]: "'
                   || CHR(13)
                   || CHR(10)
                   || 'ACCEPT userpw PROMPT "enter password of &username on target machine: "'
                   || CHR(13)
                   || CHR(10)
                   || CHR(13)
                   || CHR(10)
                   || 'SET TERMOUT OFF'
                   || CHR(13)
                   || CHR(10)
                   || CHR(13)
                   || CHR(10)
                   || '--------------------------------------------------------------------------------'
                   || CHR(13)
                   || CHR(10)
                   || '-- connect to Database'
                   || CHR(13)
                   || CHR(10)
                   || '--------------------------------------------------------------------------------'
                   || CHR(13)
                   || CHR(10)
                   || 'CONNECT &username/&userpw@(DESCRIPTION=(enable=broken)(ADDRESS=(PROTOCOL=TCP)(Host=&hostname)(Port=1521))(CONNECT_DATA=(SERVICE_NAME=&servicename)))'
                   || CHR(13)
                   || CHR(10)
                   || CHR(13)
                   || CHR(10)
                   || '--------------------------------------------------------------------------------'
                   || CHR(13)
                   || CHR(10)
                   || '-- handle the release name, default value is current date/time'
                   || CHR(13)
                   || CHR(10)
                   || '-- accept optional as an additional parameter'
                   || CHR(13)
                   || CHR(10)
                   || '--------------------------------------------------------------------------------'
                   || CHR(13)
                   || CHR(10)
                   || 'column currentdate new_value currentdate'
                   || CHR(13)
                   || CHR(10)
                   || CHR(13)
                   || CHR(10)
                   || 'select to_char(sysdate, ''yyyy.mm.dd.hh24.mi'') as currentdate from dual;'
                   || CHR(13)
                   || CHR(10)
                   || CHR(13)
                   || CHR(10)
                   || 'SET VERIFY OFF'
                   || CHR(13)
                   || CHR(10)
                   || 'SET ECHO OFF'
                   || CHR(13)
                   || CHR(10)
                   || 'SET SERVEROUTPUT OFF'
                   || CHR(13)
                   || CHR(10)
                   || 'SET HEADING ON'
                   || CHR(13)
                   || CHR(10)
                   || 'SET FEEDBACK ON'
                   || CHR(13)
                   || CHR(10)
                   || 'SET SQLBLANKLINES ON'
                   || CHR(13)
                   || CHR(10)
                   || 'SET TERMOUT ON'
                   || CHR(13)
                   || CHR(10)
                   || 'SET DEFINE ON'
                   || CHR(13)
                   || CHR(10)
                   || CHR(13)
                   || CHR(10)
                   || 'ACCEPT releasename DEFAULT &currentdate PROMPT "enter releasename of current release [&currentdate]: "'
                   || CHR(13)
                   || CHR(10)
                   || CHR(13)
                   || CHR(10)
                   || '--------------------------------------------------------------------------------'
                   || CHR(13)
                   || CHR(10)
                   || '-- activate logging'
                   || CHR(13)
                   || CHR(10)
                   || '--------------------------------------------------------------------------------'
                   || CHR(13)
                   || CHR(10)
                   || 'SPOOL install_###OWNER###.log'
                   || CHR(13)
                   || CHR(10)
                   || CHR(13)
                   || CHR(10)
                   || '--------------------------------------------------------------------------------'
                   || CHR(13)
                   || CHR(10)
                   || '-- information about connection'
                   || CHR(13)
                   || CHR(10)
                   || '--------------------------------------------------------------------------------'
                   || CHR(13)
                   || CHR(10)
                   || 'PROMPT connected as &username on &hostname'
                   || CHR(13)
                   || CHR(10)
                   || CHR(13)
                   || CHR(10)
                   || '--------------------------------------------------------------------------------'
                   || CHR(13)
                   || CHR(10)
                   || '-- set error action'
                   || CHR(13)
                   || CHR(10)
                   || '--------------------------------------------------------------------------------'
                   || CHR(13)
                   || CHR(10)
                   || 'WHENEVER SQLERROR CONTINUE'
                   || CHR(13)
                   || CHR(10)
                   || CHR(13)
                   || CHR(10)
                   || '--------------------------------------------------------------------------------'
                   || CHR(13)
                   || CHR(10)
                   || '-- ensure that objects are installed in the right schema'
                   || CHR(13)
                   || CHR(10)
                   || '--------------------------------------------------------------------------------'
                   || CHR(13)
                   || CHR(10)
                   || 'PROMPT change session to ###OWNER###'
                   || CHR(13)
                   || CHR(10)
                   || CHR(13)
                   || CHR(10)
                   || 'ALTER SESSION SET CURRENT_SCHEMA = ###OWNER###;'
                   || CHR(13)
                   || CHR(10)
                   || 'ALTER SESSION SET NLS_LANGUAGE = GERMAN;'
                   || CHR(13)
                   || CHR(10)
                   || CHR(13)
                   || CHR(10)
                   || '--------------------------------------------------------------------------------'
                   || CHR(13)
                   || CHR(10)
                   || '-- start releasing the scripts'
                   || CHR(13)
                   || CHR(10)
                   || '--------------------------------------------------------------------------------'
                   || CHR(13)
                   || CHR(10)
                   || 'PROMPT install release files...'
                   || CHR(13)
                   || CHR(10)
                   || CHR(13)
                   || CHR(10)
                   || 'SET DEFINE OFF'
                   || CHR(13)
                   || CHR(10)
                   || CHR(13)
                   || CHR(10)
                   || '###SEQUENCE###'
                   || CHR(13)
                   || CHR(10)
                   || CHR(13)
                   || CHR(10)
                   || '###TABLE###'
                   || CHR(13)
                   || CHR(10)
                   || CHR(13)
                   || CHR(10)
                   || '###INDEX###'
                   || CHR(13)
                   || CHR(10)
                   || CHR(13)
                   || CHR(10)
                   || '###FK_CONSTRAINT###'
                   || CHR(13)
                   || CHR(10)
                   || CHR(13)
                   || CHR(10)
                   || '###DATABASE_LINK###'
                   || CHR(13)
                   || CHR(10)
                   || CHR(13)
                   || CHR(10)
                   || '###SYNONYM###'
                   || CHR(13)
                   || CHR(10)
                   || CHR(13)
                   || CHR(10)
                   || '###VIEW###'
                   || CHR(13)
                   || CHR(10)
                   || CHR(13)
                   || CHR(10)
                   || '###TRIGGER###'
                   || CHR(13)
                   || CHR(10)
                   || CHR(13)
                   || CHR(10)
                   || '###MVIEW###'
                   || CHR(13)
                   || CHR(10)
                   || CHR(13)
                   || CHR(10)
                   || '###TYPE###'
                   || CHR(13)
                   || CHR(10)
                   || CHR(13)
                   || CHR(10)
                   || '###TYPE_BODY###'
                   || CHR(13)
                   || CHR(10)
                   || CHR(13)
                   || CHR(10)
                   || '###PACKAGE_API###'
                   || CHR(13)
                   || CHR(10)
                   || CHR(13)
                   || CHR(10)
                   || '###PACKAGE_BODY_API###'
                   || CHR(13)
                   || CHR(10)
                   || CHR(13)
                   || CHR(10)
                   || '###PACKAGE###'
                   || CHR(13)
                   || CHR(10)
                   || CHR(13)
                   || CHR(10)
                   || '###PACKAGE_BODY###'
                   || CHR(13)
                   || CHR(10)
                   || CHR(13)
                   || CHR(10)
                   || '###RECREATE_API###'
                   || CHR(13)
                   || CHR(10)
                   || CHR(13)
                   || CHR(10)
                   || '###PROCEDURE###'
                   || CHR(13)
                   || CHR(10)
                   || CHR(13)
                   || CHR(10)
                   || '###FUNCTION###'
                   || CHR(13)
                   || CHR(10)
                   || CHR(13)
                   || CHR(10)
                   || '###GRANT###'
                   || CHR(13)
                   || CHR(10)
                   || CHR(13)
                   || CHR(10)
                   || '###DML###'
                   || CHR(13)
                   || CHR(10)
                   || CHR(13)
                   || CHR(10)
                   || 'PROMPT ========================================================================='
                   || CHR(13)
                   || CHR(10)
                   || 'PROMPT compile schema ###OWNER###'
                   || CHR(13)
                   || CHR(10)
                   || 'PROMPT ========================================================================='
                   || CHR(13)
                   || CHR(10)
                   || 'BEGIN'
                   || CHR(13)
                   || CHR(10)
                   || '  DBMS_UTILITY.compile_schema(schema => ''###OWNER###'', compile_all => FALSE);'
                   || CHR(13)
                   || CHR(10)
                   || 'END;'
                   || CHR(13)
                   || CHR(10)
                   || '/'
                   || CHR(13)
                   || CHR(10)
                   || CHR(13)
                   || CHR(10)
                   || 'PROMPT ... done'
                   || CHR(13)
                   || CHR(10)
                   || CHR(13)
                   || CHR(10)
                   || '--------------------------------------------------------------------------------'
                   || CHR(13)
                   || CHR(10)
                   || '-- finish the logfile'
                   || CHR(13)
                   || CHR(10)
                   || '--------------------------------------------------------------------------------'
                   || CHR(13)
                   || CHR(10)
                   || 'SPOOL OFF'
                   || CHR(13)
                   || CHR(10)
                   || CHR(13)
                   || CHR(10)
                   || '--------------------------------------------------------------------------------'
                   || CHR(13)
                   || CHR(10)
                   || '-- finish the release'
                   || CHR(13)
                   || CHR(10)
                   || '--------------------------------------------------------------------------------'
                   || CHR(13)
                   || CHR(10)
                   || 'EXIT'
                     AS script_template
              FROM DUAL) b
        ON (a.id = b.id)
WHEN NOT MATCHED
THEN
  INSERT     (id, object, script_template)
      VALUES (b.id, b.object, b.script_template)
WHEN MATCHED
THEN
  UPDATE SET a.object = b.object, a.script_template = b.script_template;

MERGE INTO meta_code_template a
     USING (SELECT 5
                     AS id
                 , 'INSTALL_SQL_PROMT'
                     AS object
                 ,    'PROMPT ========================================================================='
                   || CHR(13)
                   || CHR(10)
                   || 'PROMPT install ###WHAT###...'
                   || CHR(13)
                   || CHR(10)
                   || 'PROMPT ========================================================================='
                   || CHR(13)
                   || CHR(10)
                   || ''
                     AS script_template
              FROM DUAL) b
        ON (a.id = b.id)
WHEN NOT MATCHED
THEN
  INSERT     (id, object, script_template)
      VALUES (b.id, b.object, b.script_template)
WHEN MATCHED
THEN
  UPDATE SET a.object = b.object, a.script_template = b.script_template;

MERGE INTO meta_code_template a
     USING (SELECT 6
                     AS id
                 , 'INSTALL_SQL_RECREATE_APIS'
                     AS object
                 ,    'PROMPT ========================================================================='
                   || CHR(13)
                   || CHR(10)
                   || 'PROMPT recreation of table APIs (sometimes columns differ between envs)'
                   || CHR(13)
                   || CHR(10)
                   || 'PROMPT ========================================================================='
                   || CHR(13)
                   || CHR(10)
                   || 'BEGIN'
                   || CHR(13)
                   || CHR(10)
                   || '  maint_waas.om_tapigen.recreate_existing_apis(p_owner => ''###OWNER###'');'
                   || CHR(13)
                   || CHR(10)
                   || 'END;'
                   || CHR(13)
                   || CHR(10)
                   || '/'
                     AS script_template
              FROM DUAL) b
        ON (a.id = b.id)
WHEN NOT MATCHED
THEN
  INSERT     (id, object, script_template)
      VALUES (b.id, b.object, b.script_template)
WHEN MATCHED
THEN
  UPDATE SET a.object = b.object, a.script_template = b.script_template;

MERGE INTO meta_code_template a
     USING (SELECT 7
                     AS id
                 , 'INSTALL_SQL_DML_EXAMPLE'
                     AS object
                 ,    'PROMPT ========================================================================='
                   || CHR(13)
                   || CHR(10)
                   || 'PROMPT install DML scripts required for the release...'
                   || CHR(13)
                   || CHR(10)
                   || 'PROMPT ========================================================================='
                   || CHR(13)
                   || CHR(10)
                   || '-- @@"DML\example_DML.sql"'
                     AS script_template
              FROM DUAL) b
        ON (a.id = b.id)
WHEN NOT MATCHED
THEN
  INSERT     (id, object, script_template)
      VALUES (b.id, b.object, b.script_template)
WHEN MATCHED
THEN
  UPDATE SET a.object = b.object, a.script_template = b.script_template;

COMMIT;