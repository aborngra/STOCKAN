CREATE OR REPLACE EDITIONABLE PACKAGE "UTILS_BL"
IS
  TYPE gt_varchar2_tab IS TABLE OF VARCHAR2(4000 CHAR);

  TYPE gt_ref_cursor IS REF CURSOR;

  FUNCTION clob_to_blob(p_clob CLOB)
    RETURN BLOB;

  PROCEDURE replace_clob(p_clob IN OUT NOCOPY CLOB, p_what IN VARCHAR2, p_with IN VARCHAR2);

  PROCEDURE replace_clob(p_clob IN OUT NOCOPY CLOB, p_what IN VARCHAR2, p_with IN CLOB);

  FUNCTION replace_clob(p_clob IN CLOB, p_what IN VARCHAR2, p_with IN CLOB)
    RETURN CLOB;

  FUNCTION split_to_table(p_clob IN CLOB, p_delimiter IN VARCHAR2 DEFAULT ',')
    RETURN gt_varchar2_tab
    PIPELINED;

  FUNCTION join_to_varchar(p_cursor IN gt_ref_cursor, p_delimiter IN VARCHAR2 DEFAULT ',')
    RETURN VARCHAR2;

  FUNCTION get_last_mview_refresh(p_mview_name IN user_mviews.mview_name%TYPE)
    RETURN user_mviews.last_refresh_date%TYPE;

  PROCEDURE refresh_mview(p_mview_name IN user_mviews.mview_name%TYPE);
END "UTILS_BL";
/