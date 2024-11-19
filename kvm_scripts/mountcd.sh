#!/bin/bash

#### IMPORTANT: This script is only meant to show how to implement required scripts to make custom hardware compatible with FakeFish. Dell hardware is supported by the `idrac-virtualmedia` provider in Metal3.
#### This script has to mount the iso in the server's virtualmedia and return 0 if operation succeeded, 1 otherwise
#### Note: Iso image to mount will be received as the first argument ($1)
#### You will get the following vars as environment vars
#### BMC_ENDPOINT - Has the BMC IP
#### BMC_USERNAME - Has the username configured in the BMH/InstallConfig and that is used to access BMC_ENDPOINT
#### BMC_PASSWORD - Has the password configured in the BMH/InstallConfig and that is used to access BMC_ENDPOINT


ISO=${1}
SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
source ${SCRIPTPATH}/common.sh

echo "Mount CD Script"
echo "Called to mount ${ISO} on ${VM_NAME}"

#Get VM Status
vm_status=$(get_vm_status)

#Check if VM exists or Error
if [ -z "${vm_status}" ]; then
    echo "VM ${VM_NAME} does not exist"
    exit 1
fi

echo "Mount CD Script"
#Get cdrom drive
cdrom_drive=$(get_cdrom_drive)
if [ -z "${cdrom_drive}" ]; then
    echo "No cdrom drive found"
    exit 1
fi

#Unmount ISO
unmount_iso_in_cdrom ${cdrom_drive} || true
echo "Mount CD Script"

#Remote Download ISO
remote_download_iso
echo "Mount CD Script"

# Mount Image
mount_iso_in_cdrom /tmp/${VM_NAME}.iso ${cdrom_drive}
echo "Mount CD Script"
if [ $? -ne 0 ]; then
    exit 1
else
    exit 0
fi
