#!/bin/bash

#### IMPORTANT: This script is only meant to show how to implement required scripts to make custom hardware compatible with FakeFish. Dell hardware is supported by the `idrac-virtualmedia` provider in Metal3.
#### This script has to poweron the server and return 0 if operation succeeded, 1 otherwise
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

#Check if VM is already powered on
if [ "${vm_status}" == "running" ]; then
   
    #Check if VM is shutting down
    if [ -f ${VM_SHUTDOWN_FILE} ]; then
        echo "VM ${VM_NAME} is shutting down"
        
        #Wait for VM to power off
        while true; do
            vm_status=$(get_vm_status)
            if [ "${vm_status}" == "shut" ]; then
                echo "VM ${VM_NAME} is powered off"
                rm -f ${VM_SHUTDOWN_FILE}
                break
            fi
            sleep 5
        done
    else
        #VM is not shutting down and is already powered on
        echo "VM ${VM_NAME} is already powered on"
        exit 0
    fi
fi

#Power on VM
power_on_vm
