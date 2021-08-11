#!/usr/bin/env bash

: '
    Copyright (C) 2021 IBM Corporation
    Rafael Sene <rpsene@br.ibm.com> - Initial implementation.
'

# Trap ctrl-c and call ctrl_c()
trap ctrl_c INT

function ctrl_c() {
    echo "bye!"
    exit 1
}

function install_dependencies () {

    echo "Installing dependencies on Linux..."
    OS=$(cat /etc/os-release | grep -w "ID" | awk -F "=" '{print $2}' | tr -d "\"")

    if [ "$OS" == "centos" ]; then
        dnf install -y nfs-utils
    elif [ "$OS" == "rhel" ]; then
        RH_REGISTRATION=$(subscription-manager identity 2> /tmp/rhsubs.out; cat /tmp/rhsubs.out; rm -f /tmp/rhsubs.out)
        if [[ "$RH_REGISTRATION" == *"not yet registered"* ]]; then
            echo "ERROR: ensure your system is subscribed to RedHat."
            exit 1
        else
            dnf install -y nfs-utils
        fi
    else
        echo "This operating system is not supported yet."
        exit 1
    fi
}

function enable_services () {

    systemctl enable rpcbind
    systemctl enable nfs-server
    systemctl restart rpcbind
    systemctl start nfs-server
    
    firewall-cmd --permanent --add-service=nfs
    firewall-cmd --permanent --add-service=rpc-bind
    firewall-cmd --permanent --add-service=mountd
    firewall-cmd --reload
}

function create (){

    DEVICE=$1
    NETWORK=$2
    NFS_DIR="/data/nfs-storage"

    mkfs.ext4 "$DEVICE"
    mkdir -p "$NFS_DIR"
    mount "$DEVICE" "$NFS_DIR"
    chmod -R 755 "$NFS_DIR"

    echo "$NFS_DIR $NETWORK(rw,sync,no_root_squash)" >> /etc/exports
    exportfs -rav
    systemctl restart nfs-server

    echo "$DEVICE   $NFS_DIR    ext4    defaults    0   1" >> /etc/fstab
}

run () {

    if [ -z "$1" ]; then
        echo
        echo "ERROR: Please set the correct device that will be"
        echo "       formated and used as NFS storage."
        echo "       For instance: /dev/vda1."
        echo
        exit 1
    fi
    if [ -z "$2" ]; then
        echo
        echo "ERROR: Please set the network CIDR that will be"
        echo "       configured to allow access to the NFS server."
        echo "       For instance: 192.168.0.0/24 or * to allow access"
        echo "       from any network."
        echo
        exit 1
    fi

    install_dependencies
    enable_services
    create "$1" "$2"
}

### Main Execution ###
run "$@"
