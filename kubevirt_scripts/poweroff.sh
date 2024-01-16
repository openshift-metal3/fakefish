#!/bin/bash
set -ux -o pipefail

#### IMPORTANT: This script is only meant to show how to implement required scripts to make custom hardware compatible with FakeFish.
#### This script has to poweroff the server and return 0 if operation succeeded, 1 otherwise
#### You will get the following vars as environment vars
#### BMC_ENDPOINT - Has the BMC IP
#### BMC_USERNAME - Has the username configured in the BMH/InstallConfig and that is used to access BMC_ENDPOINT
#### BMC_PASSWORD - Has the password configured in the BMH/InstallConfig and that is used to access BMC_ENDPOINT

export VM_NAME=$(echo $BMC_ENDPOINT | awk -F "_" '{print $1}')
export VM_NAMESPACE=$(echo $BMC_ENDPOINT | awk -F "_" '{print $2}')

export KUBECONFIG=/var/tmp/kubeconfig
VM_RUNNING=$(oc -n ${VM_NAMESPACE} get vm ${VM_NAME} -o jsonpath='{.spec.running}')
if [ $? -ne 0 ]; then
  echo "Failed to get VM power state."
  exit 1
fi
if [[ "${VM_RUNNING}" == "false" ]]; then
  echo "VM is already powered off"
else
  virtctl -n ${VM_NAMESPACE} stop ${VM_NAME}
  if [ $? -eq 0 ]; then
    exit 0
  else
    echo "Failed to poweroff VM"
    exit 1
  fi
fi