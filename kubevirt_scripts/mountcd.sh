#!/bin/bash
set -ux -o pipefail

#### IMPORTANT: This script is only meant to show how to implement required scripts to make custom hardware compatible with FakeFish.
#### This script has to mount the iso in the server's virtualmedia and return 0 if operation succeeded, 1 otherwise
#### Note: Iso image to mount will be received as the first argument ($1)
#### You will get the following vars as environment vars
#### BMC_ENDPOINT - Has the BMC IP
#### BMC_USERNAME - Has the username configured in the BMH/InstallConfig and that is used to access BMC_ENDPOINT
#### BMC_PASSWORD - Has the password configured in the BMH/InstallConfig and that is used to access BMC_ENDPOINT

ISO=${1}
IS_HTTPS=false

export VM_NAME=$(echo $BMC_ENDPOINT | awk -F "_" '{print $1}')
export VM_NAMESPACE=$(echo $BMC_ENDPOINT | awk -F "_" '{print $2}')

SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

source ${SCRIPTPATH}/common.sh

if [[ -r /var/tmp/kubeconfig ]]; then
  export KUBECONFIG=/var/tmp/kubeconfig
fi


CLUSTER_STORAGE_CLASS=$(oc get storageclass | awk '/(default)/ {print $1}')
if [ $? -ne 0 ]; then
  echo "Failed to get default cluster's storage class."
  exit 1
fi

if [ -z ${CLUSTER_STORAGE_CLASS} ];then
  CLUSTER_STORAGE_CLASS=ocs-storagecluster-ceph-rbd
fi

PVC_SPEC=$(cat <<EOF
  spec:
    accessModes:
    - ReadWriteOnce
    resources:
      requests:
        storage: 5Gi
    storageClassName: ${CLUSTER_STORAGE_CLASS}
EOF
)

if echo ${ISO} | grep -q https://; then
  HOSTNAME=$(echo ${ISO} | awk -F "https://" '{print $2}' | awk -F "/" '{print $1}' | awk -F ":" '{print $1}')
  PORT=$(echo ${ISO} | awk -F "https://" '{print $2}' | awk -F "/" '{print $1}' | awk -F ":" '{print $2}')
  if [ -z ${PORT} ]; then
    PORT=443
  fi
  openssl s_client -showcerts -connect ${HOSTNAME}:${PORT} </dev/null 2>/dev/null | openssl x509 -outform PEM > /tmp/iso-endpoint-ca.crt
  if [ $? -ne 0 ]; then
    echo "Failed to get https server cert."
    exit 1
  fi
  IS_HTTPS=true
fi

# we need to poweroff the VM if it's running
VM_WAS_RUNNING=$(oc -n ${VM_NAMESPACE} get vm ${VM_NAME} -o jsonpath='{.spec.running}')
if [ $? -ne 0 ]; then
  echo "Failed to get VM power state."
  exit 1
fi
stop_vm
if [ $? -ne 0 ]; then
  echo "Failed to poweroff VM."
  exit 1
fi

if [ ${IS_HTTPS} == "true" ]; then
  # We don't care about delete configmap return
  # if it fails it's likely because it didn't exist
  # we will fail on create if something is wrong with it
  oc -n ${VM_NAMESPACE} delete configmap ${VM_NAME}-iso-ca &> /dev/null
  oc -n ${VM_NAMESPACE} create configmap ${VM_NAME}-iso-ca --from-file=ca.crt=/tmp/iso-endpoint-ca.crt
  if [ $? -ne 0 ]; then
    echo "Failed to create configmap with https server cert."
    exit 1
  fi

  cat <<EOF | oc apply -f -
  apiVersion: v1
  kind: PersistentVolumeClaim
  metadata:
    annotations:
      cdi.kubevirt.io/storage.import.certConfigMap: "${VM_NAME}-iso-ca"
      cdi.kubevirt.io/storage.import.endpoint: "${ISO}"
      cdi.kubevirt.io/storage.bind.immediate.requested: "true"
    name: ${VM_NAME}-bootiso
    namespace: ${VM_NAMESPACE}
${PVC_SPEC}
EOF
  if [ $? -ne 0 ]; then
    echo "Failed to create PVC."
    exit 1
  fi
else
  cat <<EOF | oc apply -f -
  apiVersion: v1
  kind: PersistentVolumeClaim
  metadata:
    annotations:
      cdi.kubevirt.io/storage.import.endpoint: "${ISO}"
      cdi.kubevirt.io/storage.bind.immediate.requested: "true"
    name: ${VM_NAME}-bootiso
    namespace:  ${VM_NAMESPACE}
