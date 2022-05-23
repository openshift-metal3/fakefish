#!/bin/bash

#### IMPORTANT: This script is only meant to show how to implement required scripts to make custom hardware compatible with FakeFish. Dell hardware is supported by the `idrac-virtualmedia` provider in Metal3.
#### This script has to set the server's boot to once from cd and return 0 if operation succeeded, 1 otherwise
#### You will get the following vars as environment vars
#### BMC_ENDPOINT - Has the BMC IP
#### BMC_USERNAME - Has the username configured in the BMH/InstallConfig and that is used to access BMC_ENDPOINT
#### BMC_PASSWORD - Has the password configured in the BMH/InstallConfig and that is used to access BMC_ENDPOINT

/opt/dell/srvadmin/bin/idracadm7 -r ${BMC_ENDPOINT} -u ${BMC_USERNAME} -p ${BMC_PASSWORD} set iDRAC.VirtualMedia.BootOnce 1
if [ $? -eq 0 ]; then
  /opt/dell/srvadmin/bin/idracadm7 -r ${BMC_ENDPOINT} -u ${BMC_USERNAME} -p ${BMC_PASSWORD} set iDRAC.ServerBoot.FirstBootDevice VCD-DVD
  if [ $? -eq 0 ]; then
    exit 0
  else
    exit 1
  fi
else
  exit 1
fi
