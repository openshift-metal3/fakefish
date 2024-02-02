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

SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

source ${SCRIPTPATH}/common.sh

if [[ -r /var/tmp/kubeconfig ]]; then
  export KUBECONFIG=/var/tmp/kubeconfig
fi

stop_vm
if [ $? -eq 0 ]; then
  exit 0
else
  echo "Failed to poweroff VM"
  exit 1
fi