#!/usr/bin/env perl
# Generate sql for CTools read only tasks.
use YAML qw'LoadFile';
use POSIX qw(strftime);
use Data::Dumper;

use strict;

## Generate sql to remove / restore site permissions based on site types, lists of sites,
## roles, and permissions to delete.  Roles and permissions are configured in
## a yml file.  In production SQL will be run by a DBA.
## Tasks are given on the command line.  Available tasks are:
## READ_ONLY_LIST, READ_ONLY_UPDATE (list permissions to remove, remove them)
## READ_ONLY_RESTORE_LIST, READ_ONLY_RESTORE (list permissions to be restored, restore them)
## ACTION_LOG_UPDATE, ACTION_LOG_LIST, ACTION_LOG_COUNT - list or insert action log entries.
## This is based on generateROSqlSite.pl but will use sql to assemble the
## list of sites to change
# instead of expecting an explicit list of sites to be provided.  It will exclude sites based
# on an explicit list.

# Run this using the runBatchRO.sh shell script to deal with arguments and file naming.

# NOTE: oracle syntax to rename a table
# "rename SAKAI_REALM_RL_FN_20161215 to SAKAI_REALM_RL_FN_20161215_A"

################
## global configuration values read from the configuration yml file.  See below for
## purposes.
our $DB_USER;
our $comma_break_rate;
our $realms_max;
our @functions;
our @roles;
# list of sites to exclude.
our @excludedSites;
# list of sites to restore.
our @restoreSites;
# list of site types to examine
our @readonlySiteTypes;
# name of the archive table, which will change over time.
our $ARCHIVE_ROLE_FUNCTION_TABLE;
# name of action log which may change for testing.
our $ACTION_LOG_TABLE;
################

# Read the requested task from the command line.  Wrapper shell script will default it if necessary.
our $task = shift;

# get configuration file name from command line
our ($yml_file) = shift || "./ROSqlSite.yml";

# read in configuration file and set values
sub configure {
  my ($db,$functions,$sites) = LoadFile($yml_file);

  # for debugging if required.
#  print "db: \n";
#  print Dumper($db);
  
  # prefix for sql tables.
  $DB_USER=$db->{db_user};
 
  # for contents of IN clause how often put in a line break when generate list.
  $comma_break_rate=$db->{comma_break_rate};
  
  # functions (permissions) to delete.
  @functions = @{$db->{functions}};
  
  # roles to examine.
  @roles=@{$db->{roles}};

  # sites to exclude
  @excludedSites=@{$db->{excludedSites}};

    # sites to exclude
  @restoreSites=@{$db->{restoreSites}};
  
  # site types to include
  @readonlySiteTypes=@{$db->{siteTypes}};
  
  # archive table name
  $ARCHIVE_ROLE_FUNCTION_TABLE=$db->{ARCHIVE_ROLE_FUNCTION_TABLE};

  # action log name
  $ACTION_LOG_TABLE=$db->{ACTION_LOG_TABLE};
  unless($ACTION_LOG_TABLE) {
    $ACTION_LOG_TABLE="CPM_ACTION_LOG";
  };
  
  # setup the task to be done.
  setupTask($task);
}

########################
## Variables to hold information that is used when generating SQL.
# Name the action the sql should perform. Can select, delete, insert depending on circumstances.
our($sqlAction);
# permissions table that sql should read from.  It may be the current, active, table or
# might be the archive table.
our($READ_TABLE);

# Name of the active permissions table.  Name of archive table is read in from yml file.
our($CURRENT_ROLE_FUNCTION_TABLE) = "sakai_realm_rl_fn";
#########################

