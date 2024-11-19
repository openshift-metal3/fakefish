# Running FakeFish for KVM Guests

This document describes how fakefish can be used to manage KVM guests.This is helpful when you want to use kvm vm's as baremetal nodes in OCP.

# Preparing your KVM environments
The KVM scripts requires

1 SSH access to the KVM hosts for your VM's.To achieve this you can

- Determine a remote user that will have access to libvirtd on your KVM hosts. User must have permission to list vm's,power on, power off, change VM information.

- Determine a local user on the instance this script will be run in and get ssh key access to your remote KVM hosts. i.e As local-user run ssh-keygen and then ssh-copy-id remote-user@kvm_host as the user that will run the kvm scripts.  

2    We need our FakeFish image with the KVM custom scripts. You can refer to the [project's readme](https://github.com/openshift-metal3/fakefish/blob/main/README.md#building-your-own-fakefish-container-image) to see how you can build a custom FakeFish image with the scripts in [KVM custom scripts folder](../kvm_scripts/).

3 Run a podman instance for every VM guest as local-user e.g
    
```  
podman run -d --name ${podman_instance_name} \
--userns=keep-id -v ~/.ssh/id_rsa:/opt/fakefish/.ssh/id_rsa:z \
-p ${port}:${port} ${custom_kvm_script_image} \
--listen-port ${port} --remote-bmc ${kvm_host_ip} --vm-name ${vm_worker_domain_name}
```
where
- podman_instance_name: Can be any name that helps seperate the redfish instances for your VM's.
- userns=keep-id: Forces podman to run the container with the same user id as the local-user, so we can assess the ssh_keys
- ~/.ssh/id_rsa: the ssh key location are hardcorded in the containerfile in [KVM custom scripts Containerfile](../kvm_scripts/Containerfile).Keys themselves are not added into the containerfile only as a volume at runtime.
- custom_kvm_script_image: Location of the custom image built from [KVM custom scripts Containerfile](../kvm_scripts/Containerfile).
- port: Any unused port
- kvm_host_ip: Host Ip for the KVM host for VM.
- vm_name: VM domain name from virsh list



#Troublshooting

- When using virtio for guest, BMH should be updated with correct rootdevice hint.
    ```yaml
    spec:
    rootDeviceHints:
        deviceName: /dev/vda
    ```
- Depending on the speed of your host/guests you might need to power on the BMH after provisioning. 

    
