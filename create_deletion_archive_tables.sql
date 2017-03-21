drop table ARCHIVE_SAKAI_SITE_USER;
drop table ARCHIVE_SAKAI_REALM_RL_GR;
drop table ARCHIVE_SAKAI_SITE_USER_ROLE;

create table ARCHIVE_SAKAI_SITE_USER (
    SITE_ID              VARCHAR2(99) NOT NULL,
    USER_ID              VARCHAR2(99) NOT NULL,
    PERMISSION           INTEGER NOT NULL );

create table ARCHIVE_SAKAI_REALM_RL_GR (
    REALM_KEY            INTEGER NOT NULL,
    USER_ID              VARCHAR2(99) NOT NULL,
    ROLE_KEY             INTEGER NOT NULL,
    ACTIVE               CHAR(1) NULL CHECK (ACTIVE IN (1, 0)),
    PROVIDED             CHAR(1) NULL CHECK (PROVIDED IN (1, 0)) );

-- store site id, user id and user role name in human readable way
create table ARCHIVE_SAKAI_SITE_USER_ROLE (
    SITE_ID              VARCHAR2(99) NOT NULL,
    USER_ID              VARCHAR2(99) NOT NULL,
    ROLE_NAME            VARCHAR2(99) NOT NULL );

