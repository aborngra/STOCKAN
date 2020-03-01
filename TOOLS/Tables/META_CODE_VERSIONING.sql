--------------------------------------------------------------------------------
-- This anonymous block creates a table named META_CODE_VERSIONING in
-- schema MAINT_WAAS. PL/SQL Block is restartable, so it can be
-- executed n times, but only creates the table if it does not exist.
--------------------------------------------------------------------------------
BEGIN
  FOR i IN (SELECT 'META_CODE_VERSIONING' AS table_name FROM DUAL
            MINUS
            SELECT table_name
              FROM all_tables
             WHERE table_name = 'META_CODE_VERSIONING'
               AND owner = 'MAINT_WAAS')
  LOOP
    EXECUTE IMMEDIATE q'{
  CREATE TABLE "META_CODE_VERSIONING" 
   (	"ID" NUMBER, 
	"SCHEMA" VARCHAR2(30 CHAR) CONSTRAINT "META_CODE_VERSIONING_NN01" NOT NULL ENABLE, 
	"OBJECT" VARCHAR2(30 CHAR) CONSTRAINT "META_CODE_VERSIONING_NN02" NOT NULL ENABLE, 
	"NAME" VARCHAR2(64 CHAR) CONSTRAINT "META_CODE_VERSIONING_NN03" NOT NULL ENABLE, 
	"FILENAME" VARCHAR2(255 CHAR) CONSTRAINT "META_CODE_VERSIONING_NN04" NOT NULL ENABLE, 
	"SCRIPT" CLOB CONSTRAINT "META_CODE_VERSIONING_NN05" NOT NULL ENABLE, 
	"CREATED_AT" DATE CONSTRAINT "META_CODE_VERSIONING_NN06" NOT NULL ENABLE, 
	 CONSTRAINT "META_CODE_VERSIONING_CK01" CHECK ( object IN ('SEQUENCE'
                                                           , 'TABLE'
                                                           , 'VIEW'
                                                           , 'MATERIALIZED_VIEW'
                                                           , 'INDEX'
                                                           , 'SYNONYM'
                                                           , 'PACKAGE'
                                                           , 'PACKAGE_BODY'
                                                           , 'PACKAGE_API'
                                                           , 'PACKAGE_BODY_API'
                                                           , 'FUNCTION'
                                                           , 'PROCEDURE'
                                                           , 'TRIGGER'
                                                           , 'TYPE'
                                                           , 'TYPE_BODY'
                                                           , 'DATABASE_LINK'
                                                           , 'GRANT_FROM'
                                                           , 'GRANT_TO'
                                                           , 'FK_CONSTRAINT'
                                                           , 'INSTALL_BAT'
                                                           , 'INSTALL_SQL') ) ENABLE, 
	 CONSTRAINT "META_CODE_VERSIONING_PK" PRIMARY KEY ("ID")
  USING INDEX  ENABLE
   ) 
  PARTITION BY LIST ("SCHEMA") AUTOMATIC 
 (PARTITION "P_SCHEMA_LICENSING"  VALUES ('LICENSING') , 
 PARTITION "P_SCHEMA_MAINT_WAAS"  VALUES ('MAINT_WAAS') , 
 PARTITION "P_SCHEMA_PROCESS"  VALUES ('PROCESS') , 
 PARTITION "P_SCHEMA_BASIC_DATA"  VALUES ('BASIC_DATA') , 
 PARTITION "P_SCHEMA_CLK"  VALUES ('CLK') , 
 PARTITION "P_SCHEMA_PARTNER"  VALUES ('PARTNER') , 
 PARTITION "P_SCHEMA_BZ_60BAT"  VALUES ('BZ_60BAT') , 
 PARTITION "P_SCHEMA_EXCON"  VALUES ('EXCON') , 
 PARTITION "P_SCHEMA_LOCAL_EXCON"  VALUES ('LOCAL_EXCON') , 
 PARTITION "P_SCHEMA_LIONREP"  VALUES ('LIONREP') , 
 PARTITION "P_SCHEMA_LION_STAGE"  VALUES ('LION_STAGE') )
                        }';
  END LOOP;
END;
/

--------------------------------------------------------------------------------
-- Table and column comments of META_CODE_VERSIONING
--------------------------------------------------------------------------------
-- no comments defined for META_CODE_VERSIONING

--------------------------------------------------------------------------------
-- This is an example of adding a new column, you can just
-- copy and paste the code and adjust it for new columns
--------------------------------------------------------------------------------
BEGIN
  FOR i IN (SELECT 'ID' AS column_name FROM DUAL
            MINUS
            SELECT column_name
              FROM all_tab_cols
             WHERE table_name = 'META_CODE_VERSIONING'
               AND column_name = 'ID'
               AND owner = 'MAINT_WAAS')
  LOOP
    EXECUTE IMMEDIATE   'ALTER TABLE META_CODE_VERSIONING ADD '
                     || i.column_name
                     || ' NUMBER';
  END LOOP;
END;
/