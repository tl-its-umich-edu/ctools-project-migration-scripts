#!/usr/bin/env bash
# Generate the sql for the READ_ONLY tasks.
# Note that making sites read only or restoring write ability
# will update the data base.

set -e
set -u

# List of all the tasks that can be done.
declare -a TASKS=("READ_ONLY_UPDATE" "READ_ONLY_LIST" "READ_ONLY_RESTORE" "READ_ONLY_RESTORE_LIST"
                  "ACTION_LOG_UPDATE" "ACTION_LOG_LIST" "ACTION_LOG_COUNT")

# Configuration file for sql generation
CONFIG=${1:-BatchROSql-CTDEV.TINY.yml}
# Capture the name of the config file as indicating the list of
# sites to be affected.

for task in "${TASKS[@]}"; do
    ./runBatchRO.sh ${task} ${CONFIG}
done

#end
