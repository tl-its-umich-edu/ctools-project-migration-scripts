#!/usr/bin/env perl -w

# Read in list of site ids and either verify that the members can be read from the site
# or document the error.  If there is a bad user id in the site print out that user id
# and generate sql that will (usually) fix the problem.  Other cases will be dealt with
# on a case-by-case basis.

use YAML qw'LoadFile';
use POSIX qw(strftime);
use File::Temp qw(tempfile);
use Carp;

# temporary file handle for session cookies.
our $session_fh;

# Make varible available to share common curl arguments.
our $curl_args = undef();

my $help = <<END_HELP;
 $0: accept a list of site ids from standard input and check that:
  - the site can be accessed,
  - the members can be retrieved from the site.
  The file of site ids should have one id per line.  Empty and commented lines are ignored.
  There must be a credentials file that specifies:
  - the url to use to access the Sakai instance,
  - the user name and password of an admin account.
  - the database user to use in sql queries.
  See the file
  credentials.yml.TEMPLATE for a sample file to copy and configure.

  Status code of 000 suggests a serious problem in configuration.  Check the credentials file.
  Status code of 200 the request is fine.
  Status code of 400 is expected when the membership request can not be completed.
  Status code of 501 likely means that the site doesn't exist as requested.
END_HELP
    
# If asking for help give it.
if (defined($ARGV[0]) && $ARGV[0] =~ /^-?-h/i) {
  print $help;
  exit 1;
}

sub printSummaryLine {
  my($siteId,$statusCode,$other) = @_;
  croak() unless(defined($other));
  print "$siteId\t$statusCode\t$other\n";
}

# Store the connection information externally.
sub setupCredentials {

  my ($yml_file) = shift(@ARGV) || './credentials.yml';
  my ($credentials) = LoadFile($yml_file) || die("can't read credentials file: [$yml_file]");
  $HOST=$credentials->{HOST};
  $USER=$credentials->{USER};
  $PASSWORD=$credentials->{PASSWORD};
  $DB_USER=$credentials->{DB_USER};
}

# Setup a ctools session to share with later calls.
sub setupSession {
  $session_fh = new File::Temp( UNLINK => 1 );
  # setup the common curl args here since session dependent.
  # add -i to get headers printed
  $curl_args = " -o - -c $session_fh -b $session_fh ";
  $memCmd = "curl -s -S $curl_args -X POST -F \"_username=$USER\" -F \"_password=$PASSWORD\" $HOST/direct/session";
  $result = `$memCmd`;
  return $result;
}

# Get site members from ctools via API call.
sub getMembers {
  # Assumes that setupSession has been called first.
  my $sid = shift;
  # ask for members in the site.
  $mem_cmd = "curl -sw '\\n%{http_code} %{url_effective}\\n' $curl_args $HOST/direct/site/$sid/memberships.json";
  my $result = `$mem_cmd`;
  return $result;
}

# If find that can't get membership list because of missing user, generate the sql to delete site memberships/grants for that user.
sub missingEidMessage {
  my ($eid) = @_;

  my $deleteMembership = "sql:\tdelete from ${DB_USER}.SAKAI_REALM_RL_GR where user_id in ( select user_id from ${DB_USER}.SAKAI_USER_ID_MAP where eid = '$eid'  )";
  return $deleteMembership;
}

# find the unknown EID.  There are a couple of different formats to check.
sub findUnknownEID {
  my $string = shift;
  my $eid = "";

  # match a couple of different patterns.
  if (    $string =~ /eid=id=([;:(),-@\w.']+)/ms
       or $string =~ /id \(([]&';:(),-@\w.]+)\)/ms
     ) {

    $eid = $1;
    # double up single quotes for Oracle consumption.
    $eid =~ s/'/''/g;
    # Occasionally site information appears in with the user id.  Get rid of it.
    $eid =~ s/::site.+$//;
  }
  return $eid
}

# Parse the results of the membership call.
# There may be error messages in the value returned from the call so we
# need to account for those.
sub parseMembers {
  my $text = shift;

  # get http status and site id
  my ($status,$site) = ($text =~ /(\d\d\d)\s+http.+\/site\/(.+)\/memberships.json$/ms);
  $status |= "";
  $site |= "";
  my $eid |= "";

  # find the invalid user member name that is mentioned in the
  # text of errors.
  $eid = findUnknownEID($text);
  $eid |= "";

  # Generate and print a summary for the site.
  if ($status == 200) {
    $msg = "ok";
  } elsif ($status == 501) {
    $msg = "unknown site";
  } elsif (length($eid) > 0) {
    $msg = missingEidMessage($eid);
  } else {
    $msg = " unknown error:\t$text";
  }

  printSummaryLine $site, $status, $msg;
}

# Verify that the site ids provided can be accessed and can provide
# a list of site members.
# Input is a file of site ids to check.
sub runVerifyMembers {
  setupCredentials;
  while (<>) {
    next if (/^\s*$/);
    next if (/^\s*#/);
    my $siteId = $_;
    chomp($siteId);
    setupSession();
    my $members = getMembers($siteId);
    parseMembers $members;
  }
}

my $t=scalar(localtime);
print "# start at $t\n";
runVerifyMembers;
$t=scalar(localtime);
print "# end at $t\n";

#end
