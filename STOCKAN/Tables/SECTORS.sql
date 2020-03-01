--------------------------------------------------------------------------------
-- This anonymous block creates a table named SECTORS in
-- schema STOCKAN. PL/SQL Block is restartable, so it can be
-- executed n times, but only creates the table if it does not exist.
--------------------------------------------------------------------------------
BEGIN
  FOR i IN (SELECT 'SECTORS' AS table_name FROM DUAL
            MINUS
            SELECT table_name
              FROM all_tables
             WHERE table_name = 'SECTORS'
               AND owner = USER)
  LOOP
    EXECUTE IMMEDIATE q'{
  CREATE TABLE "SECTORS" 
   (	
  "ID" NUMBER GENERATED BY DEFAULT ON NULL AS IDENTITY MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 1 CACHE 1000 NOORDER  NOCYCLE  NOKEEP  NOSCALE  CONSTRAINT "SECTORS_NN01" NOT NULL ENABLE,
  "NAME" VARCHAR2(64 CHAR) CONSTRAINT "SECTORS_NN02" NOT NULL ENABLE,
  "CREATION_USR" VARCHAR2(64 CHAR) CONSTRAINT "SECTORS_NN03" NOT NULL ENABLE,
  "CREATION_DT" DATE CONSTRAINT "SECTORS_NN04" NOT NULL ENABLE,
  "MODIFICATION_USR" VARCHAR2(64 CHAR),
  "MODIFICATION_DT" DATE,
  CONSTRAINT "SECTORS_PK" PRIMARY KEY ("ID")
  USING INDEX  ENABLE,
  CONSTRAINT "SECTORS_UK" UNIQUE ("NAME")
  ENABLE
   ) ORGANIZATION INDEX 
                        }';
  END LOOP;
END;
/

--------------------------------------------------------------------------------
-- Table and column comments of SECTORS
--------------------------------------------------------------------------------
-- no comments defined for SECTORS

--------------------------------------------------------------------------------
-- This is an example of adding a new column, you can just
-- copy and paste the code and adjust it for new columns
--------------------------------------------------------------------------------
BEGIN
  FOR i IN (SELECT 'ID' AS column_name FROM DUAL
            MINUS
            SELECT column_name
              FROM all_tab_cols
             WHERE table_name = 'SECTORS'
               AND column_name = 'ID'
               AND owner = USER)
  LOOP
    EXECUTE IMMEDIATE 'ALTER TABLE SECTORS ADD ' || i.column_name || ' NUMBER';
  END LOOP;
END;
/