--------------------------------------------------------------------------------
-- This anonymous block creates a table named SYMBOLS in
-- schema STOCKAN. PL/SQL Block is restartable, so it can be
-- executed n times, but only creates the table if it does not exist.
--------------------------------------------------------------------------------
BEGIN
  FOR i IN (SELECT 'SYMBOLS' AS table_name FROM DUAL
            MINUS
            SELECT table_name
              FROM all_tables
             WHERE table_name = 'SYMBOLS'
               AND owner = USER)
  LOOP
    EXECUTE IMMEDIATE q'{
  CREATE TABLE "SYMBOLS" 
   (	
  "ID" NUMBER GENERATED BY DEFAULT ON NULL AS IDENTITY MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 1 CACHE 1000 NOORDER  NOCYCLE  NOKEEP  NOSCALE  CONSTRAINT "SYMBOLS_NN01" NOT NULL ENABLE,
  "NAME" VARCHAR2(64 CHAR) CONSTRAINT "SYMBOLS_NN02" NOT NULL ENABLE,
  "SYMBOL" VARCHAR2(64 CHAR) CONSTRAINT "SYMBOLS_NN03" NOT NULL ENABLE,
  "COUNTRY_CODE" VARCHAR2(3 CHAR) CONSTRAINT "SYMBOLS_NN04" NOT NULL ENABLE,
  "SYMBOL_TYPE_ID" NUMBER CONSTRAINT "SYMBOLS_NN05" NOT NULL ENABLE,
  "CREATION_USR" VARCHAR2(64 CHAR) CONSTRAINT "SYMBOLS_NN06" NOT NULL ENABLE,
  "CREATION_DT" DATE CONSTRAINT "SYMBOLS_NN07" NOT NULL ENABLE,
  "MODIFICATION_USR" VARCHAR2(64 CHAR),
  "MODIFICATION_DT" DATE,
	 CONSTRAINT "SYMBOLS_PK" PRIMARY KEY ("ID")
  USING INDEX  ENABLE,
  CONSTRAINT "SYMBOLS_FK" FOREIGN KEY ("SYMBOL_TYPE_ID") REFERENCES SYMBOL_TYPES("ID")
  ENABLE,
  CONSTRAINT "SYMBOLS_UK" UNIQUE ("SYMBOL")
  ENABLE
   ) ORGANIZATION INDEX 
                        }';
  END LOOP;
END;
/

--------------------------------------------------------------------------------
-- Table and column comments of SYMBOLS
--------------------------------------------------------------------------------
-- no comments defined for SYMBOLS

--------------------------------------------------------------------------------
-- This is an example of adding a new column, you can just
-- copy and paste the code and adjust it for new columns
--------------------------------------------------------------------------------
BEGIN
  FOR i IN (SELECT 'ID' AS column_name FROM DUAL
            MINUS
            SELECT column_name
              FROM all_tab_cols
             WHERE table_name = 'SYMBOLS'
               AND column_name = 'ID'
               AND owner = USER)
  LOOP
    EXECUTE IMMEDIATE 'ALTER TABLE SYMBOLS ADD ' || i.column_name || ' NUMBER';
  END LOOP;
END;
/