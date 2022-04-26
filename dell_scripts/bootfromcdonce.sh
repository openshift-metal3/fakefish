#!/bin/bash

#### IMPORTANT: This script is only meant to show how to implement required scripts to make custom hardware compatible with FakeFish. Dell hardware is supported by the `idrac-virtualmedia` provider in Metal3.
#### This script has to set the server's boot to once from cd and return 0 if operation succeeded, 1 otherwise

/opt/dell/srvadmin/bin/idracadm7 -r 192.168.1.10 -u root -p calvin set iDRAC.VirtualMedia.BootOnce 1
if [ $? -eq 0 ]; then
  /opt/dell/srvadmin/bin/idracadm7 -r 192.168.1.10 -u root -p calvin set iDRAC.ServerBoot.FirstBootDevice VCD-DVD
  if [ $? -eq 0 ]; then
    exit 0
  else
    exit 1
  fi
else
  exit 1
fi
