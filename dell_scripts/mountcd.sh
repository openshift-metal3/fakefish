#!/bin/bash

#### IMPORTANT: This script is only meant to show how to implement required scripts to make custom hardware compatible with FakeFish. Dell hardware is supported by the `idrac-virtualmedia` provider in Metal3.
#### This script has to mount the iso in the server's virtualmedia and return 0 if operation succeeded, 1 otherwise
#### Note: Iso image to mount will be received as the first argument ($1)

ISO=${1}

# Disconnect image just in case
/opt/dell/srvadmin/bin/idracadm7 -r 192.168.1.10 -u root -p calvin remoteimage -d

# Connect image
/opt/dell/srvadmin/bin/idracadm7 -r 192.168.1.10 -u root -p calvin remoteimage -c -l ${ISO}

if ! /opt/dell/srvadmin/bin/idracadm7 -r 192.168.1.10 -u root -p calvin remoteimage -s | grep ${ISO}; then
  exit 1
fi

exit 0
