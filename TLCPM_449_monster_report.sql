-- the result of the query returns the following information for project sites:
-- site id and title
-- site alias
-- site member count
-- tool list, TRUE if the tool is in site

select t1.title, t1.site_id, 
t1.type, 
FINDSITEMAILALIAS(t1.site_id) as Site_Alias, 
FindSiteMemberCount(t1.site_id) as member_count,
FINDTOTALRESOURCESIZE(t1.site_id) as resource_size,
FINDTOTALEMAILMESSAGEINSITE(t1.site_id) as emailmessage_count,
FindProjectTool(t1.site_id, 'sakai.resources') as Resources, 
FindProjectTool(t1.site_id, 'sakai.announcements') as Announcements, 
FindProjectTool(t1.site_id, 'sakai.messages') as Messages, 
FindProjectTool(t1.site_id, 'sakai.iframe') as WebContent, 
FindProjectTool(t1.site_id, 'sakai.dropbox') as DropBox, 
FindProjectTool(t1.site_id, 'sakai.mail') as Mail, 
FindProjectTool(t1.site_id, 'sakai.dashboard') as Dashboard, 
FindProjectTool(t1.site_id, 'sakai.schedule') as Schedule, 
FindProjectTool(t1.site_id, 'sakai.syllabus') as Syllabus, 
FindProjectTool(t1.site_id, 'sakai.assignment') as Assignments, 
FindProjectTool(t1.site_id, 'sakai.news') as News, 
FindProjectTool(t1.site_id, 'sakai.basiclti') as LTITool, 
FindProjectTool(t1.site_id, 'sakai.lessonbuildertool') as LessonBuilder, 
FindProjectTool(t1.site_id, 'sakai.mneme') as TestCenter, 
FindProjectTool(t1.site_id, 'sakai.rwiki') as Wiki, 
FindProjectTool(t1.site_id, 'sakai.gradebook') as Gradebook, 
FindProjectTool(t1.site_id, 'sakai.forums') as Forums, 
FindProjectTool(t1.site_id, 'sakai.chat') as Chat, 
FindProjectTool(t1.site_id, 'sakai.poll') as Poll, 
FindProjectTool(t1.site_id, 'sakai.iTunesU') as iTunesU, 
FindProjectTool(t1.site_id, 'sakai.melete') as Modules, 
FindProjectTool(t1.site_id, 'sakai.podcasts') as PodCast, 
FindProjectTool(t1.site_id, 'ctools.dissertation') as GradTool, 
FindProjectTool(t1.site_id, 'sakai.signup') as SignUp, 
FindProjectTool(t1.site_id, 'osp') as Portfolio, 
FindProjectTool(t1.site_id, 'sakai.rsf.evaluation') as Evaluation 
from sakai_site t1 
where (t1.type='project' or t1.type='specialized_projects') 
order by t1.title asc;