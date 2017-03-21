#!/usr/bin/env perl
use YAML qw'LoadFile';
use POSIX qw(strftime);

use strict;

## Generate sql to remove / restore site permissions based on lists of sites, roles, and permissions
## to delete.  Roles and permissions are configured in a yml file.  In production SQL will be run by a DBA.
## Tasks are given on the command line.  Available tasks are:
## READ_ONLY_LIST, READ_ONLY_UPDATE (list permissions to remove, remove them)
## READ_ONLY_RESTORE_LIST, READ_ONLY_RESTORE (list permissions to be restored, restore them)

# Run this using the runRO.sh shell script to deal with arguments and file naming.

################
## global configuration values read from the configuration yml file.  See below for
## purpose.
our $DB_USER;
our $comma_break_rate;
our $realms_max;
our @functions;
our @roles;
# name of the archive table, which may change over time.
our $ARCHIVE_ROLE_FUNCTION_TABLE;
################

# Read the requested task from the command line.  Wrapper shell script will default it if necessary.
our $task = shift;

# get configuration file name from command line
our ($yml_file) = shift || "./ROSqlSite.yml";

# read in configuration file and set values
sub configure {
  my ($db,$functions,$sites) = LoadFile($yml_file);

  # prefix for sql tables.
  $DB_USER=$db->{db_user};
 
  # for contents of IN clause how often put in a line break when generate list.
  $comma_break_rate=$db->{comma_break_rate};
  
  # how many realms to put in each separate query.
  $realms_max=$db->{realms_max};
  
  # functions (permissions) to delete.
  @functions = @{$db->{functions}};
  
  # roles to examine.
  @roles=@{$db->{roles}};

  # archive table name
  $ARCHIVE_ROLE_FUNCTION_TABLE=$db->{ARCHIVE_ROLE_FUNCTION_TABLE};

  # setup the task to be done.
  setupTask($task);
}

########################
## Variables to hold information that is used when generating SQL.
# Name the action the sql should perform  Can select, delete, insert depending on circumstances.
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

  if (!$ARCHIVE_ROLE_FUNCTION_TABLE && ($task eq "READ_ONLY_RESTORE" || $task eq "READ_ONLY_RESTORE_LIST")) {
    die(">>>>> For restore actions must specify value for ARCHIVE_ROLE_FUNCTION_TABLE in yml file.");
  }


  die (">>>>> INVALID TASK: [$task]") unless ($task eq "READ_ONLY_UPDATE"
                                              || $task eq "READ_ONLY_LIST"
                                              || $task eq "READ_ONLY_RESTORE"
                                              || $task eq "READ_ONLY_RESTORE_LIST");

  #########
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
  print "insert into ${DB_USER}.CPM_ACTION_LOG VALUES(CURRENT_TIMESTAMP,'${siteId}','$task');\n";
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

############ assemble the sql query

sub buildSql {
  my @realmIds = @_;
  
  my $roles_as_sql = commaList(@roles);
  my $rs = role_keys_sql($roles_as_sql);

  my $functions_as_sql = commaList(@functions);
  my $fs = function_keys_sql($functions_as_sql);

  my $realms_as_sql = unionList(@realmIds);
  my $rk = realm_keys_sql($realms_as_sql);

  my $prefix = prefix_sql();
  my $suffix = suffix_sql();

  print "\n";
#  printComment("update permissions");
  print "${prefix}\n";
  print "${rs},\n";
  print "${fs},\n";
  print "${rk},\n";
  print "${suffix}\n";

}

############# functions to return parts of the required sql.

## format a single realm key
sub formatRealmKey {
  my $rid = shift;
  "(SELECT realm_key FROM   ${DB_USER}.sakai_realm  WHERE  realm_id LIKE '%/$rid%')"
}

