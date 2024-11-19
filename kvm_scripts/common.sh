function get_vm_status() {
    vm_status=$(virsh -c qemu+ssh://${BMC_USERNAME}@${BMC_ENDPOINT}/system list --all | grep ${VM_NAME} | awk '{ print $3}')
    if [ $? -eq 0 ]; then
        echo ${vm_status}
    else
        echo "Failed to get VM ${VM_NAME} status"
        exit 1
    fi   
}

function power_on_vm() {
    vm_status=$(get_vm_status)

    if [ -z "${vm_status}" ]; then
        echo "VM ${VM_NAME} does not exist or failed to get status"
        exit 1
    fi

    if [ "${vm_status}" == "running" ]; then
        echo "VM ${VM_NAME} is already running"
        return 0
    fi

    virsh -c qemu+ssh://${BMC_USERNAME}@${BMC_ENDPOINT}/system start ${VM_NAME}
    if [ $? -eq 0 ]; then
        echo "VM ${VM_NAME} powered on successfully"
        return 0
    else
        echo "Failed to power on VM ${VM_NAME}"
        exit 1
    fi
}

function power_off_vm() {
    vm_status=$(get_vm_status)

    if [ -z "${vm_status}" ]; then
        echo "VM ${VM_NAME} does not exist or failed to get status"
        exit 1
    fi

    if [ "${vm_status}" == "shut" ]; then
        echo "VM ${VM_NAME} is already powered off"
        return 0
    fi

    virsh -c qemu+ssh://${BMC_USERNAME}@${BMC_ENDPOINT}/system shutdown ${VM_NAME} --mode acpi
    if [ $? -eq 0 ]; then
        echo "VM ${VM_NAME} powered off successfully"
        return 0
    else
        echo "Failed to power off VM ${VM_NAME}"
        exit 1
    fi
}

function reboot_vm() {
    vm_status=$(get_vm_status)

    if [ -z "${vm_status}" ]; then
        echo "VM ${VM_NAME} does not exist or failed to get status"
        exit 1
    fi

    virsh -c qemu+ssh://${BMC_USERNAME}@${BMC_ENDPOINT}/system reboot ${VM_NAME} --mode acpi
    if [ $? -eq 0 ]; then
        echo "VM ${VM_NAME} rebooted successfully"
        return 0
    else
        echo "Failed to reboot VM ${VM_NAME}"
        exit 1
    fi
}

function destroy_vm() {
    echo "Destroying VM ${VM_NAME}"
    vm_status=$(get_vm_status)

    if [ -z "${vm_status}" ]; then
        echo "VM ${VM_NAME} does not exist or failed to get status"
        exit 1
    fi

    if [ "${vm_status}" == "shut" ]; then
        echo "VM ${VM_NAME} is already powered off"
        return 0
    fi

    virsh -c qemu+ssh://${BMC_USERNAME}@${BMC_ENDPOINT}/system destroy ${VM_NAME}
    if [ $? -eq 0 ]; then
        echo "VM ${VM_NAME} destroyed successfully"
        return 0
    else
        echo "Failed to destroy VM ${VM_NAME}"
        exit 1
    fi
}


function wait_until_vm_is_running() {
    MAX_RETRIES=15
    TRIES=0
    while true
    do
        vm_status=$(get_vm_status)
        if [ "${vm_status}" == "running" ]; then
            echo "VM ${VM_NAME} is running"
            return 0
        else
            if [[ ${TRIES} -ge ${MAX_RETRIES} ]];then
                echo "Failed to power on VM ${VM_NAME}"
                exit 1
            fi
            TRIES=$((TRIES + 1))
            echo "Failed to power on VM ${VM_NAME}. Checkng again in 10 seconds. Retry [${TRIES}/${MAX_RETRIES}]"
            sleep 10
        fi
    done
}

function wait_until_vm_is_stopped() {
    MAX_RETRIES=15
    TRIES=0
    while true
    do
        vm_status=$(get_vm_status)
        if [ "${vm_status}" == "shut" ]; then
            echo "VM ${VM_NAME} is powered off"
            return 0
        else
            if [[ ${TRIES} -ge ${MAX_RETRIES} ]];then
                echo "Failed to power off VM ${VM_NAME} gracefully within ${MAX_RETRIES} retries. Destroying VM ${VM_NAME}"
                destroy_vm
            fi
            TRIES=$((TRIES + 1))
            echo "VM ${VM_NAME} not yet powered off. Checking again in 10 seconds. Retry [${TRIES}/${MAX_RETRIES}]"
            sleep 10
        fi
    done
}

function get_cdrom_drive(){    
    virsh -c qemu+ssh://${BMC_USERNAME}@${BMC_ENDPOINT}/system dumpxml ${VM_NAME} | grep -A7 "device='cdrom'" | sed -n "s/.*<target dev='\([^']*\)'.*/\1/p" | head -n 1
}

function remote_download_iso() {
    ssh -t ${BMC_USERNAME}@${BMC_ENDPOINT} "rm /tmp/${VM_NAME}.iso"
    ssh -t ${BMC_USERNAME}@${BMC_ENDPOINT} "curl -k -C - -o /tmp/${VM_NAME}.iso ${ISO}"
    if [ $? -eq 0 ]; then
        echo "Downloaded ${ISO_NAME} successfully"
        echo "/tmp/${ISO_NAME}"
    else
        echo "Failed to download ${ISO_NAME}"
        exit 1
    fi
}

function mount_iso_in_cdrom() {
    iso_name=${1}
    cdrom_drive=${2}

    virsh -c qemu+ssh://${BMC_USERNAME}@${BMC_ENDPOINT}/system change-media ${VM_NAME} --path ${cdrom_drive} --source ${iso_name} --config
    if [ $? -eq 0 ]; then
        echo "Mounted ${iso_name} successfully"
        return 0
    else
        echo "Failed to mount ${iso_name}"
        return 1
    fi
}

function get_mounted_iso() {
    mounted_iso=$(virsh -c qemu+ssh://${BMC_USERNAME}@${BMC_ENDPOINT}/system dumpxml ${VM_NAME} | grep -A7 "device='cdrom'" | sed -n "s/.*<source file='\([^']*\)'.*/\1/p" | head -n 1)
    echo ${mounted_iso}
}

function unmount_iso_in_cdrom() {
    cdrom_drive=${1}

    mounted_iso=$(get_mounted_iso)
    if [ -z "${mounted_iso}" ]; then
        echo "No iso mounted"
        return 0
    fi
    
    output_string=$(virsh -c qemu+ssh://${BMC_USERNAME}@${BMC_ENDPOINT}/system change-media ${VM_NAME} --path ${cdrom_drive} --eject --config 2>&1)
    if [ $? -eq 0 ]; then
        echo "Unmounted ${mounted_iso} successfully"
        return 0
    elif [[ ${output_string} == *"doesn't have media"* ]]; then
        echo "Virsh claims media not mounted"
        return 0
    else
        echo "Failed to unmount ${mounted_iso}"
        return 1
    fi
}