#!/bin/bash

#### IMPORTANT: This script is only meant to show how to implement required scripts to make custom hardware compatible with FakeFish. Dell hardware is supported by the `idrac-virtualmedia` provider in Metal3.
#### This script has to poweroff the server and return 0 if operation succeeded, 1 otherwise
BMC_ENDPOINT=${1}
USERNAME=${2}
PASSWORD=${3}

/opt/dell/srvadmin/bin/idracadm7 -r ${BMC_ENDPOINT} -u ${USERNAME} -p ${PASSWORD} serveraction powerdown
if [ $? -eq 0 ]; then
  exit 0
else
  exit 1
fi


