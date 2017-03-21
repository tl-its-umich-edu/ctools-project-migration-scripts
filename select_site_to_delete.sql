-- this is a query to find out  sites that are flagged to be deleted
-- the result row contains 
-- 1. ctools site id, 
-- 2. unique name of user who marked the change, 
-- 3. and when he/she marked the site to be deleted

SELECT SITE_ID, USER_ID, CONSENT_TIME FROM SITE_DELETE_CHOICE;