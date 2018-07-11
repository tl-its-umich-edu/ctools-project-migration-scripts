#!/usr/bin/env bash
# Generate the sql for the READ_ONLY tasks.
# Note that making sites read only or restoring permissions
# will update the data base.

# Be fussy to pick up bugs early
set -e
set -u

# Provide help if the number of arguments provided is wrong.
if [ $# -ne 1 ]; then
    echo "$0 <base configuration file>"
    echo "Must provide the name of the base configuration file."
    exit 1
fi

# List of all the tasks that can be done.
declare -a TASKS=("READ_ONLY_UPDATE" "READ_ONLY_LIST"
                  "READ_ONLY_RESTORE" "READ_ONLY_RESTORE_LIST"
                  "ACTION_LOG_UPDATE" "ACTION_LOG_LIST" "ACTION_LOG_COUNT")

# Configuration file for sql generation
CONFIG=${1}

# Make them all.  This will generally end up generating only a single
# version of the one-time configuration file.

for task in "${TASKS[@]}"; do
    ./runBatchRO.sh ${task} ${CONFIG}
done

#end
