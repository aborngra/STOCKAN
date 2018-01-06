DECLARE
   v_acl_filename   VARCHAR2 (64 CHAR) := 'ACL_STOCK_ANALYZER.xml';
   v_acl_descr      VARCHAR2 (64 CHAR)
                       := 'Allow STOCK_ANALYZER to connect to yahoo finance';
   v_acl_schema     VARCHAR2 (30 CHAR) := 'STOCK_ANALYZER';
   v_acl_host       VARCHAR2 (64 CHAR) := '*.yahoo.com';
BEGIN
   BEGIN
      DBMS_NETWORK_ACL_ADMIN.drop_acl (acl => v_acl_filename);
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;                                     
   END;

   DBMS_NETWORK_ACL_ADMIN.create_acl (acl           => v_acl_filename,
                                      description   => v_acl_descr,
                                      principal     => v_acl_schema,
                                      is_grant      => TRUE,
                                      privilege     => 'connect');

   DBMS_NETWORK_ACL_ADMIN.ADD_PRIVILEGE (acl         => v_acl_filename,
                                         principal   => v_acl_schema, 
                                         is_grant    => TRUE,
                                         privilege   => 'resolve');

   DBMS_NETWORK_ACL_ADMIN.assign_acl (acl          => v_acl_filename,
                                      HOST         => v_acl_host,
                                      lower_port   => 80,
                                      upper_port   => 80);
END;
/

SHOW ERROR

COMMIT
/