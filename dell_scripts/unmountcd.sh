#!/bin/bash

#### IMPORTANT: This script is only meant to show how to implement required scripts to make custom hardware compatible with FakeFish. Dell hardware is supported by the `idrac-virtualmedia` provider in Metal3.
#### This script has to unmount the iso from the server's virtualmedia and return 0 if operation succeeded, 1 otherwise

# Disconnect image
/opt/dell/srvadmin/bin/idracadm7 -r 192.168.1.10 -u root -p calvin remoteimage -d
if [ $? -eq 0 ]; then
  exit 0
else
  exit 1
fi