# Given a task setup the sql variables.
sub setupTask {
  my $task = shift;

  if (!$ARCHIVE_ROLE_FUNCTION_TABLE && ($task eq "READ_ONLY_RESTORE"
                                        || $task eq "READ_ONLY_RESTORE_LIST")) {
    die(">>>>> For restore actions must specify value for ARCHIVE_ROLE_FUNCTION_TABLE in yml file.");
  }


  die (">>>>> INVALID TASK: [$task]") unless ($task eq "READ_ONLY_UPDATE"
                                              || $task eq "READ_ONLY_LIST"
                                              || $task eq "READ_ONLY_RESTORE"
                                              || $task eq "READ_ONLY_RESTORE_LIST"
                                              || $task eq "ACTION_LOG_UPDATE"
                                              || $task eq "ACTION_LOG_LIST"
                                              || $task eq "ACTION_LOG_COUNT"
                                             );

  #########

  ## update the action log.
#  see update_action_log.sql file for format.
  if ($task =~ "ACTION_LOG_UPDATE") {
    ($sqlAction,$READ_TABLE)
      = ("INSERT INTO ${DB_USER}.${ACTION_LOG_TABLE}\n ",$ACTION_LOG_TABLE);
  }

  if ($task =~ "ACTION_LOG_LIST") {
    ($sqlAction,$READ_TABLE)
      = ("SELECT * FROM (\n",$ACTION_LOG_TABLE);
  }

  if ($task =~ "ACTION_LOG_COUNT") {
    ($sqlAction,$READ_TABLE)
      = ("SELECT count(*) FROM (\n",$ACTION_LOG_TABLE);
  }
  
  ## work with removing permissions.  Will use the current role function table.
  # take permissions out of role function table to make site read only
  if ($task eq "READ_ONLY_UPDATE") {
    ($sqlAction,$READ_TABLE)
      = ("DELETE ",$CURRENT_ROLE_FUNCTION_TABLE);
  }

  # list what would be removed from the table
  if ($task eq "READ_ONLY_LIST") {
    ($sqlAction,$READ_TABLE)
      = ("SELECT * ",$CURRENT_ROLE_FUNCTION_TABLE);
  }
  
  #########
  ## work with restoring permissions.  Will read from archive table and update
  ## the active role function table.
  # restore permissions from the archive table
  if ($task eq "READ_ONLY_RESTORE") {
    ($sqlAction,$READ_TABLE)
      = ("INSERT INTO ${DB_USER}.${CURRENT_ROLE_FUNCTION_TABLE} SELECT * ",$ARCHIVE_ROLE_FUNCTION_TABLE);
  }
  # list what would be restored.
  if ($task eq "READ_ONLY_RESTORE_LIST") {
    ($sqlAction,$READ_TABLE)
      = ("SELECT * ",$ARCHIVE_ROLE_FUNCTION_TABLE);
  }

  die "invalid task: [$task]\n" unless($sqlAction);
}
######## utilities

# sql to update the action log.
sub writeActionLog {
  my($task,$siteId) = @_;
  print "/****** update log table *******/\n";
  print "insert into ${DB_USER}.${ACTION_LOG_TABLE} VALUES(CURRENT_TIMESTAMP,'${siteId}','$task');\n";
}

# sql to make an archive function table.
sub writeRRFTableBackupSql {
  my $timeStamp = strftime '%Y%m%d', gmtime();
  print "/****** make backup table ********/\n";
  print "/* script creation time and backup table id: $timeStamp */\n";
  print "create table ${DB_USER}.SAKAI_REALM_RL_FN_${timeStamp} as select * from ${DB_USER}.SAKAI_REALM_RL_FN;\n";
}

########## Methods to expand lists to SQL suitable format.

# return a string from a list of strings. Entries to be enclosed in ', separated by commas,
# and to include line break every comma_break_rate entries.

sub commaList {
  my $entry_cnt = 0;
  my $br;
  my $list_string .= "'".shift(@_)."'";
  foreach my $l (@_) {
    $br = ((++$entry_cnt % $comma_break_rate) == 0) ? "\n" : "";
    $list_string .= ",${br}'$l'";
  }
  $list_string;
}

# return a string from a list of strings.  Entries will formatted to provide a list of
# matching realms (using SQL like function).
sub unionList {
  my $break_cnt = 0;
  my $continue = "UNION ";

  my $list_string .= " " x 8 .formatRealmKey(shift(@_));
  foreach my $l (@_) {
    $list_string .= "\n ${continue} ".formatRealmKey($l);
  }
  $list_string;
}

sub unionListSites {
  my $break_cnt = 0;
  my $continue = "UNION ";

  my $list_string .= " " x 8 .formatSiteId(shift(@_));
  foreach my $l (@_) {
    $list_string .= "\n ${continue} ".formatSiteId($l);
  }
  $list_string;
}

############ assemble the sql query

