#!/usr/bin/env bash
# Generate sql query file for specific CTools read only tasks.

#set -x
# Set these to be fussy and find bugs early :-)
set -e
set -u

# default to packed script but use pl version if more recent.
PREFIX="./generateBatchROSqlSite.pl"
PACKED=${PREFIX}.packed
SCRIPT=$PACKED

DEFAULT_CONFIG_FILE="BatchROSql-CTDEV.tiny.yml"


# use plain perl version if it is more recent.
if [ -e "${PREFIX}" ] && [ "${PREFIX}" -nt "$PACKED" ]; then
    echo "USING MORE RECENT PERL SCRIPT";
    SCRIPT=$PREFIX;
fi

help_text=$( cat<<'EOF'
$0: {task} {configuration file}

Generate varous types of sql for the CTools site read-only
process. This will generate a one-time configuration file based on a
staring input yml file and then add special site ids kept in csv
files.  The final configuration file will have information on roles,
realms, functions to modify, site ids, site types, table names to
reference.

The list of sites to make readonly is generated by the looking at site
types. Specific sites can be excluded from the process by site id. For
changes to restore permissions to sites the site ids must be listed
explicitly. See the *.template.yml file for the basic configuation.
The list of exempt sites is read from the file "exemptsites.csv".  The
list of files to restore is read from "restoresites.csv".

The possible Read Only tasks are:
  READ_ONLY_LIST and READ_ONLY_UPDATE: generate the list of sites that will be updated
     or run the actual update.
  READ_ONLY_RESTORE_LIST and READ_ONLY_RESTORE: Print the list of sites to restore or
     actually run the restore.

  ACTION_LOG_LIST, ACTION_LOG_COUNT, or ACTION_LOG_UPDATE: Print or count the sites
    that would be affected by a modification or update the ACTION_LOG table to record
    the change.  Note that since this works on the list of sites that would be updated it 
    is only accurate if it is run before the actual site update query is run.

Each sql query will be put in a file named in the following format:
   <task>.<time stamp>.<configuration file name>.sql
For example: ACTION_LOG_COUNT.2018-05-31-15-27.BatchROSql-CTDEV.specialized_projects.yml.sql
EOF
         )

############## functions
# Take a yaml key name and a list of values from a file and append those to
# a supplied file as yaml key/value list.

function appendListToNewConfig {
    local SOURCE_FILE=$1
    local KEY=$2
    local CONFIG_FILE=$3

    # redirect output of entire block to config file
    {
        if [[ -e "${SOURCE_FILE}" ]] ; then
            echo -e "\n##### ${KEY} sites added from ${SOURCE_FILE}"
            echo -e "\n${KEY}:"
            cat ${SOURCE_FILE} | cut  -f1 -d' ' | perl -n -e'next if (/^\s*#/); print("    - $_") if (length($_) > 1)'
        fi
    } >> ${CONFIG_FILE}
}

function requireFile {
    if [ ! -e "${1}" ]; then
        echo "File: $1 must exist"
        exit 1;
    fi
}

########### generate nice time stamp
function niceTimestamp {
    echo $(date +"%F-%H-%M")
}
####################################

#### verify arguments
## Try to be helpful if caller seems to need it.
if [ $# -eq 0 ]; then
    echo "${help_text}"
    exit 1
fi

# Make sure the arguments are plausible.
if [ $# -ne 2 ]; then
    echo "Must provide values for requested action and config file name"
    exit 1
fi

######## Check for task type specification.
# case insensitive match
# Only check for plausible match.  Let perl scripts
# do final checking.
shopt -s nocasematch

# extract the task
TASK=$1

if [[ $TASK =~ "READ_ONLY_" ]];
then
    :
elif [[ $TASK =~ "ACTION_LOG_" ]];
then
    :
else
    echo "Must specify plausible task."
    exit 1;
fi

# extract the config file
CONFIG=$2

requireFile "${CONFIG}"
requireFile "exemptsites.csv"
requireFile "restoresites.csv"

T=$(niceTimestamp)

############### Write an updated config file appending the sites to be excluded.
CONFIG_T=${CONFIG}.${T}
NEW_CONFIG=${CONFIG_T}.yml

echo -e "# Read only config file generated automatically from ${CONFIG} at ${T}\n" >| ${NEW_CONFIG}
cat ${CONFIG} >> ${NEW_CONFIG}

# Get explicit lists of site ids from csv files and append them, in
# yaml format, to the new, one time, config file in key / values yaml
# format.

# For excluded sites either file name will work.
appendListToNewConfig excludedsites.csv excludedSites ${NEW_CONFIG}
appendListToNewConfig exemptsites.csv excludedSites ${NEW_CONFIG}

appendListToNewConfig restoresites.csv restoreSites ${NEW_CONFIG}

# Now run the sql generation script.
echo "running: ${SCRIPT} ${TASK} ${NEW_CONFIG} >| ${TASK}.${CONFIG_T}.sql"
${SCRIPT} ${TASK} ${NEW_CONFIG} >| ${TASK}.${CONFIG_T}.sql

#end
