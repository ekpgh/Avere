#!/bin/bash
# Copyright (C) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
# Save this script to any Avere vFXT volume, for example:
#     /bootstrap/bootstrap.sh
#
# The following environment variables must be set:
#  BASE_DIR=/nfs
#  BOOTSTRAP_NFS_IP=10.0.0.22
#  BOOTSTRAP_SCRIPT_PATH=/bootstrap/bootstrap.sh
#  NFS_IP_CSV="10.0.0.22,10.0.0.23,10.0.0.24"
#  NFS_PATH=/msazure
#

function retrycmd_if_failure() {
    retries=$1; max_wait_sleep=$2; shift && shift
    for i in $(seq 1 $retries); do
        ${@}
        [ $? -eq 0  ] && break || \
        if [ $i -eq $retries ]; then
            echo Executed \"$@\" $i times;
            return 1
        else
            sleep $(($RANDOM % $max_wait_sleep))
        fi
    done
    echo Executed \"$@\" $i times;
}

function install_nfs() {
    apt-get update && apt-get install -y nfs-common
}

function mount_bootstrap_and_install() {
    echo "mount bootstrap, and run bootstrap script"
    OPT_DIR=/opt
    RUN_SCRIPT=$OPT_DIR/bootstrap.sh
    BOOTSTRAP_BASE_DIR=$BASE_DIR/b
    mkdir -p $BOOTSTRAP_BASE_DIR
    retrycmd_if_failure 60 5 mount -o "hard,nointr,proto=tcp,mountproto=tcp,retry=30" ${BOOTSTRAP_NFS_IP}:${NFS_PATH} ${BOOTSTRAP_BASE_DIR}
    mkdir -p $OPT_DIR
    retrycmd_if_failure 60 5 cp ${BOOTSTRAP_BASE_DIR}${BOOTSTRAP_SCRIPT_PATH} ${RUN_SCRIPT}
    /bin/bash ${RUN_SCRIPT} 2>&1 | tee -a /var/log/bootstrap.log
    umount $BOOTSTRAP_BASE_DIR
    rmdir $BOOTSTRAP_BASE_DIR
}

function debug_dump_env_vars() {
    echo "start env dump"
    echo $(pwd)
    echo "export BASE_DIR=$BASE_DIR"
    echo "export BOOTSTRAP_NFS_IP=$BOOTSTRAP_NFS_IP"
    echo "export BOOTSTRAP_SCRIPT_PATH=$BOOTSTRAP_SCRIPT_PATH"
    echo "export NFS_IP_CSV=$NFS_IP_CSV"
    echo "export NFS_PATH=$NFS_PATH"
    echo "finish env dump"
}

function main() {
    echo "install NFS"
    retrycmd_if_failure 60 5 install_nfs

    echo "dump env vars"
    debug_dump_env_vars

    echo "mount bootstrap and install"
    mount_bootstrap_and_install
}

main