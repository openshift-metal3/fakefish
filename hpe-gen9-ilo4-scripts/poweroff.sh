#!/bin/bash

#### IMPORTANT: This script is only meant to show how to implement required scripts to make custom hardware compatible with FakeFish. Dell hardware is supported by the `idrac-virtualmedia` provider in Metal3.
#### This script has to poweroff the server and return 0 if operation succeeded, 1 otherwise
#### You will get the following vars as environment vars
#### BMC_ENDPOINT - Has the BMC IP
#### BMC_USERNAME - Has the username configured in the BMH/InstallConfig and that is used to access BMC_ENDPOINT
#### BMC_PASSWORD - Has the password configured in the BMH/InstallConfig and that is used to access BMC_ENDPOINT

USERPASS=${BMC_USERNAME}:${BMC_PASSWORD}
curl -L -ku ${USERPASS} -H "Content-Type: application/json" -H "Accept: application/json" -d '{"ResetType": "ForceOff"}' -X POST https://${BMC_ENDPOINT}/redfish/v1/Systems/1/Actions/ComputerSystem.Reset
if [ $? -eq 0 ]; then
  exit 0
else
  exit 1
fi
