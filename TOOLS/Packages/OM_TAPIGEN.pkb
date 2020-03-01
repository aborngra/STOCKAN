CREATE OR REPLACE EDITIONABLE PACKAGE BODY "OM_TAPIGEN"
IS
  -----------------------------------------------------------------------------
  -- private global constants (c_*)
  -----------------------------------------------------------------------------
  c_generator_error_number      CONSTANT PLS_INTEGER := -20000;
  c_bulk_collect_limit          CONSTANT NUMBER := 10000;
  c_crlf                        CONSTANT VARCHAR2(2 CHAR) := CHR(13) || CHR(10);
  c_crlflf                      CONSTANT VARCHAR2(3 CHAR) := CHR(13) || CHR(10) || CHR(10);
  c_list_delimiter              CONSTANT VARCHAR2(3 CHAR) := ',' || c_crlf;
  c_custom_defaults_present_msg CONSTANT VARCHAR2(30) := 'SEE_END_OF_API_PACKAGE_SPEC';
  c_spec_options_min_line       CONSTANT NUMBER := 5;
  c_spec_options_max_line       CONSTANT NUMBER := 35;
  c_debug_max_runs              CONSTANT NUMBER := 1000;

  -----------------------------------------------------------------------------
  -- private record (t_rec_*) and collection (t_tab_*) types
  -----------------------------------------------------------------------------
  TYPE t_rec_params IS RECORD
  (
    table_name                   all_objects.object_name%TYPE
  , owner                        all_users.username%TYPE
  , reuse_existing_api_params    BOOLEAN
  , enable_insertion_of_rows     BOOLEAN
  , enable_column_defaults       BOOLEAN
  , enable_update_of_rows        BOOLEAN
  , enable_deletion_of_rows      BOOLEAN
  , enable_parameter_prefixes    BOOLEAN
  , enable_proc_with_out_params  BOOLEAN
  , enable_getter_and_setter     BOOLEAN
  , col_prefix_in_method_names   BOOLEAN
  , return_row_instead_of_pk     BOOLEAN
  , enable_dml_view              BOOLEAN
  , enable_generic_change_log    BOOLEAN
  , api_name                     user_objects.object_name%TYPE
  , sequence_name                user_sequences.sequence_name%TYPE
  , exclude_column_list          VARCHAR2(4000 CHAR)
  , enable_custom_defaults       BOOLEAN
  , custom_default_values        XMLTYPE
  , custom_defaults_serialized   VARCHAR2(32767 CHAR)
  );

  TYPE t_rec_status IS RECORD
  (
    pk_is_multi_column      BOOLEAN
  , column_prefix           user_tab_columns.column_name%TYPE
  , xmltype_column_present  BOOLEAN
  , generator_action        VARCHAR2(30 CHAR)
  , api_exists              BOOLEAN
  , rpad_columns            INTEGER
  , rpad_pk_columns         INTEGER
  , rpad_uk_columns         INTEGER
  );

  --

  TYPE t_tab_columns IS TABLE OF t_rec_columns
    INDEX BY BINARY_INTEGER; -- record type is public

  --

  TYPE t_tab_columns_index IS TABLE OF INTEGER
    INDEX BY user_tab_columns.column_name%TYPE;

  --

  TYPE t_rec_constraints IS RECORD
  (
    constraint_name  user_constraints.constraint_name%TYPE
  );

  TYPE t_tab_constraints IS TABLE OF t_rec_constraints
    INDEX BY BINARY_INTEGER;

  --

  TYPE t_rec_cons_columns IS RECORD
  (
    constraint_name     user_cons_columns.constraint_name%TYPE
  , column_name         user_cons_columns.column_name%TYPE
  , column_name_length  INTEGER
  , data_type           user_tab_columns.data_type%TYPE
  );

  TYPE t_tab_cons_columns IS TABLE OF t_rec_cons_columns
    INDEX BY BINARY_INTEGER;

  --

  TYPE t_rec_code_blocks IS RECORD
  (
    template                        VARCHAR2(32767 CHAR)
  , api_spec                        CLOB
  , api_spec_varchar_cache          VARCHAR2(32767 CHAR)
  , api_body                        CLOB
  , api_body_varchar_cache          VARCHAR2(32767 CHAR)
  , dml_view                        CLOB
  , dml_view_varchar_cache          VARCHAR2(32767 CHAR)
  , dml_view_trigger                CLOB
  , dml_view_trigger_varchar_cache  VARCHAR2(32767 CHAR)
  );

  --

  TYPE t_rec_template_options IS RECORD
  (
    use_column_defaults  BOOLEAN
  , padding              INTEGER
  );

  --

  TYPE t_tab_vc2_5k IS TABLE OF VARCHAR2(5000)
    INDEX BY BINARY_INTEGER;

  --

  TYPE t_rec_iterator IS RECORD
  (
    column_name                user_tab_columns.column_name%TYPE
  , method_name                user_tab_columns.column_name%TYPE
  , parameter_name             user_tab_columns.column_name%TYPE
  , column_compare             VARCHAR2(512 CHAR)
  , old_value                  VARCHAR2(512 CHAR)
  , new_value                  VARCHAR2(512 CHAR)
  , current_unique_constraint  user_objects.object_name%TYPE
  );

  --

  TYPE t_rec_debug_details IS RECORD
  (
    step        INTEGER(4)
  , module      st_session_module
  , action      st_session_action
  , start_time  TIMESTAMP(6)
  , stop_time   TIMESTAMP(6)
  );

  TYPE t_tab_debug_details IS TABLE OF t_rec_debug_details
    INDEX BY BINARY_INTEGER;

  --

  TYPE t_rec_debug IS RECORD
  (
    run         INTEGER(4)
  , owner       all_users.username%TYPE
  , table_name  all_objects.object_name%TYPE
  , start_time  TIMESTAMP(6)
  , stop_time   TIMESTAMP(6)
  , details     t_tab_debug_details
  );

  TYPE t_tab_debug IS TABLE OF t_rec_debug
    INDEX BY BINARY_INTEGER;

  -----------------------------------------------------------------------------
  -- private global variables (g_*)
  -----------------------------------------------------------------------------

  --variables
  g_debug_enabled                        BOOLEAN;
  g_debug_run                            INTEGER;
  g_debug_step                           INTEGER;
  g_debug_module                         st_session_module;

  -- records
  g_params                               t_rec_params;
  g_params_existing_api                  t_rec_existing_apis;
  g_iterator                             t_rec_iterator;
  g_code_blocks                          t_rec_code_blocks;
  g_status                               t_rec_status;
  g_template_options                     t_rec_template_options;

  -- collections
  g_columns                              t_tab_columns;
  g_columns_reverse_index                t_tab_columns_index;
  g_unique_constraints                   t_tab_constraints;
  g_pk_columns                           t_tab_cons_columns;
  g_uk_columns                           t_tab_cons_columns;
  g_debug                                t_tab_debug;

  -----------------------------------------------------------------------------
  -- private global cursors (g_cur_*)
  -----------------------------------------------------------------------------
  CURSOR g_cur_unique_constraints IS
      SELECT constraint_name
        FROM all_constraints
       WHERE owner = g_params.owner
         AND table_name = g_params.table_name
         AND constraint_type = 'U'
         AND status = 'ENABLED'
    ORDER BY constraint_name;

  CURSOR g_cur_columns IS
    WITH
      not_null_columns
      AS
        (SELECT CASE
                  WHEN INSTR(column_name_nn, '"') = 0 THEN UPPER(column_name_nn)
                  ELSE TRIM(BOTH '"' FROM column_name_nn)
                END
                  AS column_name_nn
           FROM (SELECT REGEXP_SUBSTR(search_condition_vc
                                    , '^\s*("[^"]+"|[a-zA-Z0-9_#$]+)\s+is\s+not\s+null\s*$'
                                    , 1
                                    , 1
                                    , 'i'
                                    , 1)
                          AS column_name_nn
                   FROM all_constraints
                  WHERE owner = g_params.owner
                    AND table_name = g_params.table_name
                    AND constraint_type = 'C'
                    AND status = 'ENABLED')
          WHERE column_name_nn IS NOT NULL),
      --      excluded_columns
      --      AS
      --        (SELECT COLUMN_VALUE AS column_name_excluded
      --           FROM TABLE(om_tapigen.util_split_to_table(null))),
      t
      AS
        (  SELECT column_id
                , column_name
                , data_type
                , data_length
                , data_precision
                , data_scale
                , char_length
                , --                CASE
                  --                    WHEN data_default IS NOT NULL
                  --                    THEN
                  --                      (SELECT om_tapigen.util_get_column_data_default(p_owner       => g_params.owner
                  --                                                                    , p_table_name  => table_name
                  --                                                                    , p_column_name => column_name)
                  --                         FROM DUAL)
                  --                    ELSE
                  --                      NULL
                  --                  END
                  NULL
                    AS data_default
                , virtual_column
                , CASE WHEN column_name_nn IS NOT NULL THEN 'N' ELSE 'Y' END
                    AS is_nullable_yn
                , CASE
                    WHEN (virtual_column = 'YES'
                      AND data_type != 'XMLTYPE')
                    --              OR excluded_columns.column_name_excluded IS NOT NULL
                    THEN
                      'Y'
                    ELSE
                      'N'
                  END
                    AS is_excluded_yn
             FROM all_tab_cols LEFT JOIN not_null_columns ON all_tab_cols.column_name = not_null_columns.column_name_nn
            --     LEFT JOIN excluded_columns ON all_tab_cols.column_name = excluded_columns.column_name_excluded
            WHERE owner = g_params.owner
              AND table_name = g_params.table_name
              AND hidden_column = 'NO'
         ORDER BY column_id)
    SELECT column_name
         , data_type
         , data_length
         , data_precision
         , data_scale
         , data_default
         , char_length
         , NULL AS data_custom_default
         , NULL AS custom_default_source
         , 'N' AS is_pk_yn
         , 'N' AS is_uk_yn
         , is_nullable_yn
         , is_excluded_yn
      FROM t;

  CURSOR g_cur_pk_columns IS
      SELECT acc.constraint_name
           , acc.column_name
           , LENGTH(acc.column_name) AS column_name_length
           , atc.data_type
        FROM all_constraints ac
             JOIN all_cons_columns acc
               ON ac.owner = acc.owner
              AND ac.constraint_name = acc.constraint_name
             JOIN all_tab_columns atc
               ON acc.owner = atc.owner
              AND acc.table_name = atc.table_name
              AND acc.column_name = atc.column_name
       WHERE ac.owner = g_params.owner
         AND ac.table_name = g_params.table_name
         AND ac.constraint_type = 'P'
         AND ac.status = 'ENABLED'
    ORDER BY ac.constraint_name, acc.position;

  CURSOR g_cur_uk_columns IS
      SELECT acc.constraint_name
           , acc.column_name
           , LENGTH(acc.column_name) AS column_name_length
           , atc.data_type
        FROM all_constraints ac
             JOIN all_cons_columns acc
               ON ac.owner = acc.owner
              AND ac.constraint_name = acc.constraint_name
             JOIN all_tab_columns atc
               ON acc.owner = atc.owner
              AND acc.table_name = atc.table_name
              AND acc.column_name = atc.column_name
       WHERE ac.owner = g_params.owner
         AND ac.table_name = g_params.table_name
         AND ac.constraint_type = 'U'
    ORDER BY ac.constraint_name, acc.position;

  -----------------------------------------------------------------------------
  -- util_execute_sql is a private helper procedure that parses and executes
  -- generated code with the help of DBMS_SQL package. Execute immediate is not
  -- used here directly, because of the missing possibility of parsing a
  -- statement in a performant way. Executing immediate and catching
  -- the error is more expensive than parsing the statement and catching the
  -- error.
  -----------------------------------------------------------------------------
  PROCEDURE util_execute_sql(p_sql IN OUT NOCOPY CLOB)
  IS
    v_cursor      NUMBER;
    v_exec_result PLS_INTEGER;
  BEGIN
    v_cursor      := DBMS_SQL.open_cursor;
    DBMS_SQL.parse(v_cursor, p_sql, DBMS_SQL.native);
    v_exec_result := DBMS_SQL.execute(v_cursor);
    DBMS_SQL.close_cursor(v_cursor);
  EXCEPTION
    WHEN OTHERS
    THEN
      DBMS_SQL.close_cursor(v_cursor);
      RAISE;
  END util_execute_sql;

  -----------------------------------------------------------------------------
  -- util_string_to_bool is a private helper function to deliver a
  -- boolean representation of an string value. True is returned,if:
  --   true,yes,y,1
  -- is given. False is returned when:
  --   false,no,n,0
  -- is given.
  -----------------------------------------------------------------------------

  FUNCTION util_string_to_bool(p_string IN VARCHAR2)
    RETURN BOOLEAN
  IS
  BEGIN
    RETURN CASE
             WHEN LOWER(p_string) IN ('true'
                                    , 'yes'
                                    , 'y'
                                    , '1')
             THEN
               TRUE
             WHEN LOWER(p_string) IN ('false'
                                    , 'no'
                                    , 'n'
                                    , '0')
             THEN
               FALSE
             ELSE
               NULL
           END;
  END util_string_to_bool;

  -----------------------------------------------------------------------------
  -- util_bool_to_string is a private helper function to deliver a
  -- varchar2 representation of an boolean value. 'TRUE' is returned,if
  -- boolean value is true. 'FALSE' is returned when boolean value is false.
  -----------------------------------------------------------------------------

  FUNCTION util_bool_to_string(p_bool IN BOOLEAN)
    RETURN VARCHAR2
  IS
  BEGIN
    RETURN CASE WHEN p_bool THEN 'TRUE' WHEN NOT p_bool THEN 'FALSE' ELSE NULL END;
  END util_bool_to_string;

  -----------------------------------------------------------------------------
  -- util_get_table_column_prefix is a private helper function to find out the
  -- column prefixes of a table. We understand everything before the first
  -- underscore "_" within the columnname as prefix. If columns have different
  -- prefixes within a table,null will be returned.
  -----------------------------------------------------------------------------

  FUNCTION util_get_table_column_prefix(p_table_name IN VARCHAR2)
    RETURN VARCHAR2
  IS
    v_return VARCHAR2(128 CHAR);
    v_count  PLS_INTEGER := 0;
  BEGIN
    FOR i
      IN (SELECT DISTINCT
                 SUBSTR(
                   column_name
                 , 1
                 , CASE WHEN INSTR(column_name, '_') = 0 THEN LENGTH(column_name) ELSE INSTR(column_name, '_') - 1 END)
                   AS prefix
            FROM all_tab_cols
           WHERE owner = g_params.owner
             AND table_name = p_table_name
             AND hidden_column = 'NO')
    LOOP
      v_count  := v_count + 1;

      IF v_count > 1
      THEN
        v_return := NULL;
        EXIT;
      END IF;

      v_return := i.prefix;
    END LOOP;

    RETURN v_return;
  END util_get_table_column_prefix;

  -----------------------------------------------------------------------------
  -- util_get_attribute_surrogate is a private helper function to find out a
  -- datatype dependent surrogate. This is required for comparing two
  -- values of a column e.g. old value and new value. There is the special case
  -- of null comparisison in Oracle,what means null compared with null is
  -- never true. That is the reason to compare:
  --     coalesce(old value,surrogate) = coalesce(new value,surrogate)
  -- that is true,if both sides are null.
  -----------------------------------------------------------------------------

  FUNCTION util_get_attribute_surrogate(p_data_type IN user_tab_cols.data_type%TYPE)
    RETURN VARCHAR2
  IS
    v_return VARCHAR2(100 CHAR);
  BEGIN
    v_return :=
      CASE
        WHEN p_data_type = 'NUMBER' THEN '-999999999999999.999999999999999'
        WHEN p_data_type LIKE '%CHAR%' THEN '''@@@@@@@@@@@@@@@'''
        WHEN p_data_type = 'DATE' THEN 'TO_DATE( ''01.01.1900'',''DD.MM.YYYY'' )'
        WHEN p_data_type LIKE 'TIMESTAMP%' THEN 'TO_TIMESTAMP( ''01.01.1900'',''dd.mm.yyyy'' )'
        WHEN p_data_type = 'CLOB' THEN 'TO_CLOB( ''@@@@@@@@@@@@@@@'' )'
        WHEN p_data_type = 'BLOB' THEN 'TO_BLOB( UTL_RAW.cast_to_raw( ''@@@@@@@@@@@@@@@'' ) )'
        WHEN p_data_type = 'XMLTYPE' THEN 'XMLTYPE( ''<NULL/>'' )'
        ELSE '''@@@@@@@@@@@@@@@'''
      END;
    RETURN v_return;
  END util_get_attribute_surrogate;

  -----------------------------------------------------------------------------
  -- util_get_attribute_compare is a private helper function to deliver the
  -- described (take a look at function util_get_attribute_surrogate) compare
  -- code for two attributes. In addition to that,the compare operation must
  -- be dynamically,because e.g. "=" or "<>" or other operations are required.
  -----------------------------------------------------------------------------

  FUNCTION util_get_attribute_compare(p_data_type         IN user_tab_cols.data_type%TYPE
                                    , p_first_attribute   IN VARCHAR2
                                    , p_second_attribute  IN VARCHAR2
                                    , p_compare_operation IN VARCHAR2 DEFAULT '<>')
    RETURN VARCHAR2
  IS
    v_surrogate VARCHAR2(100 CHAR);
    v_return    VARCHAR2(1000 CHAR);
  BEGIN
    v_surrogate := util_get_attribute_surrogate(p_data_type);
    v_return    :=
      CASE
        WHEN p_data_type = 'XMLTYPE'
        THEN
             'util_xml_compare( COALESCE( '
          || p_first_attribute
          || ','
          || v_surrogate
          || ' ),COALESCE( '
          || p_second_attribute
          || ','
          || v_surrogate
          || ' ) ) '
          || p_compare_operation
          || ' 0'
        WHEN p_data_type IN ('BLOB', 'CLOB')
        THEN
             'DBMS_LOB.compare( COALESCE( '
          || p_first_attribute
          || ','
          || v_surrogate
          || ' ),COALESCE( '
          || p_second_attribute
          || ','
          || v_surrogate
          || ' ) ) '
          || p_compare_operation
          || ' 0'
        ELSE
             'COALESCE( '
          || p_first_attribute
          || ','
          || v_surrogate
          || ' ) '
          || p_compare_operation
          || ' COALESCE( '
          || p_second_attribute
          || ','
          || v_surrogate
          || ' )'
      END;
    RETURN v_return;
  END util_get_attribute_compare;

  -----------------------------------------------------------------------------
  -- util_get_vc2_4000_operation is a private helper function to deliver a
  -- varchar2 representation of an attribute in dependency of its datatype.
  -----------------------------------------------------------------------------

  FUNCTION util_get_vc2_4000_operation(p_data_type IN all_tab_cols.data_type%TYPE, p_attribute_name IN VARCHAR2)
    RETURN VARCHAR2
  IS
    v_return VARCHAR2(1000 CHAR);
  BEGIN
    v_return :=
      CASE
        WHEN p_data_type IN ('NUMBER', 'FLOAT', 'INTEGER')
        THEN
          'to_char(' || p_attribute_name || ')'
        WHEN p_data_type = 'DATE'
        THEN
          'to_char(' || p_attribute_name || ',''yyyy.mm.dd hh24:mi:ss'')'
        WHEN p_data_type LIKE 'TIMESTAMP%'
        THEN
          'to_char(' || p_attribute_name || ',''yyyy.mm.dd hh24:mi:ss.ff'')'
        WHEN p_data_type = 'BLOB'
        THEN
          '''Data type "BLOB" is not supported for generic change log'''
        WHEN p_data_type = 'XMLTYPE'
        THEN
             'substr( CASE WHEN '
          || p_attribute_name
          || ' IS NULL THEN NULL ELSE '
          || p_attribute_name
          || '.getStringVal() END,1,4000)'
        ELSE
          'substr(' || p_attribute_name || ',1,4000)'
      END;
    RETURN v_return;
  END util_get_vc2_4000_operation;

  -----------------------------------------------------------------------------
  -- util_get_user_name is a private helper function to deliver the current
  -- username. If a valid APEX session exists,then the APEX application user
  -- is taken,otherwise the current connected operation system user.
  -----------------------------------------------------------------------------

  FUNCTION util_get_user_name
    RETURN all_users.username%TYPE
  IS
    v_return all_users.username%TYPE;
  BEGIN
    v_return := UPPER(SYS_CONTEXT('USERENV', 'OS_USER'));
    RETURN v_return;
  END util_get_user_name;

  -----------------------------------------------------------------------------
  -- util_get_parameter_name is a private helper function to deliver a cleaned
  -- normalized parameter name.
  -----------------------------------------------------------------------------

  FUNCTION util_get_parameter_name(p_column_name VARCHAR2, p_rpad INTEGER)
    RETURN VARCHAR2
  IS
    v_return user_objects.object_name%TYPE;
  BEGIN
    v_return := REGEXP_REPLACE(LOWER(p_column_name), '[^a-z0-9_]', NULL);

    IF g_params.enable_parameter_prefixes
    THEN
      v_return := 'p_' || SUBSTR(v_return, 1, c_ora_max_name_len - 2);
    END IF;

    IF p_rpad IS NOT NULL
    THEN
      v_return := RPAD(v_return, CASE WHEN g_params.enable_parameter_prefixes THEN p_rpad + 2 ELSE p_rpad END);
    END IF;

    RETURN v_return;
  END util_get_parameter_name;

  -----------------------------------------------------------------------------
  -- util_get_method_name is a private helper function to deliver a cleaned
  -- normalized method name for the getter and setter functions/procedures.
  -----------------------------------------------------------------------------

  FUNCTION util_get_method_name(p_column_name VARCHAR2)
    RETURN VARCHAR2
  IS
    v_return user_objects.object_name%TYPE;
  BEGIN
    v_return := REGEXP_REPLACE(LOWER(p_column_name), '[^a-z0-9_]', NULL);
    v_return :=
      CASE
        WHEN g_params.col_prefix_in_method_names THEN SUBSTR(v_return, 1, c_ora_max_name_len - 4)
        ELSE SUBSTR(v_return, LENGTH(g_status.column_prefix) + 2, c_ora_max_name_len - 4)
      END;

    RETURN v_return;
  END;

  -----------------------------------------------------------------------------

  FUNCTION util_get_substituted_name(p_name_template VARCHAR2)
    RETURN VARCHAR2
  IS
    v_return         all_objects.object_name%TYPE;
    v_base_name      all_objects.object_name%TYPE;
    v_replace_string all_objects.object_name%TYPE;
    v_position       PLS_INTEGER;
    v_length         PLS_INTEGER;
  BEGIN
    -- Get replace string
    v_replace_string :=
      REGEXP_SUBSTR(p_name_template
                  , '#[A-Za-z0-9_-]+#'
                  , 1
                  , 1);

    -- Check,if we have to do a replacement
    IF v_replace_string IS NULL
    THEN
      -- Without replacement we return simply the input
      v_return := p_name_template;
    ELSE
      -- Replace possible placeholders in name template
      v_base_name :=
        RTRIM(REGEXP_SUBSTR(UPPER(v_replace_string)
                          , '[A-Z_]+'
                          , 1
                          , 1)
            , '_');

      -- logger.log('v_base_name: ' || v_base_name);

      -- Check,if we have a valid base name

      IF v_base_name NOT IN ('TABLE_NAME', 'PK_COLUMN', 'COLUMN_PREFIX')
      THEN
        -- Without a valid base name we return simply the input
        v_return := p_name_template;
      ELSE
        -- Search for start and stop positions
        v_position :=
          REGEXP_SUBSTR(v_replace_string
                      , '-?\d+'
                      , 1
                      , 1);
        v_length :=
          REGEXP_SUBSTR(v_replace_string
                      , '\d+'
                      , 1
                      , 2);

        -- 1. To be backward compatible we have to support things like this TABLE_NAME_26.
        -- 2. If someone want to use the substr version he has always to provide position and length.
        -- 3. Negative position is supported like this #TABLE_NAME_-15_15# (the second number can not be omitted like in substr,see 1.)
        IF v_position IS NULL
       AND v_length IS NULL
        THEN
          v_length   := 200;
          v_position := 1;
        ELSIF v_position IS NOT NULL
          AND v_length IS NULL
        THEN
          v_length   := v_position;
          v_position := 1;
        END IF;

        v_return :=
          REPLACE(
            p_name_template
          , v_replace_string
          , SUBSTR(
              CASE v_base_name
                WHEN 'TABLE_NAME' THEN g_params.table_name
                WHEN 'PK_COLUMN' THEN g_pk_columns(1).column_name
                WHEN 'COLUMN_PREFIX' THEN g_status.column_prefix
              END
            , v_position
            , v_length));
      END IF;
    END IF;

    RETURN v_return;
  END util_get_substituted_name;

  -----------------------------------------------------------------------------

  FUNCTION util_get_column_data_default(p_table_name  IN VARCHAR2
                                      , p_column_name IN VARCHAR2
                                      , p_owner          VARCHAR2 DEFAULT USER)
    RETURN VARCHAR2
  AS
    v_return LONG;

    CURSOR c_utc IS
      SELECT data_default
        FROM all_tab_columns
       WHERE owner = p_owner
         AND table_name = p_table_name
         AND column_name = p_column_name;
  BEGIN
    OPEN c_utc;

    FETCH c_utc INTO v_return;

    CLOSE c_utc;

    RETURN SUBSTR(v_return, 1, 4000);
  END;

  --------------------------------------------------------------------------------

  FUNCTION util_get_cons_search_condition(p_constraint_name IN VARCHAR2, p_owner IN VARCHAR2 DEFAULT USER)
    RETURN VARCHAR2
  AS
    v_return LONG;

    CURSOR c_search_condition IS
      SELECT search_condition
        FROM all_constraints
       WHERE owner = p_owner
         AND constraint_name = p_constraint_name;
  BEGIN
    OPEN c_search_condition;

    FETCH c_search_condition INTO v_return;

    CLOSE c_search_condition;

    RETURN SUBSTR(v_return, 1, 4000);
  END;

  -----------------------------------------------------------------------------

  FUNCTION util_get_ora_max_name_len
    RETURN INTEGER
  IS
  BEGIN
    RETURN c_ora_max_name_len;
  END;

  -----------------------------------------------------------------------------

  FUNCTION util_split_to_table(p_string IN VARCHAR2, p_delimiter IN VARCHAR2 DEFAULT ',')
    RETURN t_tab_vc2_4k
    PIPELINED
  IS
    v_offset                 PLS_INTEGER := 1;
    v_index                  PLS_INTEGER := INSTR(p_string, p_delimiter, v_offset);
    v_delimiter_length       PLS_INTEGER := LENGTH(p_delimiter);
    v_string_length CONSTANT PLS_INTEGER := LENGTH(p_string);
  BEGIN
    WHILE v_index > 0
    LOOP
      PIPE ROW (TRIM(SUBSTR(p_string, v_offset, v_index - v_offset)));
      v_offset := v_index + v_delimiter_length;
      v_index  := INSTR(p_string, p_delimiter, v_offset);
    END LOOP;

    IF v_string_length - v_offset + 1 > 0
    THEN
      PIPE ROW (TRIM(SUBSTR(p_string, v_offset, v_string_length - v_offset + 1)));
    END IF;

    RETURN;
  END util_split_to_table;

  -----------------------------------------------------------------------------

  FUNCTION util_serialize_xml(p_xml XMLTYPE)
    RETURN VARCHAR2
  IS
    v_return VARCHAR2(32767);
  BEGIN
    SELECT XMLSERIALIZE(DOCUMENT p_xml NO INDENT) INTO v_return FROM DUAL;

    RETURN v_return;
  END util_serialize_xml;

  --------------------------------------------------------------------------------

  PROCEDURE util_set_debug_on
  IS
  BEGIN
    g_debug_enabled := TRUE;
    g_debug_run     := 0;
    g_debug_step    := 0;
    g_debug.delete;
  END;

  --------------------------------------------------------------------------------

  PROCEDURE util_set_debug_off
  IS
  BEGIN
    g_debug_enabled := FALSE;
  END;

  PROCEDURE util_debug_start_one_run(p_generator_action VARCHAR2
                                   , p_table_name       all_objects.object_name%TYPE
                                   , p_owner            all_users.username%TYPE)
  IS
  BEGIN
    g_debug_module := c_generator || ' v' || c_generator_version || ': ' || p_generator_action;

    IF g_debug_enabled
    THEN
      g_debug_run := g_debug_run + 1;

      IF g_debug_run <= c_debug_max_runs
      THEN
        g_debug_step                    := 0;
        g_debug(g_debug_run).run        := g_debug_run;
        g_debug(g_debug_run).owner      := p_owner;
        g_debug(g_debug_run).table_name := p_table_name;
        g_debug(g_debug_run).start_time := SYSTIMESTAMP;
      END IF;
    END IF;
  END;

  -----------------------------------------------------------------------------

  PROCEDURE util_debug_stop_one_run
  IS
  BEGIN
    IF g_debug_enabled
   AND g_debug_run <= c_debug_max_runs
    THEN
      g_debug(g_debug_run).stop_time := SYSTIMESTAMP;
    END IF;
  END;

  -----------------------------------------------------------------------------

  PROCEDURE util_debug_start_one_step(p_action VARCHAR2)
  IS
  BEGIN
    DBMS_APPLICATION_INFO.set_module(module_name => g_debug_module, action_name => p_action);

    IF g_debug_enabled
   AND g_debug_run <= c_debug_max_runs
    THEN
      g_debug_step                                          := g_debug_step + 1;
      g_debug(g_debug_run).details(g_debug_step).step       := g_debug_step;
      g_debug(g_debug_run).details(g_debug_step).module     := g_debug_module;
      g_debug(g_debug_run).details(g_debug_step).action     := p_action;
      g_debug(g_debug_run).details(g_debug_step).start_time := SYSTIMESTAMP;
    END IF;
  END;

  -----------------------------------------------------------------------------

  PROCEDURE util_debug_stop_one_step
  IS
  BEGIN
    DBMS_APPLICATION_INFO.set_module(module_name => NULL, action_name => NULL);

    IF g_debug_enabled
   AND g_debug_run <= c_debug_max_runs
    THEN
      g_debug(g_debug_run).details(g_debug_step).stop_time := SYSTIMESTAMP;
    END IF;
  END;

  -----------------------------------------------------------------------------

  FUNCTION util_view_debug_log
    RETURN t_tab_debug_data
    PIPELINED
  IS
    v_return t_rec_debug_data;
  BEGIN
    FOR i IN 1 .. g_debug.COUNT
    LOOP
      v_return.run        := g_debug(i).run;
      v_return.run_time   := ROUND(SYSDATE + ((g_debug(i).stop_time - g_debug(i).start_time) * 86400) - SYSDATE, 6);
      v_return.owner      := g_debug(i).owner;
      v_return.table_name := g_debug(i).table_name;

      FOR j IN 1 .. g_debug(i).details.COUNT
      LOOP
        v_return.step       := g_debug(i).details(j).step;
        v_return.elapsed    :=
          ROUND(SYSDATE + ((g_debug(i).details(j).stop_time - g_debug(i).start_time) * 86400) - SYSDATE, 6);
        v_return.execution  :=
          ROUND(SYSDATE + ((g_debug(i).details(j).stop_time - g_debug(i).details(j).start_time) * 86400) - SYSDATE, 6);
        v_return.action     := g_debug(i).details(j).action;
        v_return.start_time := g_debug(i).details(j).start_time;
        --sysdate + (interval_difference * 86400) - sysdate
        --https://stackoverflow.com/questions/10092032/extracting-the-total-number-of-seconds-from-an-interval-data-type
        PIPE ROW (v_return);
      END LOOP;
    END LOOP;
  END;

  -----------------------------------------------------------------------------

  FUNCTION util_view_columns_array
    RETURN t_tab_debug_columns
    PIPELINED
  IS
    v_return t_rec_columns;
  BEGIN
    FOR i IN 1 .. g_columns.COUNT
    LOOP
      v_return.column_name           := g_columns(i).column_name;
      v_return.char_length           := g_columns(i).char_length;
      v_return.data_type             := g_columns(i).data_type;
      v_return.data_length           := g_columns(i).data_length;
      v_return.data_precision        := g_columns(i).data_precision;
      v_return.data_scale            := g_columns(i).data_scale;
      v_return.data_default          := g_columns(i).data_default;
      v_return.data_custom_default   := g_columns(i).data_custom_default;
      v_return.custom_default_source := g_columns(i).custom_default_source;
      v_return.is_pk_yn              := g_columns(i).is_pk_yn;
      v_return.is_uk_yn              := g_columns(i).is_uk_yn;
      v_return.is_nullable_yn        := g_columns(i).is_nullable_yn;
      v_return.is_excluded_yn        := g_columns(i).is_excluded_yn;

      PIPE ROW (v_return);
    END LOOP;
  END util_view_columns_array;

  -----------------------------------------------------------------------------

  FUNCTION util_generate_list(p_list_name VARCHAR2)
    RETURN t_tab_vc2_5k
  IS
    -----------------------------------------------------------------------------
    -- Columns as flat list for insert - without p_column_exclude_list:
    -- {% LIST_INSERT_COLUMNS %}
    -- Example:
    --   col1,
    --   col2,
    --   col3,
    --   ...
    -----------------------------------------------------------------------------

    FUNCTION list_insert_columns
      RETURN t_tab_vc2_5k
    IS
      v_result t_tab_vc2_5k;
    BEGIN
      FOR i IN g_columns.FIRST .. g_columns.LAST
      LOOP
        IF g_columns(i).is_excluded_yn = 'N'
        THEN
          v_result(v_result.COUNT + 1) := '      ' || '"' || g_columns(i).column_name || '"' || c_list_delimiter;
        END IF;
      END LOOP;

      v_result(v_result.FIRST) := LTRIM(v_result(v_result.FIRST));
      v_result(v_result.LAST)  := RTRIM(v_result(v_result.LAST), c_list_delimiter);

      RETURN v_result;
    END list_insert_columns;

    -----------------------------------------------------------------------------
    -- Columns as flat list for insert - without p_column_exclude_list:
    -- {% LIST_INSERT_PARAMS %}
    -- Example:
    --   p_col2,
    --   p_col3,
    --   p_col4,
    --   ...
    -----------------------------------------------------------------------------

    FUNCTION list_insert_params
      RETURN t_tab_vc2_5k
    IS
      v_result t_tab_vc2_5k;
    BEGIN
      FOR i IN g_columns.FIRST .. g_columns.LAST
      LOOP
        IF g_columns(i).is_excluded_yn = 'N'
        THEN
          v_result(v_result.COUNT + 1) :=
               '      '
            || CASE
                 WHEN g_columns(i).is_pk_yn = 'Y'
                  AND NOT g_status.pk_is_multi_column
                  AND g_params.sequence_name IS NOT NULL
                 THEN
                      'COALESCE( '
                   || util_get_parameter_name(g_columns(i).column_name, NULL)
                   || ',"'
                   || g_params.sequence_name
                   || '".nextval )'
                 ELSE
                   util_get_parameter_name(g_columns(i).column_name, NULL)
               END
            || c_list_delimiter;
        END IF;
      END LOOP;

      v_result(v_result.FIRST) := LTRIM(v_result(v_result.FIRST));
      v_result(v_result.LAST)  := RTRIM(v_result(v_result.LAST), c_list_delimiter);

      RETURN v_result;
    END list_insert_params;

    -----------------------------------------------------------------------------
    -- Columns as flat list - with p_column_exclude_list:
    -- {% LIST_COLUMNS_W_PK_FULL %}
    -- Example:
    --   col1,
    --   col2,
    --   col3,
    --   ...
    -----------------------------------------------------------------------------

    FUNCTION list_columns_w_pk_full
      RETURN t_tab_vc2_5k
    IS
      v_result t_tab_vc2_5k;
    BEGIN
      FOR i IN g_columns.FIRST .. g_columns.LAST
      LOOP
        v_result(v_result.COUNT + 1) := '      ' || '"' || g_columns(i).column_name || '"' || c_list_delimiter;
      END LOOP;

      v_result(v_result.FIRST) := LTRIM(v_result(v_result.FIRST));
      v_result(v_result.LAST)  := RTRIM(v_result(v_result.LAST), c_list_delimiter);

      RETURN v_result;
    END list_columns_w_pk_full;

    -----------------------------------------------------------------------------
    -- A block of code which compares new and old column values (without PK column) and
    -- counts the number  of differences:
    --    {% LIST_COLUMNS_WO_PK_COMPARE %}
    -- Example:
    --    IF COALESCE( v_row.test_number,-9999.9999 ) <> COALESCE( p_test_number,-9999.9999 ) THEN
    --        v_count := v_count + 1;
    --        create_change_log_entry( p_table     => 'map_users_roles'
    --                         ,p_column    => 'mur_u_id'
    --                         ,p_pk_id     => v_row.mur_id
    --                         ,p_old_value => to_char(v_row.mur_u_id)
    --                         ,p_new_value => to_char(p_mur_u_id) );
    --    END IF;
    --    IF DBMS_LOB.compare(COALESCE(v_row.test_clob,TO_CLOB('$$$$')),COALESCE(p_test_clob,TO_CLOB('$$$$'))) <> 0 THEN
    --        v_count := v_count + 1;
    --        create_change_log_entry( p_table     => 'map_users_roles'
    --                         ,p_column    => 'mur_u_id'
    --                         ,p_pk_id     => v_row.mur_id
    --                         ,p_old_value => to_char(v_row.mur_u_id)
    --                         ,p_new_value => to_char(p_mur_u_id) );
    --    END IF;
    --    ...
    -----------------------------------------------------------------------------

    FUNCTION list_columns_wo_pk_compare
      RETURN t_tab_vc2_5k
    IS
      v_result t_tab_vc2_5k;
    BEGIN
      FOR i IN g_columns.FIRST .. g_columns.LAST
      LOOP
        IF g_columns(i).is_excluded_yn = 'N'
       AND g_columns(i).is_pk_yn = 'N'
        THEN
          v_result(v_result.COUNT + 1) :=
               CASE
                 WHEN i != v_result.FIRST
                 THEN
                   CASE
                     WHEN g_params.enable_generic_change_log
                      AND NOT g_status.pk_is_multi_column
                     THEN
                       '      IF '
                     ELSE
                       '      OR '
                   END
               END
            || util_get_attribute_compare(p_data_type         => g_columns(i).data_type
                                        , p_first_attribute   => 'v_row."' || g_columns(i).column_name || '"'
                                        , p_second_attribute  => util_get_parameter_name(g_columns(i).column_name, NULL)
                                        , p_compare_operation => '<>')
            || CASE
                 WHEN g_params.enable_generic_change_log
                  AND NOT g_status.pk_is_multi_column
                 THEN
                   ' THEN'
               END
            || c_crlf;

          IF g_params.enable_generic_change_log
         AND NOT g_status.pk_is_multi_column
          THEN
            v_result(v_result.COUNT + 1) := '        v_count := v_count + 1;' || c_crlf;
            v_result(v_result.COUNT + 1) := '        create_change_log_entry (' || c_crlf;
            v_result(v_result.COUNT + 1) := '          p_table     => ''' || g_params.table_name || ''',' || c_crlf;

            v_result(v_result.COUNT + 1) :=
              '          p_column    => ''' || g_columns(i).column_name || ''',' || c_crlf;

            v_result(v_result.COUNT + 1) :=
              '          p_pk_id     => v_row."' || g_pk_columns(1).column_name || '",' || c_crlf;

            v_result(v_result.COUNT + 1) :=
                 '          p_old_value => '
              || util_get_vc2_4000_operation(p_data_type      => g_columns(i).data_type
                                           , p_attribute_name => 'v_row."' || g_columns(i).column_name || '"')
              || ','
              || c_crlf;

            v_result(v_result.COUNT + 1) :=
                 '          p_new_value => '
              || util_get_vc2_4000_operation(
                   p_data_type      => g_columns(i).data_type
                 , p_attribute_name => util_get_parameter_name(g_columns(i).column_name, NULL))
              || ' );'
              || c_crlf;

            v_result(v_result.COUNT + 1) := '      END IF;' || c_crlf;
          END IF;
        END IF;
      END LOOP;

      IF g_params.enable_generic_change_log
     AND NOT g_status.pk_is_multi_column
      THEN
        v_result(v_result.COUNT + 1) := '      IF v_count > 0';
      END IF;

      RETURN v_result;
    END list_columns_wo_pk_compare;

    -----------------------------------------------------------------------------
    -- Columns as parameter definition for create_row,update_row with PK:
    -- {% LIST_PARAMS_W_PK %}
    -- Example:
    --   p_col1 IN table.col1%TYPE,
    --   p_col2 IN table.col2%TYPE,
    --   p_col3 IN table.col3%TYPE,
    --   ...
    -----------------------------------------------------------------------------

    FUNCTION list_params_w_pk
      RETURN t_tab_vc2_5k
    IS
      v_result t_tab_vc2_5k;
    BEGIN
      FOR i IN g_columns.FIRST .. g_columns.LAST
      LOOP
        IF g_columns(i).is_excluded_yn = 'N'
        THEN
          v_result(v_result.COUNT + 1) :=
               CASE
                 WHEN g_template_options.padding IS NOT NULL THEN RPAD(' ', g_template_options.padding)
                 ELSE '    '
               END
            || util_get_parameter_name(g_columns(i).column_name, g_status.rpad_columns)
            || ' IN "'
            || g_params.table_name
            || '"."'
            || CASE
                 WHEN g_params.enable_column_defaults
                  AND g_template_options.use_column_defaults
                 THEN
                   RPAD(g_columns(i).column_name || '"%TYPE', g_status.rpad_columns + 6)
                 ELSE
                   g_columns(i).column_name || '"%TYPE'
               END
            || CASE
                 WHEN g_columns(i).is_pk_yn = 'Y'
                  AND NOT g_status.pk_is_multi_column
                  AND g_columns(i).data_default IS NULL
                 THEN
                   ' DEFAULT NULL'
                 WHEN g_params.enable_column_defaults
                  AND g_template_options.use_column_defaults
                 THEN
                   CASE
                     WHEN g_columns(i).data_default IS NOT NULL THEN ' DEFAULT ' || g_columns(i).data_default
                     WHEN g_columns(i).is_nullable_yn = 'Y' THEN ' DEFAULT NULL'
                     ELSE ' '
                   END
               END
            || CASE WHEN g_columns(i).is_pk_yn = 'Y' THEN ' /*PK*/' END
            || c_list_delimiter;
        END IF;
      END LOOP;

      v_result(v_result.FIRST) := LTRIM(v_result(v_result.FIRST));
      v_result(v_result.LAST)  := RTRIM(v_result(v_result.LAST), c_list_delimiter);

      RETURN v_result;
    END list_params_w_pk;

    -----------------------------------------------------------------------------
    -- A parameter list with column defaults:
    -- {% LIST_PARAMS_W_PK_CUST_DEFAULTS %}
    -- Example:
    --   p_employee_id IN employees.employee_id%TYPE DEFAULT get_a_row()."EMPLOYEE_ID",
    --   p_first_name  IN employees.first_name%TYPE  DEFAULT get_a_row()."FIRST_NAME",
    --   p_last_name   IN employees.last_name%TYPE   DEFAULT get_a_row()."LAST_NAME",
    --   ...
    -----------------------------------------------------------------------------

    FUNCTION list_params_w_pk_cust_defaults
      RETURN t_tab_vc2_5k
    IS
      v_result t_tab_vc2_5k;
    BEGIN
      FOR i IN g_columns.FIRST .. g_columns.LAST
      LOOP
        IF g_columns(i).is_excluded_yn = 'N'
        THEN
          v_result(v_result.COUNT + 1) :=
               '    '
            || util_get_parameter_name(g_columns(i).column_name, g_status.rpad_columns)
            || ' IN "'
            || g_params.table_name
            || '".'
            || RPAD('"' || g_columns(i).column_name || '"%TYPE', g_status.rpad_columns + 7)
            || ' DEFAULT get_a_row()."'
            || g_columns(i).column_name
            || '"'
            || CASE WHEN g_columns(i).is_pk_yn = 'Y' THEN ' /*PK*/' END
            || c_list_delimiter;
        END IF;
      END LOOP;

      v_result(v_result.FIRST) := LTRIM(v_result(v_result.FIRST));
      v_result(v_result.LAST)  := RTRIM(v_result(v_result.LAST), c_list_delimiter);

      RETURN v_result;
    END list_params_w_pk_cust_defaults;

    -----------------------------------------------------------------------------
    -- Columns as parameter IN OUT definition for read_row with PK:
    -- {% LIST_PARAMS_W_PK_IO %}
    -- Example:
    --   p_col1 IN            table.col1%TYPE,
    --   p_col2 IN OUT NOCOPY table.col2%TYPE,
    --   p_col3 IN OUT NOCOPY table.col3%TYPE,
    --   ...
    -----------------------------------------------------------------------------

    FUNCTION list_params_w_pk_io
      RETURN t_tab_vc2_5k
    IS
      v_result t_tab_vc2_5k;
    BEGIN
      FOR i IN g_columns.FIRST .. g_columns.LAST
      LOOP
        v_result(v_result.COUNT + 1) :=
             '    '
          || util_get_parameter_name(g_columns(i).column_name, g_status.rpad_columns)
          || CASE WHEN g_columns(i).is_pk_yn = 'Y' THEN ' IN            ' ELSE '    OUT NOCOPY ' END
          || '"'
          || g_params.table_name
          || '"."'
          || g_columns(i).column_name
          || '"%TYPE'
          || CASE WHEN g_columns(i).is_pk_yn = 'Y' THEN ' /*PK*/' END
          || c_list_delimiter;
      END LOOP;

      v_result(v_result.FIRST) := LTRIM(v_result(v_result.FIRST));
      v_result(v_result.LAST)  := RTRIM(v_result(v_result.LAST), c_list_delimiter);

      RETURN v_result;
    END list_params_w_pk_io;

    -----------------------------------------------------------------------------
    -- Map :new values to parameter for IOIUD-Trigger with PK:
    -- {% LIST_MAP_PAR_EQ_NEWCOL_W_PK %}
    -- Example:
    --   p_col1 => :new.col1,
    --   p_col2 => :new.col2,
    --   p_col3 => :new.col3,
    --   ...
    -----------------------------------------------------------------------------

    FUNCTION list_map_par_eq_newcol_w_pk
      RETURN t_tab_vc2_5k
    IS
      v_result t_tab_vc2_5k;
    BEGIN
      FOR i IN g_columns.FIRST .. g_columns.LAST
      LOOP
        IF g_columns(i).is_excluded_yn = 'N'
        THEN
          v_result(v_result.COUNT + 1) :=
               '      '
            || util_get_parameter_name(g_columns(i).column_name, g_status.rpad_columns)
            || ' => :new."'
            || g_columns(i).column_name
            || '"'
            || c_list_delimiter;
        END IF;
      END LOOP;

      v_result(v_result.FIRST) := LTRIM(v_result(v_result.FIRST));
      v_result(v_result.LAST)  := RTRIM(v_result(v_result.LAST), c_list_delimiter);

      RETURN v_result;
    END list_map_par_eq_newcol_w_pk;

    -----------------------------------------------------------------------------
    --  Map parameter to parameter as pass-through parameter with PK:
    -- {% LIST_MAP_PAR_EQ_PARAM_W_PK %}
    -- Example:
    --   p_col1 => p_col1,
    --   p_col2 => p_col2,
    --   p_col3 => p_col3,
    --   ...
    -----------------------------------------------------------------------------

    FUNCTION list_map_par_eq_param_w_pk
      RETURN t_tab_vc2_5k
    IS
      v_result t_tab_vc2_5k;
    BEGIN
      FOR i IN g_columns.FIRST .. g_columns.LAST
      LOOP
        IF g_columns(i).is_excluded_yn = 'N'
        THEN
          v_result(v_result.COUNT + 1) :=
               CASE
                 WHEN g_template_options.padding IS NOT NULL THEN RPAD(' ', g_template_options.padding)
                 ELSE '      '
               END
            || util_get_parameter_name(g_columns(i).column_name, g_status.rpad_columns)
            || ' => '
            || util_get_parameter_name(g_columns(i).column_name, NULL)
            || c_list_delimiter;
        END IF;
      END LOOP;

      v_result(v_result.FIRST) := LTRIM(v_result(v_result.FIRST));
      v_result(v_result.LAST)  := RTRIM(v_result(v_result.LAST), c_list_delimiter);

      RETURN v_result;
    END list_map_par_eq_param_w_pk;

    -----------------------------------------------------------------------------
    -- map rowtype columns to parameter for rowtype handling with PK:
    -- {% LIST_MAP_PAR_EQ_ROWTYPCOL_W_PK %}
    -- Example:
    --   p_col1 => p_row.col1,
    --   p_col2 => p_row.col2,
    --   p_col3 => p_row.col3,
    --   ...
    -----------------------------------------------------------------------------

    FUNCTION list_map_par_eq_rowtypcol_w_pk
      RETURN t_tab_vc2_5k
    IS
      v_result t_tab_vc2_5k;
    BEGIN
      FOR i IN g_columns.FIRST .. g_columns.LAST
      LOOP
        IF g_columns(i).is_excluded_yn = 'N'
        THEN
          v_result(v_result.COUNT + 1) :=
               '      '
            || util_get_parameter_name(g_columns(i).column_name, g_status.rpad_columns)
            || ' => p_row."'
            || g_columns(i).column_name
            || '"'
            || c_list_delimiter;
        END IF;
      END LOOP;

      v_result(v_result.FIRST) := LTRIM(v_result(v_result.FIRST));
      v_result(v_result.LAST)  := RTRIM(v_result(v_result.LAST), c_list_delimiter);

      RETURN v_result;
    END list_map_par_eq_rowtypcol_w_pk;

    -----------------------------------------------------------------------------
    -- A column list for updating a row without PK:
    -- {% LIST_SET_COL_EQ_PARAM_WO_PK %}
    -- Example:
    --   test_number   = p_test_number,
    --   test_varchar2 = p_test_varchar2,
    --   ...
    -----------------------------------------------------------------------------

    FUNCTION list_set_col_eq_param_wo_pk
      RETURN t_tab_vc2_5k
    IS
      v_result t_tab_vc2_5k;
    BEGIN
      FOR i IN g_columns.FIRST .. g_columns.LAST
      LOOP
        IF g_columns(i).is_excluded_yn = 'N'
       AND g_columns(i).is_pk_yn = 'N'
        THEN
          v_result(v_result.COUNT + 1) :=
               '               '
            || RPAD('"' || g_columns(i).column_name || '"', g_status.rpad_columns + 2)
            || ' = '
            || util_get_parameter_name(g_columns(i).column_name, NULL)
            || c_list_delimiter;
        END IF;
      END LOOP;

      v_result(v_result.FIRST) := LTRIM(v_result(v_result.FIRST));
      v_result(v_result.LAST)  := RTRIM(v_result(v_result.LAST), c_list_delimiter);

      RETURN v_result;
    END list_set_col_eq_param_wo_pk;

    -----------------------------------------------------------------------------
    -- A column list without pk for setting parameter to row columns:
    -- {% LIST_SET_PAR_EQ_ROWTYCOL_WO_PK %}
    -- Example:
    --   p_test_number   := v_row.test_number;
    --   p_test_varchar2 := v_row.test_varchar2;
    --   ...
    -----------------------------------------------------------------------------

    FUNCTION list_set_par_eq_rowtycol_wo_pk
      RETURN t_tab_vc2_5k
    IS
      v_result t_tab_vc2_5k;
    BEGIN
      FOR i IN g_columns.FIRST .. g_columns.LAST
      LOOP
        IF g_columns(i).is_excluded_yn = 'N'
       AND g_columns(i).is_pk_yn = 'N'
        THEN
          v_result(v_result.COUNT + 1) :=
               '      '
            || util_get_parameter_name(g_columns(i).column_name, g_status.rpad_columns)
            || ' := v_row."'
            || g_columns(i).column_name
            || '"; '
            || c_crlf;
        END IF;
      END LOOP;

      v_result(v_result.FIRST) := LTRIM(v_result(v_result.FIRST));
      v_result(v_result.LAST)  := RTRIM(v_result(v_result.LAST), c_crlf);

      RETURN v_result;
    END list_set_par_eq_rowtycol_wo_pk;

    -----------------------------------------------------------------------------
    -- Primary key parameter definition for create_row:
    -- {% LIST_PARAMS_PK %}
    -- Example:
    --   p_col1 IN table.col1%TYPE,
    --   p_col2 IN table.col2%TYPE,
    --   p_col3 IN table.col3%TYPE,
    --   ...
    -----------------------------------------------------------------------------

    FUNCTION list_pk_params
      RETURN t_tab_vc2_5k
    IS
      v_result t_tab_vc2_5k;
    BEGIN
      FOR i IN g_pk_columns.FIRST .. g_pk_columns.LAST
      LOOP
        v_result(v_result.COUNT + 1) :=
             '    '
          || util_get_parameter_name(g_pk_columns(i).column_name, g_status.rpad_columns)
          || ' IN "'
          || g_params.table_name
          || '"."'
          || g_pk_columns(i).column_name
          || '"%TYPE /*PK*/'
          || c_list_delimiter;
      END LOOP;

      v_result(v_result.FIRST) := LTRIM(v_result(v_result.FIRST));
      v_result(v_result.LAST)  := RTRIM(v_result(v_result.LAST), c_list_delimiter);

      RETURN v_result;
    END list_pk_params;

    -----------------------------------------------------------------------------
    -- Primary key columns parameter compare for get_pk_by_unique_cols functions:
    -- {% LIST_PK_COLUMN_COMPARE %}
    -- Example:
    --       COALESCE( "COL1",'@@@@@@@@@@@@@@@' ) = COALESCE( p_col1,'@@@@@@@@@@@@@@@' )
    --   AND COALESCE( "COL2",'@@@@@@@@@@@@@@@' ) = COALESCE( p_col2,'@@@@@@@@@@@@@@@' )
    --   ...
    -----------------------------------------------------------------------------

    FUNCTION list_pk_column_compare
      RETURN t_tab_vc2_5k
    IS
      v_result t_tab_vc2_5k;
    BEGIN
      FOR i IN g_pk_columns.FIRST .. g_pk_columns.LAST
      LOOP
        v_result(v_result.COUNT + 1) :=
             '               '
          || 'AND '
          || util_get_attribute_compare(p_data_type         => g_pk_columns(i).data_type
                                      , p_first_attribute   => '"' || g_pk_columns(i).column_name || '"'
                                      , p_second_attribute  => util_get_parameter_name(g_pk_columns(i).column_name, NULL)
                                      , p_compare_operation => '=')
          || c_crlf;
      END LOOP;

      v_result(v_result.FIRST) := LTRIM(LTRIM(v_result(v_result.FIRST)), 'AND ');

      v_result(v_result.LAST)  := RTRIM(v_result(v_result.LAST), c_crlf);

      RETURN v_result;
    END list_pk_column_compare;

    -----------------------------------------------------------------------------
    -- Primary key columns as "parameter => parameter" mapping for read_row functions:
    -- {% LIST_PK_MAP_PARAM_EQ_PARAM %}
    -- Example:
    --   p_col1 => p_col1,
    --   p_col2 => p_col2,
    --   ...
    -----------------------------------------------------------------------------

    FUNCTION list_pk_map_param_eq_param
      RETURN t_tab_vc2_5k
    IS
      v_result t_tab_vc2_5k;
    BEGIN
      FOR i IN g_pk_columns.FIRST .. g_pk_columns.LAST
      LOOP
        v_result(v_result.COUNT + 1) :=
             '    '
          || util_get_parameter_name(g_pk_columns(i).column_name
                                   , CASE WHEN g_status.pk_is_multi_column THEN g_status.rpad_pk_columns ELSE NULL END)
          || ' => '
          || util_get_parameter_name(g_pk_columns(i).column_name, NULL)
          || c_list_delimiter;
      END LOOP;

      v_result(v_result.FIRST) := LTRIM(v_result(v_result.FIRST));
      v_result(v_result.LAST)  := RTRIM(v_result(v_result.LAST), c_list_delimiter);

      RETURN v_result;
    END list_pk_map_param_eq_param;

    -----------------------------------------------------------------------------
    -- Primary key columns as "parameter => :old.column" mapping for DML view trigger:
    -- {% LIST_PK_MAP_PARAM_EQ_OLDCOL %}
    -- Example:
    --   p_col1 => :old.col1,
    --   p_col2 => :old.col2,
    --   ...
    -----------------------------------------------------------------------------

    FUNCTION list_pk_map_param_eq_oldcol
      RETURN t_tab_vc2_5k
    IS
      v_result t_tab_vc2_5k;
    BEGIN
      FOR i IN g_pk_columns.FIRST .. g_pk_columns.LAST
      LOOP
        v_result(v_result.COUNT + 1) :=
             '      '
          || util_get_parameter_name(g_pk_columns(i).column_name
                                   , CASE WHEN g_status.pk_is_multi_column THEN g_status.rpad_pk_columns ELSE NULL END)
          || ' => '
          || ':old."'
          || g_pk_columns(i).column_name
          || '"'
          || c_list_delimiter;
      END LOOP;

      v_result(v_result.FIRST) := LTRIM(v_result(v_result.FIRST));
      v_result(v_result.LAST)  := RTRIM(v_result(v_result.LAST), c_list_delimiter);

      RETURN v_result;
    END list_pk_map_param_eq_oldcol;

    -----------------------------------------------------------------------------
    -- Unique columns as parameter definition for get_pk_by_unique_cols/read_row functions:
    -- {% LIST_UK_PARAMS %}
    -- Example:
    --   p_col1 IN table.col1%TYPE,
    --   p_col2 IN table.col2%TYPE,
    --   p_col3 IN table.col3%TYPE,
    --   ...
    -----------------------------------------------------------------------------

    FUNCTION list_uk_params
      RETURN t_tab_vc2_5k
    IS
      v_result t_tab_vc2_5k;
    BEGIN
      FOR i IN g_uk_columns.FIRST .. g_uk_columns.LAST
      LOOP
        IF g_uk_columns(i).constraint_name = g_iterator.current_unique_constraint
        THEN
          v_result(v_result.COUNT + 1) :=
               '    '
            || util_get_parameter_name(g_uk_columns(i).column_name, g_status.rpad_columns)
            || ' IN "'
            || g_params.table_name
            || '"."'
            || g_uk_columns(i).column_name
            || '"%TYPE /*UK*/'
            || c_list_delimiter;
        END IF;
      END LOOP;

      v_result(v_result.FIRST) := LTRIM(v_result(v_result.FIRST));
      v_result(v_result.LAST)  := RTRIM(v_result(v_result.LAST), c_list_delimiter);

      RETURN v_result;
    END list_uk_params;

    -----------------------------------------------------------------------------
    -- Unique columns parameter compare for get_pk_by_unique_cols functions:
    -- {% LIST_UK_COLUMN_COMPARE %}
    -- Example:
    --       COALESCE( "COL1",'@@@@@@@@@@@@@@@' ) = COALESCE( p_COL1,'@@@@@@@@@@@@@@@' )
    --   AND COALESCE( "COL2",'@@@@@@@@@@@@@@@' ) = COALESCE( p_COL2,'@@@@@@@@@@@@@@@' )
    --   ...
    -----------------------------------------------------------------------------

    FUNCTION list_uk_column_compare
      RETURN t_tab_vc2_5k
    IS
      v_result t_tab_vc2_5k;
    BEGIN
      FOR i IN g_uk_columns.FIRST .. g_uk_columns.LAST
      LOOP
        IF g_uk_columns(i).constraint_name = g_iterator.current_unique_constraint
        THEN
          v_result(v_result.COUNT + 1) :=
               '         AND '
            || util_get_attribute_compare(
                 p_data_type         => g_uk_columns(i).data_type
               , p_first_attribute   => '"' || g_uk_columns(i).column_name || '"'
               , p_second_attribute  => util_get_parameter_name(g_uk_columns(i).column_name, NULL)
               , p_compare_operation => '=')
            || c_crlf;
        END IF;
      END LOOP;

      v_result(v_result.FIRST) := LTRIM(LTRIM(v_result(v_result.FIRST)), 'AND ');

      v_result(v_result.LAST)  := RTRIM(v_result(v_result.LAST), c_crlf);

      RETURN v_result;
    END list_uk_column_compare;

    -----------------------------------------------------------------------------
    -- Unique key columns as "parameter => parameter" mapping for read_row functions:
    -- {% LIST_UK_MAP_PARAM_EQ_PARAM %}
    -- Example:
    --   p_col1 => p_col1,
    --   p_col2 => p_col2,
    --   ...
    -----------------------------------------------------------------------------

    FUNCTION list_uk_map_param_eq_param
      RETURN t_tab_vc2_5k
    IS
      v_result t_tab_vc2_5k;
    BEGIN
      FOR i IN g_uk_columns.FIRST .. g_uk_columns.LAST
      LOOP
        IF g_uk_columns(i).constraint_name = g_iterator.current_unique_constraint
        THEN
          v_result(v_result.COUNT + 1) :=
               '    '
            || util_get_parameter_name(
                 g_uk_columns(i).column_name
               , CASE WHEN g_status.pk_is_multi_column THEN g_status.rpad_uk_columns ELSE NULL END)
            || ' => '
            || util_get_parameter_name(g_uk_columns(i).column_name, NULL)
            || c_list_delimiter;
        END IF;
      END LOOP;

      v_result(v_result.FIRST) := LTRIM(v_result(v_result.FIRST));
      v_result(v_result.LAST)  := RTRIM(v_result(v_result.LAST), c_list_delimiter);

      RETURN v_result;
    END list_uk_map_param_eq_param;

    -----------------------------------------------------------------------------
    -- A list of column defaults - used in the function get_a_row:
    -- {% LIST_ROWCOLS_W_CUST_DEFAULTS %}
    -- Example:
    --   v_row.employee_id := employees_seq.nextval; --generated from SEQ
    --   v_row.first_name  := 'Rowan';
    --   v_row.last_name   := 'Atkinson';
    --   ...
    -----------------------------------------------------------------------------

    FUNCTION list_rowcols_w_cust_defaults
      RETURN t_tab_vc2_5k
    IS
      v_result t_tab_vc2_5k;
    BEGIN
      FOR i IN g_columns.FIRST .. g_columns.LAST
      LOOP
        IF g_columns(i).data_custom_default IS NOT NULL
        THEN
          v_result(v_result.COUNT + 1) :=
               '    '
            || 'v_row.'
            || RPAD('"' || g_columns(i).column_name || '"', g_status.rpad_columns + 2)
            || ' := '
            || NVL(g_columns(i).data_custom_default, g_columns(i).data_default)
            || ';'
            || c_crlf;
        END IF;
      END LOOP;

      IF v_result.COUNT > 0
      THEN
        v_result(v_result.FIRST) := LTRIM(v_result(v_result.FIRST));
        v_result(v_result.LAST)  := RTRIM(v_result(v_result.LAST), c_crlf);
      END IF;

      RETURN v_result;
    END list_rowcols_w_cust_defaults;

    -----------------------------------------------------------------------------
    -- A list of custom column defaults - used to save the defaults in the spec:
    -- {% LIST_SPEC_CUSTOM_DEFAULTS %}
    -- Example:
    --   v_row.employee_id := employees_seq.nextval; --generated from SEQ
    --   v_row.first_name  := 'Rowan';
    --   v_row.last_name   := 'Atkinson';
    --   ...
    -----------------------------------------------------------------------------

    FUNCTION list_spec_custom_defaults
      RETURN t_tab_vc2_5k
    IS
      v_result t_tab_vc2_5k;
    BEGIN
      v_result(v_result.COUNT + 1) := '<custom_defaults>' || c_crlf;

      FOR i IN g_columns.FIRST .. g_columns.LAST
      LOOP
        IF g_columns(i).data_custom_default IS NOT NULL
        THEN
          v_result(v_result.COUNT + 1) :=
               '    <column source="'
            || RPAD(g_columns(i).custom_default_source || '"', 8)
            || ' name="'
            || g_columns(i).column_name
            || '"><![CDATA['
            || g_columns(i).data_custom_default
            || ']]></column>'
            || c_crlf;
        END IF;
      END LOOP;

      v_result(v_result.COUNT + 1) := '  </custom_defaults>' || c_crlf;

      IF v_result.COUNT > 2
      THEN
        v_result(v_result.LAST) := RTRIM(v_result(v_result.LAST), c_crlf);
      ELSE
        -- no data available, only the empty <custom_defaults> element
        v_result.delete;
      END IF;

      RETURN v_result;
    END list_spec_custom_defaults;
  -----------------------------------------------------------------------------

  BEGIN
    CASE p_list_name
      WHEN 'LIST_INSERT_COLUMNS'
      THEN
        RETURN list_insert_columns;
      WHEN 'LIST_COLUMNS_W_PK_FULL'
      THEN
        RETURN list_columns_w_pk_full;
      WHEN 'LIST_ROWCOLS_W_CUST_DEFAULTS'
      THEN
        RETURN list_rowcols_w_cust_defaults;
      WHEN 'LIST_COLUMNS_WO_PK_COMPARE'
      THEN
        RETURN list_columns_wo_pk_compare;
      WHEN 'LIST_MAP_PAR_EQ_NEWCOL_W_PK'
      THEN
        RETURN list_map_par_eq_newcol_w_pk;
      WHEN 'LIST_MAP_PAR_EQ_PARAM_W_PK'
      THEN
        RETURN list_map_par_eq_param_w_pk;
      WHEN 'LIST_MAP_PAR_EQ_ROWTYPCOL_W_PK'
      THEN
        RETURN list_map_par_eq_rowtypcol_w_pk;
      WHEN 'LIST_PARAMS_W_PK'
      THEN
        RETURN list_params_w_pk;
      WHEN 'LIST_PARAMS_W_PK_IO'
      THEN
        RETURN list_params_w_pk_io;
      WHEN 'LIST_PARAMS_W_PK_CUST_DEFAULTS'
      THEN
        RETURN list_params_w_pk_cust_defaults;
      WHEN 'LIST_INSERT_PARAMS'
      THEN
        RETURN list_insert_params;
      WHEN 'LIST_SET_COL_EQ_PARAM_WO_PK'
      THEN
        RETURN list_set_col_eq_param_wo_pk;
      WHEN 'LIST_SET_PAR_EQ_ROWTYCOL_WO_PK'
      THEN
        RETURN list_set_par_eq_rowtycol_wo_pk;
      WHEN 'LIST_PK_PARAMS'
      THEN
        RETURN list_pk_params;
      WHEN 'LIST_PK_COLUMN_COMPARE'
      THEN
        RETURN list_pk_column_compare;
      WHEN 'LIST_PK_MAP_PARAM_EQ_PARAM'
      THEN
        RETURN list_pk_map_param_eq_param;
      WHEN 'LIST_PK_MAP_PARAM_EQ_OLDCOL'
      THEN
        RETURN list_pk_map_param_eq_oldcol;
      WHEN 'LIST_UK_PARAMS'
      THEN
        RETURN list_uk_params;
      WHEN 'LIST_UK_COLUMN_COMPARE'
      THEN
        RETURN list_uk_column_compare;
      WHEN 'LIST_UK_MAP_PARAM_EQ_PARAM'
      THEN
        RETURN list_uk_map_param_eq_param;
      WHEN 'LIST_SPEC_CUSTOM_DEFAULTS'
      THEN
        RETURN list_spec_custom_defaults;
      ELSE
        raise_application_error(c_generator_error_number, 'FIXME: Bug - list ' || p_list_name || ' not defined');
    END CASE;
  END;

  -----------------------------------------------------------------------------
  -- util_clob_append is a private helper procedure to append a varchar2 value
  -- to an existing clob. The idea is to increase performance by avoiding the
  -- slow DBMS_LOB.append call. Only for the final append or if the varchar
  -- cache is fullfilled,this call is done.
  -----------------------------------------------------------------------------

  PROCEDURE util_clob_append(p_clob               IN OUT NOCOPY CLOB
                           , p_clob_varchar_cache IN OUT NOCOPY VARCHAR2
                           , p_varchar_to_append  IN            VARCHAR2
                           , p_final_call         IN            BOOLEAN DEFAULT FALSE)
  IS
  BEGIN
    p_clob_varchar_cache := p_clob_varchar_cache || p_varchar_to_append;

    IF p_final_call
    THEN
      IF p_clob IS NULL
      THEN
        p_clob := p_clob_varchar_cache;
      ELSE
        DBMS_LOB.append(p_clob, p_clob_varchar_cache);
      END IF;

      -- clear cache on final call

      p_clob_varchar_cache := NULL;
    END IF;
  EXCEPTION
    WHEN VALUE_ERROR
    THEN
      IF p_clob IS NULL
      THEN
        p_clob := p_clob_varchar_cache;
      ELSE
        DBMS_LOB.append(p_clob, p_clob_varchar_cache);
      END IF;

      p_clob_varchar_cache := p_varchar_to_append;

      IF p_final_call
      THEN
        DBMS_LOB.append(p_clob, p_clob_varchar_cache);
        -- clear cache on final call
        p_clob_varchar_cache := NULL;
      END IF;
  END util_clob_append;

  -----------------------------------------------------------------------------
  -- util_template_replace is a private helper procedure:
  -- * processes static or dynamic replacements
  -- * slices the templates in blocks of code at the replacement positions
  -- * appends the slices to the resulting clobs for spec, body, view and trigger
  -- * uses a varchar2 cache to speed up the clob processing
  -----------------------------------------------------------------------------
  PROCEDURE util_template_replace(p_scope IN VARCHAR2 DEFAULT NULL)
  IS
    v_current_pos       PLS_INTEGER := 1;
    v_match_pos_static  PLS_INTEGER := 0;
    v_match_pos_dynamic PLS_INTEGER := 0;
    v_match_len         PLS_INTEGER := 0;
    v_match             VARCHAR2(256 CHAR);
    v_tpl_len           PLS_INTEGER;
    v_dynamic_result    t_tab_vc2_5k;

    -----------------------------------------------------------------------------

    PROCEDURE get_match_pos
    IS
    -- finds the first position of a substitution string like
    -- {{ TABLE_NAME }} or {% dynamic code %}
    BEGIN
      v_match_pos_static  := INSTR(g_code_blocks.template, '{{', v_current_pos);
      v_match_pos_dynamic := INSTR(g_code_blocks.template, '{%', v_current_pos);
    END get_match_pos;

    -----------------------------------------------------------------------------

    PROCEDURE code_append(p_code_snippet VARCHAR2)
    IS
    BEGIN
      IF p_scope = 'API SPEC'
      THEN
        util_clob_append(g_code_blocks.api_spec, g_code_blocks.api_spec_varchar_cache, p_code_snippet);
      ELSIF p_scope = 'API BODY'
      THEN
        util_clob_append(g_code_blocks.api_body, g_code_blocks.api_body_varchar_cache, p_code_snippet);
      ELSIF p_scope = 'VIEW'
      THEN
        util_clob_append(g_code_blocks.dml_view, g_code_blocks.dml_view_varchar_cache, p_code_snippet);
      ELSIF p_scope = 'TRIGGER'
      THEN
        util_clob_append(g_code_blocks.dml_view_trigger, g_code_blocks.dml_view_trigger_varchar_cache, p_code_snippet);
      END IF;
    END code_append;

    -----------------------------------------------------------------------------

    PROCEDURE process_static_match
    IS
    BEGIN
      v_match_len   := INSTR(g_code_blocks.template, '}}', v_match_pos_static) - v_match_pos_static - 2;

      IF v_match_len <= 0
      THEN
        raise_application_error(c_generator_error_number, 'FIXME: Bug - static substitution not properly closed');
      END IF;

      v_match       := TRIM(SUBSTR(g_code_blocks.template, v_match_pos_static + 2, v_match_len));
      -- (1) process text before the match

      code_append(SUBSTR(g_code_blocks.template, v_current_pos, v_match_pos_static - v_current_pos));

      -- (2) process the match
      CASE v_match
        WHEN 'GENERATOR'
        THEN
          code_append(c_generator);
        WHEN 'GENERATOR_VERSION'
        THEN
          code_append(c_generator_version);
        WHEN 'GENERATOR_ACTION'
        THEN
          code_append(g_status.generator_action);
        WHEN 'GENERATED_AT'
        THEN
          code_append(TO_CHAR(SYSDATE, 'yyyy-mm-dd hh24:mi:ss'));
        WHEN 'GENERATED_BY'
        THEN
          code_append(util_get_user_name);
        WHEN 'SPEC_OPTIONS_MIN_LINE'
        THEN
          code_append(c_spec_options_min_line);
        WHEN 'SPEC_OPTIONS_MAX_LINE'
        THEN
          code_append(c_spec_options_max_line);
        WHEN 'OWNER'
        THEN
          code_append(g_params.owner);
        WHEN 'TABLE_NAME'
        THEN
          code_append(g_params.table_name);
        WHEN 'TABLE_NAME_MINUS_6'
        THEN
          code_append(SUBSTR(g_params.table_name, 1, c_ora_max_name_len - 6));
        WHEN 'COLUMN_PREFIX'
        THEN
          code_append(g_status.column_prefix);
        WHEN 'PK_COLUMN'
        THEN
          code_append(g_pk_columns(1).column_name);
        WHEN 'PARAMETER_PK_FIRST_COLUMN'
        THEN
          code_append(
            CASE
              WHEN NOT g_status.pk_is_multi_column THEN util_get_parameter_name(g_pk_columns(1).column_name, NULL)
              ELSE NULL
            END);
        WHEN 'REUSE_EXISTING_API_PARAMS'
        THEN
          code_append(util_bool_to_string(g_params.reuse_existing_api_params));
        WHEN 'COL_PREFIX_IN_METHOD_NAMES'
        THEN
          code_append(util_bool_to_string(g_params.col_prefix_in_method_names));
        WHEN 'ENABLE_INSERTION_OF_ROWS'
        THEN
          code_append(util_bool_to_string(g_params.enable_insertion_of_rows));
        WHEN 'ENABLE_COLUMN_DEFAULTS'
        THEN
          code_append(util_bool_to_string(g_params.enable_column_defaults));
        WHEN 'ENABLE_CUSTOM_DEFAULTS'
        THEN
          code_append(util_bool_to_string(g_params.enable_custom_defaults));
        WHEN 'ENABLE_UPDATE_OF_ROWS'
        THEN
          code_append(util_bool_to_string(g_params.enable_update_of_rows));
        WHEN 'ENABLE_DELETION_OF_ROWS'
        THEN
          code_append(util_bool_to_string(g_params.enable_deletion_of_rows));
        WHEN 'ENABLE_GENERIC_CHANGE_LOG'
        THEN
          code_append(util_bool_to_string(g_params.enable_generic_change_log));
        WHEN 'ENABLE_DML_VIEW'
        THEN
          code_append(util_bool_to_string(g_params.enable_dml_view));
        WHEN 'ENABLE_GETTER_AND_SETTER'
        THEN
          code_append(util_bool_to_string(g_params.enable_getter_and_setter));
        WHEN 'ENABLE_PROC_WITH_OUT_PARAMS'
        THEN
          code_append(util_bool_to_string(g_params.enable_proc_with_out_params));
        WHEN 'ENABLE_PARAMETER_PREFIXES'
        THEN
          code_append(util_bool_to_string(g_params.enable_parameter_prefixes));
        WHEN 'RETURN_ROW_INSTEAD_OF_PK'
        THEN
          code_append(util_bool_to_string(g_params.return_row_instead_of_pk));
        WHEN 'CUSTOM_DEFAULTS'
        THEN
          code_append(CASE WHEN g_params.custom_default_values IS NOT NULL THEN -- We set only a placeholder to signal that column defaults are given.
                                                                                -- Column defaults itself could be very large XML and are saved at
                                                                                -- the end of the package spec.
                       c_custom_defaults_present_msg ELSE NULL END);
        WHEN 'SEQUENCE_NAME'
        THEN
          code_append(g_params.sequence_name);
        WHEN 'API_NAME'
        THEN
          code_append(g_params.api_name);
        WHEN 'EXCLUDE_COLUMN_LIST'
        THEN
          code_append(g_params.exclude_column_list);
        WHEN 'RETURN_TYPE'
        THEN
          code_append(   '"'
                      || g_params.table_name
                      || '"'
                      || CASE
                           WHEN g_params.return_row_instead_of_pk
                             OR g_status.pk_is_multi_column
                           THEN
                             '%ROWTYPE'
                           ELSE
                             '."' || g_pk_columns(1).column_name || '"%TYPE'
                         END);
        WHEN 'RETURN_TYPE_PK_SINGLE_COLUMN'
        THEN
          code_append(   'v_return'
                      || CASE
                           WHEN g_params.return_row_instead_of_pk
                             OR g_status.pk_is_multi_column
                           THEN
                             '."' || g_pk_columns(1).column_name || '"'
                           ELSE
                             NULL
                         END);
        WHEN 'RETURN_TYPE_READ_ROW'
        THEN
          code_append(CASE
                        WHEN NOT g_params.return_row_instead_of_pk
                         AND NOT g_status.pk_is_multi_column
                        THEN
                          '."' || g_pk_columns(1).column_name || '"'
                        ELSE
                          NULL
                      END);
        WHEN 'COUNTER_DECLARATION'
        THEN
          code_append(CASE
                        WHEN g_params.enable_generic_change_log
                         AND NOT g_status.pk_is_multi_column
                        THEN
                          'v_count PLS_INTEGER := 0;'
                        ELSE
                          NULL
                      END);
        WHEN 'ROWTYPE_PARAM'
        THEN
          code_append(RPAD('p_row', g_status.rpad_columns + 2) || ' IN "' || g_params.table_name || '"%ROWTYPE )');
        WHEN 'I_COLUMN_NAME'
        THEN
          code_append(g_iterator.column_name);
        WHEN 'I_METHOD_NAME'
        THEN
          code_append(g_iterator.method_name);
        WHEN 'I_PARAMETER_NAME'
        THEN
          code_append(g_iterator.parameter_name);
        WHEN 'I_COLUMN_COMPARE'
        THEN
          code_append(g_iterator.column_compare);
        WHEN 'I_OLD_VALUE'
        THEN
          code_append(g_iterator.old_value);
        WHEN 'I_NEW_VALUE'
        THEN
          code_append(g_iterator.new_value);
        WHEN 'COLUMN_DEFAULTS_SERIALIZED'
        THEN
          code_append(g_params.custom_defaults_serialized);
        ELSE
          raise_application_error(c_generator_error_number
                                , 'FIXME: Bug - static substitution ' || v_match || ' not defined');
      END CASE;

      v_current_pos := v_match_pos_static + v_match_len + 4;
    END process_static_match;

    -----------------------------------------------------------------------------

    PROCEDURE process_dynamic_match
    IS
    BEGIN
      v_match_len   := INSTR(g_code_blocks.template, '%}', v_match_pos_dynamic) - v_match_pos_dynamic - 2;

      IF v_match_len <= 0
      THEN
        raise_application_error(c_generator_error_number, 'FIXME: Bug - dynamic substitution not properly closed');
      END IF;

      v_match       := TRIM(SUBSTR(g_code_blocks.template, v_match_pos_dynamic + 2, v_match_len));

      g_template_options.use_column_defaults :=
        NVL(util_string_to_bool(REGEXP_SUBSTR(srcstr        => v_match
                                            , pattern       => 'defaults=([a-zA-Z0-9]+)'
                                            , position      => 1
                                            , occurrence    => 1
                                            , modifier      => 'i'
                                            , subexpression => 1))
          , FALSE);
      g_template_options.padding :=
        TO_NUMBER(REGEXP_SUBSTR(srcstr        => v_match
                              , pattern       => 'padding=([0-9]+)'
                              , position      => 1
                              , occurrence    => 1
                              , modifier      => 'i'
                              , subexpression => 1));
      v_match       :=
        REGEXP_SUBSTR(srcstr        => v_match
                    , pattern       => '^ *([a-zA-Z_0-9]+)'
                    , position      => 1
                    , occurrence    => 1
                    , modifier      => 'i'
                    , subexpression => 1);

      -- (1) process text before the match
      code_append(SUBSTR(g_code_blocks.template, v_current_pos, v_match_pos_dynamic - v_current_pos));

      -- (2) process the match
      v_dynamic_result.delete;

      IF v_match LIKE 'LIST%'
      THEN
        v_dynamic_result := util_generate_list(v_match);
      ELSIF v_match = 'RETURN_VALUE'
      THEN
        IF g_params.return_row_instead_of_pk
        OR g_status.pk_is_multi_column
        THEN
          v_dynamic_result := util_generate_list('LIST_COLUMNS_W_PK_FULL');
        ELSE
          v_dynamic_result(1) := '"' || g_pk_columns(1).column_name || '"';
        END IF;
      ELSE
        raise_application_error(c_generator_error_number
                              , 'FIXME: Bug - dynamic substitution ' || v_match || ' not defined');
      END IF;

      IF v_dynamic_result.COUNT > 0
      THEN
        FOR i IN v_dynamic_result.FIRST .. v_dynamic_result.LAST
        LOOP
          code_append(v_dynamic_result(i));
        END LOOP;
      END IF;

      v_current_pos := v_match_pos_dynamic + v_match_len + 4;
    END process_dynamic_match;
  -----------------------------------------------------------------------------

  BEGIN
    -- plus one is needed to correct difference between length and position
    v_tpl_len := LENGTH(g_code_blocks.template) + 1;
    get_match_pos;

    WHILE v_current_pos < v_tpl_len
    LOOP
      get_match_pos;

      IF v_match_pos_static > 0
      OR v_match_pos_dynamic > 0
      THEN
        IF v_match_pos_static > 0
       AND (v_match_pos_dynamic = 0
         OR v_match_pos_static < v_match_pos_dynamic)
        THEN
          process_static_match;
        ELSE
          process_dynamic_match;
        END IF;
      ELSE
        -- (3) process the rest of the text
        code_append(SUBSTR(g_code_blocks.template, v_current_pos));
        v_current_pos := v_tpl_len;
      END IF;
    END LOOP;
  END util_template_replace;

  -----------------------------------------------------------------------------

  PROCEDURE main_init(p_generator_action            IN VARCHAR2
                    , p_table_name                  IN all_objects.object_name%TYPE
                    , p_owner                       IN all_users.username%TYPE
                    , p_reuse_existing_api_params   IN BOOLEAN
                    , p_enable_insertion_of_rows    IN BOOLEAN
                    , p_enable_column_defaults      IN BOOLEAN
                    , p_enable_update_of_rows       IN BOOLEAN
                    , p_enable_deletion_of_rows     IN BOOLEAN
                    , p_enable_parameter_prefixes   IN BOOLEAN
                    , p_enable_proc_with_out_params IN BOOLEAN
                    , p_enable_getter_and_setter    IN BOOLEAN
                    , p_col_prefix_in_method_names  IN BOOLEAN
                    , p_return_row_instead_of_pk    IN BOOLEAN
                    , p_enable_dml_view             IN BOOLEAN
                    , p_enable_generic_change_log   IN BOOLEAN
                    , p_api_name                    IN all_objects.object_name%TYPE
                    , p_sequence_name               IN all_objects.object_name%TYPE
                    , p_exclude_column_list         IN VARCHAR2
                    , p_enable_custom_defaults      IN BOOLEAN
                    , p_custom_default_values       IN XMLTYPE)
  IS
    -----------------------------------------------------------------------------

    PROCEDURE init_reset_globals
    IS
    BEGIN
      util_debug_start_one_step(p_action => 'init_reset_globals');
      -- global records
      g_params              := NULL;
      g_params_existing_api := NULL;
      g_iterator            := NULL;
      g_code_blocks         := NULL;
      g_status              := NULL;
      -- global collections
      g_columns.delete;
      g_columns_reverse_index.delete;
      g_unique_constraints.delete;
      g_uk_columns.delete;
      g_pk_columns.delete;
      util_debug_stop_one_step;
    END init_reset_globals;

    -----------------------------------------------------------------------------

    PROCEDURE init_process_parameters
    IS
    BEGIN
      util_debug_start_one_step(p_action => 'init_process_parameters');
      g_params.enable_insertion_of_rows :=
        CASE
          WHEN g_params.reuse_existing_api_params
           AND g_status.api_exists
          THEN
            COALESCE(util_string_to_bool(g_params_existing_api.p_enable_insertion_of_rows), c_enable_insertion_of_rows)
          ELSE
            p_enable_insertion_of_rows
        END;

      g_params.enable_column_defaults :=
        CASE
          WHEN g_params.reuse_existing_api_params
           AND g_status.api_exists
          THEN
            COALESCE(util_string_to_bool(g_params_existing_api.p_enable_column_defaults), c_enable_column_defaults)
          ELSE
            p_enable_column_defaults
        END;

      g_params.enable_update_of_rows :=
        CASE
          WHEN g_params.reuse_existing_api_params
           AND g_status.api_exists
          THEN
            COALESCE(util_string_to_bool(g_params_existing_api.p_enable_update_of_rows), c_enable_update_of_rows)
          ELSE
            p_enable_update_of_rows
        END;

      g_params.enable_deletion_of_rows :=
        CASE
          WHEN g_params.reuse_existing_api_params
           AND g_status.api_exists
          THEN
            COALESCE(util_string_to_bool(g_params_existing_api.p_enable_deletion_of_rows), c_enable_deletion_of_rows)
          ELSE
            p_enable_deletion_of_rows
        END;

      g_params.enable_parameter_prefixes :=
        CASE
          WHEN g_params.reuse_existing_api_params
           AND g_status.api_exists
          THEN
            COALESCE(util_string_to_bool(g_params_existing_api.p_enable_parameter_prefixes)
                   , c_enable_parameter_prefixes)
          ELSE
            p_enable_parameter_prefixes
        END;

      g_params.enable_proc_with_out_params :=
        CASE
          WHEN g_params.reuse_existing_api_params
           AND g_status.api_exists
          THEN
            COALESCE(util_string_to_bool(g_params_existing_api.p_enable_proc_with_out_params)
                   , c_enable_proc_with_out_params)
          ELSE
            p_enable_proc_with_out_params
        END;

      g_params.enable_getter_and_setter :=
        CASE
          WHEN g_params.reuse_existing_api_params
           AND g_status.api_exists
          THEN
            COALESCE(util_string_to_bool(g_params_existing_api.p_enable_getter_and_setter), c_enable_getter_and_setter)
          ELSE
            p_enable_getter_and_setter
        END;

      g_params.col_prefix_in_method_names :=
        CASE
          WHEN g_params.reuse_existing_api_params
           AND g_status.api_exists
          THEN
            COALESCE(util_string_to_bool(g_params_existing_api.p_col_prefix_in_method_names)
                   , c_col_prefix_in_method_names)
          ELSE
            p_col_prefix_in_method_names
        END;

      g_params.return_row_instead_of_pk :=
        CASE
          WHEN g_params.reuse_existing_api_params
           AND g_status.api_exists
          THEN
            COALESCE(util_string_to_bool(g_params_existing_api.p_return_row_instead_of_pk), c_return_row_instead_of_pk)
          ELSE
            p_return_row_instead_of_pk
        END;

      g_params.enable_dml_view :=
        CASE
          WHEN g_params.reuse_existing_api_params
           AND g_status.api_exists
          THEN
            COALESCE(util_string_to_bool(g_params_existing_api.p_enable_dml_view), c_enable_dml_view)
          ELSE
            p_enable_dml_view
        END;

      g_params.enable_generic_change_log :=
        CASE
          WHEN g_params.reuse_existing_api_params
           AND g_status.api_exists
          THEN
            COALESCE(util_string_to_bool(g_params_existing_api.p_enable_generic_change_log)
                   , c_enable_generic_change_log)
          ELSE
            p_enable_generic_change_log
        END;

      g_params.api_name :=
        CASE
          WHEN g_params.reuse_existing_api_params
           AND g_status.api_exists
           AND g_params_existing_api.p_api_name IS NOT NULL
          THEN
            g_params_existing_api.p_api_name
          ELSE
            util_get_substituted_name(NVL(p_api_name, '#TABLE_NAME_1_' || TO_CHAR(c_ora_max_name_len - 4) || '#_API'))
        END;

      g_params.sequence_name :=
        CASE
          WHEN g_params.reuse_existing_api_params
           AND g_status.api_exists
          THEN
            g_params_existing_api.p_sequence_name
          ELSE
            CASE WHEN p_sequence_name IS NOT NULL THEN util_get_substituted_name(p_sequence_name) ELSE NULL END
        END;

      g_params.exclude_column_list :=
        CASE
          WHEN g_params.reuse_existing_api_params
           AND g_status.api_exists
          THEN
            g_params_existing_api.p_exclude_column_list
          ELSE
            p_exclude_column_list
        END;

      g_params.enable_custom_defaults :=
        CASE
          WHEN g_params.reuse_existing_api_params
           AND g_status.api_exists
          THEN
            COALESCE(util_string_to_bool(g_params_existing_api.p_enable_custom_defaults), c_enable_custom_defaults)
          ELSE
            p_enable_custom_defaults
        END;
      util_debug_stop_one_step;
    END init_process_parameters;

    -----------------------------------------------------------------------------

    PROCEDURE init_check_if_table_exists
    IS
      v_object_name all_objects.object_name%TYPE;

      CURSOR v_cur IS
        SELECT table_name
          FROM all_tables
         WHERE owner = g_params.owner
           AND table_name = g_params.table_name;
    BEGIN
      util_debug_start_one_step(p_action => 'init_check_if_table_exists');

      OPEN v_cur;

      FETCH v_cur INTO v_object_name;

      CLOSE v_cur;

      IF (v_object_name IS NULL)
      THEN
        raise_application_error(c_generator_error_number, 'Table "' || g_params.table_name || '" does not exist.');
      END IF;

      util_debug_stop_one_step;
    END init_check_if_table_exists;

    -----------------------------------------------------------------------------

    PROCEDURE init_fetch_existing_api_params
    IS
      CURSOR v_cur IS
        SELECT * FROM TABLE(view_existing_apis(p_table_name => g_params.table_name, p_owner => g_params.owner));
    BEGIN
      util_debug_start_one_step(p_action => 'init_fetch_existing_api_params');

      OPEN v_cur;

      FETCH v_cur INTO g_params_existing_api;

      IF v_cur%FOUND
      THEN
        g_status.api_exists := TRUE;
      END IF;

      CLOSE v_cur;

      util_debug_stop_one_step;
    EXCEPTION
      WHEN OTHERS
      THEN
        CLOSE v_cur;

        RAISE;
    END init_fetch_existing_api_params;

    -----------------------------------------------------------------------------

    PROCEDURE init_check_table_column_prefix
    IS
    BEGIN
      util_debug_start_one_step(p_action => 'init_check_table_column_prefix');
      -- check,if option "col_prefix_in_method_names" is set and check then
      -- if table's column prefix is unique
      g_status.column_prefix := util_get_table_column_prefix(p_table_name => g_params.table_name);

      IF g_status.column_prefix IS NULL
      THEN
        raise_application_error(
          c_generator_error_number
        , 'The prefix of your column names (example: prefix_rest_of_column_name) is not unique and you requested to cut off the prefix for getter and setter method names. Please ensure either your column names have a unique prefix or switch the parameter p_col_prefix_in_method_names to true (SQL Developer oddgen integration: check option "Keep column prefix in method names").');
      END IF;

      util_debug_stop_one_step;
    END init_check_table_column_prefix;

    -----------------------------------------------------------------------------

    PROCEDURE init_check_if_log_table_exists
    IS
      v_count PLS_INTEGER;
    BEGIN
      util_debug_start_one_step(p_action => 'init_check_if_log_table_exists');

      FOR i IN (SELECT 'GENERIC_CHANGE_LOG' FROM DUAL
                MINUS
                SELECT table_name
                  FROM all_tables
                 WHERE owner = g_params.owner
                   AND table_name = 'GENERIC_CHANGE_LOG')
      LOOP
        -- check constraint
        SELECT COUNT(*)
          INTO v_count
          FROM all_objects
         WHERE owner = g_params.owner
           AND object_name = 'GENERIC_CHANGE_LOG_PK';

        IF v_count > 0
        THEN
          raise_application_error(
            c_generator_error_number
          , 'Stop trying to create generic change log table: Object with the name GENERIC_CHANGE_LOG_PK already exists.');
        END IF;

        -- check sequence
        SELECT COUNT(*)
          INTO v_count
          FROM all_objects
         WHERE owner = g_params.owner
           AND object_name = 'GENERIC_CHANGE_LOG_SEQ';

        IF v_count > 0
        THEN
          raise_application_error(
            c_generator_error_number
          , 'Stop trying to create generic change log table: Object with the name GENERIC_CHANGE_LOG_SEQ already exists.');
        END IF;

        -- check index
        SELECT COUNT(*)
          INTO v_count
          FROM all_objects
         WHERE owner = g_params.owner
           AND object_name = 'GENERIC_CHANGE_LOG_IDX';

        IF v_count > 0
        THEN
          raise_application_error(
            c_generator_error_number
          , 'Stop trying to create generic change log table: Object with the name GENERIC_CHANGE_LOG_IDX already exists.');
        END IF;

        EXECUTE IMMEDIATE '
create table generic_change_log (
  gcl_id        NUMBER not null,
  gcl_table     VARCHAR2(128 CHAR) not null,
  gcl_column    VARCHAR2(128 CHAR) not null,
  gcl_pk_id     VARCHAR2(128 CHAR) not null,
  gcl_old_value VARCHAR2(4000 CHAR),
  gcl_new_value VARCHAR2(4000 CHAR),
  gcl_user      VARCHAR2(30 CHAR),
  gcl_timestamp TIMESTAMP(6) default systimestamp,
  constraint generic_change_log_pk primary key (gcl_id)
)
';

        EXECUTE IMMEDIATE '
create sequence generic_change_log_seq nocache noorder nocycle';

        EXECUTE IMMEDIATE '
create index generic_change_log_idx on generic_change_log (gcl_table,gcl_column,gcl_pk_id)';

        EXECUTE IMMEDIATE '
comment on column generic_change_log.gcl_id is ''Primary key of the table''';

        EXECUTE IMMEDIATE '
