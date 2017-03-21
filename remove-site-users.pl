#!/usr/bin/perl
#
# Generates SQL to remove all CTools users from specified sites
#
# remove-site-users.pl: {site-id-file} {output-file}
#
#      site-id-file : text file of specified site-ids (each on separate line)
#      output-file  : SQL file to be executed
#




use strict;

my $CPM_ACTION_LOG_SQL = "insert into CPM_ACTION_LOG (ACTION_TIME, SITE_ID, ACTION_TAKEN) VALUES (CURRENT_TIMESTAMP,'SITE-ID','DELETE_MEMBERS');\n";
my $ARCHIVE_USER_SQL = "insert into ARCHIVE_SAKAI_SITE_USER (select * from SAKAI_SITE_USER where site_id = 'SITE-ID');\n";
my $ARCHIVE_REALM_SQL = "insert into ARCHIVE_SAKAI_REALM_RL_GR (select * from SAKAI_REALM_RL_GR where realm_key in (select realm_key from sakai_realm where realm_id like '/site/SITE-ID%'));\n";
my $ARCHIVE_SAKAI_SITE_USER_ROLE_SQL = "insert into ARCHIVE_SAKAI_SITE_USER_ROLE
select t1.site_id, t5.EID, t4.ROLE_NAME
from Sakai_site t1, sakai_realm t2,
SAKAI_REALM_RL_GR t3,
sakai_realm_role t4,
sakai_user_id_map t5
where t2.REALM_ID = concat('/site/', t1.site_id)
and t2.REALM_KEY = t3.realm_key
and t3.USER_ID = t5.USER_ID
and t1.site_id = 'SITE-ID'
and t3.role_key = t4.ROLE_KEY;\n";


my $USER_SQL = "delete from SAKAI_SITE_USER where site_id = 'SITE-ID';\n";
my $REALM_SQL = "delete from SAKAI_REALM_RL_GR where realm_key in (select realm_key from sakai_realm where realm_id like '/site/SITE-ID%');\n";
## make site unpublished
my $SITE_SQL = "update SAKAI_SITE set published=0 where site_id = 'SITE-ID'; \n";
my $COMMIT_SQL = "commit;\n";

main:
{
   if ( $#ARGV != 1 )
   {
       print " remove-site-users.pl: {site-id-file} {output-file}\n";
       exit -1;
   }

   ## set up default values
   my $inFile  = $ARGV[0];
   my $outFile = $ARGV[1];

   open INFILE, $inFile or die "$!";
   my @sites = <INFILE>;
   close INFILE;

   open OUTFILE, "> $outFile" or die "$!";

   ## set up count value
   my $count = 0;
   SITE: foreach $_ (@sites)
   {
       $count = $count + 1;
       
       $_ =~ s/\r?\n$//;
       chomp;
       next SITE if ( !$_ );
       my $sql;
       
       print OUTFILE "-- Site $count: for site id = $_\n";
       
       $sql = $CPM_ACTION_LOG_SQL;
       $sql =~ s/SITE-ID/$_/;
       print OUTFILE $sql;
       print OUTFILE "\n";
       
       $sql = $ARCHIVE_SAKAI_SITE_USER_ROLE_SQL;
       $sql =~ s/SITE-ID/$_/;
       print OUTFILE $sql;
       print OUTFILE "\n";

       $sql = $ARCHIVE_USER_SQL;
       $sql =~ s/SITE-ID/$_/;
       print OUTFILE $sql;
       print OUTFILE "\n";

       $sql = $USER_SQL;
       $sql =~ s/SITE-ID/$_/;
       print OUTFILE $sql;
       print OUTFILE "\n";

       $sql = $ARCHIVE_REALM_SQL;
       $sql =~ s/SITE-ID/$_/;
       print OUTFILE $sql;
       print OUTFILE "\n";

       $sql = $REALM_SQL;
       $sql =~ s/SITE-ID/$_/;
       print OUTFILE $sql;
       print OUTFILE "\n";
       
       $sql = $SITE_SQL;
       $sql =~ s/SITE-ID/$_/;
       print OUTFILE $sql;
       print OUTFILE "\n\n";
   }
   print OUTFILE $COMMIT_SQL;
   close OUTFILE;

   print "\n\n...Finished...\n\n";
}
