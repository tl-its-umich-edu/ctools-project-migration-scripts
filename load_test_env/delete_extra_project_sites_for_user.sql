DECLARE
    current_user_id varchar(255);
    project_site_num number := 13
    
    -- cursor for getting current user id
    cursor user_id_cur
    is 
    select user_id 
    from load_test_user;
BEGIN
  open user_id_cur;
  loop
    fetch user_id_cur into current_user_id;
    EXIT WHEN user_id_cur%NOTFOUND;
    
    delete
    from sakai_realm_rl_gr
    where user_id = current_user_id
    and realm_key  not in 
    (
    select g.realm_key
    from sakai_realm_rl_gr g, sakai_realm r, sakai_site s
    where 
    g.realm_key = r.realm_key
    and r.realm_id= concat('/site/', s.site_id)
    and s.type='project'
    and g.user_id = current_user_id
    and rownum < project_site_num
    );
    commit;
  END LOOP;
END;
