CREATE OR REPLACE DIRECTORY index_dax30 AS 'C:\GIT\STOCKAN\YAHOO_data\INDEX_DAX30';

GRANT EXECUTE, READ, WRITE ON DIRECTORY index_dax30 TO stockan WITH GRANT OPTION;