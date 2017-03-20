-- This query is to find out each site migration status within given bulk upload.
-- The only parameter is the bulk migration name, with wild card towards start and end of the name String
-- To execute, just replace BULK_MIGRATION_NAME with the real bulk migration name, or its partial string

select site_id, bulk_migration_name, status 
from migration 
where BULK_MIGRATION_NAME like '%BULK_MIGRATION_NAME%'
order by BULK_MIGRATION_NAME;