#!/usr/bin/env bash
### TTD:
#### - make prefix/instance a command line option.
#### - make sure that the packed script exists and is runnable.


# default to packed script
SCRIPT=./verifyAccessSiteMembership.pl.packed

# use plain perl version if it is more recent.
if [ -e "./verifyAccessSiteMembership.pl" ] && [ "./verifyAccessSiteMembership.pl" -nt $SCRIPT ]; then
   echo "USING MORE RECENT PERL SCRIPT";
   SCRIPT=./verifyAccessSiteMembership.pl
fi

####### help
function help {
    echo "$0: <site id file> {configuration file}"
    echo "Verify that site ids listed will respond to a CTools API request for membership."
    echo "It requires a credentials.yml file.  The name can be overridden on the command line."
    echo "The sql will be put in the file <site id file>.sql."
    }

### time stamp utility
function niceTimestamp {
    echo $(date +"%F-%H-%M")
}
#######

CONFIG=${2:-credentials.yml}
SITEIDS=${1}
#  Add time to output files so don't overwrite old ones by accident.
T=$(niceTimestamp)

##### sanity checks
if [ $# -eq 0 ]; then
    help;
    echo $( $(pwd)/$SCRIPT -h);
    exit 1
fi

if [ ! -e "${SITEIDS}" ]; then
    echo "ERROR: must provide file of siteIds."
    exit 1;
fi

if [ ! -e "${CONFIG}" ]; then
    echo "ERROR: config file ${CONFIG} does not exist.";
    exit 1;
fi

### do it!

echo "running: cat $SITEIDS | $SCRIPT $CONFIG >| $SITEIDS.$T.membership.txt"

cat $SITEIDS | $SCRIPT $CONFIG >| $SITEIDS.$T.membership.txt

# make summary files

# list sites with users that provoked problems. Can be more that the number
# of users causing problems since a user might appear in more than 1 site.
perl -n -e '/^(\S+)\s.*sql:/ > 0 && print "$1\n"' $SITEIDS.$T.membership.txt | sort -u >| $SITEIDS.$T.membership.updatesites.txt

# Make a file of the sql to run to fix the bad users.  This might fix
# multiple sites.
perl -n -e '/sql:\s*(.+)\s*$/ && length($1) > 0 && print "$1\n"' $SITEIDS.$T.membership.txt | sort -u >| $SITEIDS.$T.membership.deleteunknown.sql

#end
