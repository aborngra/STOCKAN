DECLARE
  v_username        VARCHAR2(30 CHAR) := 'TOOLS';
  v_tablespace_name VARCHAR2(30 CHAR) := 'TS_TOOLS';
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

ALTER USER tools
  DEFAULT ROLE ALL;

-- 18 System Privileges for tools
GRANT ADVISOR TO tools;
GRANT ALTER SESSION TO tools;
GRANT ANALYZE ANY TO tools;
GRANT CREATE ANY CONTEXT TO tools;
GRANT CREATE ANY SYNONYM TO tools;
GRANT CREATE DATABASE LINK TO tools;
GRANT CREATE JOB TO tools;
GRANT CREATE PROCEDURE TO tools;
GRANT CREATE SEQUENCE TO tools;
GRANT CREATE SESSION TO tools;
GRANT CREATE SYNONYM TO tools;
GRANT CREATE TABLE TO tools;
GRANT CREATE TRIGGER TO tools;
GRANT CREATE TYPE TO tools;
GRANT CREATE VIEW TO tools;
GRANT DROP ANY SYNONYM TO tools;
GRANT SELECT ANY DICTIONARY TO tools;
GRANT UNLIMITED TABLESPACE TO tools;

-- 1 Tablespace Quota for tools
ALTER USER tools
  QUOTA UNLIMITED ON ts_tools;