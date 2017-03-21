#!/usr/bin/env bash
### TTD:
#### - make prefix/instance a command line option.
#### - make sure that the packed script exists and is runnable.

# default to packed script but use pl version if more recent.
PREFIX="./generateROSqlSite.pl"
PACKED=${PREFIX}.packed
SCRIPT=$PACKED
# use plain perl version if it is more recent.
if [ -e "${PREFIX}" ] && [ "${PREFIX}" -nt "$PACKED" ]; then
    echo "USING MORE RECENT PERL SCRIPT";
    SCRIPT=$PREFIX;
fi

function help {
    echo "$0: {task} <site id file> {configuration file}"
    echo "Generate sql for CTools site read-only process.  Requires a file of site ids"
    echo "(one per line), a specific task name, and an optional configuration file name."
    echo "The configuration file to use depends on the CTools instances being processed."
    echo "See the *.yml files for more information."
    echo "The possible tasks for the generated sql are:"
    echo " READ_ONLY_UPDATE, READ_ONLY_LIST, READ_ONLY_RESTORE, READ_ONLY_RESTORE_LIST."
    echo "READ_ONLY_UPDATE will create sql to make site read only. It is the default."
    echo "READ_ONLY_RESTORE sql will restore the permissions removed from the site."
    echo "The _LIST tasks will print what would be changed, but does not do the change."
    echo "The sql will be put in the file <site id file>.<task name>.sql"
}

### time stamp utility
function niceTimestamp {
    echo $(date +"%F-%H-%M")
}
#######

######## Check for task type specification. Default to READ_ONLY_UPDATE.
# case insensitive match
# Only check for plausible match.  Let perl scripts
# do final checking.
shopt -s nocasematch
#set -x
TASK=$1
if [[ $TASK =~ "READ_ONLY_" ]];
then
#    echo "found task"
    shift
else
    echo "defaulting task to READ_ONLY_UPDATE"
    TASK="READ_ONLY_UPDATE"
fi

######

CONFIG=${2:-ROSql-20161206-PROD.yml}
SITEIDS=${1}

if [ $# -eq 0 ]; then
    help
    exit 1
fi

if [ ! -e "${SITEIDS}" ]; then
    echo "$0: ERROR: must provide file of siteIds."
    exit 1;
fi

if [ ! -e "${CONFIG}" ]; then
    echo "$0: ERROR: config file ${CONFIG} does not exist.";
    exit 1;
fi

T=$(niceTimestamp)

echo "running: cat $SITEIDS | ${SCRIPT} ${TASK} ${CONFIG} >| ${SITEIDS}.${T}.${TASK}.sql"

cat $SITEIDS | ${SCRIPT} ${TASK} ${CONFIG} >| ${SITEIDS}.${T}.${TASK}.sql

#end
