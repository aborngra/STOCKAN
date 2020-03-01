--------------------------------------------------------------------------------
-- This anonymous block creates a table named RELATION_TYPES in
-- schema STOCKAN. PL/SQL Block is restartable, so it can be
-- executed n times, but only creates the table if it does not exist.
--------------------------------------------------------------------------------
BEGIN
  FOR i IN (SELECT 'RELATION_TYPES' AS table_name FROM DUAL
            MINUS
            SELECT table_name
              FROM all_tables
             WHERE table_name = 'RELATION_TYPES'
               AND owner = USER)
  LOOP
    EXECUTE IMMEDIATE q'{
  CREATE TABLE "RELATION_TYPES" 
   (	
  "ID" NUMBER GENERATED BY DEFAULT ON NULL AS IDENTITY MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 1 CACHE 1000 NOORDER  NOCYCLE  NOKEEP  NOSCALE  CONSTRAINT "RELATION_TYPES_NN01" NOT NULL ENABLE,
  "NAME" VARCHAR2(64 CHAR) CONSTRAINT "RELATION_TYPES_NN02" NOT NULL ENABLE,
  "CREATION_USR" VARCHAR2(64 CHAR) CONSTRAINT "RELATION_TYPES_NN03" NOT NULL ENABLE,
  "CREATION_DT" DATE CONSTRAINT "RELATION_TYPES_NN04" NOT NULL ENABLE,
  "MODIFICATION_USR" VARCHAR2(64 CHAR),
  "MODIFICATION_DT" DATE,
  CONSTRAINT "RELATION_TYPES_PK" PRIMARY KEY ("ID")
  USING INDEX  ENABLE,
  CONSTRAINT "RELATION_TYPES_UK" UNIQUE ("NAME")
  ENABLE
   ) ORGANIZATION INDEX 
                        }';
  END LOOP;
END;
/

--------------------------------------------------------------------------------
-- Table and column comments of RELATION_TYPES
--------------------------------------------------------------------------------
-- no comments defined for RELATION_TYPES

--------------------------------------------------------------------------------
-- This is an example of adding a new column, you can just
-- copy and paste the code and adjust it for new columns
--------------------------------------------------------------------------------
BEGIN
  FOR i IN (SELECT 'ID' AS column_name FROM DUAL
            MINUS
            SELECT column_name
              FROM all_tab_cols
             WHERE table_name = 'RELATION_TYPES'
               AND column_name = 'ID'
               AND owner = USER)
  LOOP
    EXECUTE IMMEDIATE 'ALTER TABLE RELATION_TYPES ADD ' || i.column_name || ' NUMBER';
  END LOOP;
END;
/