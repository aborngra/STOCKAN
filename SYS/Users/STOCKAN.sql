DECLARE
  v_username        VARCHAR2(30 CHAR) := 'STOCKAN';
  v_tablespace_name VARCHAR2(30 CHAR) := 'TS_STOCKAN';
  v_sql             VARCHAR2(32667 CHAR);
BEGIN
  FOR i IN (SELECT v_username AS username FROM DUAL
            MINUS
            SELECT username FROM dba_users)
  LOOP
    v_sql :=
         'CREATE USER '
      || i.username
      || ' IDENTIFIED BY '
      || LOWER(i.username)
      || ' DEFAULT TABLESPACE '
      || v_tablespace_name
      || ' TEMPORARY TABLESPACE TEMP PROFILE DEFAULT ACCOUNT UNLOCK';

    DBMS_OUTPUT.put_line(v_sql);

    EXECUTE IMMEDIATE v_sql;
  END LOOP;
END;
/

ALTER USER stockan
  DEFAULT ROLE ALL;

-- 19 System Privileges for stockan
GRANT ADVISOR TO stockan;
GRANT ALTER SESSION TO stockan;
GRANT ANALYZE ANY TO stockan;
GRANT CREATE ANY CONTEXT TO stockan;
GRANT CREATE ANY SYNONYM TO stockan;
GRANT CREATE DATABASE LINK TO stockan;
GRANT CREATE ANY DIRECTORY TO stockan;
GRANT CREATE JOB TO stockan;
GRANT CREATE PROCEDURE TO stockan;
GRANT CREATE SEQUENCE TO stockan;
GRANT CREATE SESSION TO stockan;
GRANT CREATE SYNONYM TO stockan;
GRANT CREATE TABLE TO stockan;
GRANT CREATE TRIGGER TO stockan;
GRANT CREATE TYPE TO stockan;
GRANT CREATE VIEW TO stockan;
GRANT DROP ANY SYNONYM TO stockan;
GRANT SELECT ANY DICTIONARY TO stockan;
GRANT UNLIMITED TABLESPACE TO stockan;

-- 1 Tablespace Quota for stockan
ALTER USER stockan
  QUOTA UNLIMITED ON ts_stockan;