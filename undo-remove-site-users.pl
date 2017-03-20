#!/usr/bin/perl
#
# Generates SQL to undelete all CTools users from specified sites
#
# undo-remove-site-users.pl: {site-id-file} {output-file}
#
#      site-id-file : text file of specified site-ids (each on separate line)
#      output-file  : SQL file to be executed
#
use strict;

my $CPM_ACTION_LOG_SQL = "INSERT INTO CPM_ACTION_LOG (ACTION_TIME, SITE_ID, ACTION_TAKEN) VALUES (CURRENT_TIMESTAMP,'SITE-ID','UNDELETE_MEMBERS');\n";
my $USER_SQL = "INSERT INTO SAKAI_SITE_USER (SITE_ID, USER_ID, PERMISSION) SELECT SITE_ID, USER_ID, PERMISSION FROM ARCHIVE_SAKAI_SITE_USER WHERE SITE_ID = 'SITE-ID';\n";
my $REALM_SQL = "INSERT INTO SAKAI_REALM_RL_GR (REALM_KEY, USER_ID, ROLE_KEY, ACTIVE, PROVIDED) SELECT REALM_KEY, USER_ID, ROLE_KEY, ACTIVE, PROVIDED FROM ARCHIVE_SAKAI_REALM_RL_GR WHERE REALM_KEY IN (SELECT REALM_KEY FROM SAKAI_REALM WHERE REALM_ID LIKE '/site/SITE-ID%');\n";
my $COMMIT_SQL = "COMMIT;\n";

main:
{
   print "\n\n...Started...\n\n";
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
   ## variable to hold the site id from the input list
   my $siteId;
   SITE: foreach $siteId (@sites)
   {
       $count = $count + 1;
       
       ## remove the trailing return characters
       $siteId =~ s/\r?\n$//;
       chomp;
       next SITE if ( !$siteId );
       my $sql;
       
       print OUTFILE "-- Site $count: for site id = $siteId\n";
       
       ## update the change record
       $sql = $CPM_ACTION_LOG_SQL;
       $sql =~ s/SITE-ID/$siteId/;
       print OUTFILE $sql;
       print OUTFILE "\n";

       ## recover site user
       $sql = $USER_SQL;
       $sql =~ s/SITE-ID/$siteId/;
       print OUTFILE $sql;
       print OUTFILE "\n";
       
       ## recover site user role
       $sql = $REALM_SQL;
       $sql =~ s/SITE-ID/$siteId/;
       print OUTFILE $sql;
       print OUTFILE "\n";
   }
   print OUTFILE $COMMIT_SQL;
   close OUTFILE;

   print "\n\n...Finished...\n\n";
}
