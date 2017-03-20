-- check whether there is any user with CPM tool added by now
select *
from sakai_site_tool t, 
(select m.eid, m.user_id
from sakai_user_id_map m, QSZHU.CPM_USER u
where m.eid = u.eid) u
where (site_id = concat('~',u.eid) 
or site_id = concat('~',u.user_id))
and registration='sakai.iframe'
and title like  '%Project Site Migration%'


-- insert the CPM tool page as the second tool in the MyWorkspace site
insert into sakai_site_page
(page_id, site_id, title, layout, site_order, popup)
select sys_guid(), site_id, 'Project Site Migration', 0, 2, 0
from sakai_site
where type='myworkspace'
and site_id in 
(
select s.site_id
from sakai_site s,
(select m.user_id as user_id, m.eid as eid
from sakai_user_id_map m, CPM_USER c
where m.EID = c.EID) cUser
where (s.SITE_ID = concat('~', cUser.user_id) 
or s.SITE_ID = concat('~', cUser.eid))
)
-- make sure not to insert the page multiple times
and site_id not in
(
select site_id
from sakai_site_page
where title = 'Project Site Migration');
commit;

-- insert the CPM tool to the page
insert into sakai_site_tool
(tool_id, page_id, site_id, registration, page_order, title, layout_hints)
select sys_guid(), page_id, site_id, 'sakai.iframe', 0, 'Project Site Migration', 0
from sakai_site_page
where title = 'Project Site Migration'
and page_id not in
(select page_id
from sakai_site_tool
where title = 'Project Site Migration');
commit;

-- specify the source attribute to point to CPM server
insert into
sakai_site_tool_property
(site_id, tool_id, name, value)
select site_id, tool_id, 'source', 'https://cpm.it.umich.edu/'
from sakai_site_tool
where title = 'Project Site Migration' and registration = 'sakai.iframe'
and site_id not in
(
select distinct(site_id)
from sakai_site_tool_property
where name='source'
and value like 'https://cpm.it.umich.edu/%'
);

commit; 