comment on column generic_change_log.gcl_table is ''Table on which the change occured''';

        EXECUTE IMMEDIATE '
comment on column generic_change_log.gcl_column is ''Column on which the change occured''';

        EXECUTE IMMEDIATE '
comment on column generic_change_log.gcl_pk_id is ''We assume that the pk column of the changed table has a number type''';

        EXECUTE IMMEDIATE '
comment on column generic_change_log.gcl_old_value is ''The old value before the change''';

        EXECUTE IMMEDIATE '
comment on column generic_change_log.gcl_new_value is ''The new value after the change''';

        EXECUTE IMMEDIATE '
comment on column generic_change_log.gcl_user is ''The user,who changed the data''';

        EXECUTE IMMEDIATE '
comment on column generic_change_log.gcl_timestamp is ''The time when the change occured''';
      END LOOP;

      util_debug_stop_one_step;
    END init_check_if_log_table_exists;

    -----------------------------------------------------------------------------

    PROCEDURE init_check_if_api_name_exists
    IS
      v_object_type all_objects.object_type%TYPE;

      CURSOR v_cur IS
        SELECT object_type
          FROM all_objects
         WHERE owner = g_params.owner
           AND object_name = g_params.api_name
           AND object_type NOT IN ('PACKAGE', 'PACKAGE BODY');
    BEGIN
      util_debug_start_one_step(p_action => 'init_check_if_api_name_exists');

      OPEN v_cur;

      FETCH v_cur INTO v_object_type;

      CLOSE v_cur;

      IF (v_object_type IS NOT NULL)
      THEN
        raise_application_error(
          c_generator_error_number
        ,    'API name "'
          || g_params.api_name
          || '" does already exist as an object type "'
          || v_object_type
          || '". Please provide a different API name.');
      END IF;

      util_debug_stop_one_step;
    END init_check_if_api_name_exists;

    -----------------------------------------------------------------------------

    PROCEDURE init_check_if_sequence_exists
    IS
      v_object_name all_objects.object_name%TYPE;

      CURSOR v_cur IS
        SELECT sequence_name
          FROM all_sequences
         WHERE sequence_owner = g_params.owner
           AND sequence_name = g_params.sequence_name;
    BEGIN
      util_debug_start_one_step(p_action => 'init_check_if_sequence_exists');

      OPEN v_cur;

      FETCH v_cur INTO v_object_name;

      CLOSE v_cur;

      IF (v_object_name IS NULL)
      THEN
        raise_application_error(
          c_generator_error_number
        ,    'Sequence '
          || g_params.sequence_name
          || ' does not exist. Please provide correct sequence name or create missing sequence.');
      END IF;

      util_debug_stop_one_step;
    END init_check_if_sequence_exists;

    -----------------------------------------------------------------------------

    PROCEDURE init_create_temporary_lobs
    IS
    BEGIN
      util_debug_start_one_step(p_action => 'init_create_temporary_lobs');
      DBMS_LOB.createtemporary(lob_loc => g_code_blocks.api_spec, cache => FALSE);
      DBMS_LOB.createtemporary(lob_loc => g_code_blocks.api_body, cache => FALSE);
      DBMS_LOB.createtemporary(lob_loc => g_code_blocks.dml_view, cache => FALSE);
      DBMS_LOB.createtemporary(lob_loc => g_code_blocks.dml_view_trigger, cache => FALSE);
      util_debug_stop_one_step;
    END init_create_temporary_lobs;

    -----------------------------------------------------------------------------

    PROCEDURE init_fetch_columns
    IS
    BEGIN
      util_debug_start_one_step(p_action => 'init_fetch_columns');

      OPEN g_cur_columns;

      FETCH g_cur_columns BULK COLLECT INTO g_columns LIMIT c_bulk_collect_limit;

      CLOSE g_cur_columns;

      util_debug_stop_one_step;
    EXCEPTION
      WHEN OTHERS
      THEN
        CLOSE g_cur_columns;

        RAISE;
    END init_fetch_columns;

    -----------------------------------------------------------------------------

    PROCEDURE init_fetch_unique_constraints
    IS
    BEGIN
      util_debug_start_one_step(p_action => 'init_fetch_unique_constraints');

      OPEN g_cur_unique_constraints;

      FETCH g_cur_unique_constraints BULK COLLECT INTO g_unique_constraints LIMIT c_bulk_collect_limit;

      CLOSE g_cur_unique_constraints;

      util_debug_stop_one_step;
    EXCEPTION
      WHEN OTHERS
      THEN
        CLOSE g_cur_unique_constraints;

        RAISE;
    END init_fetch_unique_constraints;

    -----------------------------------------------------------------------------

    PROCEDURE init_fetch_unique_cons_columns
    IS
    BEGIN
      util_debug_start_one_step(p_action => 'init_fetch_unique_cons_columns');

      OPEN g_cur_uk_columns;

      FETCH g_cur_uk_columns BULK COLLECT INTO g_uk_columns LIMIT c_bulk_collect_limit;

      CLOSE g_cur_uk_columns;

      util_debug_stop_one_step;
    EXCEPTION
      WHEN OTHERS
      THEN
        CLOSE g_cur_uk_columns;

        RAISE;
    END init_fetch_unique_cons_columns;

    -----------------------------------------------------------------------------

    PROCEDURE init_fetch_pk_cons_columns
    IS
    BEGIN
      util_debug_start_one_step(p_action => 'init_fetch_pk_cons_columns');

      OPEN g_cur_pk_columns;

      FETCH g_cur_pk_columns BULK COLLECT INTO g_pk_columns LIMIT c_bulk_collect_limit;

      CLOSE g_cur_pk_columns;

      util_debug_stop_one_step;
    EXCEPTION
      WHEN OTHERS
      THEN
        CLOSE g_cur_pk_columns;

        RAISE;
    END init_fetch_pk_cons_columns;

    PROCEDURE init_process_columns
    IS
    BEGIN
      util_debug_start_one_step(p_action => 'init_process_columns');
      -- init rpad
      g_status.rpad_columns := 0;

      FOR i IN g_columns.FIRST .. g_columns.LAST
      LOOP
        -- calc rpad length
        IF LENGTH(g_columns(i).column_name) > g_status.rpad_columns
        THEN
          g_status.rpad_columns := LENGTH(g_columns(i).column_name);
        END IF;

        -- set initial pk info (will be refined in init_process_pk_columns)
        g_columns(i).is_pk_yn                             := 'N';
        -- create reverse index to get collection id by column name
        g_columns_reverse_index(g_columns(i).column_name) := i;

        -- check,if we have a xmltype column present (we have then to provide a XML compare function)
        IF g_columns(i).data_type = 'XMLTYPE'
        THEN
          g_status.xmltype_column_present := TRUE;
        END IF;
      END LOOP;

      util_debug_stop_one_step;
    END init_process_columns;

    -----------------------------------------------------------------------------

    PROCEDURE init_process_pk_columns
    IS
      v_count PLS_INTEGER;
    BEGIN
      util_debug_start_one_step(p_action => 'init_process_pk_columns');
      -- check pk
      v_count                  := g_pk_columns.COUNT;

      IF v_count = 0
      THEN
        raise_application_error(c_generator_error_number
                              , 'Unable to generate API - no primary key present for table ' || g_params.table_name);
      ELSIF v_count = 1
      THEN
        g_status.pk_is_multi_column := FALSE;
      ELSIF v_count > 1
      THEN
        g_status.pk_is_multi_column := TRUE;
      END IF;

      -- check validity of generic change log parameter
      IF g_params.enable_generic_change_log
     AND g_status.pk_is_multi_column
      THEN
        raise_application_error(
          c_generator_error_number
        ,    'Unable to generate API - you requested to use the generic change log and your table "'
          || g_params.table_name
          || '" has a multi column primary key. This combination is not supported.');
      END IF;

      -- init rpad
      g_status.rpad_pk_columns := 0;

      FOR i IN g_pk_columns.FIRST .. g_pk_columns.LAST
      LOOP
        -- mark column as pk
        g_columns(g_columns_reverse_index(g_pk_columns(i).column_name)).is_pk_yn       := 'Y';

        -- mark column as not nullable
        g_columns(g_columns_reverse_index(g_pk_columns(i).column_name)).is_nullable_yn := 'N';

        -- calc rpad length
        IF g_pk_columns(i).column_name_length > g_status.rpad_pk_columns
        THEN
          g_status.rpad_pk_columns := g_pk_columns(i).column_name_length;
        END IF;
      END LOOP;

      util_debug_stop_one_step;
    END init_process_pk_columns;

    -----------------------------------------------------------------------------

    PROCEDURE init_process_uk_columns
    IS
      v_count PLS_INTEGER;
    BEGIN
      util_debug_start_one_step(p_action => 'init_process_uk_columns');
      -- check uk
      v_count := g_uk_columns.COUNT;

      IF v_count > 0
      THEN
        -- init rpad
        g_status.rpad_uk_columns := 0;

        FOR i IN g_uk_columns.FIRST .. g_uk_columns.LAST
        LOOP
          -- mark column as uk
          g_columns(g_columns_reverse_index(g_uk_columns(i).column_name)).is_uk_yn := 'Y';

          -- calc rpad length
          IF g_uk_columns(i).column_name_length > g_status.rpad_uk_columns
          THEN
            g_status.rpad_uk_columns := g_uk_columns(i).column_name_length;
          END IF;
        END LOOP;
      END IF;

      util_debug_stop_one_step;
    END init_process_uk_columns;

    -----------------------------------------------------------------------------

    PROCEDURE init_fetch_custom_defaults
    IS
      FUNCTION get_spec_custom_defaults
        RETURN XMLTYPE
      IS
        v_return VARCHAR2(32767);
      BEGIN
        FOR i IN (SELECT text
                    FROM all_source
                   WHERE owner = g_params.owner
                     AND name = g_params.api_name
                     AND TYPE = 'PACKAGE'
                     AND line >= (SELECT MIN(line) AS line
                                    FROM all_source
                                   WHERE owner = g_params.owner
                                     AND name = g_params.api_name
                                     AND TYPE = 'PACKAGE'
                                     AND INSTR(text, '<custom_defaults>') > 0))
        LOOP
          IF INSTR(i.text, 'source="USER"') > 0
          OR INSTR(i.text, 'custom_defaults') > 0
          THEN
            v_return := v_return || LTRIM(i.text, -- needed for backward compatibility of old comment style
                                                  ' *');
          END IF;

          EXIT WHEN INSTR(i.text, '</custom_defaults>') > 0;
        END LOOP;

        RETURN CASE WHEN v_return IS NULL THEN NULL ELSE xmltype(v_return) END;
      END;
    BEGIN
      util_debug_start_one_step(p_action => 'init_fetch_custom_defaults');
      g_params.custom_default_values :=
        CASE
          WHEN g_params.reuse_existing_api_params
           AND g_status.api_exists
          THEN
            CASE WHEN g_params_existing_api.p_custom_default_values IS NOT NULL THEN -- g_params_existing_api.p_custom_default_values contains only a
                                                                                     -- placeholder to signal that custom defaults exists, because the
                                                                                     -- defaults could be very large. We have to fetch the xml encoded
                                                                                     -- custom defaults from the end of the package spec.
             get_spec_custom_defaults END
          ELSE
            p_custom_default_values
        END;

      IF g_params.custom_default_values IS NOT NULL
      THEN
        g_params.custom_defaults_serialized := util_serialize_xml(g_params.custom_default_values);
      END IF;

      -- check for empty XML element
      IF g_params.custom_defaults_serialized = '<defaults/>'
      THEN
        g_params.custom_default_values      := NULL;
        g_params.custom_defaults_serialized := NULL;
      END IF;

      util_debug_stop_one_step;
    END init_fetch_custom_defaults;

    -----------------------------------------------------------------------------

    PROCEDURE init_process_custom_defaults
    IS
      v_index INTEGER;
    BEGIN
      util_debug_start_one_step(p_action => 'init_process_custom_defaults');

      -- process user provided custom defaults
      IF g_params.custom_default_values IS NOT NULL
      THEN
        FOR i
          IN (SELECT x.column_name AS column_name
                   , x.data_default AS data_default
                FROM XMLTABLE(
                       'for $i in /custom_defaults/column return $i'
                       PASSING g_params.custom_default_values
                       COLUMNS --
                               column_name VARCHAR2(200) PATH '@name', --
                                                                       data_default VARCHAR2(4000) PATH 'text()') x)
        LOOP
          BEGIN
            v_index := g_columns_reverse_index(i.column_name);

            IF v_index IS NOT NULL
            THEN
              g_columns(v_index).data_custom_default   := i.data_default;
              g_columns(v_index).custom_default_source := 'USER';
            END IF;
          EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
              NULL;
          END;
        END LOOP;
      END IF;

      -- generate standard custom defaults for the users convenience...
      FOR i IN g_columns.FIRST .. g_columns.LAST
      LOOP
        IF g_columns(i).data_custom_default IS NULL -- do not override users defaults from the processing step above
       AND (g_columns(i).is_pk_yn = 'N'
         OR (g_columns(i).is_pk_yn = 'Y'
         AND g_status.pk_is_multi_column)) --
       AND g_columns(i).is_excluded_yn = 'N' --
        THEN
          IF g_columns(i).data_default IS NOT NULL
          THEN
            g_columns(i).data_custom_default   := g_columns(i).data_default;
            g_columns(i).custom_default_source := 'TABLE';
          ELSE
            g_columns(i).data_custom_default :=
              CASE
                WHEN g_columns(i).data_type IN ('NUMBER', 'INTEGER', 'FLOAT')
                THEN
                     'round(dbms_random.value(0,'
                  || RPAD('9', g_columns(i).data_precision - g_columns(i).data_scale, '9')
                  || CASE
                       WHEN g_columns(i).data_scale > 0 THEN '.' || RPAD('9', g_columns(i).data_scale, '9')
                       ELSE NULL
                     END
                  || '),'
                  || TO_CHAR(g_columns(i).data_scale)
                  || ')'
                WHEN g_columns(i).data_type LIKE '%CHAR%'
                THEN
                  CASE
                    WHEN LOWER(g_columns(i).column_name) LIKE '%mail%'
                    THEN
                      'substr(sys_guid(),1,' || TO_CHAR(g_columns(i).char_length - 10) || ') || ''@dummy.com'''
                    WHEN LOWER(g_columns(i).column_name) LIKE '%phone%'
                    THEN
                         'substr(''+1.''||lpad(to_char(trunc(dbms_random.value(1,999))),3,''0'')||''.''||lpad(to_char(trunc(dbms_random.value(1,999))),3,''0'')||''.''||lpad(to_char(trunc(dbms_random.value(1,9999))),4,''0''),1,'
                      || TO_CHAR(g_columns(i).char_length)
                      || ')'
                    ELSE
                      'substr(sys_guid(),1,' || TO_CHAR(g_columns(i).char_length) || ')'
                  END
                WHEN g_columns(i).data_type = 'DATE'
                THEN
                  'to_date(trunc(dbms_random.value(to_char(date''1900-01-01'',''j''),to_char(date''2099-12-31'',''j''))),''j'')'
                WHEN g_columns(i).data_type LIKE 'TIMESTAMP%'
                THEN
                  'systimestamp'
                WHEN g_columns(i).data_type = 'CLOB'
                THEN
                  'to_clob(''Dummy clob for API method get_a_row: '' || sys_guid())'
                WHEN g_columns(i).data_type = 'BLOB'
                THEN
                  'to_blob(utl_raw.cast_to_raw(''Dummy clob for API method get_a_row: '' || sys_guid()))'
                WHEN g_columns(i).data_type = 'XMLTYPE'
                THEN
                  'xmltype(''<dummy>Dummy XML for API method get_a_row: '' || sys_guid() || ''</dummy>'')'
                ELSE
                  NULL
              END;

            -- set source to TAPIGEN only, if we found a default in the case above
            IF g_columns(i).data_custom_default IS NOT NULL
            THEN
              g_columns(i).custom_default_source := 'TAPIGEN';
            END IF;
          END IF;
        END IF;
      END LOOP;

      util_debug_stop_one_step;
    END init_process_custom_defaults;
  BEGIN
    init_reset_globals;
    --
    g_status.generator_action          := p_generator_action;
    g_params.owner                     := p_owner;
    g_params.table_name                := p_table_name;
    --
    init_check_if_table_exists;
    --
    g_params.reuse_existing_api_params := p_reuse_existing_api_params;
    g_status.api_exists                := FALSE;

    --
    IF g_params.reuse_existing_api_params
    THEN
      init_fetch_existing_api_params;
    END IF;

    --
    init_process_parameters;

    --
    IF g_params.col_prefix_in_method_names = FALSE
    THEN
      init_check_table_column_prefix;
    END IF;

    --
    IF g_params.enable_generic_change_log
    THEN
      init_check_if_log_table_exists;
    END IF;

    --
    IF g_params.api_name IS NOT NULL
    THEN
      init_check_if_api_name_exists;
    END IF;

    --
    IF g_params.sequence_name IS NOT NULL
    THEN
      init_check_if_sequence_exists;
    END IF;

    --
    init_create_temporary_lobs;
    init_fetch_columns;
    init_fetch_unique_constraints;
    init_fetch_unique_cons_columns;
    init_fetch_pk_cons_columns;
    init_process_columns;
    init_process_pk_columns;
    init_process_uk_columns;

    --
    IF g_params.enable_custom_defaults
    THEN
      init_fetch_custom_defaults;
      init_process_custom_defaults;
    END IF;
  END main_init;

  -----------------------------------------------------------------------------

  PROCEDURE main_generate_code
  IS
    -----------------------------------------------------------------------------

    PROCEDURE gen_header
    IS
    BEGIN
      util_debug_start_one_step(p_action => 'gen_header');
      g_code_blocks.template := '
