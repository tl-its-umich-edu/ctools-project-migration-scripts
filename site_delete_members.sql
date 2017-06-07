set serveroutput on;

declare
    i   NUMBER := 0;
    
PROCEDURE looping_example as
  BEGIN
  FOR rec IN (SELECT * FROM SITE_DELETE_IDS)
     LOOP
        i := i + 1;
        DBMS_OUTPUT.put_line ('DELETE MEMBERS FROM SITE ' || i || '  WITH ID=' || rec.site_id);
        
        insert into CPM_ACTION_LOG (ACTION_TIME, SITE_ID, ACTION_TAKEN) VALUES (CURRENT_TIMESTAMP,rec.site_id,'DELETE_MEMBERS');

        insert into ARCHIVE_SAKAI_SITE_USER_ROLE
        select t1.site_id, t5.EID, t4.ROLE_NAME
        from Sakai_site t1, sakai_realm t2,
        SAKAI_REALM_RL_GR t3,
        sakai_realm_role t4,
        sakai_user_id_map t5
        where t2.REALM_ID = concat('/site/', t1.site_id)
        and t2.REALM_KEY = t3.realm_key
        and t3.USER_ID = t5.USER_ID
        and t1.site_id = rec.site_id
        and t3.role_key = t4.ROLE_KEY;
        
        insert into ARCHIVE_SAKAI_SITE_USER (select * from SAKAI_SITE_USER where site_id = rec.site_id);
        
        delete from SAKAI_SITE_USER where site_id = rec.site_id;
        
        insert into ARCHIVE_SAKAI_REALM_RL_GR (select * from SAKAI_REALM_RL_GR where realm_key in (select realm_key from sakai_realm where realm_id like concat(concat('/site/', rec.site_id), '%')));
        
        delete from SAKAI_REALM_RL_GR where realm_key in (select realm_key from sakai_realm where realm_id like concat(concat('/site/', rec.site_id), '%'));
        
        update SAKAI_SITE set published=0 where site_id = rec.site_id; 

	commit;

    END LOOP;
        
      DBMS_OUTPUT.put_line ('CPM site membership delete is done');
  END;
  
  BEGIN
  DBMS_OUTPUT.PUT_LINE ('BEGINNING DELETING SITE MEMBERS:');
  looping_example;
  DBMS_OUTPUT.PUT_LINE ('THE END OF DELETING SITE MEMBERS: ');
 END;
/
