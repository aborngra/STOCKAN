DECLARE
   v_path            VARCHAR2(256 CHAR) := 'E:\APP\ABO\ORADATA\ORCL\';
   v_tablespace_name VARCHAR2(256 CHAR) := 'TOOLS_DATA';
   v_size            VARCHAR2(256 CHAR) := '512M';
   v_size_next       VARCHAR2(256 CHAR) := '256M';
   v_sql             VARCHAR2(32667 CHAR);
BEGIN
   FOR i IN (SELECT v_tablespace_name AS tablespace_name FROM DUAL
             MINUS
             SELECT tablespace_name FROM dba_tablespaces)
   LOOP
      v_sql      :=
            '
              CREATE TABLESPACE '
         || v_tablespace_name
         || ' DATAFILE '''
         || v_path
         || v_tablespace_name
         || '_01.DBF'' SIZE '
         || v_size
         || ' AUTOEXTEND ON NEXT '
         || v_size_next
         || ' MAXSIZE UNLIMITED
              LOGGING
              DEFAULT
                NO INMEMORY
              ONLINE
              EXTENT MANAGEMENT LOCAL AUTOALLOCATE
              BLOCKSIZE 8K
              SEGMENT SPACE MANAGEMENT AUTO
              FLASHBACK ON';

      DBMS_OUTPUT.put_line(v_sql);

      EXECUTE IMMEDIATE v_sql;
   END LOOP;
END;
/