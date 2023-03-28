#!/bin/bash

#### IMPORTANT: This script is only meant to show how to implement required scripts to make custom hardware compatible with FakeFish. Dell hardware is supported by the `idrac-virtualmedia` provider in Metal3.
#### This script has to mount the iso in the server's virtualmedia and return 0 if operation succeeded, 1 otherwise
#### Note: Iso image to mount will be received as the first argument ($1)
#### You will get the following vars as environment vars
#### BMC_ENDPOINT - Has the BMC IP
#### BMC_USERNAME - Has the username configured in the BMH/InstallConfig and that is used to access BMC_ENDPOINT
#### BMC_PASSWORD - Has the password configured in the BMH/InstallConfig and that is used to access BMC_ENDPOINT

ISO=${1}

USERPASS=${BMC_USERNAME}:${BMC_PASSWORD}
# Disconnect image just in case (VirtualMedia 2 is CD/DVD 1 is floppy)
curl -L -ku ${USERPASS} -H "Content-Type: application/json" -H "Accept: application/json" -d '{}'  -X POST https://${BMC_ENDPOINT}/redfish/v1/Managers/1/VirtualMedia/2/Actions/Oem/Hp/HpiLOVirtualMedia.EjectVirtualMedia
# Connect image
IMAGE_JSON="{\"Image\": \"${ISO}\"}"
curl -L -ku ${USERPASS} -H "Content-Type: application/json" -H "Accept: application/json" -d "${IMAGE_JSON}" -X POST https://${BMC_ENDPOINT}/redfish/v1/Managers/1/VirtualMedia/2/Actions/Oem/Hp/HpiLOVirtualMedia.InsertVirtualMedia

if [ $? -eq 0 ]; then
  exit 0
else
  exit 1
fi
