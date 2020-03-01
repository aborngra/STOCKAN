CREATE OR REPLACE EDITIONABLE PACKAGE BODY "UTILS_BL"
AS
  FUNCTION clob_to_blob(p_clob CLOB)
    RETURN BLOB
  IS
    v_blob         BLOB;
    v_dest_offsset INTEGER := 1;
    v_src_offsset  INTEGER := 1;
    v_lang_context INTEGER := DBMS_LOB.default_lang_ctx;
    v_warning      INTEGER;
  BEGIN
    IF p_clob IS NOT NULL
    THEN
      DBMS_LOB.createtemporary(lob_loc => v_blob, cache => FALSE);

      DBMS_LOB.converttoblob(dest_lob     => v_blob
                           , src_clob     => p_clob
                           , amount       => DBMS_LOB.lobmaxsize
                           , dest_offset  => v_dest_offsset
                           , src_offset   => v_src_offsset
                           , blob_csid    => DBMS_LOB.default_csid
                           , lang_context => v_lang_context
                           , warning      => v_warning);
    END IF;

    RETURN v_blob;
  END clob_to_blob;

  PROCEDURE replace_clob(p_clob IN OUT NOCOPY CLOB, p_what IN VARCHAR2, p_with IN VARCHAR2)
  IS
    c_whatlen CONSTANT PLS_INTEGER := LENGTH(p_what);
    c_withlen CONSTANT PLS_INTEGER := NVL(LENGTH(p_with), 0);

    l_return           CLOB;
    l_segment          CLOB;
    l_pos              PLS_INTEGER := 1 - c_withlen;
    l_offset           PLS_INTEGER := 1;
  BEGIN
    IF p_what IS NOT NULL
    THEN
      WHILE l_offset < DBMS_LOB.getlength(p_clob)
      LOOP
        l_segment := DBMS_LOB.SUBSTR(p_clob, 32767, l_offset);

        LOOP
          l_pos := DBMS_LOB.INSTR(l_segment, p_what, l_pos + GREATEST(c_withlen, 1));
          EXIT WHEN (NVL(l_pos, 0) = 0)
                 OR (l_pos = 32767 - c_withlen);
          l_segment :=
            TO_CLOB(
                 DBMS_LOB.SUBSTR(l_segment, l_pos - 1)
              || p_with
              || DBMS_LOB.SUBSTR(l_segment, 32767 - c_whatlen - l_pos - c_whatlen + 1, l_pos + c_whatlen));
        END LOOP;

        l_return  := l_return || l_segment;
        l_offset  := l_offset + 32767 - c_whatlen;
      END LOOP;
    END IF;

    p_clob := l_return;
  END replace_clob;

  PROCEDURE replace_clob(p_clob IN OUT NOCOPY CLOB, p_what IN VARCHAR2, p_with IN CLOB)
  IS
    l_pos PLS_INTEGER;
  BEGIN
    l_pos := INSTR(p_clob, p_what);

    IF l_pos > 0
    THEN
      p_clob := SUBSTR(p_clob, 1, l_pos - 1) || p_with || SUBSTR(p_clob, l_pos + LENGTH(p_what));
    END IF;
  END replace_clob;

  FUNCTION replace_clob(p_clob IN CLOB, p_what IN VARCHAR2, p_with IN CLOB)
    RETURN CLOB
  IS
    n        NUMBER;
    l_result CLOB := p_clob;
  BEGIN
    n := DBMS_LOB.INSTR(p_clob, p_what);

    IF (NVL(n, 0) > 0)
    THEN
      DBMS_LOB.createtemporary(l_result, FALSE, DBMS_LOB.call);
      DBMS_LOB.COPY(l_result
                  , p_clob
                  , n - 1
                  , 1
                  , 1);
      DBMS_LOB.COPY(l_result
                  , p_with
                  , DBMS_LOB.getlength(p_with)
                  , DBMS_LOB.getlength(l_result) + 1
                  , 1);
      DBMS_LOB.COPY(l_result
                  , p_clob
                  , DBMS_LOB.getlength(p_clob) - (n + LENGTH(p_what)) + 1
                  , DBMS_LOB.getlength(l_result) + 1
                  , n + LENGTH(p_what));
    END IF;

    IF NVL(DBMS_LOB.INSTR(l_result, p_what), 0) > 0
    THEN
      RETURN replace_clob(l_result, p_what, p_with);
    END IF;

    RETURN l_result;
  END replace_clob;

  FUNCTION split_to_table(p_clob IN CLOB, p_delimiter IN VARCHAR2 DEFAULT ',')
    RETURN gt_varchar2_tab
    PIPELINED
  IS
    v_offset                 PLS_INTEGER := 1;
    v_index                  PLS_INTEGER := INSTR(p_clob, p_delimiter, v_offset);
    v_delimiter_length       PLS_INTEGER := LENGTH(p_delimiter);
    v_string_length CONSTANT PLS_INTEGER := DBMS_LOB.getlength(p_clob);
  BEGIN
    WHILE v_index > 0
    LOOP
      PIPE ROW (TRIM(DBMS_LOB.SUBSTR(p_clob, v_index - v_offset, v_offset)));
      v_offset := v_index + v_delimiter_length;
      v_index  := INSTR(p_clob, p_delimiter, v_offset);
    END LOOP;

    IF v_string_length - v_offset + 1 > 0
    THEN
      PIPE ROW (TRIM(DBMS_LOB.SUBSTR(p_clob, v_string_length - v_offset + 1, v_offset)));
    END IF;

    RETURN;
  END split_to_table;

  FUNCTION join_to_varchar(p_cursor IN gt_ref_cursor, p_delimiter IN VARCHAR2 DEFAULT ',')
    RETURN VARCHAR2
  IS
    v_return VARCHAR2(32767);
    v_value  VARCHAR2(32767);
  BEGIN
    LOOP
      FETCH p_cursor INTO v_value;

      EXIT WHEN p_cursor%NOTFOUND;

      v_return := v_return || CASE WHEN v_return IS NULL THEN NULL ELSE p_delimiter END || v_value;
    END LOOP;

    RETURN v_return;
  END join_to_varchar;

  FUNCTION get_last_mview_refresh(p_mview_name IN user_mviews.mview_name%TYPE)
    RETURN user_mviews.last_refresh_date%TYPE
  IS
    v_return user_mviews.last_refresh_date%TYPE;
  BEGIN
    SELECT last_refresh_date
      INTO v_return
      FROM user_mviews
     WHERE mview_name = p_mview_name;

    RETURN v_return;
  END get_last_mview_refresh;

  PROCEDURE refresh_mview(p_mview_name IN user_mviews.mview_name%TYPE)
  IS
  BEGIN
    DBMS_MVIEW.refresh(list => p_mview_name, method => 'C');
  END refresh_mview;
END "UTILS_BL";
/