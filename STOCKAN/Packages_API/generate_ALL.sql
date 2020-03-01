BEGIN
  FOR i IN (SELECT *
              FROM user_tables
             WHERE external = 'NO')
  LOOP
    tools.om_tapigen.compile_api(p_table_name                  => i.table_name
                               , p_owner                       => USER
                               , p_reuse_existing_api_params   => FALSE
                               , p_enable_insertion_of_rows    => TRUE
                               , p_enable_column_defaults      => FALSE
                               , p_enable_update_of_rows       => TRUE
                               , p_enable_deletion_of_rows     => TRUE
                               , p_enable_parameter_prefixes   => TRUE
                               , p_enable_proc_with_out_params => TRUE
                               , p_enable_getter_and_setter    => TRUE
                               , p_col_prefix_in_method_names  => TRUE
                               , p_return_row_instead_of_pk    => FALSE
                               , p_enable_dml_view             => FALSE
                               , p_enable_generic_change_log   => FALSE
                               , p_api_name                    => i.table_name || '_API'
                               , p_sequence_name               => NULL
                               , p_exclude_column_list         => NULL
                               , p_enable_custom_defaults      => FALSE
                               , p_custom_default_values       => NULL);
  END LOOP;
END;
/