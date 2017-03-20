-- this is to update all existing CPM tool into the 2nd tool position
-- move CPM tool to the second tool in list
update sakai_site_page
set site_order = 2
where title = 'Project Site Migration';
commit;

-- if there is already a tool in the 2nd row of tool list
-- move it to the third row 
update sakai_site_page
set site_order = 3
select * from sakai_site_page
where page_id in
(
select PAGE_ID
from sakai_site_page
where site_order=2
and title != 'Project Site Migration')
and site_id in 
(
select site_ID
from sakai_site_page
where title = 'Project Site Migration'
);
commit;