function stop_vm() {
  MAX_RETRIES=25
  TRIES=0
  VM_RUNNING_OUTPUT=$(virtctl -n ${VM_NAMESPACE} stop ${VM_NAME} 2>&1 >/dev/null || true)
  if grep -q "VM is not running" <<< "${VM_RUNNING_OUTPUT}"; then
    return 0
  else
    while true
    do
      VM_RUNNING_OUTPUT=$(virtctl -n ${VM_NAMESPACE} stop ${VM_NAME} 2>&1 >/dev/null || true)
      if grep -q "VM is not running" <<< "${VM_RUNNING_OUTPUT}"; then
        return 0
      else
        if [[ ${TRIES} -ge ${MAX_RETRIES} ]];then
          echo "Failed to poweroff VM"
          return 1
        fi
        TRIES=$((TRIES + 1))
        echo "Failed to poweroff VM. Retrying in 5 seconds. Retry [${TRIES}/${MAX_RETRIES}]"
        sleep 2
      fi
    done
  fi
}

function start_vm() {
  MAX_RETRIES=25
  TRIES=0
  VM_RUNNING_OUTPUT=$(virtctl -n ${VM_NAMESPACE} start ${VM_NAME} 2>&1 >/dev/null || true)
  if grep -q "VM is already running" <<< "${VM_RUNNING_OUTPUT}"; then
    return 0
  else
    while true
    do
      VM_RUNNING_OUTPUT=$(virtctl -n ${VM_NAMESPACE} start ${VM_NAME} 2>&1 >/dev/null || true)
      if grep -q "VM is already running" <<< "${VM_RUNNING_OUTPUT}"; then
        return 0
      else
        if [[ ${TRIES} -ge ${MAX_RETRIES} ]];then
          echo "Failed to poweron VM"
          return 1
        fi
        TRIES=$((TRIES + 1))
        echo "Failed to poweron VM. Retrying in 5 seconds. Retry [${TRIES}/${MAX_RETRIES}]"
        sleep 2   
      fi
    done
  fi
}