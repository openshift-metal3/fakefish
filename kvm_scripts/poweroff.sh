#!/bin/bash

#### IMPORTANT: This script is only meant to show how to implement required scripts to make custom hardware compatible with FakeFish. Dell hardware is supported by the `idrac-virtualmedia` provider in Metal3.
#### This script has to poweroff the server and return 0 if operation succeeded, 1 otherwise
#### You will get the following vars as environment vars
#### BMC_ENDPOINT - Has the BMC IP
#### BMC_USERNAME - Has the username configured in the BMH/InstallConfig and that is used to access BMC_ENDPOINT
#### BMC_PASSWORD - Has the password configured in the BMH/InstallConfig and that is used to access BMC_ENDPOINT

SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
VM_SHUTDOWN_FILE="/tmp/shutdown"

source ${SCRIPTPATH}/common.sh

#Get VM Status
vm_status=$(get_vm_status)

#Check if VM exists or Error
if [ -z "${vm_status}" ]; then
    echo "VM ${VM_NAME} does not exist"
    exit 1
fi

#Check if VM is already powered off
if [ "${vm_status}" == "shut" ]; then
    echo "VM ${VM_NAME} is already powered off"
    rm -f ${VM_SHUTDOWN_FILE}
    exit 0
fi

#Power off VM
power_off_vm
if [ $? -eq 0 ]; then
    #Write temp status file
    touch ${VM_SHUTDOWN_FILE}
    exit 0
else
    echo "Failed to poweroff VM"
    exit 1
fi