CREATE OR REPLACE PACKAGE "{{ API_NAME }}" IS
  /*
  This is the API for the table "{{ TABLE_NAME }}".

  GENERATION OPTIONS
  - Must be in the lines {{ SPEC_OPTIONS_MIN_LINE }}-{{ SPEC_OPTIONS_MAX_LINE }} to be reusable by the generator
  - DO NOT TOUCH THIS until you know what you do
  - Read the docs under github.com/OraMUC/table-api-generator ;-)
  <options
    generator="{{ GENERATOR }}"
    generator_version="{{ GENERATOR_VERSION }}"
    generator_action="{{ GENERATOR_ACTION }}"
    generated_at="{{ GENERATED_AT }}"
    generated_by="{{ GENERATED_BY }}"
    p_table_name="{{ TABLE_NAME }}"
    p_owner="{{ OWNER }}"
    p_reuse_existing_api_params="{{ REUSE_EXISTING_API_PARAMS }}"
    p_enable_insertion_of_rows="{{ ENABLE_INSERTION_OF_ROWS }}"
    p_enable_column_defaults="{{ ENABLE_COLUMN_DEFAULTS }}"
    p_enable_update_of_rows="{{ ENABLE_UPDATE_OF_ROWS }}"
    p_enable_deletion_of_rows="{{ ENABLE_DELETION_OF_ROWS }}"
    p_enable_parameter_prefixes="{{ ENABLE_PARAMETER_PREFIXES }}"
    p_enable_proc_with_out_params="{{ ENABLE_PROC_WITH_OUT_PARAMS }}"
    p_enable_getter_and_setter="{{ ENABLE_GETTER_AND_SETTER }}"
    p_col_prefix_in_method_names="{{ COL_PREFIX_IN_METHOD_NAMES }}"
    p_return_row_instead_of_pk="{{ RETURN_ROW_INSTEAD_OF_PK }}"
    p_enable_dml_view="{{ ENABLE_DML_VIEW }}"
    p_enable_generic_change_log="{{ ENABLE_GENERIC_CHANGE_LOG }}"
    p_api_name="{{ API_NAME }}"
    p_sequence_name="{{ SEQUENCE_NAME }}"
    p_exclude_column_list="{{ EXCLUDE_COLUMN_LIST }}"
    p_enable_custom_defaults="{{ ENABLE_CUSTOM_DEFAULTS }}"
    p_custom_default_values="{{ CUSTOM_DEFAULTS }}"/>

  This API provides DML functionality that can be easily called from APEX.
  Target of the table API is to encapsulate the table DML source code for
  security (UI schema needs only the execute right for the API and the
  read/write right for the {{ TABLE_NAME_MINUS_6 }}_DML_V, tables can be
  hidden in extra data schema) and easy readability of the business logic
  (all DML is then written in the same style). For APEX automatic row
  processing like tabular forms you can optionally use the
  {{ TABLE_NAME_MINUS_6 }}_DML_V. The instead of trigger for this view
  is calling simply this "{{ API_NAME }}".
  */';
      util_template_replace('API SPEC');
      g_code_blocks.template :=
           '
