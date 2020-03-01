CREATE OR REPLACE EDITIONABLE PACKAGE "META_CODE_VERSIONING_API"
IS
  /*
  This is the API for the table "META_CODE_VERSIONING".

  GENERATION OPTIONS
  - Must be in the lines 5-35 to be reusable by the generator
  - DO NOT TOUCH THIS until you know what you do
  - Read the docs under github.com/OraMUC/table-api-generator ;-)
  <options
    generator="OM_TAPIGEN"
    generator_version="0.5.0_b3"
    generator_action="COMPILE_API"
    generated_at="2019-05-07 15:15:48"
    generated_by="ANDBOR"
    p_table_name="META_CODE_VERSIONING"
    p_owner="MAINT_WAAS"
    p_reuse_existing_api_params="TRUE"
    p_enable_insertion_of_rows="TRUE"
    p_enable_column_defaults="FALSE"
    p_enable_update_of_rows="TRUE"
    p_enable_deletion_of_rows="FALSE"
    p_enable_parameter_prefixes="TRUE"
    p_enable_proc_with_out_params="TRUE"
    p_enable_getter_and_setter="TRUE"
    p_col_prefix_in_method_names="TRUE"
    p_return_row_instead_of_pk="FALSE"
    p_enable_dml_view="FALSE"
    p_enable_generic_change_log="FALSE"
    p_api_name="META_CODE_VERSIONING_API"
    p_sequence_name="META_CODE_VERSIONING_SEQ"
    p_exclude_column_list=""
    p_enable_custom_defaults="FALSE"
    p_custom_default_values=""/>

  This API provides DML functionality that can be easily called from APEX.
  Target of the table API is to encapsulate the table DML source code for
  security (UI schema needs only the execute right for the API and the
  read/write right for the META_CODE_VERSIONING_DML_V, tables can be
  hidden in extra data schema) and easy readability of the business logic
  (all DML is then written in the same style). For APEX automatic row
  processing like tabular forms you can optionally use the
  META_CODE_VERSIONING_DML_V. The instead of trigger for this view
  is calling simply this "META_CODE_VERSIONING_API".
  */

  FUNCTION row_exists(p_id IN "META_CODE_VERSIONING"."ID"%TYPE /*PK*/
                                                              )
    RETURN BOOLEAN;

  FUNCTION row_exists_yn(p_id IN "META_CODE_VERSIONING"."ID"%TYPE /*PK*/
                                                                 )
    RETURN VARCHAR2;

  FUNCTION create_row(p_id         IN "META_CODE_VERSIONING"."ID"%TYPE DEFAULT NULL /*PK*/
                    , p_schema     IN "META_CODE_VERSIONING"."SCHEMA"%TYPE
                    , p_object     IN "META_CODE_VERSIONING"."OBJECT"%TYPE
                    , p_name       IN "META_CODE_VERSIONING"."NAME"%TYPE
                    , p_filename   IN "META_CODE_VERSIONING"."FILENAME"%TYPE
                    , p_script     IN "META_CODE_VERSIONING"."SCRIPT"%TYPE
                    , p_created_at IN "META_CODE_VERSIONING"."CREATED_AT"%TYPE)
    RETURN "META_CODE_VERSIONING"."ID"%TYPE;

  PROCEDURE create_row(
    p_id         IN "META_CODE_VERSIONING"."ID"%TYPE DEFAULT NULL /*PK*/
  , p_schema     IN "META_CODE_VERSIONING"."SCHEMA"%TYPE
  , p_object     IN "META_CODE_VERSIONING"."OBJECT"%TYPE
  , p_name       IN "META_CODE_VERSIONING"."NAME"%TYPE
  , p_filename   IN "META_CODE_VERSIONING"."FILENAME"%TYPE
  , p_script     IN "META_CODE_VERSIONING"."SCRIPT"%TYPE
  , p_created_at IN "META_CODE_VERSIONING"."CREATED_AT"%TYPE);

  FUNCTION create_row(p_row IN "META_CODE_VERSIONING"%ROWTYPE)
    RETURN "META_CODE_VERSIONING"."ID"%TYPE;

  PROCEDURE create_row(p_row IN "META_CODE_VERSIONING"%ROWTYPE);

  FUNCTION read_row(p_id IN "META_CODE_VERSIONING"."ID"%TYPE /*PK*/
                                                            )
    RETURN "META_CODE_VERSIONING"%ROWTYPE;

  PROCEDURE read_row(
    p_id         IN            "META_CODE_VERSIONING"."ID"%TYPE /*PK*/
  , p_schema        OUT NOCOPY "META_CODE_VERSIONING"."SCHEMA"%TYPE
  , p_object        OUT NOCOPY "META_CODE_VERSIONING"."OBJECT"%TYPE
  , p_name          OUT NOCOPY "META_CODE_VERSIONING"."NAME"%TYPE
  , p_filename      OUT NOCOPY "META_CODE_VERSIONING"."FILENAME"%TYPE
  , p_script        OUT NOCOPY "META_CODE_VERSIONING"."SCRIPT"%TYPE
  , p_created_at    OUT NOCOPY "META_CODE_VERSIONING"."CREATED_AT"%TYPE);

  PROCEDURE update_row(
    p_id         IN "META_CODE_VERSIONING"."ID"%TYPE DEFAULT NULL /*PK*/
  , p_schema     IN "META_CODE_VERSIONING"."SCHEMA"%TYPE
  , p_object     IN "META_CODE_VERSIONING"."OBJECT"%TYPE
  , p_name       IN "META_CODE_VERSIONING"."NAME"%TYPE
  , p_filename   IN "META_CODE_VERSIONING"."FILENAME"%TYPE
  , p_script     IN "META_CODE_VERSIONING"."SCRIPT"%TYPE
  , p_created_at IN "META_CODE_VERSIONING"."CREATED_AT"%TYPE);

  PROCEDURE update_row(p_row IN "META_CODE_VERSIONING"%ROWTYPE);

  FUNCTION create_or_update_row(
    p_id         IN "META_CODE_VERSIONING"."ID"%TYPE DEFAULT NULL /*PK*/
  , p_schema     IN "META_CODE_VERSIONING"."SCHEMA"%TYPE
  , p_object     IN "META_CODE_VERSIONING"."OBJECT"%TYPE
  , p_name       IN "META_CODE_VERSIONING"."NAME"%TYPE
  , p_filename   IN "META_CODE_VERSIONING"."FILENAME"%TYPE
  , p_script     IN "META_CODE_VERSIONING"."SCRIPT"%TYPE
  , p_created_at IN "META_CODE_VERSIONING"."CREATED_AT"%TYPE)
    RETURN "META_CODE_VERSIONING"."ID"%TYPE;

  PROCEDURE create_or_update_row(
    p_id         IN "META_CODE_VERSIONING"."ID"%TYPE DEFAULT NULL /*PK*/
  , p_schema     IN "META_CODE_VERSIONING"."SCHEMA"%TYPE
  , p_object     IN "META_CODE_VERSIONING"."OBJECT"%TYPE
  , p_name       IN "META_CODE_VERSIONING"."NAME"%TYPE
  , p_filename   IN "META_CODE_VERSIONING"."FILENAME"%TYPE
  , p_script     IN "META_CODE_VERSIONING"."SCRIPT"%TYPE
  , p_created_at IN "META_CODE_VERSIONING"."CREATED_AT"%TYPE);

  FUNCTION create_or_update_row(p_row IN "META_CODE_VERSIONING"%ROWTYPE)
    RETURN "META_CODE_VERSIONING"."ID"%TYPE;

  PROCEDURE create_or_update_row(p_row IN "META_CODE_VERSIONING"%ROWTYPE);

  FUNCTION get_schema(p_id IN "META_CODE_VERSIONING"."ID"%TYPE /*PK*/
                                                              )
    RETURN "META_CODE_VERSIONING"."SCHEMA"%TYPE;

  FUNCTION get_object(p_id IN "META_CODE_VERSIONING"."ID"%TYPE /*PK*/
                                                              )
    RETURN "META_CODE_VERSIONING"."OBJECT"%TYPE;

  FUNCTION get_name(p_id IN "META_CODE_VERSIONING"."ID"%TYPE /*PK*/
                                                            )
    RETURN "META_CODE_VERSIONING"."NAME"%TYPE;

  FUNCTION get_filename(p_id IN "META_CODE_VERSIONING"."ID"%TYPE /*PK*/
                                                                )
    RETURN "META_CODE_VERSIONING"."FILENAME"%TYPE;

  FUNCTION get_script(p_id IN "META_CODE_VERSIONING"."ID"%TYPE /*PK*/
                                                              )
    RETURN "META_CODE_VERSIONING"."SCRIPT"%TYPE;

  FUNCTION get_created_at(p_id IN "META_CODE_VERSIONING"."ID"%TYPE /*PK*/
                                                                  )
    RETURN "META_CODE_VERSIONING"."CREATED_AT"%TYPE;

  PROCEDURE set_schema(p_id     IN "META_CODE_VERSIONING"."ID"%TYPE /*PK*/
                     , p_schema IN "META_CODE_VERSIONING"."SCHEMA"%TYPE);

  PROCEDURE set_object(p_id     IN "META_CODE_VERSIONING"."ID"%TYPE /*PK*/
                     , p_object IN "META_CODE_VERSIONING"."OBJECT"%TYPE);

  PROCEDURE set_name(p_id   IN "META_CODE_VERSIONING"."ID"%TYPE /*PK*/
                   , p_name IN "META_CODE_VERSIONING"."NAME"%TYPE);

  PROCEDURE set_filename(p_id       IN "META_CODE_VERSIONING"."ID"%TYPE /*PK*/
                       , p_filename IN "META_CODE_VERSIONING"."FILENAME"%TYPE);

  PROCEDURE set_script(p_id     IN "META_CODE_VERSIONING"."ID"%TYPE /*PK*/
                     , p_script IN "META_CODE_VERSIONING"."SCRIPT"%TYPE);

  PROCEDURE set_created_at(
    p_id         IN "META_CODE_VERSIONING"."ID"%TYPE /*PK*/
  , p_created_at IN "META_CODE_VERSIONING"."CREATED_AT"%TYPE);
END "META_CODE_VERSIONING_API";
/