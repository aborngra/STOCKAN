CREATE OR REPLACE EDITIONABLE PACKAGE "CODE_VERSIONING_BL"
  AUTHID CURRENT_USER
IS
  ------------------------------------------------------------------------------
  -- specification of public procedures / functions
  ------------------------------------------------------------------------------
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
                        , p_create_install_sql_yn    IN VARCHAR2 DEFAULT 'Y');

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
                                  , p_create_install_sql_yn    IN VARCHAR2 DEFAULT 'Y');

  PROCEDURE ep_create_sequences(p_user IN all_users.username%TYPE DEFAULT USER);

  PROCEDURE ep_create_tables(p_user IN all_users.username%TYPE DEFAULT USER);

  PROCEDURE ep_create_indexes(p_user IN all_users.username%TYPE DEFAULT USER);

  PROCEDURE ep_create_packages_api(p_user IN all_users.username%TYPE DEFAULT USER);

  PROCEDURE ep_create_packages_bl(p_user IN all_users.username%TYPE DEFAULT USER);

  PROCEDURE ep_create_synonyms(p_user IN all_users.username%TYPE DEFAULT USER);

  PROCEDURE ep_create_triggers(p_user IN all_users.username%TYPE DEFAULT USER);

  PROCEDURE ep_create_types(p_user IN all_users.username%TYPE DEFAULT USER);

  PROCEDURE ep_create_views(p_user IN all_users.username%TYPE DEFAULT USER);

  PROCEDURE ep_create_grants_from(p_user IN all_users.username%TYPE DEFAULT USER);

  PROCEDURE ep_create_grants_to(p_user IN all_users.username%TYPE DEFAULT USER);

  PROCEDURE ep_create_mviews(p_user IN all_users.username%TYPE DEFAULT USER);

  PROCEDURE ep_create_dblinks(p_user IN all_users.username%TYPE DEFAULT USER);

  PROCEDURE ep_create_procedures(p_user IN all_users.username%TYPE DEFAULT USER);

  PROCEDURE ep_create_functions(p_user IN all_users.username%TYPE DEFAULT USER);

  PROCEDURE ep_create_fk_constraints(p_user IN all_users.username%TYPE DEFAULT USER);

  PROCEDURE ep_create_install_batch(p_user IN all_users.username%TYPE DEFAULT USER);

  PROCEDURE ep_create_install_sql(p_user IN all_users.username%TYPE DEFAULT USER);

  FUNCTION ep_is_job_running_yn
    RETURN VARCHAR2;
END "CODE_VERSIONING_BL";
/