--------------------------------------------------------------------------------
-- This anonymous block creates a table named META_CODE_TEMPLATE in
-- schema MAINT_WAAS. PL/SQL Block is restartable, so it can be
-- executed n times, but only creates the table if it does not exist.
--------------------------------------------------------------------------------
BEGIN
  FOR i IN (SELECT 'META_CODE_TEMPLATE' AS table_name FROM DUAL
            MINUS
            SELECT table_name
              FROM all_tables
             WHERE table_name = 'META_CODE_TEMPLATE'
               AND owner = 'MAINT_WAAS')
  LOOP
    EXECUTE IMMEDIATE q'{
  CREATE TABLE "META_CODE_TEMPLATE" 
   (	"ID" NUMBER, 
	"OBJECT" VARCHAR2(30 CHAR) CONSTRAINT "META_CODE_TEMPLATE_NN01" NOT NULL ENABLE, 
	"SCRIPT_TEMPLATE" CLOB CONSTRAINT "META_CODE_TEMPLATE_NN02" NOT NULL ENABLE, 
	 CONSTRAINT "META_CODE_TEMPLATE_PK" PRIMARY KEY ("ID")
  USING INDEX  ENABLE, 
	 CONSTRAINT "META_CODE_TEMPLATE_UK" UNIQUE ("OBJECT")
  USING INDEX  ENABLE
   )
                        }';
  END LOOP;
END;
/

--------------------------------------------------------------------------------
-- Table and column comments of META_CODE_TEMPLATE
--------------------------------------------------------------------------------
-- no comments defined for META_CODE_TEMPLATE

--------------------------------------------------------------------------------
-- This is an example of adding a new column, you can just
-- copy and paste the code and adjust it for new columns
--------------------------------------------------------------------------------
BEGIN
  FOR i IN (SELECT 'ID' AS column_name FROM DUAL
            MINUS
            SELECT column_name
              FROM all_tab_cols
             WHERE table_name = 'META_CODE_TEMPLATE'
               AND column_name = 'ID'
               AND owner = 'MAINT_WAAS')
  LOOP
    EXECUTE IMMEDIATE   'ALTER TABLE META_CODE_TEMPLATE ADD '
                     || i.column_name
                     || ' NUMBER';
  END LOOP;
END;
/