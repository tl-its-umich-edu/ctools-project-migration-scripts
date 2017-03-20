#!/usr/bin/perl
#
# Generates SQL to verify whether there is still records inside SAKAI_SITE_USER, SAKAI_REALM_RL_GR or SAKAI_SITE table 
# with associated site ids
#
# verify-remove-site-users.pl: {site-id-file} {output-file}
#
#      site-id-file : text file of specified site-ids (each on separate line)
#      output-file  : SQL file to be executed
#




use strict;

my $VERIFY_SAKAI_SITE_USER_SQL = "select site_id, count(*) from SAKAI_SITE_USER where SITE_ID in IN_CLAUSE group by site_id;\n";
my $VERIFY_SAKAI_REALM_RL_GR_SQL = "select substr(t2.realm_id, length('/site/')+1) as SITE_ID, count(*) from SAKAI_REALM_RL_GR t1, sakai_realm t2 where t1.realm_key=t2.realm_key and substr(t2.realm_id, length('/site/')+1) in IN_CLAUSE group by t2.REALM_ID;\n";
my $VERIFY_SAKAI_SITE_SQL = "select site_id from SAKAI_SITE where site_id in IN_CLAUSE and PUBLISHED=1; \n";

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
   
   # the count of delete site ids 
   my $site_id_count = 0;
   
   ## this is to construct the in_clause
   ## start with a left parenthesis
   my $sql_in_clause = "(";
   
   SITE: foreach $_ (@sites)
   {
       $_ =~ s/\r?\n$//;
       next SITE if ( !$_ );
       
       if ($site_id_count > 0)
       {
           # concatenate with a comma
           $sql_in_clause = $sql_in_clause . ",\n"
       }
       
       $sql_in_clause = $sql_in_clause . "'" . $_ . "'";
       $site_id_count = $site_id_count +1;
   }
   $sql_in_clause = $sql_in_clause . ")";
   
   my $sql;
       
   print OUTFILE "-- to see if there is any user associated with those deleted sites, checking SAKAI_SITE_USER table \n";
   $sql = $VERIFY_SAKAI_SITE_USER_SQL;
   $sql =~ s/IN_CLAUSE/$sql_in_clause/;
   print OUTFILE $sql;
   print OUTFILE "\n";

   print OUTFILE "-- to see if there is any user role assignments associated with those deleted sites, checking SAKAI_REALM_RL_GR table \n";
   $sql = $VERIFY_SAKAI_REALM_RL_GR_SQL;
   $sql =~ s/IN_CLAUSE/$sql_in_clause/;
   print OUTFILE $sql;
   print OUTFILE "\n";
   
   print OUTFILE "-- to see if there is any site still marked as PUBLISHED, checking SAKAI_SITE table \n";
   $sql = $VERIFY_SAKAI_SITE_SQL;
   $sql =~ s/IN_CLAUSE/$sql_in_clause/;
   print OUTFILE $sql;
   print OUTFILE "\n";

   print "\n\n...Finished...\n\n";
}
