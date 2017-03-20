#!/usr/bin/env bash
# package a perl script to generate sql to make sites read-only.
#set -x

# LIMITATION: This script will only work if the fatpack has been installed here.
SITEBIN="/opt/local/libexec/perl5.22/sitebin";

# temporary build directory
BUILD_DIR=TMP_BUILD.DIR
TAR_DIR=$(pwd)/TARS

function niceTimestamp {
    echo $(date +"%F-%H-%M")
}

function build_tar {
    TS=$(niceTimestamp)

    # make sure there is a place to put built tars.
    [ -e ${TAR_DIR} ] || mkdir ${TAR_DIR}

    # create a clean temporary build directory.
    [ -e ${BUILD_DIR} ] && rm -rf ${BUILD_DIR}
    mkdir ${BUILD_DIR}

    # copy over the site membership files.

    cp runVerifyAccessSiteMembership.sh ${BUILD_DIR}
    cp credentials.yml.TEMPLATE ${BUILD_DIR}

    # copy over the RO script configuration files
    cp runRO.sh ${BUILD_DIR}
    cp ROSql-*yml ${BUILD_DIR}

    # copy the common files and the packed files.
    cp README.md ${BUILD_DIR}
    cp README.html ${BUILD_DIR}
    cp *packed ${BUILD_DIR}
    
    chmod +x *packed *.sh
    
    TAR_OUT=${TAR_DIR}/CPMTools.${TS}.tar
    echo "+++ Created ${TAR_OUT} for CPM site migration."
    tar -cf ${TAR_OUT} -C ${BUILD_DIR} .
    rm -rf ${BUILD_DIR}
}

function pack_script {
    local APP=$1
    local APP_OUT=$APP.packed

    [ -e "$APP" ] || { echo "######### ERROR: SCRIPT $APP NOT FOUND FOR PACKING."; exit 1; }
    
    ## pack up the script files
    PATH=$PATH:$SITEBIN fatpack pack  ./$APP >| ${APP_OUT}
    return_value=$?
    if [ $return_value != 0 ]; then
        echo "$0: failed to generate ${APP_OUT}"
        exit -1
    fi
    echo "+++ Packed ${APP_OUT}."
}


echo "+++ Please ignore error messages about 'pod' files."

pack_script generateROSqlSite.pl
pack_script verifyAccessSiteMembership.pl

build_tar


#end
