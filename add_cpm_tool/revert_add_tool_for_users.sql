
-- revert the site property changes
delete 
from sakai_site_tool_property
where name='source'
and value like 'https://cpm.it.umich.edu/%'
and site_id in
(
select concat('~', t.user_id)
from sakai_user_id_map t, QSZHU.CPM_USER u
where (t.eid = u.eid or t.user_id=u.eid)
);
commit;

-- revert the site tool changes
delete
from sakai_site_tool
where registration='sakai.iframe'
and title = 'Project Site Migration'
and site_id in
(
select concat('~', t.user_id)
from sakai_user_id_map t, QSZHU.CPM_USER u
where (t.eid = u.eid or t.user_id=u.eid)
);
commit;

-- revert the site page changes
delete
from sakai_site_page
where title = 'Project Site Migration'
and site_id in
(
select concat('~', t.user_id)
from sakai_user_id_map t, QSZHU.CPM_USER u
where (t.eid = u.eid or t.user_id=u.eid)
);
commit;