sub buildSql {

  my $roles_as_sql = commaList(@roles);
  my $role_keys = role_keys_sql($roles_as_sql).strip();

  my $functions_as_sql = commaList(@functions);
  my $function_keys = function_keys_sql($functions_as_sql).strip();

  my $excluded_sites_as_sql = unionListSites(@excludedSites);
  my $excluded_sites = excluded_sites_sql($excluded_sites_as_sql).strip();

  my $site_realm_keys = site_realm_key_sql();
  
  # types
  my $candidate_site_as_sql = commaList(@readonlySiteTypes);
  my $candidate_sites = candidate_site_sql($candidate_site_as_sql).strip();

  my $target_sites = target_site_id_sql();

  my $target_sites_explicit_as_sql = unionListSites(@restoreSites);
  my $target_sites_explicit = target_site_id_explicit_sql($target_sites_explicit_as_sql).strip();

  my $prefix = prefix_sql($task).strip();
  my $suffix = suffix_sql($task).strip();

  print "\n";
  print "${prefix}\n";

  # sql to generate sites to target.
  if ($task !~ m|_RESTORE|) {
    print "${excluded_sites},\n";
    print "${candidate_sites},\n";
    print "${target_sites}\n";
  }
  
  if ($task =~ m|_RESTORE|) {
    print "${target_sites_explicit}\n";
  }


  # sql to generate the internal role, function, and realm keys
  if ($task !~ m|ACTION_LOG|) {
    print ",\n"; # if adding the keys then need a comma separator.
    print "${role_keys},\n";
    print "${function_keys},\n";
    print "${site_realm_keys}\n";
  }
  
  print "${suffix}";
  if ($task eq "ACTION_LOG_LIST" || $task eq "ACTION_LOG_COUNT") {
    print ")";
  }
  print ";\n";

}

############# functions to return parts of the required sql.

## format a single realm key
sub formatRealmKey {
  my $rid = shift;
  "(SELECT realm_key FROM   ${DB_USER}.sakai_realm  WHERE  realm_id LIKE '%/$rid%')"
}

## format a single realm key
sub formatSiteId {
  my $rid = shift;
  "(SELECT site_id FROM   ${DB_USER}.sakai_site  WHERE  site_id = '$rid')"
}

