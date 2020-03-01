CREATE OR REPLACE EDITIONABLE PACKAGE BODY "CODE_VERSIONING_BL"
IS
  ------------------------------------------------------------------------------
  -- global private package variables
  ------------------------------------------------------------------------------
  g_user                    all_users.username%TYPE;

  TYPE type_tab_files IS TABLE OF meta_code_versioning.filename%TYPE
    INDEX BY meta_code_versioning.object%TYPE;

  g_files                   type_tab_files;

  CURSOR g_cur_sequences IS
    SELECT s.sequence_name
         , TO_CLOB(NULL) AS sequence_script
         , g_files('SEQUENCE') AS filename
      FROM dba_sequences s
           JOIN dba_objects o
             ON s.sequence_name = o.object_name
            AND s.sequence_owner = o.owner
     WHERE s.sequence_owner = g_user
       -------------------------------------------------------------------------
       -- ignore identity column sequence
       -------------------------------------------------------------------------
       AND o.generated = 'N';

  TYPE type_tab_sequences IS TABLE OF g_cur_sequences%ROWTYPE;

  g_tab_sequences           type_tab_sequences;

  CURSOR g_cur_tables IS
    SELECT table_name
         , TO_CLOB(NULL) AS table_script
         , g_files('TABLE') AS filename
      FROM dba_tables
     WHERE owner = g_user
       AND table_name NOT IN (SELECT mview_name
                                FROM dba_mviews
                               WHERE owner = g_user)
       AND table_name <> 'TOAD_PLAN_TABLE';

  TYPE type_tab_tables IS TABLE OF g_cur_tables%ROWTYPE;

  g_tab_tables              type_tab_tables;

  CURSOR g_cur_fk_constraints IS
      SELECT owner
           , table_name
           , LISTAGG(constraint_name, ',') WITHIN GROUP (ORDER BY constraint_name) AS fk_constraint_list
           , TO_CLOB(NULL) AS fk_constraint_script
           , g_files('FK_CONSTRAINT') AS filename
        FROM dba_constraints
       WHERE owner = g_user
         AND constraint_type = 'R'
    GROUP BY owner, table_name;

  TYPE type_tab_fk_constraints IS TABLE OF g_cur_fk_constraints%ROWTYPE;

  g_tab_fk_constraints      type_tab_fk_constraints;

  CURSOR g_cur_indexes IS
    SELECT index_name
         , table_name
         , TO_CLOB(NULL) AS index_script
         , g_files('INDEX') AS filename
      FROM dba_indexes
     WHERE owner = g_user
       AND index_type = 'NORMAL';

  TYPE type_tab_indexes IS TABLE OF g_cur_indexes%ROWTYPE;

  g_tab_indexes             type_tab_indexes;

  CURSOR g_cur_packages_api IS
      SELECT object_name
           , TO_CLOB(NULL) AS package_script
           , g_files('PACKAGE_API') AS filename
        FROM dba_objects
       WHERE owner = g_user
         AND object_type = 'PACKAGE'
         AND object_name IN (SELECT DISTINCT name
                               FROM dba_source
                              WHERE text LIKE '%generator="OM_TAPIGEN"%'
                                AND TYPE = 'PACKAGE'
                                AND owner = g_user)
    ORDER BY object_id;

  TYPE type_tab_packages_api IS TABLE OF g_cur_packages_api%ROWTYPE;

  g_tab_packages_api        type_tab_packages_api;

  CURSOR g_cur_package_api_bodies IS
      SELECT object_name
           , TO_CLOB(NULL) AS package_script
           , g_files('PACKAGE_BODY_API') AS filename
        FROM dba_objects
       WHERE owner = g_user
         AND object_type = 'PACKAGE BODY'
         AND object_name IN (SELECT DISTINCT name
                               FROM dba_source
                              WHERE text LIKE '%generator="OM_TAPIGEN"%'
                                AND TYPE = 'PACKAGE'
                                AND owner = g_user)
    ORDER BY object_id;

  TYPE type_tab_package_api_bodies IS TABLE OF g_cur_package_api_bodies%ROWTYPE;

  g_tab_packages_api_bodies type_tab_package_api_bodies;

  CURSOR g_cur_packages_bl IS
      SELECT object_name
           , TO_CLOB(NULL) AS package_script
           , g_files('PACKAGE') AS filename
        FROM dba_objects
       WHERE owner = g_user
         AND object_type = 'PACKAGE'
         AND object_name NOT IN (SELECT DISTINCT name
                                   FROM dba_source
                                  WHERE text LIKE '%generator="OM_TAPIGEN"%'
                                    AND TYPE = 'PACKAGE'
                                    AND owner = g_user)
    ORDER BY object_id;

  TYPE type_tab_packages_bl IS TABLE OF g_cur_packages_bl%ROWTYPE;

  g_tab_packages_bl         type_tab_packages_bl;

  CURSOR g_cur_package_bl_bodies IS
      SELECT object_name
           , TO_CLOB(NULL) AS package_script
           , g_files('PACKAGE_BODY') AS filename
        FROM dba_objects
       WHERE owner = g_user
         AND object_type = 'PACKAGE BODY'
         AND object_name NOT IN (SELECT DISTINCT name
                                   FROM dba_source
                                  WHERE text LIKE '%generator="OM_TAPIGEN"%'
                                    AND TYPE = 'PACKAGE'
                                    AND owner = g_user)
    ORDER BY object_id;

  TYPE type_tab_package_bl_body IS TABLE OF g_cur_package_bl_bodies%ROWTYPE;

  g_tab_packages_bl_bodies  type_tab_package_bl_body;

  CURSOR g_cur_synonyms IS
    SELECT synonym_name
         , table_owner
         , TO_CLOB(NULL) AS synonym_script
         , g_files('SYNONYM') AS filename
      FROM dba_synonyms
     WHERE owner = g_user;

  TYPE type_tab_synonyms IS TABLE OF g_cur_synonyms%ROWTYPE;

  g_tab_synonyms            type_tab_synonyms;

  CURSOR g_cur_triggers IS
    SELECT trigger_name
         , TO_CLOB(NULL) AS trigger_script
         , g_files('TRIGGER') AS filename
      FROM dba_triggers
     WHERE owner = g_user;

  TYPE type_tab_triggers IS TABLE OF g_cur_triggers%ROWTYPE;

  g_tab_triggers            type_tab_triggers;

  CURSOR g_cur_types IS
    SELECT name AS type_name
         , TO_CLOB(NULL) AS type_script
         , g_files('TYPE') AS filename
      FROM (SELECT DISTINCT s.name
              FROM dba_source s
                   JOIN dba_types t
                     ON s.owner = t.owner
                    AND s.name = t.type_name
             WHERE s.owner = g_user
               AND s.TYPE = 'TYPE');

  TYPE type_tab_types IS TABLE OF g_cur_types%ROWTYPE;

  g_tab_types               type_tab_types;

  CURSOR g_cur_type_bodies IS
    SELECT name AS type_name
         , TO_CLOB(NULL) AS type_script
         , g_files('TYPE_BODY') AS filename
      FROM (SELECT DISTINCT s.name
              FROM dba_source s
                   JOIN dba_types t
                     ON s.owner = t.owner
                    AND s.name = t.type_name
             WHERE s.owner = g_user
               AND s.TYPE = 'TYPE BODY');

  TYPE type_tab_type_bodies IS TABLE OF g_cur_type_bodies%ROWTYPE;

  g_tab_type_bodies         type_tab_type_bodies;

  CURSOR g_cur_views IS
    SELECT view_name
         , TO_CLOB(NULL) AS view_script
         , g_files('VIEW') AS filename
      FROM dba_views
     WHERE owner = g_user;

  TYPE type_tab_views IS TABLE OF g_cur_views%ROWTYPE;

  g_tab_views               type_tab_views;

  CURSOR g_cur_grants_from IS
      SELECT grantor
           , grantee
           , owner
           , table_name
           , grantable
           , hierarchy
           , common
           , TYPE
           , grantor || '_' || table_name AS name
           , LISTAGG(privilege, ', ') WITHIN GROUP (ORDER BY privilege) AS grants
           , LISTAGG(single_grant) WITHIN GROUP (ORDER BY privilege) AS grants_short
           , TO_CLOB(NULL) AS grant_from_script
           , g_files('GRANT_FROM') AS filename
        FROM (SELECT p.*
                   , SUBSTR(privilege, 1, 1) AS single_grant
                FROM dba_tab_privs p
               WHERE grantee = g_user
                 AND table_name NOT LIKE 'SYS_PLSQL%')
    GROUP BY grantor
           , grantee
           , owner
           , table_name
           , grantable
           , hierarchy
           , common
           , TYPE;

  TYPE type_tab_grants_from IS TABLE OF g_cur_grants_from%ROWTYPE;

  g_tab_grants_from         type_tab_grants_from;

  CURSOR g_cur_grants_to IS
      SELECT grantor
           , grantee
           , owner
           , table_name
           , grantable
           , hierarchy
           , common
           , TYPE
           , grantee || '_' || table_name AS name
           , LISTAGG(privilege, ', ') WITHIN GROUP (ORDER BY privilege) AS grants
           , LISTAGG(single_grant) WITHIN GROUP (ORDER BY privilege) AS grants_short
           , TO_CLOB(NULL) AS grant_to_script
           , g_files('GRANT_TO') AS filename
        FROM (SELECT p.*
                   , SUBSTR(privilege, 1, 1) AS single_grant
                FROM dba_tab_privs p
               WHERE grantor = g_user
                 AND privilege <> 'INHERIT PRIVILEGES'
                 AND table_name <> 'TOAD_PLAN_TABLE')
    GROUP BY grantor
           , grantee
           , owner
           , table_name
           , grantable
           , hierarchy
           , common
           , TYPE;

  TYPE type_tab_grants_to IS TABLE OF g_cur_grants_to%ROWTYPE;

  g_tab_grants_to           type_tab_grants_to;

  CURSOR g_cur_mviews IS
    SELECT mview_name
         , TO_CLOB(NULL) AS mview_script
         , g_files('MATERIALIZED_VIEW') AS filename
      FROM dba_mviews
     WHERE owner = g_user;

  TYPE type_tab_mviews IS TABLE OF g_cur_mviews%ROWTYPE;

  g_tab_mviews              type_tab_mviews;

  CURSOR g_cur_dblinks IS
    SELECT l.*
         , TO_CLOB(NULL) AS dblink_script
         , g_files('DATABASE_LINK') AS filename
      FROM dba_db_links l
     WHERE owner = g_user;

  TYPE type_tab_dblinks IS TABLE OF g_cur_dblinks%ROWTYPE;

  g_tab_dblinks             type_tab_dblinks;

  CURSOR g_cur_procedures IS
    SELECT object_name AS procedure_name
         , TO_CLOB(NULL) AS procedure_script
         , g_files('PROCEDURE') AS filename
      FROM dba_procedures
     WHERE owner = g_user
       AND object_type = 'PROCEDURE';

  TYPE type_tab_procedures IS TABLE OF g_cur_procedures%ROWTYPE;

  g_tab_procedures          type_tab_procedures;

  CURSOR g_cur_functions IS
    SELECT object_name AS function_name
         , TO_CLOB(NULL) AS function_script
         , g_files('FUNCTION') AS filename
      FROM dba_procedures
     WHERE owner = g_user
       AND object_type = 'FUNCTION';

  TYPE type_tab_functions IS TABLE OF g_cur_functions%ROWTYPE;

  g_tab_functions           type_tab_functions;

  g_bulk_limit              NUMBER := 10000;

  ------------------------------------------------------------------------------
  -- implementation of public and private procedures / functions
  ------------------------------------------------------------------------------
  PROCEDURE lp_config_dbms_metadata(p_pretty_yn               IN BOOLEAN DEFAULT TRUE
                                  , p_constraints_yn          IN BOOLEAN DEFAULT TRUE
                                  , p_refconstraints_yn       IN BOOLEAN DEFAULT FALSE
                                  , p_partitioning_yn         IN BOOLEAN DEFAULT TRUE
                                  , p_tablespace_yn           IN BOOLEAN DEFAULT FALSE
                                  , p_storage_yn              IN BOOLEAN DEFAULT FALSE
                                  , p_segment_attr_yn         IN BOOLEAN DEFAULT FALSE
                                  , p_sqlterminator_yn        IN BOOLEAN DEFAULT TRUE
                                  , p_constraints_as_alter_yn IN BOOLEAN DEFAULT FALSE
                                  , p_emit_schema_yn          IN BOOLEAN DEFAULT FALSE)
  IS
  BEGIN
    DBMS_METADATA.set_transform_param(transform_handle => DBMS_METADATA.session_transform
                                    , name             => 'PRETTY'
                                    , VALUE            => p_pretty_yn);

    DBMS_METADATA.set_transform_param(transform_handle => DBMS_METADATA.session_transform
                                    , name             => 'CONSTRAINTS'
                                    , VALUE            => p_constraints_yn);

    DBMS_METADATA.set_transform_param(transform_handle => DBMS_METADATA.session_transform
                                    , name             => 'REF_CONSTRAINTS'
                                    , VALUE            => p_refconstraints_yn);

    DBMS_METADATA.set_transform_param(transform_handle => DBMS_METADATA.session_transform
                                    , name             => 'PARTITIONING'
                                    , VALUE            => p_partitioning_yn);

    DBMS_METADATA.set_transform_param(transform_handle => DBMS_METADATA.session_transform
                                    , name             => 'TABLESPACE'
                                    , VALUE            => p_tablespace_yn);

    DBMS_METADATA.set_transform_param(transform_handle => DBMS_METADATA.session_transform
                                    , name             => 'STORAGE'
                                    , VALUE            => p_storage_yn);

    DBMS_METADATA.set_transform_param(transform_handle => DBMS_METADATA.session_transform
                                    , name             => 'SEGMENT_ATTRIBUTES'
                                    , VALUE            => p_segment_attr_yn);

    DBMS_METADATA.set_transform_param(transform_handle => DBMS_METADATA.session_transform
                                    , name             => 'SQLTERMINATOR'
                                    , VALUE            => p_sqlterminator_yn);

    DBMS_METADATA.set_transform_param(transform_handle => DBMS_METADATA.session_transform
                                    , name             => 'CONSTRAINTS_AS_ALTER'
                                    , VALUE            => p_constraints_as_alter_yn);

    DBMS_METADATA.set_transform_param(transform_handle => DBMS_METADATA.session_transform
                                    , name             => 'EMIT_SCHEMA'
                                    , VALUE            => p_emit_schema_yn);
  END lp_config_dbms_metadata;

  FUNCTION lp_get_template(p_object IN maint_waas.meta_code_template.object%TYPE)
    RETURN CLOB
  IS
    CURSOR v_template(p_object IN maint_waas.meta_code_template.object%TYPE)
    IS
      SELECT script_template
        FROM maint_waas.meta_code_template
       WHERE object = p_object;

    v_template_clob maint_waas.meta_code_template.script_template%TYPE;
  BEGIN
    ----------------------------------------------------------------------------
    -- check the param
    ----------------------------------------------------------------------------
    IF (p_object IS NOT NULL)
    THEN
      --------------------------------------------------------------------------
      -- get the template from maint_waas.meta_code_template
      --------------------------------------------------------------------------
      OPEN v_template(p_object => p_object);

      FETCH v_template INTO v_template_clob;

      CLOSE v_template;
    END IF;

    RETURN v_template_clob;
  END lp_get_template;

  FUNCTION lp_prepare_filename(p_object IN maint_waas.meta_code_versioning.object%TYPE
                             , p_name   IN maint_waas.meta_code_versioning.name%TYPE)
    RETURN maint_waas.meta_code_versioning.filename%TYPE
  IS
    v_filename maint_waas.meta_code_versioning.filename%TYPE;
  BEGIN
    v_filename := REPLACE(g_files(p_object), '###NAME###', p_name);
    v_filename := REPLACE(v_filename, '###OWNER###', g_user);

    RETURN v_filename;
  END lp_prepare_filename;

  PROCEDURE lp_delete_scripts_of_type(p_object IN maint_waas.meta_code_versioning.object%TYPE)
  IS
  BEGIN
    ----------------------------------------------------------------------------
    -- delete existing scripts from user
    ----------------------------------------------------------------------------
    DELETE FROM maint_waas.meta_code_versioning
          WHERE schema = g_user
            AND object = p_object;

    COMMIT;
  END lp_delete_scripts_of_type;

  PROCEDURE ep_create_sequences(p_user IN all_users.username%TYPE DEFAULT USER)
  IS
    v_sequence_template CLOB;
    v_generated         CLOB;
  BEGIN
    ----------------------------------------------------------------------------
    -- initialization part
    ----------------------------------------------------------------------------
    DBMS_OUTPUT.put_line('create sequences');

    g_user              := p_user;

    lp_delete_scripts_of_type(p_object => 'SEQUENCE');

    v_sequence_template := lp_get_template(p_object => 'SEQUENCE');

    IF (g_cur_sequences%ISOPEN)
    THEN
      CLOSE g_cur_sequences;
    END IF;

    lp_config_dbms_metadata(p_sqlterminator_yn => FALSE);

    ----------------------------------------------------------------------------
    -- generate  script for each sequence
    ----------------------------------------------------------------------------
    OPEN g_cur_sequences;

    LOOP
      FETCH g_cur_sequences BULK COLLECT INTO g_tab_sequences LIMIT g_bulk_limit;

      EXIT WHEN g_tab_sequences.COUNT = 0;

      FOR i IN g_tab_sequences.FIRST .. g_tab_sequences.LAST
      LOOP
        ------------------------------------------------------------------------
        -- generated script based on the template and save it
        -- within within the collection
        ------------------------------------------------------------------------
        g_tab_sequences(i).sequence_script := v_sequence_template;

        v_generated                        :=
          DBMS_METADATA.get_ddl(object_type => 'SEQUENCE', name => g_tab_sequences(i).sequence_name, schema => g_user);

        g_tab_sequences(i).sequence_script :=
          utils_bl.replace_clob(p_clob => g_tab_sequences(i).sequence_script
                              , p_what => '###SEQUENCE_NAME###'
                              , p_with => g_tab_sequences(i).sequence_name);

        g_tab_sequences(i).sequence_script :=
          utils_bl.replace_clob(p_clob => g_tab_sequences(i).sequence_script
                              , p_what => '###GENERATED_CODE###'
                              , p_with => TRIM(v_generated));

        g_tab_sequences(i).sequence_script :=
          utils_bl.replace_clob(p_clob => g_tab_sequences(i).sequence_script, p_what => '###OWNER###', p_with => g_user);

        g_tab_sequences(i).filename        :=
          lp_prepare_filename(p_object => 'SEQUENCE', p_name => g_tab_sequences(i).sequence_name);
      END LOOP;

      --------------------------------------------------------------------------
      -- bulk insert all scripts from collection
      --------------------------------------------------------------------------
      FORALL i IN INDICES OF g_tab_sequences
        INSERT INTO maint_waas.meta_code_versioning(id
                                                  , schema
                                                  , object
                                                  , name
                                                  , filename
                                                  , script
                                                  , created_at)
             VALUES (maint_waas.meta_code_versioning_seq.NEXTVAL
                   , g_user
                   , 'SEQUENCE'
                   , g_tab_sequences(i).sequence_name
                   , g_tab_sequences(i).filename
                   , g_tab_sequences(i).sequence_script
                   , SYSDATE);
    END LOOP;

    COMMIT;

    CLOSE g_cur_sequences;

    lp_config_dbms_metadata(p_sqlterminator_yn => TRUE);
  END ep_create_sequences;

  PROCEDURE ep_create_tables(p_user IN all_users.username%TYPE DEFAULT USER)
  IS
    v_table_template       CLOB;
    v_generated            CLOB;
    v_comments             CLOB;

    v_example_col_datatype all_tab_cols.data_type%TYPE;
  BEGIN
    ----------------------------------------------------------------------------
    -- initialization part
    ----------------------------------------------------------------------------
    DBMS_OUTPUT.put_line('create tables');

    g_user           := p_user;

    lp_delete_scripts_of_type(p_object => 'TABLE');

    v_table_template := lp_get_template(p_object => 'TABLE');

    IF (g_cur_tables%ISOPEN)
    THEN
      CLOSE g_cur_tables;
    END IF;

    lp_config_dbms_metadata(p_sqlterminator_yn => FALSE);

    ----------------------------------------------------------------------------
    -- generate  script for each table
    ----------------------------------------------------------------------------
    OPEN g_cur_tables;

    LOOP
      FETCH g_cur_tables BULK COLLECT INTO g_tab_tables LIMIT g_bulk_limit;

      EXIT WHEN g_tab_tables.COUNT = 0;

      FOR i IN g_tab_tables.FIRST .. g_tab_tables.LAST
      LOOP
        ------------------------------------------------------------------------
        -- generated script based on the template and save it
        -- within within the collection
        ------------------------------------------------------------------------
        g_tab_tables(i).table_script := v_table_template;

        v_generated                  :=
          DBMS_METADATA.get_ddl(object_type => 'TABLE', name => g_tab_tables(i).table_name, schema => g_user);

        g_tab_tables(i).table_script :=
          utils_bl.replace_clob(p_clob => g_tab_tables(i).table_script
                              , p_what => '###TABLE_NAME###'
                              , p_with => g_tab_tables(i).table_name);

        g_tab_tables(i).table_script :=
          utils_bl.replace_clob(p_clob => g_tab_tables(i).table_script
                              , p_what => '###GENERATED_CODE###'
                              , p_with => TRIM(v_generated));

        g_tab_tables(i).table_script :=
          utils_bl.replace_clob(p_clob => g_tab_tables(i).table_script, p_what => '###OWNER###', p_with => g_user);

        ------------------------------------------------------------------------
        -- generate table and column comments
        ------------------------------------------------------------------------
        lp_config_dbms_metadata(p_sqlterminator_yn => TRUE);

        ------------------------------------------------------------------------
        -- unfortunately get_dependent_ddl throws error when no comment is there
        ------------------------------------------------------------------------
        DECLARE
          no_comments EXCEPTION;
          PRAGMA EXCEPTION_INIT (no_comments, -31608);
        BEGIN
          v_comments :=
            DBMS_METADATA.get_dependent_ddl(object_type        => 'COMMENT'
                                          , base_object_name   => g_tab_tables(i).table_name
                                          , base_object_schema => g_user);
        EXCEPTION
          WHEN no_comments
          THEN
            v_comments := '-- no comments defined for ' || g_tab_tables(i).table_name;
        END;

        g_tab_tables(i).table_script :=
          utils_bl.replace_clob(p_clob => g_tab_tables(i).table_script
                              , p_what => '###TABLE_AND_COLUMN_COMMENTS###'
                              , p_with => LTRIM(v_comments, CHR(10)));

        lp_config_dbms_metadata(p_sqlterminator_yn => FALSE);

        ------------------------------------------------------------------------
        -- generate filename
        ------------------------------------------------------------------------
        g_tab_tables(i).filename     := lp_prepare_filename(p_object => 'TABLE', p_name => g_tab_tables(i).table_name);

        ------------------------------------------------------------------------
        -- generate adding an example column code
        ------------------------------------------------------------------------
        FOR example IN (SELECT *
                          FROM dba_tab_cols
                         WHERE owner = g_user
                           AND table_name = g_tab_tables(i).table_name
                           AND column_id = 1)
        LOOP
          v_example_col_datatype :=
               example.data_type
            || CASE WHEN example.data_type LIKE '%CHAR%' THEN ' (' || example.data_length || ')' ELSE NULL END;

          g_tab_tables(i).table_script :=
            utils_bl.replace_clob(p_clob => g_tab_tables(i).table_script
                                , p_what => '###COLUMN_NAME###'
                                , p_with => example.column_name);

          g_tab_tables(i).table_script :=
            utils_bl.replace_clob(p_clob => g_tab_tables(i).table_script
                                , p_what => '###COLUMN_DATA_TYPE###'
                                , p_with => v_example_col_datatype);
        END LOOP; -- example column
      END LOOP; -- tables

      --------------------------------------------------------------------------
      -- bulk insert all scripts from collection
      --------------------------------------------------------------------------
      FORALL i IN INDICES OF g_tab_tables
        INSERT INTO maint_waas.meta_code_versioning(id
                                                  , schema
                                                  , object
                                                  , name
                                                  , filename
                                                  , script
                                                  , created_at)
             VALUES (maint_waas.meta_code_versioning_seq.NEXTVAL
                   , g_user
                   , 'TABLE'
                   , g_tab_tables(i).table_name
                   , g_tab_tables(i).filename
                   , g_tab_tables(i).table_script
                   , SYSDATE);
    END LOOP;

    COMMIT;

    CLOSE g_cur_tables;

    lp_config_dbms_metadata(p_sqlterminator_yn => TRUE);
  END ep_create_tables;

  PROCEDURE ep_create_fk_constraints(p_user IN all_users.username%TYPE DEFAULT USER)
  IS
    v_fk_constraint_template      CLOB;
    v_generated                   CLOB;
    v_constraint_counts_per_table BINARY_INTEGER;
    v_constraints_per_table       DBMS_UTILITY.lname_array;
  BEGIN
    ----------------------------------------------------------------------------
    -- initialization part
    ----------------------------------------------------------------------------
    DBMS_OUTPUT.put_line('create FK constraints');

    g_user                   := p_user;

    lp_delete_scripts_of_type(p_object => 'FK_CONSTRAINT');

    v_fk_constraint_template := lp_get_template(p_object => 'FK_CONSTRAINT');

    IF (g_cur_fk_constraints%ISOPEN)
    THEN
      CLOSE g_cur_fk_constraints;
    END IF;

    lp_config_dbms_metadata(p_sqlterminator_yn => FALSE, p_constraints_as_alter_yn => TRUE);

    ----------------------------------------------------------------------------
    -- generate  script for each table with their fk constraints
    ----------------------------------------------------------------------------
    OPEN g_cur_fk_constraints;

    LOOP
      FETCH g_cur_fk_constraints BULK COLLECT INTO g_tab_fk_constraints LIMIT g_bulk_limit;

      EXIT WHEN g_tab_fk_constraints.COUNT = 0;

      FOR i IN g_tab_fk_constraints.FIRST .. g_tab_fk_constraints.LAST
      LOOP
        v_constraint_counts_per_table := NULL;
        v_generated                   := NULL;
        v_constraints_per_table.delete;

        ------------------------------------------------------------------------
        -- each g_tab_fk_constraints element is on table granularity because
        -- only 1 FK constraints script per table should be created, so one
        -- table record can have multiple fk constraints in column
        -- FK_CONSTRAINT_LIST that have to be splitted
        ------------------------------------------------------------------------
        DBMS_UTILITY.comma_to_table(list   => g_tab_fk_constraints(i).fk_constraint_list
                                  , tablen => v_constraint_counts_per_table
                                  , tab    => v_constraints_per_table);

        FOR constr IN 1 .. v_constraint_counts_per_table
        LOOP
          ----------------------------------------------------------------------
          -- generated script based on the template and save it
          -- within within the collection
          ----------------------------------------------------------------------
          g_tab_fk_constraints(i).fk_constraint_script :=
            g_tab_fk_constraints(i).fk_constraint_script || v_fk_constraint_template;

          g_tab_fk_constraints(i).filename :=
            lp_prepare_filename(p_object => 'FK_CONSTRAINT', p_name => g_tab_fk_constraints(i).table_name || '_FKs');

          v_generated :=
            DBMS_METADATA.get_ddl(object_type => 'REF_CONSTRAINT'
                                , name        => v_constraints_per_table(constr)
                                , schema      => g_user);

          g_tab_fk_constraints(i).fk_constraint_script :=
            utils_bl.replace_clob(p_clob => g_tab_fk_constraints(i).fk_constraint_script
                                , p_what => '###FK_CONSTRAINT###'
                                , p_with => v_constraints_per_table(constr));

          g_tab_fk_constraints(i).fk_constraint_script :=
            utils_bl.replace_clob(p_clob => g_tab_fk_constraints(i).fk_constraint_script
                                , p_what => '###GENERATED_CODE###'
                                , p_with => TRIM(v_generated));

          g_tab_fk_constraints(i).fk_constraint_script :=
            utils_bl.replace_clob(p_clob => g_tab_fk_constraints(i).fk_constraint_script
                                , p_what => '###OWNER###'
                                , p_with => g_user);
        END LOOP; -- each constraint per table loop
      END LOOP; -- each table loop

      --------------------------------------------------------------------------
      -- bulk insert all scripts from collection
      --------------------------------------------------------------------------
      FORALL i IN INDICES OF g_tab_fk_constraints
        INSERT INTO maint_waas.meta_code_versioning(id
                                                  , schema
                                                  , object
                                                  , name
                                                  , filename
                                                  , script
                                                  , created_at)
             VALUES (maint_waas.meta_code_versioning_seq.NEXTVAL
                   , g_user
                   , 'FK_CONSTRAINT'
                   , g_tab_fk_constraints(i).table_name || '_FKs'
                   , g_tab_fk_constraints(i).filename
                   , g_tab_fk_constraints(i).fk_constraint_script
                   , SYSDATE);
    END LOOP;

    COMMIT;

    CLOSE g_cur_fk_constraints;

    lp_config_dbms_metadata(p_sqlterminator_yn => TRUE, p_constraints_as_alter_yn => FALSE);
  END ep_create_fk_constraints;

  PROCEDURE ep_create_indexes(p_user IN all_users.username%TYPE DEFAULT USER)
  IS
    v_index_template CLOB;
    v_generated      CLOB;
  BEGIN
    ----------------------------------------------------------------------------
    -- initialization part
    ----------------------------------------------------------------------------
    DBMS_OUTPUT.put_line('create indexes');

    g_user           := p_user;

    lp_delete_scripts_of_type(p_object => 'INDEX');

    v_index_template := lp_get_template(p_object => 'INDEX');

    IF (g_cur_indexes%ISOPEN)
    THEN
      CLOSE g_cur_indexes;
    END IF;

    lp_config_dbms_metadata(p_partitioning_yn => FALSE, p_sqlterminator_yn => FALSE);

    ----------------------------------------------------------------------------
    -- generate  script for each sequence
    ----------------------------------------------------------------------------
    OPEN g_cur_indexes;

    LOOP
      FETCH g_cur_indexes BULK COLLECT INTO g_tab_indexes LIMIT g_bulk_limit;

      EXIT WHEN g_tab_indexes.COUNT = 0;

      FOR i IN g_tab_indexes.FIRST .. g_tab_indexes.LAST
      LOOP
        ------------------------------------------------------------------------
        -- generated script based on the template and save it
        -- within within the collection
        ------------------------------------------------------------------------
        g_tab_indexes(i).index_script := v_index_template;

        v_generated                   :=
          DBMS_METADATA.get_ddl(object_type => 'INDEX', name => g_tab_indexes(i).index_name, schema => g_user);

        g_tab_indexes(i).index_script :=
          utils_bl.replace_clob(p_clob => g_tab_indexes(i).index_script
                              , p_what => '###INDEX_NAME###'
                              , p_with => g_tab_indexes(i).index_name);

        g_tab_indexes(i).index_script :=
          utils_bl.replace_clob(p_clob => g_tab_indexes(i).index_script
                              , p_what => '###GENERATED_CODE###'
                              , p_with => TRIM(v_generated));

        g_tab_indexes(i).index_script :=
          utils_bl.replace_clob(p_clob => g_tab_indexes(i).index_script, p_what => '###OWNER###', p_with => g_user);

        g_tab_indexes(i).filename     :=
          lp_prepare_filename(p_object => 'INDEX'
                            , p_name   => g_tab_indexes(i).table_name || '_' || g_tab_indexes(i).index_name);
      END LOOP;

      --------------------------------------------------------------------------
      -- bulk insert all scripts from collection
      --------------------------------------------------------------------------
      FORALL i IN INDICES OF g_tab_indexes
        INSERT INTO maint_waas.meta_code_versioning(id
                                                  , schema
                                                  , object
                                                  , name
                                                  , filename
                                                  , script
                                                  , created_at)
             VALUES (maint_waas.meta_code_versioning_seq.NEXTVAL
                   , g_user
                   , 'INDEX'
                   , g_tab_indexes(i).index_name
                   , g_tab_indexes(i).filename
                   , g_tab_indexes(i).index_script
                   , SYSDATE);
    END LOOP;

    COMMIT;

    CLOSE g_cur_indexes;

    lp_config_dbms_metadata(p_partitioning_yn => TRUE, p_sqlterminator_yn => TRUE);
  END ep_create_indexes;

  PROCEDURE ep_create_packages_api(p_user IN all_users.username%TYPE DEFAULT USER)
  IS
  BEGIN
    ----------------------------------------------------------------------------
    -- initialization part
    ----------------------------------------------------------------------------
    DBMS_OUTPUT.put_line('create packages for table API');

    g_user := p_user;

    lp_delete_scripts_of_type(p_object => 'PACKAGE_API');

    IF (g_cur_packages_api%ISOPEN)
    THEN
      CLOSE g_cur_packages_api;
    END IF;

    ----------------------------------------------------------------------------
    -- generate  script for each package spec
    ----------------------------------------------------------------------------
    OPEN g_cur_packages_api;

    LOOP
      FETCH g_cur_packages_api BULK COLLECT INTO g_tab_packages_api LIMIT g_bulk_limit;

      EXIT WHEN g_tab_packages_api.COUNT = 0;

      FOR i IN g_tab_packages_api.FIRST .. g_tab_packages_api.LAST
      LOOP
        ------------------------------------------------------------------------
        -- generated script based on the template and save it
        -- within within the collection
        ------------------------------------------------------------------------
        g_tab_packages_api(i).package_script :=
          DBMS_METADATA.get_ddl(object_type => 'PACKAGE_SPEC'
                              , name        => g_tab_packages_api(i).object_name
                              , schema      => g_user);

        g_tab_packages_api(i).filename :=
          lp_prepare_filename(p_object => 'PACKAGE_API', p_name => g_tab_packages_api(i).object_name);
      END LOOP;

      --------------------------------------------------------------------------
      -- bulk insert all scripts from collection
      --------------------------------------------------------------------------
      FORALL i IN INDICES OF g_tab_packages_api
        INSERT INTO maint_waas.meta_code_versioning(id
                                                  , schema
                                                  , object
                                                  , name
                                                  , filename
                                                  , script
                                                  , created_at)
             VALUES (maint_waas.meta_code_versioning_seq.NEXTVAL
                   , g_user
                   , 'PACKAGE_API'
                   , g_tab_packages_api(i).object_name
                   , g_tab_packages_api(i).filename
                   , g_tab_packages_api(i).package_script
                   , SYSDATE);
    END LOOP;

    COMMIT;

    CLOSE g_cur_packages_api;

    ----------------------------------------------------------------------------
    -- generate  script for each package body
    ----------------------------------------------------------------------------
    lp_delete_scripts_of_type(p_object => 'PACKAGE_BODY_API');

    OPEN g_cur_package_api_bodies;

    LOOP
      FETCH g_cur_package_api_bodies BULK COLLECT INTO g_tab_packages_api_bodies LIMIT g_bulk_limit;

      EXIT WHEN g_tab_packages_api_bodies.COUNT = 0;

      FOR i IN g_tab_packages_api_bodies.FIRST .. g_tab_packages_api_bodies.LAST
      LOOP
        ------------------------------------------------------------------------
        -- generated script based on the template and save it
        -- within within the collection
        ------------------------------------------------------------------------
        g_tab_packages_api_bodies(i).package_script :=
          DBMS_METADATA.get_ddl(object_type => 'PACKAGE_BODY'
                              , name        => g_tab_packages_api_bodies(i).object_name
                              , schema      => g_user);

        g_tab_packages_api_bodies(i).filename :=
          lp_prepare_filename(p_object => 'PACKAGE_BODY_API', p_name => g_tab_packages_api_bodies(i).object_name);
      END LOOP;

      --------------------------------------------------------------------------
      -- bulk insert all scripts from collection
      --------------------------------------------------------------------------
      FORALL i IN INDICES OF g_tab_packages_api_bodies
        INSERT INTO maint_waas.meta_code_versioning(id
                                                  , schema
                                                  , object
                                                  , name
                                                  , filename
                                                  , script
                                                  , created_at)
             VALUES (maint_waas.meta_code_versioning_seq.NEXTVAL
                   , g_user
                   , 'PACKAGE_BODY_API'
                   , g_tab_packages_api_bodies(i).object_name
                   , g_tab_packages_api_bodies(i).filename
                   , g_tab_packages_api_bodies(i).package_script
                   , SYSDATE);
    END LOOP;

    COMMIT;

    CLOSE g_cur_package_api_bodies;
  END ep_create_packages_api;

  PROCEDURE ep_create_packages_bl(p_user IN all_users.username%TYPE DEFAULT USER)
  IS
  BEGIN
    ----------------------------------------------------------------------------
    -- initialization part
    ----------------------------------------------------------------------------
    DBMS_OUTPUT.put_line('create packages for business logic');

    g_user := p_user;

    lp_delete_scripts_of_type(p_object => 'PACKAGE');

    IF (g_cur_packages_bl%ISOPEN)
    THEN
      CLOSE g_cur_packages_bl;
    END IF;

    IF (g_cur_package_bl_bodies%ISOPEN)
    THEN
      CLOSE g_cur_package_bl_bodies;
    END IF;

    ----------------------------------------------------------------------------
    -- generate  script for each package spec
    ----------------------------------------------------------------------------
    OPEN g_cur_packages_bl;

    LOOP
      FETCH g_cur_packages_bl BULK COLLECT INTO g_tab_packages_bl LIMIT g_bulk_limit;

      EXIT WHEN g_tab_packages_bl.COUNT = 0;

      FOR i IN g_tab_packages_bl.FIRST .. g_tab_packages_bl.LAST
      LOOP
        ------------------------------------------------------------------------
        -- generated script based on the template and save it
        -- within within the collection
        ------------------------------------------------------------------------
        g_tab_packages_bl(i).package_script :=
          TRIM(
            DBMS_METADATA.get_ddl(object_type => 'PACKAGE_SPEC'
                                , name        => g_tab_packages_bl(i).object_name
                                , schema      => g_user));

        g_tab_packages_bl(i).filename :=
          lp_prepare_filename(p_object => 'PACKAGE', p_name => g_tab_packages_bl(i).object_name);
      END LOOP;

      --------------------------------------------------------------------------
      -- bulk insert all scripts from collection
      --------------------------------------------------------------------------
      FORALL i IN INDICES OF g_tab_packages_bl
        INSERT INTO maint_waas.meta_code_versioning(id
                                                  , schema
                                                  , object
                                                  , name
                                                  , filename
                                                  , script
                                                  , created_at)
             VALUES (maint_waas.meta_code_versioning_seq.NEXTVAL
                   , g_user
                   , 'PACKAGE'
                   , g_tab_packages_bl(i).object_name
                   , g_tab_packages_bl(i).filename
                   , g_tab_packages_bl(i).package_script
                   , SYSDATE);
    END LOOP;

    COMMIT;

    CLOSE g_cur_packages_bl;

    ----------------------------------------------------------------------------
    -- generate  script for each package body
    ----------------------------------------------------------------------------
    lp_delete_scripts_of_type(p_object => 'PACKAGE_BODY');

    OPEN g_cur_package_bl_bodies;

    LOOP
      FETCH g_cur_package_bl_bodies BULK COLLECT INTO g_tab_packages_bl_bodies LIMIT g_bulk_limit;

      EXIT WHEN g_tab_packages_bl_bodies.COUNT = 0;

      FOR i IN g_tab_packages_bl_bodies.FIRST .. g_tab_packages_bl_bodies.LAST
      LOOP
        ------------------------------------------------------------------------
        -- generated script based on the template and save it
        -- within within the collection
        ------------------------------------------------------------------------
        g_tab_packages_bl_bodies(i).package_script :=
          DBMS_METADATA.get_ddl(object_type => 'PACKAGE_BODY'
                              , name        => g_tab_packages_bl_bodies(i).object_name
                              , schema      => g_user);

        g_tab_packages_bl_bodies(i).filename :=
          lp_prepare_filename(p_object => 'PACKAGE_BODY', p_name => g_tab_packages_bl_bodies(i).object_name);
      END LOOP;

      --------------------------------------------------------------------------
      -- bulk insert all scripts from collection
      --------------------------------------------------------------------------
      FORALL i IN INDICES OF g_tab_packages_bl_bodies
        INSERT INTO maint_waas.meta_code_versioning(id
                                                  , schema
                                                  , object
                                                  , name
                                                  , filename
                                                  , script
                                                  , created_at)
             VALUES (maint_waas.meta_code_versioning_seq.NEXTVAL
                   , g_user
                   , 'PACKAGE_BODY'
                   , g_tab_packages_bl_bodies(i).object_name
                   , g_tab_packages_bl_bodies(i).filename
                   , g_tab_packages_bl_bodies(i).package_script
                   , SYSDATE);
    END LOOP;

    COMMIT;

    CLOSE g_cur_package_bl_bodies;
  END ep_create_packages_bl;

  PROCEDURE ep_create_synonyms(p_user IN all_users.username%TYPE DEFAULT USER)
  IS
  BEGIN
    ----------------------------------------------------------------------------
    -- initialization part
    ----------------------------------------------------------------------------
    DBMS_OUTPUT.put_line('create synonyms');

    g_user := p_user;

    lp_delete_scripts_of_type(p_object => 'SYNONYM');

    IF (g_cur_synonyms%ISOPEN)
    THEN
      CLOSE g_cur_synonyms;
    END IF;

    lp_config_dbms_metadata(p_emit_schema_yn => TRUE);

    ----------------------------------------------------------------------------
    -- generate  script for each synonym
    ----------------------------------------------------------------------------
    OPEN g_cur_synonyms;

    LOOP
      FETCH g_cur_synonyms BULK COLLECT INTO g_tab_synonyms LIMIT g_bulk_limit;

      EXIT WHEN g_tab_synonyms.COUNT = 0;

      FOR i IN g_tab_synonyms.FIRST .. g_tab_synonyms.LAST
      LOOP
        ------------------------------------------------------------------------
        -- generated script based on the template and save it
        -- within within the collection
        ------------------------------------------------------------------------
        g_tab_synonyms(i).synonym_script :=
          TRIM(DBMS_METADATA.get_ddl(object_type => 'SYNONYM', name => g_tab_synonyms(i).synonym_name, schema => g_user));

        g_tab_synonyms(i).filename :=
          lp_prepare_filename(p_object => 'SYNONYM'
                            , p_name   => g_tab_synonyms(i).table_owner || '_' || g_tab_synonyms(i).synonym_name);
      END LOOP;

      --------------------------------------------------------------------------
      -- bulk insert all scripts from collection
      --------------------------------------------------------------------------
      FORALL i IN INDICES OF g_tab_synonyms
        INSERT INTO maint_waas.meta_code_versioning(id
                                                  , schema
                                                  , object
                                                  , name
                                                  , filename
                                                  , script
                                                  , created_at)
             VALUES (maint_waas.meta_code_versioning_seq.NEXTVAL
                   , g_user
                   , 'SYNONYM'
                   , g_tab_synonyms(i).synonym_name
                   , g_tab_synonyms(i).filename
                   , g_tab_synonyms(i).synonym_script
                   , SYSDATE);
    END LOOP;

    COMMIT;

    CLOSE g_cur_synonyms;

    lp_config_dbms_metadata(p_emit_schema_yn => FALSE);
  END ep_create_synonyms;

  PROCEDURE ep_create_triggers(p_user IN all_users.username%TYPE DEFAULT USER)
  IS
  BEGIN
    ----------------------------------------------------------------------------
    -- initialization part
    ----------------------------------------------------------------------------
    DBMS_OUTPUT.put_line('create triggers');

    g_user := p_user;

    lp_delete_scripts_of_type(p_object => 'TRIGGER');

    IF (g_cur_triggers%ISOPEN)
    THEN
      CLOSE g_cur_triggers;
    END IF;

    ----------------------------------------------------------------------------
    -- generate  script for each trigger
    ----------------------------------------------------------------------------
    OPEN g_cur_triggers;

    LOOP
      FETCH g_cur_triggers BULK COLLECT INTO g_tab_triggers LIMIT g_bulk_limit;

      EXIT WHEN g_tab_triggers.COUNT = 0;

      FOR i IN g_tab_triggers.FIRST .. g_tab_triggers.LAST
      LOOP
        ------------------------------------------------------------------------
        -- generated script based on the template and save it
        -- within within the collection
        ------------------------------------------------------------------------
        g_tab_triggers(i).trigger_script :=
          TRIM(DBMS_METADATA.get_ddl(object_type => 'TRIGGER', name => g_tab_triggers(i).trigger_name, schema => g_user));

        g_tab_triggers(i).filename :=
          lp_prepare_filename(p_object => 'TRIGGER', p_name => g_tab_triggers(i).trigger_name);
      END LOOP;

      --------------------------------------------------------------------------
      -- bulk insert all scripts from collection
      --------------------------------------------------------------------------
      FORALL i IN INDICES OF g_tab_triggers
        INSERT INTO maint_waas.meta_code_versioning(id
                                                  , schema
                                                  , object
                                                  , name
                                                  , filename
                                                  , script
                                                  , created_at)
             VALUES (maint_waas.meta_code_versioning_seq.NEXTVAL
                   , g_user
                   , 'TRIGGER'
                   , g_tab_triggers(i).trigger_name
                   , g_tab_triggers(i).filename
                   , g_tab_triggers(i).trigger_script
                   , SYSDATE);
    END LOOP;

    COMMIT;

    CLOSE g_cur_triggers;
  END ep_create_triggers;

  PROCEDURE ep_create_types(p_user IN all_users.username%TYPE DEFAULT USER)
  IS
    v_generated     CLOB;
    v_type_template CLOB;
  BEGIN
    ----------------------------------------------------------------------------
    -- initialization part
    ----------------------------------------------------------------------------
    DBMS_OUTPUT.put_line('create types');

    g_user          := p_user;

    lp_delete_scripts_of_type(p_object => 'TYPE');

    v_type_template := lp_get_template(p_object => 'TYPE_SPEC');

    IF (g_cur_types%ISOPEN)
    THEN
      CLOSE g_cur_types;
    END IF;

    ----------------------------------------------------------------------------
    -- generate  script for each Type
    ----------------------------------------------------------------------------
    OPEN g_cur_types;

    LOOP
      FETCH g_cur_types BULK COLLECT INTO g_tab_types LIMIT g_bulk_limit;

      EXIT WHEN g_tab_types.COUNT = 0;

      FOR i IN g_tab_types.FIRST .. g_tab_types.LAST
      LOOP
        ------------------------------------------------------------------------
        -- generated script based on the template and save it
        -- within within the collection
        ------------------------------------------------------------------------
        g_tab_types(i).type_script := v_type_template;

        v_generated                :=
          DBMS_METADATA.get_ddl(object_type => 'TYPE_SPEC', name => g_tab_types(i).type_name, schema => g_user);

        utils_bl.replace_clob(p_clob => g_tab_types(i).type_script
                            , p_what => '###TYPE_NAME###'
                            , p_with => g_tab_types(i).type_name);

        g_tab_types(i).type_script :=
          utils_bl.replace_clob(p_clob => g_tab_types(i).type_script
                              , p_what => '###GENERATED_CODE###'
                              , p_with => v_generated);

        utils_bl.replace_clob(p_clob => g_tab_types(i).type_script, p_what => '###OWNER###', p_with => g_user);

        ------------------------------------------------------------------------
        -- remove qoutes, there is no dbms_metadata transforms
        ------------------------------------------------------------------------
        utils_bl.replace_clob(p_clob => g_tab_types(i).type_script
                            , p_what => '"' || g_tab_types(i).type_name || '"'
                            , p_with => g_tab_types(i).type_name);

        g_tab_types(i).filename    := lp_prepare_filename(p_object => 'TYPE', p_name => g_tab_types(i).type_name);
      END LOOP;

      --------------------------------------------------------------------------
      -- bulk insert all scripts from collection
      --------------------------------------------------------------------------
      FORALL i IN INDICES OF g_tab_types
        INSERT INTO maint_waas.meta_code_versioning(id
                                                  , schema
                                                  , object
                                                  , name
                                                  , filename
                                                  , script
                                                  , created_at)
             VALUES (maint_waas.meta_code_versioning_seq.NEXTVAL
                   , g_user
                   , 'TYPE'
                   , g_tab_types(i).type_name
                   , g_tab_types(i).filename
                   , g_tab_types(i).type_script
                   , SYSDATE);
    END LOOP;

    COMMIT;

    CLOSE g_cur_types;

    ----------------------------------------------------------------------------
    -- generate  script for each Type Body
    ----------------------------------------------------------------------------
    lp_delete_scripts_of_type(p_object => 'TYPE_BODY');

    OPEN g_cur_type_bodies;

    LOOP
      FETCH g_cur_type_bodies BULK COLLECT INTO g_tab_type_bodies LIMIT g_bulk_limit;

      EXIT WHEN g_tab_type_bodies.COUNT = 0;

      FOR i IN g_tab_type_bodies.FIRST .. g_tab_type_bodies.LAST
      LOOP
        ------------------------------------------------------------------------
        -- generated script based on the template and save it
        -- within within the collection
        -- enforce ';' at the end
        ------------------------------------------------------------------------
        g_tab_type_bodies(i).type_script :=
          DBMS_METADATA.get_ddl(object_type => 'TYPE_BODY', name => g_tab_type_bodies(i).type_name, schema => g_user);

        ------------------------------------------------------------------------
        -- remove qoutes, there is no dbms_metadata transforms
        ------------------------------------------------------------------------
        utils_bl.replace_clob(p_clob => g_tab_type_bodies(i).type_script
                            , p_what => '"' || g_tab_type_bodies(i).type_name || '"'
                            , p_with => g_tab_type_bodies(i).type_name);

        g_tab_type_bodies(i).filename :=
          lp_prepare_filename(p_object => 'TYPE_BODY', p_name => g_tab_type_bodies(i).type_name);
      END LOOP;

      --------------------------------------------------------------------------
      -- bulk insert all scripts from collection
      --------------------------------------------------------------------------
      FORALL i IN INDICES OF g_tab_type_bodies
        INSERT INTO maint_waas.meta_code_versioning(id
                                                  , schema
                                                  , object
                                                  , name
                                                  , filename
                                                  , script
                                                  , created_at)
             VALUES (maint_waas.meta_code_versioning_seq.NEXTVAL
                   , g_user
                   , 'TYPE_BODY'
                   , g_tab_type_bodies(i).type_name
                   , g_tab_type_bodies(i).filename
                   , g_tab_type_bodies(i).type_script
                   , SYSDATE);
    END LOOP;

    COMMIT;

    CLOSE g_cur_type_bodies;
  END ep_create_types;

  PROCEDURE ep_create_views(p_user IN all_users.username%TYPE DEFAULT USER)
  IS
  BEGIN
    ----------------------------------------------------------------------------
    -- initialization part
    ----------------------------------------------------------------------------
    DBMS_OUTPUT.put_line('create views');

    g_user := p_user;

    lp_delete_scripts_of_type(p_object => 'VIEW');

    IF (g_cur_views%ISOPEN)
    THEN
      CLOSE g_cur_views;
    END IF;

    ----------------------------------------------------------------------------
    -- generate  script for each view
    ----------------------------------------------------------------------------
    OPEN g_cur_views;

    LOOP
      FETCH g_cur_views BULK COLLECT INTO g_tab_views LIMIT g_bulk_limit;

      EXIT WHEN g_tab_views.COUNT = 0;

      FOR i IN g_tab_views.FIRST .. g_tab_views.LAST
      LOOP
        ------------------------------------------------------------------------
        -- generated script based on the template and save it
        -- within within the collection
        ------------------------------------------------------------------------
        g_tab_views(i).view_script :=
          TRIM(DBMS_METADATA.get_ddl(object_type => 'VIEW', name => g_tab_views(i).view_name, schema => g_user));

        g_tab_views(i).filename := lp_prepare_filename(p_object => 'VIEW', p_name => g_tab_views(i).view_name);
      END LOOP;

      --------------------------------------------------------------------------
      -- bulk insert all scripts from collection
      --------------------------------------------------------------------------
      FORALL i IN INDICES OF g_tab_views
        INSERT INTO maint_waas.meta_code_versioning(id
                                                  , schema
                                                  , object
                                                  , name
                                                  , filename
                                                  , script
                                                  , created_at)
             VALUES (maint_waas.meta_code_versioning_seq.NEXTVAL
                   , g_user
                   , 'VIEW'
                   , g_tab_views(i).view_name
                   , g_tab_views(i).filename
                   , g_tab_views(i).view_script
                   , SYSDATE);
    END LOOP;

    COMMIT;

    CLOSE g_cur_views;
  END ep_create_views;

  PROCEDURE ep_create_install_batch(p_user IN all_users.username%TYPE DEFAULT USER)
  IS
    v_install_batch_template CLOB;
    v_filename               meta_code_versioning.filename%TYPE;
  BEGIN
    ----------------------------------------------------------------------------
    --  insert install batch file
    ----------------------------------------------------------------------------
    DBMS_OUTPUT.put_line('create batch file for installation');

    g_user                   := p_user;

    v_filename               := lp_prepare_filename(p_object => 'INSTALL_BAT', p_name => g_user);

    lp_delete_scripts_of_type(p_object => 'INSTALL_BAT');

    v_install_batch_template := lp_get_template(p_object => 'INSTALL_BAT');

    INSERT INTO maint_waas.meta_code_versioning(id
                                              , schema
                                              , object
                                              , name
                                              , filename
                                              , script
                                              , created_at)
         VALUES (maint_waas.meta_code_versioning_seq.NEXTVAL
               , g_user
               , 'INSTALL_BAT'
               , v_filename
               , v_filename
               , REPLACE(v_install_batch_template, '###OWNER###', g_user)
               , SYSDATE);

    COMMIT;
  END ep_create_install_batch;

  PROCEDURE ep_create_install_sql(p_user IN all_users.username%TYPE DEFAULT USER)
  IS
    v_install_sql_template     CLOB;
    v_install_sql_prompt       CLOB;
    v_install_sql_recreate_api CLOB;
    v_install_sql_dml_example  CLOB;
    v_generated_list           CLOB;
    v_generated_promt          CLOB;
    v_filename                 meta_code_versioning.filename%TYPE;
    v_table_api_counter        NUMBER;
  BEGIN
    ----------------------------------------------------------------------------
    -- initialization part
    ----------------------------------------------------------------------------
    DBMS_OUTPUT.put_line('create sql file for installation');

    g_user                     := p_user;

    v_filename                 := lp_prepare_filename(p_object => 'INSTALL_SQL', p_name => g_user);

    lp_delete_scripts_of_type(p_object => 'INSTALL_SQL');

    v_install_sql_template     := lp_get_template(p_object => 'INSTALL_SQL');
    v_install_sql_prompt       := lp_get_template(p_object => 'INSTALL_SQL_PROMT');
    v_install_sql_recreate_api := lp_get_template(p_object => 'INSTALL_SQL_RECREATE_APIS');
    v_install_sql_dml_example  := lp_get_template(p_object => 'INSTALL_SQL_DML_EXAMPLE');

    ----------------------------------------------------------------------------
    -- insert all scripts into sql file
    ----------------------------------------------------------------------------
    FOR scripts
      IN (SELECT 'SEQUENCE' AS object_type
               , 'Sequences' AS prompt_substitution_string
               , '###SEQUENCE###' AS template_substitution_string
               , 1 AS forced_order
            FROM DUAL
          UNION ALL
          SELECT 'TABLE' AS object_type
               , 'Tables' AS prompt_substitution_string
               , '###TABLE###' AS template_substitution_string
               , 2 AS forced_order
            FROM DUAL
          UNION ALL
          SELECT 'INDEX' AS object_type
               , 'Indexes' AS prompt_substitution_string
               , '###INDEX###' AS template_substitution_string
               , 3 AS forced_order
            FROM DUAL
          UNION ALL
          SELECT 'FK_CONSTRAINT' AS object_type
               , 'Foreign Key Constraints' AS prompt_substitution_string
               , '###FK_CONSTRAINT###' AS template_substitution_string
               , 4 AS forced_order
            FROM DUAL
          UNION ALL
          SELECT 'TRIGGER' AS object_type
               , 'Triggers' AS prompt_substitution_string
               , '###TRIGGER###' AS template_substitution_string
               , 5 AS forced_order
            FROM DUAL
          UNION ALL
          SELECT 'DATABASE_LINK' AS object_type
               , 'Database Links' AS prompt_substitution_string
               , '###DATABASE_LINK###' AS template_substitution_string
               , 6 AS forced_order
            FROM DUAL
          UNION ALL
          SELECT 'SYNONYM' AS object_type
               , 'Synonyms' AS prompt_substitution_string
               , '###SYNONYM###' AS template_substitution_string
               , 7 AS forced_order
            FROM DUAL
          UNION ALL
          SELECT 'VIEW' AS object_type
               , 'Views' AS prompt_substitution_string
               , '###VIEW###' AS template_substitution_string
               , 8 AS forced_order
            FROM DUAL
          UNION ALL
          SELECT 'MATERIALIZED_VIEW' AS object_type
               , 'Materialize Views' AS prompt_substitution_string
               , '###MVIEW###' AS template_substitution_string
               , 9 AS forced_order
            FROM DUAL
          UNION ALL
          SELECT 'TYPE' AS object_type
               , 'Type Specs' AS prompt_substitution_string
               , '###TYPE###' AS template_substitution_string
               , 10 AS forced_order
            FROM DUAL
          UNION ALL
          SELECT 'TYPE_BODY' AS object_type
               , 'Type Bodies' AS prompt_substitution_string
               , '###TYPE_BODY###' AS template_substitution_string
               , 11 AS forced_order
            FROM DUAL
          UNION ALL
          SELECT 'PACKAGE_API' AS object_type
               , 'Packages Spec for Table DML operations (table APIs)' AS prompt_substitution_string
               , '###PACKAGE_API###' AS template_substitution_string
               , 12 AS forced_order
            FROM DUAL
          UNION ALL
          SELECT 'PACKAGE_BODY_API' AS object_type
               , 'Packages Body for Table DML operations (table APIs)' AS prompt_substitution_string
               , '###PACKAGE_BODY_API###' AS template_substitution_string
               , 13 AS forced_order
            FROM DUAL
          UNION ALL
          SELECT 'PACKAGE' AS object_type
               , 'Packages Spec with Business Logic' AS prompt_substitution_string
               , '###PACKAGE###' AS template_substitution_string
               , 14 AS forced_order
            FROM DUAL
          UNION ALL
          SELECT 'PACKAGE_BODY' AS object_type
               , 'Packages Body with Business Logic' AS prompt_substitution_string
               , '###PACKAGE_BODY###' AS template_substitution_string
               , 15 AS forced_order
            FROM DUAL
          UNION ALL
          SELECT 'PROCEDURE' AS object_type
               , 'single Procedures' AS prompt_substitution_string
               , '###PROCEDURE###' AS template_substitution_string
               , 16 AS forced_order
            FROM DUAL
          UNION ALL
          SELECT 'FUNCTION' AS object_type
               , 'single Functions' AS prompt_substitution_string
               , '###FUNCTION###' AS template_substitution_string
               , 17 AS forced_order
            FROM DUAL
          UNION ALL
          SELECT 'GRANT_TO' AS object_type
               , 'Grants provided to other users' AS prompt_substitution_string
               , '###GRANT###' AS template_substitution_string
               , 18 AS forced_order
            FROM DUAL
          ORDER BY 4)
    LOOP
      v_generated_list  := EMPTY_CLOB;
      v_generated_promt := EMPTY_CLOB;

      FOR i IN (  SELECT filename
                       , name
                       , object
                    FROM maint_waas.meta_code_versioning
                   WHERE object = scripts.object_type
                     AND schema = g_user
                ORDER BY 1)
      LOOP
        v_generated_list :=
             v_generated_list
          || 'PROMPT '
          || INITCAP(i.object)
          || ' '
          || i.name
          || ':'
          || CHR(13)
          || '@@"'
          || REPLACE(i.filename, g_user || '\', NULL)
          || '"'
          || CHR(13)
          || CHR(13);
      END LOOP;

      IF (DBMS_LOB.getlength(v_generated_list) = 0)
      THEN
        ------------------------------------------------------------------------
        -- no object found of type scripts.object_type in dictionary
        ------------------------------------------------------------------------
        v_install_sql_template :=
          utils_bl.replace_clob(p_clob => v_install_sql_template
                              , p_what => scripts.template_substitution_string
                              , p_with => TO_CLOB(' '));
      ELSE
        ------------------------------------------------------------------------
        -- there are some objects of scripts.object_type
        ------------------------------------------------------------------------
        v_generated_promt := REPLACE(v_install_sql_prompt, '###WHAT###', scripts.prompt_substitution_string);

        v_generated_list  := v_generated_promt || v_generated_list;

        v_install_sql_template :=
          utils_bl.replace_clob(p_clob => v_install_sql_template
                              , p_what => scripts.template_substitution_string
                              , p_with => v_generated_list);
      END IF;
    END LOOP;

    ----------------------------------------------------------------------------
    -- DML part to show an example
    ----------------------------------------------------------------------------
    v_install_sql_template     :=
      utils_bl.replace_clob(p_clob => v_install_sql_template, p_what => '###DML###', p_with => v_install_sql_dml_example);

    ----------------------------------------------------------------------------
    -- recreate all table APIs only if valid OM_TAPIGEN package is installed
    ----------------------------------------------------------------------------
    FOR i IN (SELECT *
                FROM all_objects
               WHERE object_name = 'OM_TAPIGEN'
                 AND object_type = 'PACKAGE'
                 AND status = 'VALID')
    LOOP
      EXECUTE IMMEDIATE   'SELECT COUNT(*)
                           FROM TABLE(maint_waas.om_tapigen.view_existing_apis(p_owner => '''
                       || p_user
                       || '''))
                          WHERE owner = '''
                       || p_user
                       || ''''
        INTO v_table_api_counter;

      IF (v_table_api_counter > 0)
      THEN
        v_install_sql_template :=
          utils_bl.replace_clob(p_clob => v_install_sql_template
                              , p_what => '###RECREATE_API###'
                              , p_with => v_install_sql_recreate_api);
      END IF;
    END LOOP;

    ----------------------------------------------------------------------------
    -- if no OM_TAPIGEN is installed, remove the line
    ----------------------------------------------------------------------------
    v_install_sql_template     :=
      utils_bl.replace_clob(p_clob => v_install_sql_template, p_what => '###RECREATE_API###', p_with => TO_CLOB('  '));

    ----------------------------------------------------------------------------
    -- replace the owner
    ----------------------------------------------------------------------------
    v_install_sql_template     :=
      utils_bl.replace_clob(p_clob => v_install_sql_template, p_what => '###OWNER###', p_with => g_user);

    ----------------------------------------------------------------------------
    -- replace empty lines
    ----------------------------------------------------------------------------
    v_install_sql_template     :=
      REGEXP_REPLACE(v_install_sql_template, CHR(10) || '+\s*' || CHR(10), CHR(10) || CHR(10));

    ----------------------------------------------------------------------------
    --  insert install sql file
    ----------------------------------------------------------------------------
    INSERT INTO maint_waas.meta_code_versioning(id
                                              , schema
                                              , object
                                              , name
                                              , filename
                                              , script
                                              , created_at)
         VALUES (maint_waas.meta_code_versioning_seq.NEXTVAL
               , g_user
               , 'INSTALL_SQL'
               , v_filename
               , v_filename
               , v_install_sql_template
               , SYSDATE);

    COMMIT;
  END ep_create_install_sql;

  PROCEDURE ep_create_procedures(p_user IN all_users.username%TYPE DEFAULT USER)
  IS
  BEGIN
    ----------------------------------------------------------------------------
    -- initialization part
    ----------------------------------------------------------------------------
    DBMS_OUTPUT.put_line('create procedures');

    g_user := p_user;

    lp_delete_scripts_of_type(p_object => 'PROCEDURE');

    IF (g_cur_procedures%ISOPEN)
    THEN
      CLOSE g_cur_procedures;
    END IF;

    ----------------------------------------------------------------------------
    -- generate  script for each procedure
    ----------------------------------------------------------------------------
    OPEN g_cur_procedures;

    LOOP
      FETCH g_cur_procedures BULK COLLECT INTO g_tab_procedures LIMIT g_bulk_limit;

      EXIT WHEN g_tab_procedures.COUNT = 0;

      FOR i IN g_tab_procedures.FIRST .. g_tab_procedures.LAST
      LOOP
        ------------------------------------------------------------------------
        -- generated script based on the template and save it
        -- within within the collection
        ------------------------------------------------------------------------
        g_tab_procedures(i).procedure_script :=
          TRIM(
            DBMS_METADATA.get_ddl(object_type => 'PROCEDURE'
                                , name        => g_tab_procedures(i).procedure_name
                                , schema      => g_user));

        ------------------------------------------------------------------------
        -- remove qoutes, there is no dbms_metadata transforms
        ------------------------------------------------------------------------
        utils_bl.replace_clob(p_clob => g_tab_procedures(i).procedure_script
                            , p_what => '"' || g_tab_procedures(i).procedure_name || '"'
                            , p_with => g_tab_procedures(i).procedure_name);

        g_tab_procedures(i).filename :=
          lp_prepare_filename(p_object => 'PROCEDURE', p_name => g_tab_procedures(i).procedure_name);
      END LOOP;

      --------------------------------------------------------------------------
      -- bulk insert all scripts from collection
      --------------------------------------------------------------------------
      FORALL i IN INDICES OF g_tab_procedures
        INSERT INTO maint_waas.meta_code_versioning(id
                                                  , schema
                                                  , object
                                                  , name
                                                  , filename
                                                  , script
                                                  , created_at)
             VALUES (maint_waas.meta_code_versioning_seq.NEXTVAL
                   , g_user
                   , 'PROCEDURE'
                   , g_tab_procedures(i).procedure_name
                   , g_tab_procedures(i).filename
                   , g_tab_procedures(i).procedure_script
                   , SYSDATE);
    END LOOP;

    COMMIT;

    CLOSE g_cur_procedures;
  END ep_create_procedures;

  PROCEDURE ep_create_functions(p_user IN all_users.username%TYPE DEFAULT USER)
  IS
  BEGIN
    ----------------------------------------------------------------------------
    -- initialization part
    ----------------------------------------------------------------------------
    DBMS_OUTPUT.put_line('create functions');

    g_user := p_user;

    lp_delete_scripts_of_type(p_object => 'FUNCTION');

    IF (g_cur_functions%ISOPEN)
    THEN
      CLOSE g_cur_functions;
    END IF;

    ----------------------------------------------------------------------------
    -- generate  script for each function
    ----------------------------------------------------------------------------
    OPEN g_cur_functions;

    LOOP
      FETCH g_cur_functions BULK COLLECT INTO g_tab_functions LIMIT g_bulk_limit;

      EXIT WHEN g_tab_functions.COUNT = 0;

      FOR i IN g_tab_functions.FIRST .. g_tab_functions.LAST
      LOOP
        ------------------------------------------------------------------------
        -- generated script based on the template and save it
        -- within within the collection
        ------------------------------------------------------------------------
        g_tab_functions(i).function_script :=
          TRIM(
            DBMS_METADATA.get_ddl(object_type => 'FUNCTION', name => g_tab_functions(i).function_name, schema => g_user));

        ------------------------------------------------------------------------
        -- remove qoutes, there is no dbms_metadata transforms
        ------------------------------------------------------------------------
        utils_bl.replace_clob(p_clob => g_tab_functions(i).function_script
                            , p_what => '"' || g_tab_functions(i).function_name || '"'
                            , p_with => g_tab_functions(i).function_name);

        g_tab_functions(i).filename :=
          lp_prepare_filename(p_object => 'FUNCTION', p_name => g_tab_functions(i).function_name);
      END LOOP;

      --------------------------------------------------------------------------
      -- bulk insert all scripts from collection
      --------------------------------------------------------------------------
      FORALL i IN INDICES OF g_tab_functions
        INSERT INTO maint_waas.meta_code_versioning(id
                                                  , schema
                                                  , object
                                                  , name
                                                  , filename
                                                  , script
                                                  , created_at)
             VALUES (maint_waas.meta_code_versioning_seq.NEXTVAL
                   , g_user
                   , 'FUNCTION'
                   , g_tab_functions(i).function_name
                   , g_tab_functions(i).filename
                   , g_tab_functions(i).function_script
                   , SYSDATE);
    END LOOP;

    COMMIT;

    CLOSE g_cur_functions;
  END ep_create_functions;

  PROCEDURE ep_create_grants_from(p_user IN all_users.username%TYPE DEFAULT USER)
  IS
  BEGIN
    ----------------------------------------------------------------------------
    -- initialization part
    ----------------------------------------------------------------------------
    DBMS_OUTPUT.put_line('create grants from');

    g_user := p_user;

    lp_delete_scripts_of_type(p_object => 'GRANT_FROM');

    IF (g_cur_grants_from%ISOPEN)
    THEN
      CLOSE g_cur_grants_from;
    END IF;

    ----------------------------------------------------------------------------
    -- generate  script for each Grant From
    ----------------------------------------------------------------------------
    OPEN g_cur_grants_from;

    LOOP
      FETCH g_cur_grants_from BULK COLLECT INTO g_tab_grants_from LIMIT g_bulk_limit;

      EXIT WHEN g_tab_grants_from.COUNT = 0;

      FOR i IN g_tab_grants_from.FIRST .. g_tab_grants_from.LAST
      LOOP
        ------------------------------------------------------------------------
        -- generated script based on the template and save it
        -- within within the collection
        ------------------------------------------------------------------------
        g_tab_grants_from(i).grant_from_script :=
             'ALTER SESSION SET CURRENT_SCHEMA = '
          || g_tab_grants_from(i).owner
          || ';'
          || CHR(13)
          || CHR(13)
          || 'GRANT '
          || g_tab_grants_from(i).grants
          || ' ON "'
          || g_tab_grants_from(i).owner
          || '"."'
          || g_tab_grants_from(i).table_name
          || '" TO "'
          || g_tab_grants_from(i).grantee
          || '" '
          || CASE WHEN g_tab_grants_from(i).grantable = 'YES' THEN 'WITH GRANT OPTION' ELSE NULL END
          || ';';

        g_tab_grants_from(i).filename :=
          lp_prepare_filename(
            p_object => 'GRANT_FROM'
          , p_name   =>
                 g_tab_grants_from(i).grantor
              || '_'
              || g_tab_grants_from(i).TYPE
              || '_'
              || g_tab_grants_from(i).table_name
              || '_'
              || g_tab_grants_from(i).grants_short);
      END LOOP;

      --------------------------------------------------------------------------
      -- bulk insert all scripts from collection
      --------------------------------------------------------------------------
      FORALL i IN INDICES OF g_tab_grants_from
        INSERT INTO maint_waas.meta_code_versioning(id
                                                  , schema
                                                  , object
                                                  , name
                                                  , filename
                                                  , script
                                                  , created_at)
             VALUES (maint_waas.meta_code_versioning_seq.NEXTVAL
                   , g_user
                   , 'GRANT_FROM'
                   , g_tab_grants_from(i).name
                   , g_tab_grants_from(i).filename
                   , g_tab_grants_from(i).grant_from_script
                   , SYSDATE);
    END LOOP;

    COMMIT;

    CLOSE g_cur_grants_from;
  END ep_create_grants_from;

  PROCEDURE ep_create_grants_to(p_user IN all_users.username%TYPE DEFAULT USER)
  IS
  BEGIN
    ----------------------------------------------------------------------------
    -- initialization part
    ----------------------------------------------------------------------------
    DBMS_OUTPUT.put_line('create grants to');

    g_user := p_user;

    lp_delete_scripts_of_type(p_object => 'GRANT_TO');

    IF (g_cur_grants_to%ISOPEN)
    THEN
      CLOSE g_cur_grants_to;
    END IF;

    ----------------------------------------------------------------------------
    -- generate  script for each Grant To
    ----------------------------------------------------------------------------
    OPEN g_cur_grants_to;

    LOOP
      FETCH g_cur_grants_to BULK COLLECT INTO g_tab_grants_to LIMIT g_bulk_limit;

      EXIT WHEN g_tab_grants_to.COUNT = 0;

      FOR i IN g_tab_grants_to.FIRST .. g_tab_grants_to.LAST
      LOOP
        ------------------------------------------------------------------------
        -- generated script based on the template and save it
        -- within within the collection
        ------------------------------------------------------------------------
        g_tab_grants_to(i).grant_to_script :=
             'GRANT '
          || g_tab_grants_to(i).grants
          || ' ON "'
          || g_tab_grants_to(i).owner
          || '"."'
          || g_tab_grants_to(i).table_name
          || '" TO "'
          || g_tab_grants_to(i).grantee
          || '" '
          || CASE WHEN g_tab_grants_to(i).grantable = 'YES' THEN 'WITH GRANT OPTION' ELSE NULL END
          || ';';

        g_tab_grants_to(i).filename :=
          lp_prepare_filename(
            p_object => 'GRANT_TO'
          , p_name   =>
                 g_tab_grants_to(i).TYPE
              || '_'
              || g_tab_grants_to(i).table_name
              || '_'
              || g_tab_grants_to(i).grantee
              || '_'
              || g_tab_grants_to(i).grants_short);
      END LOOP;

      --------------------------------------------------------------------------
      -- bulk insert all scripts from collection
      --------------------------------------------------------------------------
      FORALL i IN INDICES OF g_tab_grants_to
        INSERT INTO maint_waas.meta_code_versioning(id
                                                  , schema
                                                  , object
                                                  , name
                                                  , filename
                                                  , script
                                                  , created_at)
             VALUES (maint_waas.meta_code_versioning_seq.NEXTVAL
                   , g_user
                   , 'GRANT_TO'
                   , g_tab_grants_to(i).name
                   , g_tab_grants_to(i).filename
                   , g_tab_grants_to(i).grant_to_script
                   , SYSDATE);
    END LOOP;

    COMMIT;

    CLOSE g_cur_grants_to;
  END ep_create_grants_to;

  PROCEDURE ep_create_mviews(p_user IN all_users.username%TYPE DEFAULT USER)
  IS
    v_mview_template CLOB;
    v_generated      CLOB;
  BEGIN
    ----------------------------------------------------------------------------
    -- initialization part
    ----------------------------------------------------------------------------
    DBMS_OUTPUT.put_line('create mviews');

    g_user           := p_user;

    lp_delete_scripts_of_type(p_object => 'MATERIALIZED_VIEW');

    v_mview_template := lp_get_template(p_object => 'MATERIALIZED_VIEW');

    IF (g_cur_mviews%ISOPEN)
    THEN
      CLOSE g_cur_mviews;
    END IF;

    lp_config_dbms_metadata(p_sqlterminator_yn => FALSE);

    ----------------------------------------------------------------------------
    -- generate  script for each MATERIALIZED VIEW
    ----------------------------------------------------------------------------
    OPEN g_cur_mviews;

    LOOP
      FETCH g_cur_mviews BULK COLLECT INTO g_tab_mviews LIMIT g_bulk_limit;

      EXIT WHEN g_tab_mviews.COUNT = 0;

      FOR i IN g_tab_mviews.FIRST .. g_tab_mviews.LAST
      LOOP
        ------------------------------------------------------------------------
        -- generated script based on the template and save it
        -- within within the collection
        ------------------------------------------------------------------------
        g_tab_mviews(i).mview_script := v_mview_template;

        v_generated                  :=
          DBMS_METADATA.get_ddl(object_type => 'MATERIALIZED_VIEW', name => g_tab_mviews(i).mview_name, schema => g_user);

        g_tab_mviews(i).mview_script :=
          utils_bl.replace_clob(p_clob => g_tab_mviews(i).mview_script
                              , p_what => '###MVIEW_NAME###'
                              , p_with => g_tab_mviews(i).mview_name);

        g_tab_mviews(i).mview_script :=
          utils_bl.replace_clob(p_clob => g_tab_mviews(i).mview_script
                              , p_what => '###GENERATED_CODE###'
                              , p_with => TRIM(v_generated));

        g_tab_mviews(i).mview_script :=
          utils_bl.replace_clob(p_clob => g_tab_mviews(i).mview_script, p_what => '###OWNER###', p_with => g_user);

        g_tab_mviews(i).filename     :=
          lp_prepare_filename(p_object => 'MATERIALIZED_VIEW', p_name => g_tab_mviews(i).mview_name);
      END LOOP;

      --------------------------------------------------------------------------
      -- bulk insert all scripts from collection
      --------------------------------------------------------------------------
      FORALL i IN INDICES OF g_tab_mviews
        INSERT INTO maint_waas.meta_code_versioning(id
                                                  , schema
                                                  , object
                                                  , name
                                                  , filename
                                                  , script
                                                  , created_at)
             VALUES (maint_waas.meta_code_versioning_seq.NEXTVAL
                   , g_user
                   , 'MATERIALIZED_VIEW'
                   , g_tab_mviews(i).mview_name
                   , g_tab_mviews(i).filename
                   , g_tab_mviews(i).mview_script
                   , SYSDATE);
    END LOOP;

    COMMIT;

    CLOSE g_cur_mviews;

    lp_config_dbms_metadata(p_sqlterminator_yn => TRUE);
  END ep_create_mviews;

  PROCEDURE ep_create_dblinks(p_user IN all_users.username%TYPE DEFAULT USER)
  IS
    v_db_link_template CLOB;
    v_generated        CLOB;
  BEGIN
    ----------------------------------------------------------------------------
    -- initialization part
    ----------------------------------------------------------------------------
    DBMS_OUTPUT.put_line('create database links');

    g_user             := p_user;

    lp_delete_scripts_of_type(p_object => 'DATABASE_LINK');

    v_db_link_template := lp_get_template(p_object => 'DB_LINK');

    IF (g_cur_dblinks%ISOPEN)
    THEN
      CLOSE g_cur_dblinks;
    END IF;

    lp_config_dbms_metadata(p_sqlterminator_yn => FALSE);

    ----------------------------------------------------------------------------
    -- generate  script for each DBLink
    ----------------------------------------------------------------------------
    OPEN g_cur_dblinks;

    LOOP
      FETCH g_cur_dblinks BULK COLLECT INTO g_tab_dblinks LIMIT g_bulk_limit;

      EXIT WHEN g_tab_dblinks.COUNT = 0;

      FOR i IN g_tab_dblinks.FIRST .. g_tab_dblinks.LAST
      LOOP
        ------------------------------------------------------------------------
        -- generated script based on the template and save it
        -- within within the collection
        ------------------------------------------------------------------------
        g_tab_dblinks(i).dblink_script := v_db_link_template;

        g_tab_dblinks(i).filename      :=
          lp_prepare_filename(p_object => 'DATABASE_LINK', p_name => g_tab_dblinks(i).db_link);
        v_generated                    :=
          DBMS_METADATA.get_ddl(object_type => 'DB_LINK', name => g_tab_dblinks(i).db_link, schema => g_user);

        g_tab_dblinks(i).dblink_script :=
          utils_bl.replace_clob(p_clob => g_tab_dblinks(i).dblink_script
                              , p_what => '###DB_LINK###'
                              , p_with => g_tab_dblinks(i).db_link);

        g_tab_dblinks(i).dblink_script :=
          utils_bl.replace_clob(p_clob => g_tab_dblinks(i).dblink_script
                              , p_what => '###GENERATED_CODE###'
                              , p_with => TRIM(v_generated));

        g_tab_dblinks(i).dblink_script :=
          utils_bl.replace_clob(p_clob => g_tab_dblinks(i).dblink_script, p_what => '###OWNER###', p_with => g_user);
      END LOOP;

      --------------------------------------------------------------------------
      -- bulk insert all scripts from collection
      --------------------------------------------------------------------------
      FORALL i IN INDICES OF g_tab_dblinks
        INSERT INTO maint_waas.meta_code_versioning(id
                                                  , schema
                                                  , object
                                                  , name
                                                  , filename
                                                  , script
                                                  , created_at)
             VALUES (maint_waas.meta_code_versioning_seq.NEXTVAL
                   , g_user
                   , 'DATABASE_LINK'
                   , g_tab_dblinks(i).db_link
                   , g_tab_dblinks(i).filename
                   , g_tab_dblinks(i).dblink_script
                   , SYSDATE);
    END LOOP;

    COMMIT;

    CLOSE g_cur_dblinks;

    lp_config_dbms_metadata(p_sqlterminator_yn => TRUE);
  END ep_create_dblinks;

  PROCEDURE ep_create_all_as_db_job(p_user                     IN all_users.username%TYPE DEFAULT USER
                                  , p_create_sequences_yn      IN VARCHAR2 DEFAULT 'Y'
                                  , p_create_tables_yn         IN VARCHAR2 DEFAULT 'Y'
                                  , p_create_indexes_yn        IN VARCHAR2 DEFAULT 'Y'
                                  , p_create_packages_api_yn   IN VARCHAR2 DEFAULT 'Y'
                                  , p_create_packages_bl_yn    IN VARCHAR2 DEFAULT 'Y'
                                  , p_create_synonyms_yn       IN VARCHAR2 DEFAULT 'Y'
                                  , p_create_triggers_yn       IN VARCHAR2 DEFAULT 'Y'
                                  , p_create_types_yn          IN VARCHAR2 DEFAULT 'Y'
                                  , p_create_views_yn          IN VARCHAR2 DEFAULT 'Y'
                                  , p_create_grants_from_yn    IN VARCHAR2 DEFAULT 'Y'
                                  , p_create_grants_to_yn      IN VARCHAR2 DEFAULT 'Y'
                                  , p_create_mviews_yn         IN VARCHAR2 DEFAULT 'Y'
                                  , p_create_dblinks_yn        IN VARCHAR2 DEFAULT 'Y'
                                  , p_create_procedures_yn     IN VARCHAR2 DEFAULT 'Y'
                                  , p_create_functions_yn      IN VARCHAR2 DEFAULT 'Y'
                                  , p_create_fk_constraints_yn IN VARCHAR2 DEFAULT 'Y'
                                  , p_create_install_batch_yn  IN VARCHAR2 DEFAULT 'Y'
                                  , p_create_install_sql_yn    IN VARCHAR2 DEFAULT 'Y')
  IS
    v_plsql_block VARCHAR(32767 CHAR);
  BEGIN
    ----------------------------------------------------------------------------
    -- prepare the code block for the scheduler job
    ----------------------------------------------------------------------------
    v_plsql_block :=
      '
        BEGIN
          maint_waas.code_versioning_bl.ep_create_all(p_user                     => ''###p_user###''
		                                                , p_create_sequences_yn      => ''###p_create_sequences_yn###''
                                                    , p_create_tables_yn         => ''###p_create_tables_yn###''
                                                    , p_create_indexes_yn        => ''###p_create_indexes_yn###''
	                                                  , p_create_packages_api_yn   => ''###p_create_packages_api_yn###''
	                                                  , p_create_packages_bl_yn    => ''###p_create_packages_bl_yn###''
                                                    , p_create_synonyms_yn       => ''###p_create_synonyms_yn###''
                                                    , p_create_triggers_yn       => ''###p_create_triggers_yn###''
                                                    , p_create_types_yn          => ''###p_create_types_yn###''
                                                    , p_create_views_yn          => ''###p_create_views_yn###''
                                                    , p_create_grants_from_yn    => ''###p_create_grants_from_yn###''
                                                    , p_create_grants_to_yn      => ''###p_create_grants_to_yn###''
                                                    , p_create_mviews_yn         => ''###p_create_mviews_yn###''
                                                    , p_create_dblinks_yn        => ''###p_create_dblinks_yn###''
                                                    , p_create_procedures_yn     => ''###p_create_procedures_yn###''
                                                    , p_create_functions_yn      => ''###p_create_functions_yn###''
                                                    , p_create_fk_constraints_yn => ''###p_create_fk_constraints_yn###''
                                                    , p_create_install_batch_yn  => ''###p_create_install_batch_yn###''
                                                    , p_create_install_sql_yn    => ''###p_create_install_sql_yn###'');
			  END; 
			';

    ----------------------------------------------------------------------------
    -- just filling the params
    ----------------------------------------------------------------------------
    v_plsql_block := REPLACE(v_plsql_block, '###p_user###', p_user);
    v_plsql_block := REPLACE(v_plsql_block, '###p_create_sequences_yn###', p_create_sequences_yn);
    v_plsql_block := REPLACE(v_plsql_block, '###p_create_tables_yn###', p_create_tables_yn);
    v_plsql_block := REPLACE(v_plsql_block, '###p_create_indexes_yn###', p_create_indexes_yn);
    v_plsql_block := REPLACE(v_plsql_block, '###p_create_packages_api_yn###', p_create_packages_api_yn);
    v_plsql_block := REPLACE(v_plsql_block, '###p_create_packages_bl_yn###', p_create_packages_bl_yn);
    v_plsql_block := REPLACE(v_plsql_block, '###p_create_synonyms_yn###', p_create_synonyms_yn);
    v_plsql_block := REPLACE(v_plsql_block, '###p_create_triggers_yn###', p_create_triggers_yn);
    v_plsql_block := REPLACE(v_plsql_block, '###p_create_types_yn###', p_create_types_yn);
    v_plsql_block := REPLACE(v_plsql_block, '###p_create_views_yn###', p_create_views_yn);
    v_plsql_block := REPLACE(v_plsql_block, '###p_create_grants_from_yn###', p_create_grants_from_yn);
    v_plsql_block := REPLACE(v_plsql_block, '###p_create_grants_to_yn###', p_create_grants_to_yn);
    v_plsql_block := REPLACE(v_plsql_block, '###p_create_mviews_yn###', p_create_mviews_yn);
    v_plsql_block := REPLACE(v_plsql_block, '###p_create_dblinks_yn###', p_create_dblinks_yn);
    v_plsql_block := REPLACE(v_plsql_block, '###p_create_procedures_yn###', p_create_procedures_yn);
    v_plsql_block := REPLACE(v_plsql_block, '###p_create_functions_yn###', p_create_functions_yn);
    v_plsql_block := REPLACE(v_plsql_block, '###p_create_fk_constraints_yn###', p_create_fk_constraints_yn);
    v_plsql_block := REPLACE(v_plsql_block, '###p_create_install_batch_yn###', p_create_install_batch_yn);
    v_plsql_block := REPLACE(v_plsql_block, '###p_create_install_sql_yn###', p_create_install_sql_yn);

    ----------------------------------------------------------------------------
    -- create scheduler job
    ----------------------------------------------------------------------------
    DBMS_SCHEDULER.create_job(
      job_name   => 'WaaS_code_versioning_' || p_user || '_' || TO_CHAR(SYSDATE, 'yyyymmdd_hh24miss')
    , job_type   => 'PLSQL_BLOCK'
    , job_action => v_plsql_block
    , start_date => SYSDATE
    , enabled    => TRUE);
  END ep_create_all_as_db_job;

  PROCEDURE ep_create_all(p_user                     IN all_users.username%TYPE DEFAULT USER
                        , p_create_sequences_yn      IN VARCHAR2 DEFAULT 'Y'
                        , p_create_tables_yn         IN VARCHAR2 DEFAULT 'Y'
                        , p_create_indexes_yn        IN VARCHAR2 DEFAULT 'Y'
                        , p_create_packages_api_yn   IN VARCHAR2 DEFAULT 'Y'
                        , p_create_packages_bl_yn    IN VARCHAR2 DEFAULT 'Y'
                        , p_create_synonyms_yn       IN VARCHAR2 DEFAULT 'Y'
                        , p_create_triggers_yn       IN VARCHAR2 DEFAULT 'Y'
                        , p_create_types_yn          IN VARCHAR2 DEFAULT 'Y'
                        , p_create_views_yn          IN VARCHAR2 DEFAULT 'Y'
                        , p_create_grants_from_yn    IN VARCHAR2 DEFAULT 'Y'
                        , p_create_grants_to_yn      IN VARCHAR2 DEFAULT 'Y'
                        , p_create_mviews_yn         IN VARCHAR2 DEFAULT 'Y'
                        , p_create_dblinks_yn        IN VARCHAR2 DEFAULT 'Y'
                        , p_create_procedures_yn     IN VARCHAR2 DEFAULT 'Y'
                        , p_create_functions_yn      IN VARCHAR2 DEFAULT 'Y'
                        , p_create_fk_constraints_yn IN VARCHAR2 DEFAULT 'Y'
                        , p_create_install_batch_yn  IN VARCHAR2 DEFAULT 'Y'
                        , p_create_install_sql_yn    IN VARCHAR2 DEFAULT 'Y')
  IS
  BEGIN
    g_user := p_user;

    ----------------------------------------------------------------------------
    -- delete existing scripts from user
    ----------------------------------------------------------------------------
    DELETE FROM maint_waas.meta_code_versioning
          WHERE schema = g_user;

    COMMIT;

    IF (p_create_sequences_yn = 'Y')
    THEN
      ep_create_sequences(p_user => g_user);
      COMMIT;
    END IF;

    IF (p_create_tables_yn = 'Y')
    THEN
      ep_create_tables(p_user => g_user);
      COMMIT;
    END IF;

    IF (p_create_indexes_yn = 'Y')
    THEN
      ep_create_indexes(p_user => g_user);
      COMMIT;
    END IF;

    IF (p_create_packages_api_yn = 'Y')
    THEN
      ep_create_packages_api(p_user => g_user);
      COMMIT;
    END IF;

    IF (p_create_packages_bl_yn = 'Y')
    THEN
      ep_create_packages_bl(p_user => g_user);
      COMMIT;
    END IF;

    IF (p_create_synonyms_yn = 'Y')
    THEN
      ep_create_synonyms(p_user => g_user);
      COMMIT;
    END IF;

    IF (p_create_triggers_yn = 'Y')
    THEN
      ep_create_triggers(p_user => g_user);
      COMMIT;
    END IF;

    IF (p_create_types_yn = 'Y')
    THEN
      ep_create_types(p_user => g_user);
      COMMIT;
    END IF;

    IF (p_create_views_yn = 'Y')
    THEN
      ep_create_views(p_user => g_user);
      COMMIT;
    END IF;

    IF (p_create_grants_from_yn = 'Y')
    THEN
      ep_create_grants_from(p_user => g_user);
      COMMIT;
    END IF;

    IF (p_create_grants_to_yn = 'Y')
    THEN
      ep_create_grants_to(p_user => g_user);
      COMMIT;
    END IF;

    IF (p_create_mviews_yn = 'Y')
    THEN
      ep_create_mviews(p_user => g_user);
      COMMIT;
    END IF;

    IF (p_create_dblinks_yn = 'Y')
    THEN
      ep_create_dblinks(p_user => g_user);
      COMMIT;
    END IF;

    IF (p_create_procedures_yn = 'Y')
    THEN
      ep_create_procedures(p_user => g_user);
      COMMIT;
    END IF;

    IF (p_create_functions_yn = 'Y')
    THEN
      ep_create_functions(p_user => g_user);
      COMMIT;
    END IF;

    IF (p_create_fk_constraints_yn = 'Y')
    THEN
      ep_create_fk_constraints(p_user => g_user);
      COMMIT;
    END IF;

    IF (p_create_install_batch_yn = 'Y')
    THEN
      ep_create_install_batch(p_user => g_user);
      COMMIT;
    END IF;

    IF (p_create_install_sql_yn = 'Y')
    THEN
      ep_create_install_sql(p_user => g_user);
      COMMIT;
    END IF;
  END ep_create_all;

  FUNCTION ep_is_job_running_yn
    RETURN VARCHAR2
  IS
    lv_count NUMBER;
  BEGIN
    SELECT COUNT(*)
      INTO lv_count
      FROM dba_scheduler_running_jobs
     WHERE job_name LIKE 'WAAS_CODE_VERSIONING_%';

    RETURN CASE WHEN lv_count > 0 THEN 'Y' ELSE 'N' END;
  END ep_is_job_running_yn;
--------------------------------------------------------------------------------
-- initialization block of the package
--------------------------------------------------------------------------------
BEGIN
  DBMS_OUTPUT.put_line('initialize');

  g_files('GRANT_FROM')        := '###OWNER###\Grants_From\###NAME###.sql';
  g_files('SEQUENCE')          := '###OWNER###\Sequences\###NAME###.sql';
  g_files('TABLE')             := '###OWNER###\Tables\###NAME###.sql';
  g_files('INDEX')             := '###OWNER###\Indexes\###NAME###.sql';
  g_files('FK_CONSTRAINT')     := '###OWNER###\FK_Constraints\###NAME###.sql';
  g_files('TRIGGER')           := '###OWNER###\Triggers\###NAME###.trg';
  g_files('DATABASE_LINK')     := '###OWNER###\DB_Links\###NAME###.sql';
  g_files('SYNONYM')           := '###OWNER###\Synonyms\###NAME###.sql';
  g_files('VIEW')              := '###OWNER###\Views\###NAME###.vw';
  g_files('MATERIALIZED_VIEW') := '###OWNER###\MViews\###NAME###.sql';
  g_files('TYPE')              := '###OWNER###\Types\###NAME###.tps';
  g_files('TYPE_BODY')         := '###OWNER###\Types\###NAME###.tpb';
  g_files('PACKAGE')           := '###OWNER###\Packages\###NAME###.pks';
  g_files('PACKAGE_BODY')      := '###OWNER###\Packages\###NAME###.pkb';
  g_files('PACKAGE_API')       := '###OWNER###\Packages_API\###NAME###.pks';
  g_files('PACKAGE_BODY_API')  := '###OWNER###\Packages_API\###NAME###.pkb';
  g_files('PROCEDURE')         := '###OWNER###\Procedures\###NAME###.prc';
  g_files('FUNCTION')          := '###OWNER###\Functions\###NAME###.fnc';
  g_files('GRANT_TO')          := '###OWNER###\Grants_To\###NAME###.sql';
  g_files('INSTALL_BAT')       := '###OWNER###\install_###NAME###.bat';
  g_files('INSTALL_SQL')       := '###OWNER###\install_###NAME###.sql';

  ------------------------------------------------------------------------------
  -- configure DBMS_METADATA for table scripts with default properties
  ------------------------------------------------------------------------------
  lp_config_dbms_metadata;
END "CODE_VERSIONING_BL";
/