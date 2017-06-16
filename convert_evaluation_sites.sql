-- update the site type from 'project' to 'evaluation'
-- for all sites with just Teaching Evaluation tool
update sakai_site
set type='evaluation'
where type='project'
and site_id in
(
select site_id
from SAKAI_SITE_TOOL
where registration = 'sakai.rsf.evaluation'
and site_id in 
(
select site_id 
from 
(select site_id, count(*) as tcount
from SAKAI_SITE_TOOL
group by site_id) site_tool_count
where site_tool_count.tcount =1
)
);

-- commit
commit;