${PVC_SPEC}
EOF
  if [ $? -ne 0 ]; then
    echo "Failed to create PVC."
    exit 1
  fi
fi

STATUS=$(oc -n ${VM_NAMESPACE} get pvc ${VM_NAME}-bootiso -o jsonpath='{.metadata.annotations.cdi\.kubevirt\.io/storage\.condition\.running\.message}')
if [ $? -ne 0 ]; then
  echo "Failed to get CDI import state."
  exit 1
fi
MAX_WAIT=60
WAIT=0
while [[ ${STATUS} != "Import Complete" ]]
do
  WAIT=$((WAIT + 2))
  sleep 2
  if [ ${WAIT} -ge ${MAX_WAIT} ]; then
    # This will make the request fail, Metal3 will retry the operation.
    echo "Timeout waiting for ISO to be imported"
    exit 1
  fi
  echo "Waiting for ISO to be imported [${WAIT}/${MAX_WAIT}]"
  STATUS=$(oc -n ${VM_NAMESPACE} get pvc ${VM_NAME}-bootiso -o jsonpath='{.metadata.annotations.cdi\.kubevirt\.io/storage\.condition\.running\.message}')
  if [ $? -ne 0 ]; then
    echo "Failed to get CDI import state."
    exit 1
  fi
done

NUM_VOLUMES=$(oc -n ${VM_NAMESPACE} get vm ${VM_NAME} -o jsonpath='{.spec.template.spec.volumes[*].name}' | tr " " ";" | { grep -o ";" || true; } | wc -l)
if [ $? -ne 0 ]; then
  echo "Failed to get VM volumes."
  exit 1
fi

cat <<EOF > /tmp/${VM_NAME}.patch
[
  {
    "op": "add",
    "path": "/spec/template/spec/volumes/$((NUM_VOLUMES + 1))",
    "value": {
      "name": "${VM_NAME}-bootiso",
      "persistentVolumeClaim": {
         "claimName": "${VM_NAME}-bootiso"
      }
    }
  }
]
EOF

# Add it to VM object if it doesn't exist
VOLUME_EXIST=$(oc -n ${VM_NAMESPACE} get vm ${VM_NAME} -o jsonpath='{.spec.template.spec.volumes[*].name}' | { grep -c "${VM_NAME}-bootiso" || true; })
if [ $? -ne 0 ]; then
  echo "Failed to get VM volumes."
  exit 1
fi

if [ ${VOLUME_EXIST} -eq 0 ]; then
  oc -n ${VM_NAMESPACE} patch vm ${VM_NAME} --patch-file /tmp/${VM_NAME}.patch --type json
  if [ $? -eq 0 ]; then
    echo "Volume added to the VM"
  else
    echo "Failed to add bootiso volume to the VM"
    exit 1
  fi
else
  echo "Volume already added to the VM"
fi

# We get the number of disks, since we need to delete the one we just added to fix the config
NUM_DISK=$(oc -n ${VM_NAMESPACE} get vm ${VM_NAME} -o jsonpath='{.spec.template.spec.domain.devices.disks[*].name}' | tr " " ";" | { grep -o ";" || true; } | wc -l)
if [ $? -ne 0 ]; then
  echo "Failed to get VM disks."
  exit 1
fi

cat <<EOF > /tmp/${VM_NAME}.patch
[
  {
    "op": "add",
    "path": "/spec/template/spec/domain/devices/disks/$((NUM_DISK + 1))",
    "value": {
      "bootOrder": $((NUM_DISK + 2)),
      "cdrom": {
         "bus": "sata"
      },
      "name": "${VM_NAME}-bootiso"
    }
  }
]
EOF

# Add it to VM object if it doesn't exist
DISK_EXIST=$(oc -n ${VM_NAMESPACE} get vm ${VM_NAME} -o jsonpath='{.spec.template.spec.domain.devices.disks[*].name}' | { grep -c "${VM_NAME}-bootiso" || true; })
if [ $? -ne 0 ]; then
  echo "Failed to get VM volumes."
  exit 1
fi

if [ ${DISK_EXIST} -eq 0 ]; then
  oc -n ${VM_NAMESPACE} patch vm ${VM_NAME} --patch-file /tmp/${VM_NAME}.patch --type json
  if [ $? -eq 0 ]; then
    echo "Disk added to the VM"
  else
    echo "Failed to add bootiso disk to the VM"
    exit 1
  fi
else
  echo "Volume already added to the VM"
fi

# If VM was running, restore it
if [[ "${VM_WAS_RUNNING}" == "true" ]]; then
  start_vm
  if [ $? -ne 0 ]; then
    echo "Failed to poweron VM."
    exit 1
  fi
fi
