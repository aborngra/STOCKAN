CREATE OR REPLACE EDITIONABLE PACKAGE BODY "META_CODE_VERSIONING_API"
IS
  FUNCTION row_exists(p_id IN "META_CODE_VERSIONING"."ID"%TYPE /*PK*/
                                                              )
    RETURN BOOLEAN
  IS
    v_return BOOLEAN := FALSE;
    v_dummy  PLS_INTEGER;

    CURSOR cur_bool IS
      SELECT 1
        FROM "META_CODE_VERSIONING"
       WHERE COALESCE("ID", -999999999999999.999999999999999) =
             COALESCE(p_id, -999999999999999.999999999999999);
  BEGIN
    OPEN cur_bool;

    FETCH cur_bool INTO v_dummy;

    IF cur_bool%FOUND
    THEN
      v_return := TRUE;
    END IF;

    CLOSE cur_bool;

    RETURN v_return;
  END;

  FUNCTION row_exists_yn(p_id IN "META_CODE_VERSIONING"."ID"%TYPE /*PK*/
                                                                 )
    RETURN VARCHAR2
  IS
  BEGIN
    RETURN CASE WHEN row_exists(p_id => p_id) THEN 'Y' ELSE 'N' END;
  END;

  FUNCTION create_row(p_id         IN "META_CODE_VERSIONING"."ID"%TYPE DEFAULT NULL /*PK*/
                    , p_schema     IN "META_CODE_VERSIONING"."SCHEMA"%TYPE
                    , p_object     IN "META_CODE_VERSIONING"."OBJECT"%TYPE
                    , p_name       IN "META_CODE_VERSIONING"."NAME"%TYPE
                    , p_filename   IN "META_CODE_VERSIONING"."FILENAME"%TYPE
                    , p_script     IN "META_CODE_VERSIONING"."SCRIPT"%TYPE
                    , p_created_at IN "META_CODE_VERSIONING"."CREATED_AT"%TYPE)
    RETURN "META_CODE_VERSIONING"."ID"%TYPE
  IS
    v_return "META_CODE_VERSIONING"."ID"%TYPE;
  BEGIN
    INSERT INTO "META_CODE_VERSIONING"("ID"
                                     , "SCHEMA"
                                     , "OBJECT"
                                     , "NAME"
                                     , "FILENAME"
                                     , "SCRIPT"
                                     , "CREATED_AT")
         VALUES (COALESCE(p_id, "META_CODE_VERSIONING_SEQ".NEXTVAL)
               , p_schema
               , p_object
               , p_name
               , p_filename
               , p_script
               , p_created_at)
         RETURN "ID"
           INTO v_return;

    RETURN v_return;
  END create_row;

  PROCEDURE create_row(
    p_id         IN "META_CODE_VERSIONING"."ID"%TYPE DEFAULT NULL /*PK*/
  , p_schema     IN "META_CODE_VERSIONING"."SCHEMA"%TYPE
  , p_object     IN "META_CODE_VERSIONING"."OBJECT"%TYPE
  , p_name       IN "META_CODE_VERSIONING"."NAME"%TYPE
  , p_filename   IN "META_CODE_VERSIONING"."FILENAME"%TYPE
  , p_script     IN "META_CODE_VERSIONING"."SCRIPT"%TYPE
  , p_created_at IN "META_CODE_VERSIONING"."CREATED_AT"%TYPE)
  IS
    v_return "META_CODE_VERSIONING"."ID"%TYPE;
  BEGIN
    v_return :=
      create_row(p_id         => p_id
               , p_schema     => p_schema
               , p_object     => p_object
               , p_name       => p_name
               , p_filename   => p_filename
               , p_script     => p_script
               , p_created_at => p_created_at);
  END create_row;

  FUNCTION create_row(p_row IN "META_CODE_VERSIONING"%ROWTYPE)
    RETURN "META_CODE_VERSIONING"."ID"%TYPE
  IS
    v_return "META_CODE_VERSIONING"."ID"%TYPE;
  BEGIN
    v_return :=
      create_row(p_id         => p_row."ID"
               , p_schema     => p_row."SCHEMA"
               , p_object     => p_row."OBJECT"
               , p_name       => p_row."NAME"
               , p_filename   => p_row."FILENAME"
               , p_script     => p_row."SCRIPT"
               , p_created_at => p_row."CREATED_AT");
    RETURN v_return;
  END create_row;

  PROCEDURE create_row(p_row IN "META_CODE_VERSIONING"%ROWTYPE)
  IS
    v_return "META_CODE_VERSIONING"."ID"%TYPE;
  BEGIN
    v_return :=
      create_row(p_id         => p_row."ID"
               , p_schema     => p_row."SCHEMA"
               , p_object     => p_row."OBJECT"
               , p_name       => p_row."NAME"
               , p_filename   => p_row."FILENAME"
               , p_script     => p_row."SCRIPT"
               , p_created_at => p_row."CREATED_AT");
  END create_row;

  FUNCTION read_row(p_id IN "META_CODE_VERSIONING"."ID"%TYPE /*PK*/
                                                            )
    RETURN "META_CODE_VERSIONING"%ROWTYPE
  IS
    v_row "META_CODE_VERSIONING"%ROWTYPE;

    CURSOR cur_row IS
      SELECT *
        FROM "META_CODE_VERSIONING"
       WHERE COALESCE("ID", -999999999999999.999999999999999) =
             COALESCE(p_id, -999999999999999.999999999999999);
  BEGIN
    OPEN cur_row;

    FETCH cur_row INTO v_row;

    CLOSE cur_row;

    RETURN v_row;
  END read_row;

  PROCEDURE read_row(
    p_id         IN            "META_CODE_VERSIONING"."ID"%TYPE /*PK*/
  , p_schema        OUT NOCOPY "META_CODE_VERSIONING"."SCHEMA"%TYPE
  , p_object        OUT NOCOPY "META_CODE_VERSIONING"."OBJECT"%TYPE
  , p_name          OUT NOCOPY "META_CODE_VERSIONING"."NAME"%TYPE
  , p_filename      OUT NOCOPY "META_CODE_VERSIONING"."FILENAME"%TYPE
  , p_script        OUT NOCOPY "META_CODE_VERSIONING"."SCRIPT"%TYPE
  , p_created_at    OUT NOCOPY "META_CODE_VERSIONING"."CREATED_AT"%TYPE)
  IS
    v_row "META_CODE_VERSIONING"%ROWTYPE;
  BEGIN
    IF row_exists(p_id => p_id)
    THEN
      v_row        := read_row(p_id => p_id);
      p_schema     := v_row."SCHEMA";
      p_object     := v_row."OBJECT";
      p_name       := v_row."NAME";
      p_filename   := v_row."FILENAME";
      p_script     := v_row."SCRIPT";
      p_created_at := v_row."CREATED_AT";
    END IF;
  END read_row;

  PROCEDURE update_row(
    p_id         IN "META_CODE_VERSIONING"."ID"%TYPE DEFAULT NULL /*PK*/
  , p_schema     IN "META_CODE_VERSIONING"."SCHEMA"%TYPE
  , p_object     IN "META_CODE_VERSIONING"."OBJECT"%TYPE
  , p_name       IN "META_CODE_VERSIONING"."NAME"%TYPE
  , p_filename   IN "META_CODE_VERSIONING"."FILENAME"%TYPE
  , p_script     IN "META_CODE_VERSIONING"."SCRIPT"%TYPE
  , p_created_at IN "META_CODE_VERSIONING"."CREATED_AT"%TYPE)
  IS
    v_row "META_CODE_VERSIONING"%ROWTYPE;
  BEGIN
    IF row_exists(p_id => p_id)
    THEN
      v_row := read_row(p_id => p_id);

      -- update only,if the column values really differ
      IF COALESCE(v_row."SCHEMA", '@@@@@@@@@@@@@@@') <>
         COALESCE(p_schema, '@@@@@@@@@@@@@@@')
      OR COALESCE(v_row."OBJECT", '@@@@@@@@@@@@@@@') <>
         COALESCE(p_object, '@@@@@@@@@@@@@@@')
      OR COALESCE(v_row."NAME", '@@@@@@@@@@@@@@@') <>
         COALESCE(p_name, '@@@@@@@@@@@@@@@')
      OR COALESCE(v_row."FILENAME", '@@@@@@@@@@@@@@@') <>
         COALESCE(p_filename, '@@@@@@@@@@@@@@@')
      OR DBMS_LOB.compare(COALESCE(v_row."SCRIPT", TO_CLOB('@@@@@@@@@@@@@@@'))
                        , COALESCE(p_script, TO_CLOB('@@@@@@@@@@@@@@@'))) <>
         0
      OR COALESCE(v_row."CREATED_AT", TO_DATE('01.01.1900', 'DD.MM.YYYY')) <>
         COALESCE(p_created_at, TO_DATE('01.01.1900', 'DD.MM.YYYY'))
      THEN
        UPDATE meta_code_versioning
           SET "SCHEMA"     = p_schema
             , "OBJECT"     = p_object
             , "NAME"       = p_name
             , "FILENAME"   = p_filename
             , "SCRIPT"     = p_script
             , "CREATED_AT" = p_created_at
         WHERE COALESCE("ID", -999999999999999.999999999999999) =
               COALESCE(p_id, -999999999999999.999999999999999);
      END IF;
    END IF;
  END update_row;

  PROCEDURE update_row(p_row IN "META_CODE_VERSIONING"%ROWTYPE)
  IS
  BEGIN
    update_row(p_id         => p_row."ID"
             , p_schema     => p_row."SCHEMA"
             , p_object     => p_row."OBJECT"
             , p_name       => p_row."NAME"
             , p_filename   => p_row."FILENAME"
             , p_script     => p_row."SCRIPT"
             , p_created_at => p_row."CREATED_AT");
  END update_row;

  FUNCTION create_or_update_row(
    p_id         IN "META_CODE_VERSIONING"."ID"%TYPE DEFAULT NULL /*PK*/
  , p_schema     IN "META_CODE_VERSIONING"."SCHEMA"%TYPE
  , p_object     IN "META_CODE_VERSIONING"."OBJECT"%TYPE
  , p_name       IN "META_CODE_VERSIONING"."NAME"%TYPE
  , p_filename   IN "META_CODE_VERSIONING"."FILENAME"%TYPE
  , p_script     IN "META_CODE_VERSIONING"."SCRIPT"%TYPE
  , p_created_at IN "META_CODE_VERSIONING"."CREATED_AT"%TYPE)
    RETURN "META_CODE_VERSIONING"."ID"%TYPE
  IS
    v_return "META_CODE_VERSIONING"."ID"%TYPE;
  BEGIN
    IF row_exists(p_id => p_id)
    THEN
      update_row(p_id         => p_id
               , p_schema     => p_schema
               , p_object     => p_object
               , p_name       => p_name
               , p_filename   => p_filename
               , p_script     => p_script
               , p_created_at => p_created_at);
      v_return := read_row(p_id => p_id)."ID";
    ELSE
      v_return :=
        create_row(p_id         => p_id
                 , p_schema     => p_schema
                 , p_object     => p_object
                 , p_name       => p_name
                 , p_filename   => p_filename
                 , p_script     => p_script
                 , p_created_at => p_created_at);
    END IF;

    RETURN v_return;
  END create_or_update_row;

  PROCEDURE create_or_update_row(
    p_id         IN "META_CODE_VERSIONING"."ID"%TYPE DEFAULT NULL /*PK*/
  , p_schema     IN "META_CODE_VERSIONING"."SCHEMA"%TYPE
  , p_object     IN "META_CODE_VERSIONING"."OBJECT"%TYPE
  , p_name       IN "META_CODE_VERSIONING"."NAME"%TYPE
  , p_filename   IN "META_CODE_VERSIONING"."FILENAME"%TYPE
  , p_script     IN "META_CODE_VERSIONING"."SCRIPT"%TYPE
  , p_created_at IN "META_CODE_VERSIONING"."CREATED_AT"%TYPE)
  IS
    v_return "META_CODE_VERSIONING"."ID"%TYPE;
  BEGIN
    v_return :=
      create_or_update_row(p_id         => p_id
                         , p_schema     => p_schema
                         , p_object     => p_object
                         , p_name       => p_name
                         , p_filename   => p_filename
                         , p_script     => p_script
                         , p_created_at => p_created_at);
  END create_or_update_row;

  FUNCTION create_or_update_row(p_row IN "META_CODE_VERSIONING"%ROWTYPE)
    RETURN "META_CODE_VERSIONING"."ID"%TYPE
  IS
    v_return "META_CODE_VERSIONING"."ID"%TYPE;
  BEGIN
    v_return :=
      create_or_update_row(p_id         => p_row."ID"
                         , p_schema     => p_row."SCHEMA"
                         , p_object     => p_row."OBJECT"
                         , p_name       => p_row."NAME"
                         , p_filename   => p_row."FILENAME"
                         , p_script     => p_row."SCRIPT"
                         , p_created_at => p_row."CREATED_AT");
    RETURN v_return;
  END create_or_update_row;

  PROCEDURE create_or_update_row(p_row IN "META_CODE_VERSIONING"%ROWTYPE)
  IS
    v_return "META_CODE_VERSIONING"."ID"%TYPE;
  BEGIN
    v_return :=
      create_or_update_row(p_id         => p_row."ID"
                         , p_schema     => p_row."SCHEMA"
                         , p_object     => p_row."OBJECT"
                         , p_name       => p_row."NAME"
                         , p_filename   => p_row."FILENAME"
                         , p_script     => p_row."SCRIPT"
                         , p_created_at => p_row."CREATED_AT");
  END create_or_update_row;

  FUNCTION get_schema(p_id IN "META_CODE_VERSIONING"."ID"%TYPE /*PK*/
                                                              )
    RETURN "META_CODE_VERSIONING"."SCHEMA"%TYPE
  IS
    v_row "META_CODE_VERSIONING"%ROWTYPE;
  BEGIN
    v_row := read_row(p_id => p_id);
    RETURN v_row."SCHEMA";
  END get_schema;

  FUNCTION get_object(p_id IN "META_CODE_VERSIONING"."ID"%TYPE /*PK*/
                                                              )
    RETURN "META_CODE_VERSIONING"."OBJECT"%TYPE
  IS
    v_row "META_CODE_VERSIONING"%ROWTYPE;
  BEGIN
    v_row := read_row(p_id => p_id);
    RETURN v_row."OBJECT";
  END get_object;

  FUNCTION get_name(p_id IN "META_CODE_VERSIONING"."ID"%TYPE /*PK*/
                                                            )
    RETURN "META_CODE_VERSIONING"."NAME"%TYPE
  IS
    v_row "META_CODE_VERSIONING"%ROWTYPE;
  BEGIN
    v_row := read_row(p_id => p_id);
    RETURN v_row."NAME";
  END get_name;

  FUNCTION get_filename(p_id IN "META_CODE_VERSIONING"."ID"%TYPE /*PK*/
                                                                )
    RETURN "META_CODE_VERSIONING"."FILENAME"%TYPE
  IS
    v_row "META_CODE_VERSIONING"%ROWTYPE;
  BEGIN
    v_row := read_row(p_id => p_id);
    RETURN v_row."FILENAME";
  END get_filename;

  FUNCTION get_script(p_id IN "META_CODE_VERSIONING"."ID"%TYPE /*PK*/
                                                              )
    RETURN "META_CODE_VERSIONING"."SCRIPT"%TYPE
  IS
    v_row "META_CODE_VERSIONING"%ROWTYPE;
  BEGIN
    v_row := read_row(p_id => p_id);
    RETURN v_row."SCRIPT";
  END get_script;

  FUNCTION get_created_at(p_id IN "META_CODE_VERSIONING"."ID"%TYPE /*PK*/
                                                                  )
    RETURN "META_CODE_VERSIONING"."CREATED_AT"%TYPE
  IS
    v_row "META_CODE_VERSIONING"%ROWTYPE;
  BEGIN
    v_row := read_row(p_id => p_id);
    RETURN v_row."CREATED_AT";
  END get_created_at;

  PROCEDURE set_schema(p_id     IN "META_CODE_VERSIONING"."ID"%TYPE /*PK*/
                     , p_schema IN "META_CODE_VERSIONING"."SCHEMA"%TYPE)
  IS
    v_row "META_CODE_VERSIONING"%ROWTYPE;
  BEGIN
    IF row_exists(p_id => p_id)
    THEN
      v_row := read_row(p_id => p_id);

      -- update only,if the column value really differs
      IF COALESCE(v_row."SCHEMA", '@@@@@@@@@@@@@@@') <>
         COALESCE(p_schema, '@@@@@@@@@@@@@@@')
      THEN
        UPDATE meta_code_versioning
           SET "SCHEMA" = p_schema
         WHERE COALESCE("ID", -999999999999999.999999999999999) =
               COALESCE(p_id, -999999999999999.999999999999999);
      END IF;
    END IF;
  END set_schema;

  PROCEDURE set_object(p_id     IN "META_CODE_VERSIONING"."ID"%TYPE /*PK*/
                     , p_object IN "META_CODE_VERSIONING"."OBJECT"%TYPE)
  IS
    v_row "META_CODE_VERSIONING"%ROWTYPE;
  BEGIN
    IF row_exists(p_id => p_id)
    THEN
      v_row := read_row(p_id => p_id);

      -- update only,if the column value really differs
      IF COALESCE(v_row."OBJECT", '@@@@@@@@@@@@@@@') <>
         COALESCE(p_object, '@@@@@@@@@@@@@@@')
      THEN
        UPDATE meta_code_versioning
           SET "OBJECT" = p_object
         WHERE COALESCE("ID", -999999999999999.999999999999999) =
               COALESCE(p_id, -999999999999999.999999999999999);
      END IF;
    END IF;
  END set_object;

  PROCEDURE set_name(p_id   IN "META_CODE_VERSIONING"."ID"%TYPE /*PK*/
                   , p_name IN "META_CODE_VERSIONING"."NAME"%TYPE)
  IS
    v_row "META_CODE_VERSIONING"%ROWTYPE;
  BEGIN
    IF row_exists(p_id => p_id)
    THEN
      v_row := read_row(p_id => p_id);

      -- update only,if the column value really differs
      IF COALESCE(v_row."NAME", '@@@@@@@@@@@@@@@') <>
         COALESCE(p_name, '@@@@@@@@@@@@@@@')
      THEN
        UPDATE meta_code_versioning
           SET "NAME" = p_name
         WHERE COALESCE("ID", -999999999999999.999999999999999) =
               COALESCE(p_id, -999999999999999.999999999999999);
      END IF;
    END IF;
  END set_name;

  PROCEDURE set_filename(p_id       IN "META_CODE_VERSIONING"."ID"%TYPE /*PK*/
                       , p_filename IN "META_CODE_VERSIONING"."FILENAME"%TYPE)
  IS
    v_row "META_CODE_VERSIONING"%ROWTYPE;
  BEGIN
    IF row_exists(p_id => p_id)
    THEN
      v_row := read_row(p_id => p_id);

      -- update only,if the column value really differs
      IF COALESCE(v_row."FILENAME", '@@@@@@@@@@@@@@@') <>
         COALESCE(p_filename, '@@@@@@@@@@@@@@@')
      THEN
        UPDATE meta_code_versioning
           SET "FILENAME" = p_filename
         WHERE COALESCE("ID", -999999999999999.999999999999999) =
               COALESCE(p_id, -999999999999999.999999999999999);
      END IF;
    END IF;
  END set_filename;

  PROCEDURE set_script(p_id     IN "META_CODE_VERSIONING"."ID"%TYPE /*PK*/
                     , p_script IN "META_CODE_VERSIONING"."SCRIPT"%TYPE)
  IS
    v_row "META_CODE_VERSIONING"%ROWTYPE;
  BEGIN
    IF row_exists(p_id => p_id)
    THEN
      v_row := read_row(p_id => p_id);

      -- update only,if the column value really differs
      IF DBMS_LOB.compare(COALESCE(v_row."SCRIPT", TO_CLOB('@@@@@@@@@@@@@@@'))
                        , COALESCE(p_script, TO_CLOB('@@@@@@@@@@@@@@@'))) <>
         0
      THEN
        UPDATE meta_code_versioning
           SET "SCRIPT" = p_script
         WHERE COALESCE("ID", -999999999999999.999999999999999) =
               COALESCE(p_id, -999999999999999.999999999999999);
      END IF;
    END IF;
  END set_script;

  PROCEDURE set_created_at(
    p_id         IN "META_CODE_VERSIONING"."ID"%TYPE /*PK*/
  , p_created_at IN "META_CODE_VERSIONING"."CREATED_AT"%TYPE)
  IS
    v_row "META_CODE_VERSIONING"%ROWTYPE;
  BEGIN
    IF row_exists(p_id => p_id)
    THEN
      v_row := read_row(p_id => p_id);

      -- update only,if the column value really differs
      IF COALESCE(v_row."CREATED_AT", TO_DATE('01.01.1900', 'DD.MM.YYYY')) <>
         COALESCE(p_created_at, TO_DATE('01.01.1900', 'DD.MM.YYYY'))
      THEN
        UPDATE meta_code_versioning
           SET "CREATED_AT" = p_created_at
         WHERE COALESCE("ID", -999999999999999.999999999999999) =
               COALESCE(p_id, -999999999999999.999999999999999);
      END IF;
    END IF;
  END set_created_at;
END "META_CODE_VERSIONING_API";
/