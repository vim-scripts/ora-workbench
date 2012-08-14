-- dump one object from the USER_SOURCE view
--
-- parameter:
-- 1 = package name
-- 2 = object type
--
SET VERIFY OFF
SET FEEDBACK 0
set serveroutput on size 1000000
set pagesize 0
set linesize 32000
SELECT 'CREATE OR REPLACE' from DUAL;
select text from user_source where name = Upper ('&1')
and type = Upper('&2') order by LINE;
select '/' from dual;
exit