# sql for the start of query.
sub prefix_sql {
  # there might not be an action.
  my $task = shift;

  if ($task eq "READ_ONLY_LIST") {
    return prefix_SQL_READ_ONLY_LIST();
  }

    if ($task eq "ACTION_LOG_UPDATE") {
    return prefix_SQL_ACTION_LOG_UPDATE();
  }

    if ($task eq "ACTION_LOG_LIST") {
    return prefix_SQL_ACTION_LOG_LIST();
  }

  if ($task eq "ACTION_LOG_COUNT") {
    return prefix_SQL_ACTION_LOG_COUNT();
  }

  if ($task eq "READ_ONLY_RESTORE") {
    return prefix_SQL_READ_ONLY_RESTORE();
  }

  my $USE_TABLE=$ARCHIVE_ROLE_FUNCTION_TABLE;

  if ($task eq "READ_ONLY_UPDATE") {
    $USE_TABLE=$CURRENT_ROLE_FUNCTION_TABLE;
  }

  my $sql = <<"PREFIX_SQL";
   ${sqlAction}
   FROM   ${DB_USER}.${USE_TABLE} SRRF
   WHERE  EXISTS 
       ( SELECT 1
         FROM
           ( WITH 
PREFIX_SQL
  $sql
}

sub prefix_SQL_READ_ONLY_LIST {
  "WITH ";
}

sub prefix_SQL_ACTION_LOG_UPDATE {
  "INSERT INTO ${DB_USER}.${ACTION_LOG_TABLE}(ACTION_TIME,SITE_ID,ACTION_TAKEN) \nWITH";
}

sub prefix_SQL_ACTION_LOG_LIST {
  "SELECT *   FROM ( \nWITH";
}

sub prefix_SQL_ACTION_LOG_COUNT {
  "SELECT COUNT(*)   FROM ( \nWITH";
}

sub prefix_SQL_READ_ONLY_RESTORE {
   "INSERT INTO ${DB_USER}.sakai_realm_rl_fn 
   SELECT * 
   FROM   ${DB_USER}.${ARCHIVE_ROLE_FUNCTION_TABLE} SRRF 
   WHERE  EXISTS (
          SELECT 1 FROM (
           WITH ";
}

# return the sql for the role keys sub-table
sub role_keys_sql {
  my $role_as_sql = shift;
  my $sql = <<"END_ROLE_KEYS_SQL";
      role_keys 
        AS (
        SELECT role_key AS role_key 
        FROM   ${DB_USER}.sakai_realm_role 
        WHERE  role_name IN (
${role_as_sql}
                             ))
END_ROLE_KEYS_SQL
  $sql
}

# return the sql for the function keys sub-table
sub function_keys_sql {
  my $function_as_sql = shift;
  my $sql = <<"FUNCTION_KEYS_SQL";
      function_keys
        AS (
        SELECT function_key AS function_key
        FROM   ${DB_USER}.sakai_realm_function
        WHERE  function_name IN (
${function_as_sql}
                                 ))
FUNCTION_KEYS_SQL
  $sql
}

# return the sql for the role keys sub-table
sub candidate_site_sql {
  my $candidate_site_as_sql = shift;
  my $sql = <<"CANDIDATE_SITE_SQL";
      candidate_site_id 
        AS (
            SELECT site_id
            FROM
                  ${DB_USER}.sakai_site
            WHERE
                ${DB_USER}.sakai_site.type IN ($candidate_site_as_sql)
            )
CANDIDATE_SITE_SQL
  $sql
}

# return the sql for the excluded realm keys sub-table.
sub excluded_sites_sql {
  my $excluded_sites_as_sql = shift;
  my $sql = <<"REALM_KEY_SQL";
     excluded_site_id 
       AS (
       $excluded_sites_as_sql
  )
REALM_KEY_SQL
  $sql
}

# Generate sql for realm keys with realm_id that matches site.
sub site_realm_key_sql {
  my $site_realm_key_sql = shift;
  my $sql = << "SITE_REALM_KEY_SQL";
     site_realm_key 
       AS(
         SELECT ${DB_USER}.sakai_realm.realm_key
         FROM ${DB_USER}.sakai_realm,target_site_id
         WHERE ${DB_USER}.sakai_realm.realm_id LIKE '%'||target_site_id.site_id||'%'
  )
SITE_REALM_KEY_SQL
  $sql
}

sub filtered_realms_sql {
  my $sql = <<"REALM_KEY_SQL";
  SELECT * FROM target_site_ids WHERE target_site_ids.SITE_ID NOT IN (SELECT SID FROM excluded_ids)
REALM_KEY_SQL
  $sql
}

sub target_site_id_sql{
  my $sql = << "TARGET_SITE_ID_SQL";
     target_site_id
       AS (
          SELECT candidate_site_id.site_id FROM candidate_site_id
          LEFT OUTER JOIN excluded_site_id
          ON candidate_site_id.site_id = excluded_site_id.site_id
          WHERE excluded_site_id.site_id is null
           )           
TARGET_SITE_ID_SQL
 $sql
}

sub target_site_id_explicit_sql{
    my $sites_sql = shift;
  my $sql = << "TARGET_SITE_ID_EXPLICIT_SQL";
     target_site_id
       AS (
           ${sites_sql}
           )           
TARGET_SITE_ID_EXPLICIT_SQL
 $sql
}

# sql that uses the sub-tables to generate list of grants matching the
# role, function, realm criteria
sub suffix_sql {
  my $task = shift;
  my $UPDATE_DELIMITER="";

  if ($task eq "READ_ONLY_LIST") {
    return " select * from target_site_id ";
  }

  if ($task =~ /ACTION_LOG_.*/i) {
     $task = "READ_ONLY_UPDATE" if ($task eq "ACTION_LOG_UPDATE");
      return "select CURRENT_TIMESTAMP AS ACTION_TIME, SITE_ID AS SITE_ID, '${task}' AS ACTION_TAKEN from dual,target_site_id ";
  }

  if ($task eq "READ_ONLY_UPDATE") {
    $UPDATE_DELIMITER="    )";
  }
  
  my $sql = <<"SUFFIX_SQL";

   -- list grant rows to act on.
    SELECT SRRF_2.*
          FROM   ${DB_USER}.${READ_TABLE} SRRF_2,
                role_keys,function_keys,site_realm_key
          WHERE  SRRF_2.role_key = role_keys.role_key
             AND SRRF_2.function_key = function_keys.function_key
             AND SRRF_2.realm_key =  site_realm_key.realm_key
     -- name the table generate by the WITH
     ) SELECTED_KEYS
     -- now select the rows to delete
  WHERE SRRF.role_key = SELECTED_KEYS.role_key
    AND SRRF.realm_key = SELECTED_KEYS.realm_key
    AND SRRF.function_key = SELECTED_KEYS.function_key
 -- end exists
)
SUFFIX_SQL
  $sql
}

sub printComment {
  my($msg) = shift;
  print "/****** ${msg} ******/\n\n";
}

sub printPermissionsCount {
  my $msg = shift;
  printComment($msg);
  print "SELECT COUNT(*) FROM ${DB_USER}.SAKAI_REALM_RL_FN;\n\n";
}

# Run and generate sql based on the config file.
sub runWithExcludedSites {
  
  # make a backup table.
  writeRRFTableBackupSql($task) if ($task eq "READ_ONLY_UPDATE");

  printPermissionsCount("initial count") if ($task =~ /UPDATE$/ or $task =~ /RESTORE$/);
  
  buildSql();
  
  printPermissionsCount("final count") if ($task =~ /UPDATE$/ or $task =~ /RESTORE$/);
}

#### Invoke with configuration file and list of site ids.

configure(@ARGV);

runWithExcludedSites();
#end

