#!/bin/bash
set -ux -o pipefail

#### IMPORTANT: This script is only meant to show how to implement required scripts to make custom hardware compatible with FakeFish.
#### This script has to unmount the iso from the server's virtualmedia and return 0 if operation succeeded, 1 otherwise
#### You will get the following vars as environment vars
#### BMC_ENDPOINT - Has the BMC IP
#### BMC_USERNAME - Has the username configured in the BMH/InstallConfig and that is used to access BMC_ENDPOINT
#### BMC_PASSWORD - Has the password configured in the BMH/InstallConfig and that is used to access BMC_ENDPOINT

# Disconnect image

export VM_NAME=$(echo $BMC_ENDPOINT | awk -F "_" '{print $1}')
export VM_NAMESPACE=$(echo $BMC_ENDPOINT | awk -F "_" '{print $2}')

export KUBECONFIG=/var/tmp/kubeconfig

# we cannot unmount the disk if it's running
VM_RUNNING=$(oc -n ${VM_NAMESPACE} get vm ${VM_NAME} -o jsonpath='{.spec.running}')
if [ $? -ne 0 ]; then
  echo "Failed to get VM power state."
  exit 1
fi

if [[ "${VM_RUNNING}" == "true" ]]; then
  # Even if we don't unmount the ISO the VM
  # will boot from HD next time (providing there is an S.O installed)
  echo "VM is running, ignoring unmount"
  exit 0
fi

NUM_DISK=$(oc -n ${VM_NAMESPACE} get vm ${VM_NAME} -o jsonpath='{.spec.template.spec.domain.devices.disks[*].name}' | tr " " ";" | { grep -o ";" || true; } | wc -l)
if [ $? -ne 0 ]; then
  echo "Failed to get VM disks."
  exit 1
fi

cat <<EOF > /tmp/${VM_NAME}.patch
[
  {
    "op": "remove",
    "path": "/spec/template/spec/domain/devices/disks/${NUM_DISK}"
  }
]
EOF

# If NUM_DISK is <=1 means that mount didn't happen
if [[ ${NUM_DISK} -gt 1 ]]; then
  oc -n ${VM_NAMESPACE} patch vm ${VM_NAME} --patch-file /tmp/${VM_NAME}.patch --type json
  if [ $? -eq 0 ]; then
    exit 0
  else
    echo "Failed to remove ISO disk from VM"
    exit 1
  fi
fi

NUM_VOLUMES=$(oc -n ${VM_NAMESPACE} get vm ${VM_NAME} -o jsonpath='{.spec.template.spec.volumes[*].name}' | tr " " ";" | { grep -o ";" || true; } | wc -l)
if [ $? -ne 0 ]; then
  echo "Failed to get VM volumes."
  exit 1
fi

cat <<EOF > /tmp/${VM_NAME}.patch
[
  {
    "op": "remove",
    "path": "/spec/template/spec/volumes/${NUM_VOLUMES}"
  }
]
EOF

# If NUM_VOLUMES is <=1 means that mount didn't happen
if [[ ${NUM_VOLUMES} -gt 1 ]]; then
  oc -n ${VM_NAMESPACE} patch vm ${VM_NAME} --patch-file /tmp/${VM_NAME}.patch --type json
  if [ $? -eq 0 ]; then
    oc -n ${VM_NAMESPACE} delete configmap ${VM_NAME}-iso-ca &> /dev/null
    oc -n ${VM_NAMESPACE} delete pvc ${VM_NAME}-bootiso
    if [ $? -ne 0 ]; then
      echo "Failed to delete CDI ISO PVC."
      exit 1
    fi
  else
    echo "Failed to remove iso volume from VM"
    exit 1
  fi
fi