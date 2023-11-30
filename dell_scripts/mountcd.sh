#!/bin/bash

#### IMPORTANT: This script is only meant to show how to implement required scripts to make custom hardware compatible with FakeFish. Dell hardware is supported by the `idrac-virtualmedia` provider in Metal3.
#### This script has to mount the iso in the server's virtualmedia and return 0 if operation succeeded, 1 otherwise
#### Note: Iso image to mount will be received as the first argument ($1)
#### You will get the following vars as environment vars
#### BMC_ENDPOINT - Has the BMC IP
#### BMC_USERNAME - Has the username configured in the BMH/InstallConfig and that is used to access BMC_ENDPOINT
#### BMC_PASSWORD - Has the password configured in the BMH/InstallConfig and that is used to access BMC_ENDPOINT

ISO=${1}

# Disconnect image just in case
/opt/dell/srvadmin/bin/idracadm7 -r ${BMC_ENDPOINT} -u ${BMC_USERNAME} -p ${BMC_PASSWORD} remoteimage -d

# Connect image
/opt/dell/srvadmin/bin/idracadm7 -r ${BMC_ENDPOINT} -u ${BMC_USERNAME} -p ${BMC_PASSWORD} remoteimage -c -l ${ISO}

if ! /opt/dell/srvadmin/bin/idracadm7 -r ${BMC_ENDPOINT} -u ${BMC_USERNAME} -p ${BMC_PASSWORD} remoteimage -s | grep -F ${ISO}; then
  exit 1
fi

exit 0