# sql for the start of query.
sub prefix_sql {
  printComment("take action");
  my $sql = <<"PREFIX_SQL";
   ${sqlAction}
   FROM   ${DB_USER}.${READ_TABLE} SRRF 
   WHERE  EXISTS (WITH 
PREFIX_SQL
  $sql
}

# return the sql for the role keys sub-table
sub role_keys_sql {
  my $role_as_sql = shift;
  my $sql = <<"END_ROLE_KEYS_SQL";
      role_keys 
        AS ((SELECT role_key AS role_key 
        FROM   ${DB_USER}.sakai_realm_role 
        WHERE  role_name IN (
${role_as_sql}
                             )))
END_ROLE_KEYS_SQL
  $sql
}

# return the sql for the function keys sub-table
sub function_keys_sql {
  my $function_as_sql = shift;
  my $sql = <<"FUNCTION_KEYS_SQL";
      function_keys
        AS ((SELECT function_key AS function_key
        FROM   ${DB_USER}.sakai_realm_function
        WHERE  function_name IN (
${function_as_sql}
                                 )))
FUNCTION_KEYS_SQL
  $sql
}

# return the sql for the realm keys sub-table.
sub realm_keys_sql {
  my $realm_as_sql = shift;
  my $sql = <<"REALM_KEY_SQL";
      realm_keys
        AS (
$realm_as_sql
            )
REALM_KEY_SQL
  $sql
}

# sql that uses the sub-tables to generate list of grants matching the
# role, function, realm criteria
sub suffix_sql {
  my $sql = <<"SUFFIX_SQL";
      -- generate all the possible rows to act on
      role_function_realm_keys
        AS (SELECT * FROM   role_keys, function_keys, realm_keys),
      -- find the rows that actually exist
        extant_grants
          AS (SELECT SRRF_2.*
          FROM   ${DB_USER}.${READ_TABLE} SRRF_2, role_function_realm_keys
          WHERE  SRRF_2.role_key = role_function_realm_keys.role_key
             AND SRRF_2.function_key = role_function_realm_keys.function_key
             AND SRRF_2.realm_key =  role_function_realm_keys.realm_key)
      -- use coordinated query to connect the list of rows to act on with the grant table
      SELECT realm_key,
             role_key,
             function_key
        FROM   extant_grants
        WHERE  extant_grants.realm_key = SRRF.realm_key
           AND extant_grants.role_key = SRRF.role_key
           AND extant_grants.function_key = SRRF.function_key);
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
  print "select count(*) from ${DB_USER}.SAKAI_REALM_RL_FN;\n\n";
}

### utilities to manage input / output

sub parseSiteLine {
  $_ = shift;

  # skip empty lines and comments
  return if (/^\s*$/);
  return if (/^\s*#/);
  split(' ',$_);
}

# print site sql if there are any sites.
sub printForSites {
  my $task = shift;
  my @realmIds = @_;
  return if ((scalar @realmIds) == 0);
  buildSql(@realmIds);
  }

##### Driver reads site ids from stdin #######

# read list of site ids from stdin and output sql update script.
# Will limit number of site ids in a single query to a maximum number,
# so there may be multiple queries.
sub readFromStdin {
  
  # make a backup table.
  writeRRFTableBackupSql($task) if ($task eq "READ_ONLY_UPDATE");

  printPermissionsCount("initial count");

  my @realmIds = ();
  
  while (<>) {

    if ((scalar @realmIds) >= $realms_max) {
      printForSites($task,@realmIds);
      printPermissionsCount("updated so far");
      @realmIds = ();
    }
    chomp;
    my(@P) = parseSiteLine $_;
    next unless(defined($P[0]));
    writeActionLog($task,@P[0]) if ($task eq "READ_ONLY_UPDATE" || $task eq "READ_ONLY_RESTORE");
    # add site id  to list of realms to process.
    if ((scalar @P) == 1) {
      push @realmIds,$P[0];
    }
  }
  
  # print any trailing sites
  if ((scalar @realmIds) >= 0) {
    printForSites($task,@realmIds);
  }

  printPermissionsCount("final count");
}

#### Invoke with configuration file and list of site ids.

configure(@ARGV);
readFromStdin();

#end