CREATE OR REPLACE PACKAGE BODY "{{ API_NAME }}" IS'
        || CASE WHEN g_status.xmltype_column_present THEN '

  FUNCTION util_xml_compare (
    p_doc1 XMLTYPE,
    p_doc2 XMLTYPE )
  RETURN NUMBER IS
    v_return NUMBER;
  BEGIN
    SELECT CASE
             WHEN XMLEXISTS(
                    ''declare default element namespace "http://xmlns.oracle.com/xdb/xdiff.xsd"; /xdiff/*''
                    PASSING XMLDIFF( p_doc1, p_doc2 ) )
             THEN 1
             ELSE 0
           END
      INTO v_return
      FROM DUAL;
    RETURN v_return;
  END util_xml_compare;' END
        || CASE
             WHEN g_params.enable_generic_change_log
              AND NOT g_status.pk_is_multi_column
             THEN
               '

  PROCEDURE create_change_log_entry (
    p_table     IN generic_change_log.gcl_table%TYPE,
    p_column    IN generic_change_log.gcl_column%TYPE,
    p_pk_id     IN generic_change_log.gcl_pk_id%TYPE,
    p_old_value IN generic_change_log.gcl_old_value%TYPE,
    p_new_value IN generic_change_log.gcl_new_value%TYPE )
  IS
  BEGIN
    INSERT INTO generic_change_log (
      gcl_id,
      gcl_table,
      gcl_column,
      gcl_pk_id,
      gcl_old_value,
      gcl_new_value,
      gcl_user )
    VALUES (
      generic_change_log_seq.nextval,
      p_table,
      p_column,
      p_pk_id,
      p_old_value,
      p_new_value,
      coalesce(v(''APP_USER''),sys_context(''USERENV'',''OS_USER'')) );
  END;'
           END;

      util_template_replace('API BODY');
      util_debug_stop_one_step;
    END gen_header;

    -----------------------------------------------------------------------------

    PROCEDURE gen_row_exists_fnc
    IS
    BEGIN
      util_debug_start_one_step(p_action => 'gen_row_exists_fnc');
      g_code_blocks.template := '

  FUNCTION row_exists (
    {% LIST_PK_PARAMS %} )
  RETURN BOOLEAN;';
      util_template_replace('API SPEC');
      g_code_blocks.template := '

  FUNCTION row_exists (
    {% LIST_PK_PARAMS %} )
  RETURN BOOLEAN
  IS
    v_return BOOLEAN := FALSE;
    v_dummy  PLS_INTEGER;
    CURSOR   cur_bool IS
      SELECT 1
        FROM "{{ TABLE_NAME }}"
       WHERE {% LIST_PK_COLUMN_COMPARE %};
  BEGIN
    OPEN cur_bool;
    FETCH cur_bool INTO v_dummy;
    IF cur_bool%FOUND THEN
      v_return := TRUE;
    END IF;
    CLOSE cur_bool;
    RETURN v_return;
  END;';
      util_template_replace('API BODY');
      util_debug_stop_one_step;
    END gen_row_exists_fnc;

    -----------------------------------------------------------------------------

    PROCEDURE gen_row_exists_yn_fnc
    IS
    BEGIN
      util_debug_start_one_step(p_action => 'gen_row_exists_yn_fnc');
      g_code_blocks.template := '

  FUNCTION row_exists_yn (
    {% LIST_PK_PARAMS %} )
  RETURN VARCHAR2;';
      util_template_replace('API SPEC');
      g_code_blocks.template := '

  FUNCTION row_exists_yn (
    {% LIST_PK_PARAMS %} )
  RETURN VARCHAR2
  IS
  BEGIN
    RETURN CASE WHEN row_exists( {% LIST_PK_MAP_PARAM_EQ_PARAM %} )
             THEN ''Y''
             ELSE ''N''
           END;
  END;';
      util_template_replace('API BODY');
      util_debug_stop_one_step;
    END gen_row_exists_yn_fnc;

    -----------------------------------------------------------------------------

    PROCEDURE gen_get_pk_by_unique_cols_fnc
    IS
    BEGIN
      util_debug_start_one_step(p_action => 'gen_get_pk_by_unique_cols_fnc');

      IF g_unique_constraints.COUNT > 0
      THEN
        FOR i IN g_unique_constraints.FIRST .. g_unique_constraints.LAST
        LOOP
          g_iterator.current_unique_constraint := g_unique_constraints(i).constraint_name;
          g_code_blocks.template               := '

  FUNCTION get_pk_by_unique_cols (
    {% LIST_UK_PARAMS %} )
  RETURN {{ RETURN_TYPE }};';
          util_template_replace('API SPEC');
          g_code_blocks.template               := '

  FUNCTION get_pk_by_unique_cols (
    {% LIST_UK_PARAMS %} )
  RETURN {{ RETURN_TYPE }} IS
    v_return {{ RETURN_TYPE }};
  BEGIN
    v_return := read_row ( {% LIST_UK_MAP_PARAM_EQ_PARAM %} ){{ RETURN_TYPE_READ_ROW }};
    RETURN v_return;
  END get_pk_by_unique_cols;';
          util_template_replace('API BODY');
        END LOOP;
      END IF;

      util_debug_stop_one_step;
    END gen_get_pk_by_unique_cols_fnc;

    -----------------------------------------------------------------------------

    PROCEDURE gen_create_row_fnc
    IS
    BEGIN
      util_debug_start_one_step(p_action => 'gen_create_row_fnc');
      g_code_blocks.template := '

  FUNCTION create_row (
    {% LIST_PARAMS_W_PK?defaults=true %} )
  RETURN {{ RETURN_TYPE }};';
      util_template_replace('API SPEC');
      g_code_blocks.template :=
           '

  FUNCTION create_row (
    {% LIST_PARAMS_W_PK?defaults=true %} )
  RETURN {{ RETURN_TYPE }} IS
    v_return {{ RETURN_TYPE }};
  BEGIN
    INSERT INTO "{{ TABLE_NAME }}" (
      {% LIST_INSERT_COLUMNS %} )
    VALUES (
      {% LIST_INSERT_PARAMS %} )'
        || CASE WHEN g_status.xmltype_column_present THEN ';
    -- returning clause does not support XMLTYPE,so we do here an extra fetch
    v_return := read_row ( {% LIST_PK_MAP_PARAM_EQ_PARAM %} ){{ RETURN_TYPE_READ_ROW }};' ELSE '
    RETURN
      {% RETURN_VALUE %}
    INTO v_return;' END
        || CASE
             WHEN g_params.enable_generic_change_log
              AND NOT g_status.pk_is_multi_column
             THEN
               '
    create_change_log_entry (
      p_table     => ''{{ TABLE_NAME }}'',
      p_column    => ''{{ PK_COLUMN }}'',
      p_pk_id     => {{ RETURN_TYPE_PK_SINGLE_COLUMN }},
      p_old_value => ''ROW CREATED'',
      p_new_value => ''ROW CREATED'' );'
           END
        || '
    RETURN v_return;
  END create_row;';

      util_template_replace('API BODY');
      util_debug_stop_one_step;
    END gen_create_row_fnc;

    -----------------------------------------------------------------------------

    PROCEDURE gen_create_row_prc
    IS
    BEGIN
      util_debug_start_one_step(p_action => 'gen_create_row_prc');
      g_code_blocks.template := '

  PROCEDURE create_row (
    {% LIST_PARAMS_W_PK?defaults=true %} );';
      util_template_replace('API SPEC');
      g_code_blocks.template := '

  PROCEDURE create_row (
    {% LIST_PARAMS_W_PK?defaults=true %} )
  IS
    v_return {{ RETURN_TYPE }};
  BEGIN
    v_return := create_row (
      {% LIST_MAP_PAR_EQ_PARAM_W_PK %} );
  END create_row;';
      util_template_replace('API BODY');
      util_debug_stop_one_step;
    END gen_create_row_prc;

    -----------------------------------------------------------------------------

    PROCEDURE gen_create_rowtype_fnc
    IS
    BEGIN
      util_debug_start_one_step(p_action => 'gen_create_rowtype_fnc');
      g_code_blocks.template := '

  FUNCTION create_row (
    {{ ROWTYPE_PARAM }}
  RETURN {{ RETURN_TYPE }};';
      util_template_replace('API SPEC');
      g_code_blocks.template := '

  FUNCTION create_row (
    {{ ROWTYPE_PARAM }}
  RETURN {{ RETURN_TYPE }} IS
    v_return {{ RETURN_TYPE }};
  BEGIN
    v_return := create_row (
      {% LIST_MAP_PAR_EQ_ROWTYPCOL_W_PK %} );
    RETURN v_return;
  END create_row;';
      util_template_replace('API BODY');
      util_debug_stop_one_step;
    END gen_create_rowtype_fnc;

    -----------------------------------------------------------------------------

    PROCEDURE gen_create_rowtype_prc
    IS
    BEGIN
      util_debug_start_one_step(p_action => 'gen_create_rowtype_prc');
      g_code_blocks.template := '

  PROCEDURE create_row (
    {{ ROWTYPE_PARAM }};';
      util_template_replace('API SPEC');
      g_code_blocks.template := '

  PROCEDURE create_row (
    {{ ROWTYPE_PARAM }}
  IS
    v_return {{ RETURN_TYPE }};
  BEGIN
    v_return := create_row (
      {% LIST_MAP_PAR_EQ_ROWTYPCOL_W_PK %} );
  END create_row;';
      util_template_replace('API BODY');
      util_debug_stop_one_step;
    END gen_create_rowtype_prc;

    -----------------------------------------------------------------------------

    PROCEDURE gen_createorupdate_row_fnc
    IS
    BEGIN
      util_debug_start_one_step(p_action => 'gen_createorupdate_row_fnc');
      g_code_blocks.template := '

  FUNCTION create_or_update_row (
    {% LIST_PARAMS_W_PK %} )
  RETURN {{ RETURN_TYPE }};';
      util_template_replace('API SPEC');
      g_code_blocks.template := '

  FUNCTION create_or_update_row (
    {% LIST_PARAMS_W_PK %} )
  RETURN {{ RETURN_TYPE }} IS
    v_return {{ RETURN_TYPE }};
  BEGIN
    IF row_exists( {% LIST_PK_MAP_PARAM_EQ_PARAM %} ) THEN
      update_row(
        {% LIST_MAP_PAR_EQ_PARAM_W_PK padding=8 %} );
      v_return := read_row ( {% LIST_PK_MAP_PARAM_EQ_PARAM %} ){{ RETURN_TYPE_READ_ROW }};
    ELSE
      v_return := create_row (
        {% LIST_MAP_PAR_EQ_PARAM_W_PK padding=8 %} );
    END IF;
    RETURN v_return;
  END create_or_update_row;';
      util_template_replace('API BODY');
      util_debug_stop_one_step;
    END gen_createorupdate_row_fnc;

    -----------------------------------------------------------------------------

    PROCEDURE gen_createorupdate_row_prc
    IS
    BEGIN
      util_debug_start_one_step(p_action => 'gen_createorupdate_row_prc');
      g_code_blocks.template := '

  PROCEDURE create_or_update_row (
    {% LIST_PARAMS_W_PK %} );';
      util_template_replace('API SPEC');
      g_code_blocks.template := '

  PROCEDURE create_or_update_row (
    {% LIST_PARAMS_W_PK %} )
  IS
    v_return {{ RETURN_TYPE }};
  BEGIN
    v_return := create_or_update_row(
      {% LIST_MAP_PAR_EQ_PARAM_W_PK %} );
  END create_or_update_row;';
      util_template_replace('API BODY');
      util_debug_stop_one_step;
    END gen_createorupdate_row_prc;

    -----------------------------------------------------------------------------

    PROCEDURE gen_createorupdate_rowtype_fnc
    IS
    BEGIN
      util_debug_start_one_step(p_action => 'gen_createorupdate_rowtype_fnc');
      g_code_blocks.template := '

  FUNCTION create_or_update_row (
    {{ ROWTYPE_PARAM }}
  RETURN {{ RETURN_TYPE }};';
      util_template_replace('API SPEC');
      g_code_blocks.template := '

  FUNCTION create_or_update_row (
    {{ ROWTYPE_PARAM }}
  RETURN {{ RETURN_TYPE }} IS
    v_return {{ RETURN_TYPE }};
  BEGIN
    v_return := create_or_update_row(
      {% LIST_MAP_PAR_EQ_ROWTYPCOL_W_PK %} );
    RETURN v_return;
  END create_or_update_row;';
      util_template_replace('API BODY');
      util_debug_stop_one_step;
    END gen_createorupdate_rowtype_fnc;

    PROCEDURE gen_createorupdate_rowtype_prc
    IS
    BEGIN
      util_debug_start_one_step(p_action => 'gen_createorupdate_rowtype_prc');
      g_code_blocks.template := '

  PROCEDURE create_or_update_row (
    {{ ROWTYPE_PARAM }};';
      util_template_replace('API SPEC');
      g_code_blocks.template := '

  PROCEDURE create_or_update_row (
    {{ ROWTYPE_PARAM }}
  IS
    v_return {{ RETURN_TYPE }};
  BEGIN
    v_return := create_or_update_row(
      {% LIST_MAP_PAR_EQ_ROWTYPCOL_W_PK %} );
  END create_or_update_row;';
      util_template_replace('API BODY');
      util_debug_stop_one_step;
    END gen_createorupdate_rowtype_prc;

    PROCEDURE gen_read_row_fnc
    IS
    BEGIN
      util_debug_start_one_step(p_action => 'gen_read_row_fnc');
      g_code_blocks.template := '

  FUNCTION read_row (
    {% LIST_PK_PARAMS %} )
  RETURN "{{ TABLE_NAME }}"%ROWTYPE;';
      util_template_replace('API SPEC');
      g_code_blocks.template := '

  FUNCTION read_row (
    {% LIST_PK_PARAMS %} )
  RETURN "{{ TABLE_NAME }}"%ROWTYPE IS
    v_row "{{ TABLE_NAME }}"%ROWTYPE;
    CURSOR cur_row IS
      SELECT *
        FROM "{{ TABLE_NAME }}"
       WHERE {% LIST_PK_COLUMN_COMPARE %};
  BEGIN
    OPEN cur_row;
    FETCH cur_row INTO v_row;
    CLOSE cur_row;
    RETURN v_row;
  END read_row;';
      util_template_replace('API BODY');
      util_debug_stop_one_step;
    END gen_read_row_fnc;

    PROCEDURE gen_read_row_prc
    IS
    BEGIN
      util_debug_start_one_step(p_action => 'gen_read_row_prc');
      g_code_blocks.template := '

  PROCEDURE read_row (
    {% LIST_PARAMS_W_PK_IO %} );';
      util_template_replace('API SPEC');
      g_code_blocks.template := '

  PROCEDURE read_row (
    {% LIST_PARAMS_W_PK_IO %} )
  IS
    v_row "{{ TABLE_NAME }}"%ROWTYPE;
  BEGIN
    IF row_exists( {% LIST_PK_MAP_PARAM_EQ_PARAM %} ) THEN
      v_row := read_row ( {% LIST_PK_MAP_PARAM_EQ_PARAM %} );
      {% LIST_SET_PAR_EQ_ROWTYCOL_WO_PK %}
    END IF;
  END read_row;';
      util_template_replace('API BODY');
      util_debug_stop_one_step;
    END gen_read_row_prc;

    PROCEDURE gen_read_row_by_uk_fnc
    IS
    BEGIN
      util_debug_start_one_step(p_action => 'gen_read_row_by_uk_fnc');

      IF g_unique_constraints.COUNT > 0
      THEN
        FOR i IN g_unique_constraints.FIRST .. g_unique_constraints.LAST
        LOOP
          g_iterator.current_unique_constraint := g_unique_constraints(i).constraint_name;
          g_code_blocks.template               := '

  FUNCTION read_row (
    {% LIST_UK_PARAMS %} )
  RETURN "{{ TABLE_NAME }}"%ROWTYPE;';
          util_template_replace('API SPEC');
          g_code_blocks.template               := '

  FUNCTION read_row (
    {% LIST_UK_PARAMS %} )
  RETURN "{{ TABLE_NAME }}"%ROWTYPE IS
    v_row "{{ TABLE_NAME }}"%ROWTYPE;
    CURSOR cur_row IS
      SELECT *
        FROM "{{ TABLE_NAME }}"
       WHERE {% LIST_UK_COLUMN_COMPARE %};
  BEGIN
    OPEN cur_row;
    FETCH cur_row INTO v_row;
    CLOSE cur_row;
    RETURN v_row;
  END;';
          util_template_replace('API BODY');
        END LOOP;
      END IF;

      util_debug_stop_one_step;
    END gen_read_row_by_uk_fnc;

    PROCEDURE gen_update_row_prc
    IS
    BEGIN
      util_debug_start_one_step(p_action => 'gen_update_row_prc');
      g_code_blocks.template := '

  PROCEDURE update_row (
    {% LIST_PARAMS_W_PK %} );';
      util_template_replace('API SPEC');
      g_code_blocks.template := '

  PROCEDURE update_row (
    {% LIST_PARAMS_W_PK %} )
  IS
    v_row   "{{ TABLE_NAME }}"%ROWTYPE;
    {{ COUNTER_DECLARATION }}
  BEGIN
    IF row_exists ( {% LIST_PK_MAP_PARAM_EQ_PARAM %} ) THEN
      v_row := read_row ( {% LIST_PK_MAP_PARAM_EQ_PARAM %} );
      -- update only,if the column values really differ
      IF {% LIST_COLUMNS_WO_PK_COMPARE %}
      THEN
        UPDATE {{ TABLE_NAME }}
           SET {% LIST_SET_COL_EQ_PARAM_WO_PK %}
         WHERE {% LIST_PK_COLUMN_COMPARE %};
      END IF;
    END IF;
  END update_row;';
      util_template_replace('API BODY');
      util_debug_stop_one_step;
    END gen_update_row_prc;

    PROCEDURE gen_update_rowtype_prc
    IS
    BEGIN
      util_debug_start_one_step(p_action => 'gen_update_rowtype_prc');
      g_code_blocks.template := '

  PROCEDURE update_row (
    {{ ROWTYPE_PARAM }};';
      util_template_replace('API SPEC');
      g_code_blocks.template := '

  PROCEDURE update_row (
    {{ ROWTYPE_PARAM }}
  IS
  BEGIN
    update_row(
      {% LIST_MAP_PAR_EQ_ROWTYPCOL_W_PK %} );
  END update_row;';
      util_template_replace('API BODY');
      util_debug_stop_one_step;
    END gen_update_rowtype_prc;

    PROCEDURE gen_delete_row_prc
    IS
    BEGIN
      util_debug_start_one_step(p_action => 'gen_delete_row_prc');
      g_code_blocks.template := '

  PROCEDURE delete_row (
    {% LIST_PK_PARAMS %} );';
      util_template_replace('API SPEC');
      g_code_blocks.template :=
           '

  PROCEDURE delete_row (
    {% LIST_PK_PARAMS %} )
  IS
  BEGIN
    DELETE FROM {{ TABLE_NAME }}
     WHERE {% LIST_PK_COLUMN_COMPARE %};'
        || CASE
             WHEN g_params.enable_generic_change_log
              AND NOT g_status.pk_is_multi_column
             THEN
               '
    create_change_log_entry(
      p_table     => ''{{ TABLE_NAME }}'',
      p_column    => ''{{ PK_COLUMN }}'',
      p_pk_id     => {{ PARAMETER_PK_FIRST_COLUMN }},
      p_old_value => ''ROW DELETED'',
      p_new_value => ''ROW DELETED'' );'
           END
        || '
  END delete_row;';

      util_template_replace('API BODY');
      util_debug_stop_one_step;
    END gen_delete_row_prc;

    PROCEDURE gen_getter_functions
    IS
    BEGIN
      util_debug_start_one_step(p_action => 'gen_getter_functions');

      FOR i IN g_columns.FIRST .. g_columns.LAST
      LOOP
        IF g_columns(i).is_pk_yn = 'N'
        THEN
          g_iterator.column_name := g_columns(i).column_name;
          g_iterator.method_name := util_get_method_name(g_columns(i).column_name);
          g_code_blocks.template := '

  FUNCTION get_{{ I_METHOD_NAME }}(
    {% LIST_PK_PARAMS %} )
  RETURN "{{ TABLE_NAME }}"."{{ I_COLUMN_NAME }}"%TYPE;';
          util_template_replace('API SPEC');
          g_code_blocks.template := '

  FUNCTION get_{{ I_METHOD_NAME }}(
    {% LIST_PK_PARAMS %} )
  RETURN "{{ TABLE_NAME }}"."{{ I_COLUMN_NAME }}"%TYPE IS
    v_row "{{ TABLE_NAME }}"%ROWTYPE;
  BEGIN
    v_row := read_row ( {% LIST_PK_MAP_PARAM_EQ_PARAM %} );
    RETURN v_row."{{ I_COLUMN_NAME }}";
  END get_{{ I_METHOD_NAME }};';
          util_template_replace('API BODY');
        END IF;
      END LOOP;

      util_debug_stop_one_step;
    END gen_getter_functions;

    PROCEDURE gen_setter_procedures
    IS
    BEGIN
      util_debug_start_one_step(p_action => 'gen_setter_procedures');

      FOR i IN g_columns.FIRST .. g_columns.LAST
      LOOP
        IF g_columns(i).is_excluded_yn = 'N'
       AND g_columns(i).is_pk_yn = 'N'
        THEN
          g_iterator.column_name    := g_columns(i).column_name;
          g_iterator.method_name    := util_get_method_name(g_columns(i).column_name);
          g_iterator.parameter_name := util_get_parameter_name(g_columns(i).column_name, g_status.rpad_columns);

          g_iterator.column_compare :=
            util_get_attribute_compare(p_data_type         => g_columns(i).data_type
                                     , p_first_attribute   => 'v_row."' || g_columns(i).column_name || '"'
                                     , p_second_attribute  => g_iterator.parameter_name
                                     , p_compare_operation => '<>');

          g_iterator.old_value      :=
            util_get_vc2_4000_operation(p_data_type      => g_columns(i).data_type
                                      , p_attribute_name => 'v_row."' || g_columns(i).column_name || '"');

          g_iterator.new_value      :=
            util_get_vc2_4000_operation(p_data_type      => g_columns(i).data_type
                                      , p_attribute_name => g_iterator.parameter_name);

          g_code_blocks.template    := '

  PROCEDURE set_{{ I_METHOD_NAME }}(
    {% LIST_PK_PARAMS %},
    {{ I_PARAMETER_NAME }} IN "{{ TABLE_NAME }}"."{{ I_COLUMN_NAME }}"%TYPE );';
          util_template_replace('API SPEC');
          g_code_blocks.template    :=
               '

  PROCEDURE set_{{ I_METHOD_NAME }}(
    {% LIST_PK_PARAMS %},
    {{ I_PARAMETER_NAME }} IN "{{ TABLE_NAME }}"."{{ I_COLUMN_NAME }}"%TYPE )
  IS
    v_row "{{ TABLE_NAME }}"%ROWTYPE;
  BEGIN
    IF row_exists ( {% LIST_PK_MAP_PARAM_EQ_PARAM %} ) THEN
      v_row := read_row ( {% LIST_PK_MAP_PARAM_EQ_PARAM %} );
      -- update only,if the column value really differs
      IF {{ I_COLUMN_COMPARE }} THEN
        UPDATE {{ TABLE_NAME }}
           SET "{{ I_COLUMN_NAME }}" = {{ I_PARAMETER_NAME }}
         WHERE {% LIST_PK_COLUMN_COMPARE %};'
            || CASE
                 WHEN g_params.enable_generic_change_log
                  AND NOT g_status.pk_is_multi_column
                 THEN
                   '
        create_change_log_entry(
          p_table     => ''{{ TABLE_NAME }}'',
          p_column    => ''{{ I_COLUMN_NAME }}'',
          p_pk_id     => {{ PARAMETER_PK_FIRST_COLUMN }},
          p_old_value => {{ I_OLD_VALUE }},
          p_new_value => {{ I_NEW_VALUE }} );'
               END
            || '
      END IF;
    END IF;
  END set_{{ I_METHOD_NAME }};';

          util_template_replace('API BODY');
        END IF;
      END LOOP;

      util_debug_stop_one_step;
    END gen_setter_procedures;

    PROCEDURE gen_get_a_row_fnc
    IS
    BEGIN
      util_debug_start_one_step(p_action => 'gen_get_a_row_fnc');
      g_code_blocks.template := '

  FUNCTION get_a_row
  RETURN "{{ TABLE_NAME }}"%ROWTYPE;';
      util_template_replace('API SPEC');
      g_code_blocks.template := '

  FUNCTION get_a_row
  RETURN "{{ TABLE_NAME }}"%ROWTYPE IS
    v_row "{{ TABLE_NAME }}"%ROWTYPE;
  BEGIN
    {% LIST_ROWCOLS_W_CUST_DEFAULTS %}
    return v_row;
  END get_a_row;';
      util_template_replace('API BODY');
      util_debug_stop_one_step;
    END gen_get_a_row_fnc;

    PROCEDURE gen_create_a_row_fnc
    IS
    BEGIN
      util_debug_start_one_step(p_action => 'gen_create_a_row_fnc');
      g_code_blocks.template := '

  FUNCTION create_a_row (
    {% LIST_PARAMS_W_PK_CUST_DEFAULTS %} )
  RETURN {{ RETURN_TYPE }};';
      util_template_replace('API SPEC');
      g_code_blocks.template := '

  FUNCTION create_a_row (
    {% LIST_PARAMS_W_PK_CUST_DEFAULTS %} )
  RETURN {{ RETURN_TYPE }} IS
    v_return {{ RETURN_TYPE }};
  BEGIN
    v_return := create_row (
      {% LIST_MAP_PAR_EQ_PARAM_W_PK %} );
    RETURN v_return;
  END create_a_row;';
      util_template_replace('API BODY');
      util_debug_stop_one_step;
    END gen_create_a_row_fnc;

    PROCEDURE gen_create_a_row_prc
    IS
    BEGIN
      util_debug_start_one_step(p_action => 'gen_create_a_row_prc');
      g_code_blocks.template := '

  PROCEDURE create_a_row (
    {% LIST_PARAMS_W_PK_CUST_DEFAULTS %} );';
      util_template_replace('API SPEC');
      g_code_blocks.template := '

  PROCEDURE create_a_row (
    {% LIST_PARAMS_W_PK_CUST_DEFAULTS %} )
  IS
    v_return {{ RETURN_TYPE }};
  BEGIN
    v_return := create_row (
      {% LIST_MAP_PAR_EQ_PARAM_W_PK %} );
  END create_a_row;';
      util_template_replace('API BODY');
      util_debug_stop_one_step;
    END gen_create_a_row_prc;

    PROCEDURE gen_read_a_row_fnc
    IS
    BEGIN
      util_debug_start_one_step(p_action => 'gen_read_a_row_fnc');
      g_code_blocks.template := '

  FUNCTION read_a_row
  RETURN "{{ TABLE_NAME }}"%ROWTYPE;';
      util_template_replace('API SPEC');
      g_code_blocks.template := '

  FUNCTION read_a_row
  RETURN "{{ TABLE_NAME }}"%ROWTYPE IS
    v_row  "{{ TABLE_NAME }}"%ROWTYPE;
    CURSOR cur_row IS SELECT * FROM {{ TABLE_NAME }};
  BEGIN
    OPEN cur_row;
    FETCH cur_row INTO v_row;
    CLOSE cur_row;
    RETURN v_row;
  END read_a_row;';
      util_template_replace('API BODY');
      util_debug_stop_one_step;
    END gen_read_a_row_fnc;

    PROCEDURE gen_footer
    IS
    BEGIN
      util_debug_start_one_step(p_action => 'gen_footer');
      g_code_blocks.template := CASE WHEN g_params.enable_custom_defaults THEN c_crlf || '
  /*
  Only custom defaults with the source "USER" are used when "c_reuse_existing_api_params" is set to true.
  All other custom defaults are only listed for convenience and determined at runtime by the generator.
  {% LIST_SPEC_CUSTOM_DEFAULTS %}
  */' END || '

END "{{ API_NAME }}";';

      util_template_replace('API SPEC');
      g_code_blocks.template := '

END "{{ API_NAME }}";';
      util_template_replace('API BODY');
      util_debug_stop_one_step;
    END gen_footer;

    PROCEDURE gen_dml_view
    IS
    BEGIN
      util_debug_start_one_step(p_action => 'gen_dml_view');
      g_code_blocks.template := '
CREATE OR REPLACE VIEW "{{ OWNER }}"."{{ TABLE_NAME_MINUS_6 }}_DML_V" AS
SELECT {% LIST_COLUMNS_W_PK_FULL %}
  FROM {{ TABLE_NAME }}';
      util_template_replace('VIEW');
      util_debug_stop_one_step;
    END gen_dml_view;

    -----------------------------------------------------------------------------

    PROCEDURE gen_dml_view_trigger
    IS
    BEGIN
      util_debug_start_one_step(p_action => 'gen_dml_view_trigger');
      g_code_blocks.template :=
           '
CREATE OR REPLACE TRIGGER "{{ OWNER }}"."{{ TABLE_NAME_MINUS_6 }}_IOIUD"
  INSTEAD OF INSERT OR UPDATE OR DELETE
  ON "{{ TABLE_NAME_MINUS_6 }}_DML_V"
  FOR EACH ROW
BEGIN
  IF INSERTING THEN'
        || CASE
             WHEN g_params.enable_insertion_of_rows THEN '
    "{{ API_NAME }}".create_row (
      {% LIST_MAP_PAR_EQ_NEWCOL_W_PK %} );'
             ELSE '
    raise_application_error (' || c_generator_error_number || ',''Insertion of a row is not allowed.'');'
           END
        || '
  ELSIF UPDATING THEN'
        || CASE
             WHEN g_params.enable_update_of_rows THEN '
    "{{ API_NAME }}".update_row (
      {% LIST_MAP_PAR_EQ_NEWCOL_W_PK %} );'
             ELSE '
    raise_application_error (' || c_generator_error_number || ',''Update of a row is not allowed.'');'
           END
        || '
  ELSIF DELETING THEN'
        || CASE
             WHEN g_params.enable_deletion_of_rows THEN '
    "{{ API_NAME }}".delete_row (
      {% LIST_PK_MAP_PARAM_EQ_OLDCOL %} );'
             ELSE '
    raise_application_error (' || c_generator_error_number || ',''Deletion of a row is not allowed.'');'
           END
        || '
  END IF;
END "{{ TABLE_NAME_MINUS_6 }}_IOIUD";';

      util_template_replace('TRIGGER');
      util_debug_stop_one_step;
    END gen_dml_view_trigger;

    PROCEDURE gen_finalize_clob_vc2_caching
    IS
    BEGIN
      util_debug_start_one_step(p_action => 'gen_finalize_clob_vc2_caching');
      util_clob_append(p_clob               => g_code_blocks.api_spec
                     , p_clob_varchar_cache => g_code_blocks.api_spec_varchar_cache
                     , p_varchar_to_append  => NULL
                     , p_final_call         => TRUE);

      util_clob_append(p_clob               => g_code_blocks.api_body
                     , p_clob_varchar_cache => g_code_blocks.api_body_varchar_cache
                     , p_varchar_to_append  => NULL
                     , p_final_call         => TRUE);

      IF g_params.enable_dml_view
      THEN
        util_clob_append(p_clob               => g_code_blocks.dml_view
                       , p_clob_varchar_cache => g_code_blocks.dml_view_varchar_cache
                       , p_varchar_to_append  => NULL
                       , p_final_call         => TRUE);

        util_clob_append(p_clob               => g_code_blocks.dml_view_trigger
                       , p_clob_varchar_cache => g_code_blocks.dml_view_trigger_varchar_cache
                       , p_varchar_to_append  => NULL
                       , p_final_call         => TRUE);
      END IF;

      util_debug_stop_one_step;
    END gen_finalize_clob_vc2_caching;
  BEGIN
    gen_header;
    gen_row_exists_fnc;
    gen_row_exists_yn_fnc;

    -- GET_PK_BY_UNIQUE_COLS functions only if no multi row pk is present
    -- use overloaded READ_ROW functions with unique paramams instead
    IF NOT g_status.pk_is_multi_column
    THEN
      gen_get_pk_by_unique_cols_fnc;
    END IF;

    -- CREATE procedures/functions only if allowed
    IF g_params.enable_insertion_of_rows
    THEN
      gen_create_row_fnc;
      gen_create_row_prc;
      gen_create_rowtype_fnc;
      gen_create_rowtype_prc;
    END IF;

    -- READ procedures
    gen_read_row_fnc;
    gen_read_row_by_uk_fnc;

    IF g_params.enable_proc_with_out_params
    THEN
      gen_read_row_prc;
    END IF;

    -- UPDATE procedures/functions only if allowed
    IF g_params.enable_update_of_rows
    THEN
      gen_update_row_prc;
      gen_update_rowtype_prc;
    END IF;

    -- DELETE procedures only if allowed
    IF g_params.enable_deletion_of_rows
    THEN
      gen_delete_row_prc;
    END IF;

    -- CREATE or UPDATE procedures/functions only if both is allowed
    IF g_params.enable_insertion_of_rows
   AND g_params.enable_update_of_rows
    THEN
      gen_createorupdate_row_fnc;
      gen_createorupdate_row_prc;
      gen_createorupdate_rowtype_fnc;
      gen_createorupdate_rowtype_prc;
    END IF;

    -- GETTER procedures/functions always
    IF g_params.enable_getter_and_setter
    THEN
      gen_getter_functions;
    END IF;

    -- SETTER procedures/functions only if allowed
    IF g_params.enable_update_of_rows
   AND g_params.enable_getter_and_setter
    THEN
      gen_setter_procedures;
    END IF;

    -- Some special stuff for the testing folks - thanks to Jacek GÃÂbal ;-)
    IF g_params.enable_custom_defaults
    THEN
      gen_get_a_row_fnc;
      gen_create_a_row_fnc;
      gen_create_a_row_prc;
      gen_read_a_row_fnc;
    END IF;

    gen_footer;

    -- DML View and Trigger only if allowed
    IF g_params.enable_dml_view
    THEN
      gen_dml_view;
      gen_dml_view_trigger;
    END IF;

    gen_finalize_clob_vc2_caching;
  END main_generate_code;

  PROCEDURE main_compile_code
  IS
  BEGIN
    -- compile package spec
    util_debug_start_one_step(p_action => 'compile_spec');

    BEGIN
      util_execute_sql(g_code_blocks.api_spec);
    EXCEPTION
      WHEN OTHERS
      THEN
        NULL;
    END;

    util_debug_stop_one_step;

    -- compile package body
    util_debug_start_one_step(p_action => 'compile_body');

    BEGIN
      util_execute_sql(g_code_blocks.api_body);
    EXCEPTION
      WHEN OTHERS
      THEN
        NULL;
    END;

    util_debug_stop_one_step;

    IF g_params.enable_dml_view
    THEN
      -- compile DML view
      util_debug_start_one_step(p_action => 'compile_dml_view');

      BEGIN
        util_execute_sql(g_code_blocks.dml_view);
      EXCEPTION
        WHEN OTHERS
        THEN
          NULL;
      END;

      util_debug_stop_one_step;

      -- compile DML view trigger
      util_debug_start_one_step(p_action => 'compile_dml_view_trigger');

      BEGIN
        util_execute_sql(g_code_blocks.dml_view_trigger);
      EXCEPTION
        WHEN OTHERS
        THEN
          NULL;
      END;

      util_debug_stop_one_step;
    END IF;
  END main_compile_code;

  FUNCTION main_return_code
    RETURN CLOB
  IS
    terminator VARCHAR2(10 CHAR) := c_crlf || '/' || c_crlflf;
  BEGIN
    RETURN    g_code_blocks.api_spec
           || terminator
           || g_code_blocks.api_body
           || terminator
           || CASE
                WHEN g_params.enable_dml_view
                THEN
                  g_code_blocks.dml_view || terminator || g_code_blocks.dml_view_trigger || terminator
                ELSE
                  NULL
              END;
  END main_return_code;

  PROCEDURE compile_api(
    p_table_name                  IN all_objects.object_name%TYPE
  , p_owner                       IN all_users.username%TYPE DEFAULT USER
  , p_reuse_existing_api_params   IN BOOLEAN DEFAULT om_tapigen.c_reuse_existing_api_params
  , --^ if true,the following params are ignored when API package are already existing and params are extractable from spec source
    p_enable_insertion_of_rows    IN BOOLEAN DEFAULT om_tapigen.c_enable_insertion_of_rows
  , p_enable_column_defaults      IN BOOLEAN DEFAULT om_tapigen.c_enable_column_defaults
  , p_enable_update_of_rows       IN BOOLEAN DEFAULT om_tapigen.c_enable_update_of_rows
  , p_enable_deletion_of_rows     IN BOOLEAN DEFAULT om_tapigen.c_enable_deletion_of_rows
  , p_enable_parameter_prefixes   IN BOOLEAN DEFAULT om_tapigen.c_enable_parameter_prefixes
  , p_enable_proc_with_out_params IN BOOLEAN DEFAULT om_tapigen.c_enable_proc_with_out_params
  , p_enable_getter_and_setter    IN BOOLEAN DEFAULT om_tapigen.c_enable_getter_and_setter
  , p_col_prefix_in_method_names  IN BOOLEAN DEFAULT om_tapigen.c_col_prefix_in_method_names
  , p_return_row_instead_of_pk    IN BOOLEAN DEFAULT om_tapigen.c_return_row_instead_of_pk
  , p_enable_dml_view             IN BOOLEAN DEFAULT om_tapigen.c_enable_dml_view
  , p_enable_generic_change_log   IN BOOLEAN DEFAULT om_tapigen.c_enable_generic_change_log
  , p_api_name                    IN all_objects.object_name%TYPE DEFAULT om_tapigen.c_api_name
  , p_sequence_name               IN all_objects.object_name%TYPE DEFAULT om_tapigen.c_sequence_name
  , p_exclude_column_list         IN VARCHAR2 DEFAULT om_tapigen.c_exclude_column_list
  , p_enable_custom_defaults      IN BOOLEAN DEFAULT om_tapigen.c_enable_custom_defaults
  , p_custom_default_values       IN XMLTYPE DEFAULT om_tapigen.c_custom_default_values)
  IS
  BEGIN
    util_debug_start_one_run(p_generator_action => 'compile API', p_table_name => p_table_name, p_owner => p_owner);
    main_init(p_generator_action            => 'COMPILE_API'
            , p_table_name                  => p_table_name
            , p_owner                       => p_owner
            , p_reuse_existing_api_params   => p_reuse_existing_api_params
            , p_enable_insertion_of_rows    => p_enable_insertion_of_rows
            , p_enable_column_defaults      => p_enable_column_defaults
            , p_enable_update_of_rows       => p_enable_update_of_rows
            , p_enable_deletion_of_rows     => p_enable_deletion_of_rows
            , p_enable_parameter_prefixes   => p_enable_parameter_prefixes
            , p_enable_proc_with_out_params => p_enable_proc_with_out_params
            , p_enable_getter_and_setter    => p_enable_getter_and_setter
            , p_col_prefix_in_method_names  => p_col_prefix_in_method_names
            , p_return_row_instead_of_pk    => p_return_row_instead_of_pk
            , p_enable_dml_view             => p_enable_dml_view
            , p_enable_generic_change_log   => p_enable_generic_change_log
            , p_api_name                    => p_api_name
            , p_sequence_name               => p_sequence_name
            , p_exclude_column_list         => p_exclude_column_list
            , p_enable_custom_defaults      => p_enable_custom_defaults
            , p_custom_default_values       => p_custom_default_values);
    main_generate_code;
    main_compile_code;
    util_debug_stop_one_run;
  END compile_api;

  FUNCTION compile_api_and_get_code(
    p_table_name                  IN all_objects.object_name%TYPE
  , p_owner                       IN all_users.username%TYPE DEFAULT USER
  , p_reuse_existing_api_params   IN BOOLEAN DEFAULT om_tapigen.c_reuse_existing_api_params
  , --^ if true,the following params are ignored when API package are already existing and params are extractable from spec source
    p_enable_insertion_of_rows    IN BOOLEAN DEFAULT om_tapigen.c_enable_insertion_of_rows
  , p_enable_column_defaults      IN BOOLEAN DEFAULT om_tapigen.c_enable_column_defaults
  , p_enable_update_of_rows       IN BOOLEAN DEFAULT om_tapigen.c_enable_update_of_rows
  , p_enable_deletion_of_rows     IN BOOLEAN DEFAULT om_tapigen.c_enable_deletion_of_rows
  , p_enable_parameter_prefixes   IN BOOLEAN DEFAULT om_tapigen.c_enable_parameter_prefixes
  , p_enable_proc_with_out_params IN BOOLEAN DEFAULT om_tapigen.c_enable_proc_with_out_params
  , p_enable_getter_and_setter    IN BOOLEAN DEFAULT om_tapigen.c_enable_getter_and_setter
  , p_col_prefix_in_method_names  IN BOOLEAN DEFAULT om_tapigen.c_col_prefix_in_method_names
  , p_return_row_instead_of_pk    IN BOOLEAN DEFAULT om_tapigen.c_return_row_instead_of_pk
  , p_enable_dml_view             IN BOOLEAN DEFAULT om_tapigen.c_enable_dml_view
  , p_enable_generic_change_log   IN BOOLEAN DEFAULT om_tapigen.c_enable_generic_change_log
  , p_api_name                    IN all_objects.object_name%TYPE DEFAULT om_tapigen.c_api_name
  , p_sequence_name               IN all_objects.object_name%TYPE DEFAULT om_tapigen.c_sequence_name
  , p_exclude_column_list         IN VARCHAR2 DEFAULT om_tapigen.c_exclude_column_list
  , p_enable_custom_defaults      IN BOOLEAN DEFAULT om_tapigen.c_enable_custom_defaults
  , p_custom_default_values       IN XMLTYPE DEFAULT om_tapigen.c_custom_default_values)
    RETURN CLOB
  IS
  BEGIN
    util_debug_start_one_run(p_generator_action => 'compile API, get code'
                           , p_table_name       => p_table_name
                           , p_owner            => p_owner);
    main_init(p_generator_action            => 'COMPILE_API_AND_GET_CODE'
            , p_table_name                  => p_table_name
            , p_owner                       => p_owner
            , p_reuse_existing_api_params   => p_reuse_existing_api_params
            , p_enable_insertion_of_rows    => p_enable_insertion_of_rows
            , p_enable_column_defaults      => p_enable_column_defaults
            , p_enable_update_of_rows       => p_enable_update_of_rows
            , p_enable_deletion_of_rows     => p_enable_deletion_of_rows
            , p_enable_parameter_prefixes   => p_enable_parameter_prefixes
            , p_enable_proc_with_out_params => p_enable_proc_with_out_params
            , p_enable_getter_and_setter    => p_enable_getter_and_setter
            , p_col_prefix_in_method_names  => p_col_prefix_in_method_names
            , p_return_row_instead_of_pk    => p_return_row_instead_of_pk
            , p_enable_dml_view             => p_enable_dml_view
            , p_enable_generic_change_log   => p_enable_generic_change_log
            , p_api_name                    => p_api_name
            , p_sequence_name               => p_sequence_name
            , p_exclude_column_list         => p_exclude_column_list
            , p_enable_custom_defaults      => p_enable_custom_defaults
            , p_custom_default_values       => p_custom_default_values);
    main_generate_code;
    main_compile_code;
    util_debug_stop_one_run;
    RETURN main_return_code;
  END compile_api_and_get_code;

  FUNCTION get_code(p_table_name                  IN all_objects.object_name%TYPE
                  , p_owner                       IN all_users.username%TYPE DEFAULT USER
                  , p_reuse_existing_api_params   IN BOOLEAN DEFAULT om_tapigen.c_reuse_existing_api_params
                  , --^ if true,the following params are ignored when API package are already existing and params are extractable from spec source
                    p_enable_insertion_of_rows    IN BOOLEAN DEFAULT om_tapigen.c_enable_insertion_of_rows
                  , p_enable_column_defaults      IN BOOLEAN DEFAULT om_tapigen.c_enable_column_defaults
                  , p_enable_update_of_rows       IN BOOLEAN DEFAULT om_tapigen.c_enable_update_of_rows
                  , p_enable_deletion_of_rows     IN BOOLEAN DEFAULT om_tapigen.c_enable_deletion_of_rows
                  , p_enable_parameter_prefixes   IN BOOLEAN DEFAULT om_tapigen.c_enable_parameter_prefixes
                  , p_enable_proc_with_out_params IN BOOLEAN DEFAULT om_tapigen.c_enable_proc_with_out_params
                  , p_enable_getter_and_setter    IN BOOLEAN DEFAULT om_tapigen.c_enable_getter_and_setter
                  , p_col_prefix_in_method_names  IN BOOLEAN DEFAULT om_tapigen.c_col_prefix_in_method_names
                  , p_return_row_instead_of_pk    IN BOOLEAN DEFAULT om_tapigen.c_return_row_instead_of_pk
                  , p_enable_dml_view             IN BOOLEAN DEFAULT om_tapigen.c_enable_dml_view
                  , p_enable_generic_change_log   IN BOOLEAN DEFAULT om_tapigen.c_enable_generic_change_log
                  , p_api_name                    IN all_objects.object_name%TYPE DEFAULT om_tapigen.c_api_name
                  , p_sequence_name               IN all_objects.object_name%TYPE DEFAULT om_tapigen.c_sequence_name
                  , p_exclude_column_list         IN VARCHAR2 DEFAULT om_tapigen.c_exclude_column_list
                  , p_enable_custom_defaults      IN BOOLEAN DEFAULT om_tapigen.c_enable_custom_defaults
                  , p_custom_default_values       IN XMLTYPE DEFAULT om_tapigen.c_custom_default_values)
    RETURN CLOB
  IS
  BEGIN
    util_debug_start_one_run(p_generator_action => 'get code', p_table_name => p_table_name, p_owner => p_owner);
    main_init(p_generator_action            => 'GET_CODE'
            , p_table_name                  => p_table_name
            , p_owner                       => p_owner
            , p_reuse_existing_api_params   => p_reuse_existing_api_params
            , p_enable_insertion_of_rows    => p_enable_insertion_of_rows
            , p_enable_column_defaults      => p_enable_column_defaults
            , p_enable_update_of_rows       => p_enable_update_of_rows
            , p_enable_deletion_of_rows     => p_enable_deletion_of_rows
            , p_enable_parameter_prefixes   => p_enable_parameter_prefixes
            , p_enable_proc_with_out_params => p_enable_proc_with_out_params
            , p_enable_getter_and_setter    => p_enable_getter_and_setter
            , p_col_prefix_in_method_names  => p_col_prefix_in_method_names
            , p_return_row_instead_of_pk    => p_return_row_instead_of_pk
            , p_enable_dml_view             => p_enable_dml_view
            , p_enable_generic_change_log   => p_enable_generic_change_log
            , p_api_name                    => p_api_name
            , p_sequence_name               => p_sequence_name
            , p_exclude_column_list         => p_exclude_column_list
            , p_enable_custom_defaults      => p_enable_custom_defaults
            , p_custom_default_values       => p_custom_default_values);
    main_generate_code;
    util_debug_stop_one_run;
    RETURN main_return_code;
  END get_code;

  PROCEDURE recreate_existing_apis(p_owner IN all_users.username%TYPE DEFAULT USER)
  IS
    v_apis t_tab_existing_apis;

    CURSOR v_cur IS SELECT * FROM TABLE(view_existing_apis(p_owner => p_owner));
  BEGIN
    OPEN v_cur;

    FETCH v_cur BULK COLLECT INTO v_apis LIMIT c_bulk_collect_limit;

    CLOSE v_cur;

    IF v_apis.COUNT > 0
    THEN
      FOR i IN v_apis.FIRST .. v_apis.LAST
      LOOP
        compile_api(p_table_name => v_apis(i).table_name, p_owner => v_apis(i).owner);
      END LOOP;
    END IF;
  END;

  FUNCTION view_existing_apis(p_table_name all_tables.table_name%TYPE DEFAULT NULL
                            , p_owner      all_users.username%TYPE DEFAULT USER)
    RETURN t_tab_existing_apis
    PIPELINED
  IS
    v_tab t_tab_existing_apis;
    v_row t_rec_existing_apis;
  BEGIN
    -- I was not able to compile without execute immediate - got a strange ORA-03113.
    -- Direct execution of the statement in SQL tool works :-(
    EXECUTE IMMEDIATE '
-- ATTENTION: query columns need to match the global row definition om_tapigen.g_row_existing_apis.
-- Creating a cursor was not possible - database throws an error

WITH api_names AS (
         SELECT owner,
                NAME AS api_name
           FROM dba_source
          WHERE     owner = :p_owner
                AND TYPE = ''PACKAGE''
                AND line BETWEEN :spec_options_min_line
                             AND :spec_options_max_line
                AND INSTR (text,''generator="OM_TAPIGEN"'') > 0
     ) -- select * from api_names;
     , sources AS (
         SELECT owner,
                package_name,
                xmltype (
                   NVL (REGEXP_SUBSTR (REPLACE (source_code, ''*'', NULL), -- replace needed for backward compatibility of old comment style
                                       ''<options.*>'',
                                       1,
                                       1,
                                       ''ni''),
                        ''<no_data_found/>''))
                   AS options
           FROM (SELECT owner,
                        NAME AS package_name,
                        LISTAGG (text, '' '')
                           WITHIN GROUP (ORDER BY NAME, line)
                           OVER (PARTITION BY NAME)
                           AS source_code
                   FROM dba_source
                  WHERE     owner = :p_owner
                        AND name  IN (SELECT api_name FROM api_names)
                        AND TYPE  = ''PACKAGE''
                        AND line  BETWEEN :spec_options_min_line
                                      AND :spec_options_max_line)
          GROUP BY owner, package_name, source_code
     ) -- select * from sources;
     , apis AS (
         SELECT x.p_owner as owner,
                x.p_table_name AS table_name,
                t.package_name,
                x.generator,
                x.generator_version,
                x.generator_action,
                TO_DATE (x.generated_at,''yyyy-mm-dd hh24:mi:ss'') AS generated_at,
                x.generated_by,
                x.p_owner,
                x.p_table_name,
                x.p_reuse_existing_api_params,
                x.p_enable_insertion_of_rows,
                x.p_enable_column_defaults,
                x.p_enable_update_of_rows,
                x.p_enable_deletion_of_rows,
                x.p_enable_parameter_prefixes,
                x.p_enable_proc_with_out_params,
                x.p_enable_getter_and_setter,
                x.p_col_prefix_in_method_names,
                x.p_return_row_instead_of_pk,
                x.p_enable_dml_view,
                x.p_enable_generic_change_log,
                x.p_api_name,
                x.p_sequence_name,
                x.p_exclude_column_list,
                x.p_enable_custom_defaults,
                x.p_custom_default_values
           FROM sources t
                CROSS JOIN
                XMLTABLE (
                   ''/options''
                   PASSING options
                   COLUMNS generator                     VARCHAR2 (30 CHAR)   PATH ''@generator'',
                           generator_version             VARCHAR2 (10 CHAR)   PATH ''@generator_version'',
                           generator_action              VARCHAR2 (30 CHAR)   PATH ''@generator_action'',
                           generated_at                  VARCHAR2 (30 CHAR)   PATH ''@generated_at'',
                           generated_by                  VARCHAR2 (128 CHAR)  PATH ''@generated_by'',
                           p_owner                       VARCHAR2 (128 CHAR)  PATH ''@p_owner'',
                           p_table_name                  VARCHAR2 (128 CHAR)  PATH ''@p_table_name'',
                           p_reuse_existing_api_params   VARCHAR2 (5 CHAR)    PATH ''@p_reuse_existing_api_params'',
                           p_enable_insertion_of_rows    VARCHAR2 (5 CHAR)    PATH ''@p_enable_insertion_of_rows'',
                           p_enable_column_defaults      VARCHAR2 (5 CHAR)    PATH ''@p_enable_column_defaults'',
                           p_enable_update_of_rows       VARCHAR2 (5 CHAR)    PATH ''@p_enable_update_of_rows'',
                           p_enable_deletion_of_rows     VARCHAR2 (5 CHAR)    PATH ''@p_enable_deletion_of_rows'',
                           p_enable_parameter_prefixes   VARCHAR2 (5 CHAR)    PATH ''@p_enable_parameter_prefixes'',
                           p_enable_proc_with_out_params VARCHAR2 (5 CHAR)    PATH ''@p_enable_proc_with_out_params'',
                           p_enable_getter_and_setter    VARCHAR2 (5 CHAR)    PATH ''@p_enable_getter_and_setter'',
                           p_col_prefix_in_method_names  VARCHAR2 (5 CHAR)    PATH ''@p_col_prefix_in_method_names'',
                           p_return_row_instead_of_pk    VARCHAR2 (5 CHAR)    PATH ''@p_return_row_instead_of_pk'',
                           p_enable_dml_view             VARCHAR2 (5 CHAR)    PATH ''@p_enable_dml_view'',
                           p_enable_generic_change_log   VARCHAR2 (5 CHAR)    PATH ''@p_enable_generic_change_log'',
                           p_api_name                    VARCHAR2 (128 CHAR)  PATH ''@p_api_name'',
                           p_sequence_name               VARCHAR2 (128 CHAR)  PATH ''@p_sequence_name'',
                           p_exclude_column_list         VARCHAR2 (4000 CHAR) PATH ''@p_exclude_column_list'',
                           p_enable_custom_defaults      VARCHAR2 (5 CHAR)    PATH ''@p_enable_custom_defaults'',
                           p_custom_default_values       VARCHAR2 (30 CHAR)   PATH ''@p_custom_default_values'') x
     ) -- select * from apis;
     , objects AS (
         SELECT specs.object_name   AS package_name,
                specs.status        AS spec_status,
                specs.last_ddl_time AS spec_last_ddl_time,
                bodys.status        AS body_status,
                bodys.last_ddl_time AS body_last_ddl_time
           FROM (SELECT object_name,
                        object_type,
                        status,
                        last_ddl_time
                   FROM dba_objects
                  WHERE     owner       = :p_owner
                        AND object_type = ''PACKAGE''
                        AND object_name IN (SELECT api_name FROM api_names))
                specs
                LEFT JOIN
                (SELECT object_name,
                        object_type,
                        status,
                        last_ddl_time
                   FROM dba_objects
                  WHERE     owner       = :p_owner
                        AND object_type = ''PACKAGE BODY''
                        AND object_name IN (SELECT api_name FROM api_names))
                bodys
                   ON     specs.object_name              = bodys.object_name
                      AND specs.object_type || '' BODY'' = bodys.object_type
     ) -- select * from objects;
SELECT NULL AS errors,
       apis.owner,
       apis.table_name,
       objects.package_name,
       objects.spec_status,
       objects.spec_last_ddl_time,
       objects.body_status,
       objects.body_last_ddl_time,
       apis.generator,
       apis.generator_version,
       apis.generator_action,
       apis.generated_at,
       apis.generated_by,
       apis.p_owner,
       apis.p_table_name,
       apis.p_reuse_existing_api_params,
       apis.p_enable_insertion_of_rows,
       apis.p_enable_column_defaults,
       apis.p_enable_update_of_rows,
       apis.p_enable_deletion_of_rows,
       apis.p_enable_parameter_prefixes,
       apis.p_enable_proc_with_out_params,
       apis.p_enable_getter_and_setter,
       apis.p_col_prefix_in_method_names,
       apis.p_return_row_instead_of_pk,
       apis.p_enable_dml_view,
       apis.p_enable_generic_change_log,
       apis.p_api_name,
       apis.p_sequence_name,
       apis.p_exclude_column_list,
       apis.p_enable_custom_defaults,
       apis.p_custom_default_values
  FROM apis JOIN objects ON apis.package_name = objects.package_name
 WHERE table_name = NVL ( :p_table_name, table_name)
            '
      BULK COLLECT INTO v_tab
      USING p_owner
          , c_spec_options_min_line
          , c_spec_options_max_line
          , p_owner
          , c_spec_options_min_line
          , c_spec_options_max_line
          , p_owner
          , p_owner
          , p_table_name;

    IF v_tab.COUNT > 0
    THEN
      FOR i IN v_tab.FIRST .. v_tab.LAST
      LOOP
        PIPE ROW (v_tab(i));
      END LOOP;
    END IF;
  EXCEPTION
    WHEN OTHERS
    THEN
      v_row.errors :=
        SUBSTR(
             'Incomplete resultset! '
          || 'This is the last correct proccessed row from the pipelined function. '
          || 'Did you change the params XML in one of the API packages? Original error message: '
          || c_crlflf
          || SQLERRM
          || c_crlflf
          || DBMS_UTILITY.format_error_backtrace
        , 1
        , 4000);

      PIPE ROW (v_row);
  END view_existing_apis;

  FUNCTION view_naming_conflicts(p_owner all_users.username%TYPE DEFAULT USER)
    RETURN t_tab_naming_conflicts
    PIPELINED
  IS
  BEGIN
    FOR i
      IN (WITH
            ut
            AS
              (SELECT table_name
                 FROM all_tables
                WHERE owner = p_owner),
            temp
            AS
              (SELECT SUBSTR(table_name, 1, (SELECT om_tapigen.util_get_ora_max_name_len FROM DUAL) - 4) || '_API'
                        AS object_name
                 FROM ut
               UNION ALL
               SELECT SUBSTR(table_name, 1, (SELECT om_tapigen.util_get_ora_max_name_len FROM DUAL) - 6) || '_DML_V'
                 FROM ut
               UNION ALL
               SELECT SUBSTR(table_name, 1, (SELECT om_tapigen.util_get_ora_max_name_len FROM DUAL) - 6) || '_IOIUD'
                 FROM ut
               UNION ALL
               SELECT 'GENERIC_CHANGE_LOG' FROM DUAL
               UNION ALL
               SELECT 'GENERIC_CHANGE_LOG_SEQ' FROM DUAL
               UNION ALL
               SELECT 'GENERIC_CHANGE_LOG_PK' FROM DUAL
               UNION ALL
               SELECT 'GENERIC_CHANGE_LOG_IDX' FROM DUAL)
            SELECT uo.object_name
                 , uo.object_type
                 , uo.status
                 , uo.last_ddl_time
              FROM all_objects uo
             WHERE owner = p_owner
               AND uo.object_name IN (SELECT object_name FROM temp)
          ORDER BY uo.object_name)
    LOOP
      PIPE ROW (i);
    END LOOP;
  END view_naming_conflicts;
END om_tapigen;
/