CREATE OR REPLACE PACKAGE partition_control_bl
  AUTHID CURRENT_USER
IS
  ------------------------------------------------------------------------------
  -- ep_list_partition_rename is just a technical helper procedure with the
  -- main target: rename the partition to p_partition_name_new (if not
  -- already done yet). It can be especially used for list partitioned tables.
  -- It requires an existing partition, that can be identified by the
  -- high_value partition key. So it's usefull for automatic partitioning
  -- and the partition renaming afterwards.
  ------------------------------------------------------------------------------
  PROCEDURE list_partition_rename(p_table_owner          IN all_tab_partitions.table_owner%TYPE DEFAULT USER
                                , p_table_name           IN all_tab_partitions.table_name%TYPE
                                , p_partition_name_new   IN all_tab_partitions.partition_name%TYPE
                                , p_partition_high_value IN VARCHAR2);

  ------------------------------------------------------------------------------
  -- ep_list_partition_stats is just a technical helper procedure with the
  -- main target: calculate the statistics for a defined table and a defined
  -- partition. It can be especially used for list partitioned tables. It
  -- requires an existing partition p_partition_name. So it's usefull for
  -- automatic partitioning and the renaming afterwards.
  ------------------------------------------------------------------------------
  PROCEDURE list_partition_stats(p_table_owner    IN all_tab_partitions.table_owner%TYPE DEFAULT USER
                               , p_table_name     IN all_tab_partitions.table_name%TYPE
                               , p_partition_name IN all_tab_partitions.partition_name%TYPE);
END partition_control_bl;
/