#!/bin/bash

#### IMPORTANT: This script translates to an older Supermicro redfish format that is incompatible with metal3.
#### This script has to mount the iso in the server's virtualmedia and return 0 if operation succeeded, 1 otherwise
#### Note: Iso image to mount will be received as the first argument ($1)
#### You will get the following vars as environment vars
#### BMC_ENDPOINT - Has the BMC IP
#### BMC_USERNAME - Has the username configured in the BMH/InstallConfig and that is used to access BMC_ENDPOINT
#### BMC_PASSWORD - Has the password configured in the BMH/InstallConfig and that is used to access BMC_ENDPOINT

ISO=${1}
ISO_URL=$(echo $ISO| cut -d '/' -f-3)
ISO_PATH='/'$(echo $ISO| cut -d '/' -f4-)

# UnMount image just in case
curl -X POST -s -k -u ''"${BMC_USERNAME}"'':''"${BMC_PASSWORD}"'' https://${BMC_ENDPOINT}/redfish/v1/Managers/1/VM1/CfgCD/Actions/IsoConfig.UnMount -d ""

# Configure image
sleep 2
echo
curl -X PATCH -s -k -u ''"${BMC_USERNAME}"'':''"${BMC_PASSWORD}"'' https://${BMC_ENDPOINT}/redfish/v1/Managers/1/VM1/CfgCD --data '{"Host": "'${ISO_URL}'","Path": "'${ISO_PATH}'"}'
if [ $? -eq 0 ]; then
  # Mount image
  sleep 3
  echo
  curl -X POST -s -k -u ''"${BMC_USERNAME}"'':''"${BMC_PASSWORD}"'' https://${BMC_ENDPOINT}/redfish/v1/Managers/1/VM1/CfgCD/Actions/IsoConfig.Mount -d ""
  if [ $? -eq 0 ]; then
    # Check image is mounted
    IMAGE=$(curl -s -k -u ''"${BMC_USERNAME}"'':''"${BMC_PASSWORD}"'' https://${BMC_ENDPOINT}/redfish/v1/Managers/1/VM1/CD1)
    echo
    echo $IMAGE
    if `echo $IMAGE | egrep -q ${ISO_PATH}`; then
      exit 0
    else
      exit 1
    fi
  else
    exit 1
  fi
else
  exit 1
fi
