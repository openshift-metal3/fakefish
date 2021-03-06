# FakeFish

> **WARNING**: The work exposed here is not supported in any way by Red Hat, this is the result of exploratory work. Use at your own risk.

`FakeFish` is a flask based app that exposes a RedFish-like API with a set of limited endpoints that allow the deployment of OpenShift nodes via the Metal3 operator on hardware that doesn't support RedFish or doesn't follow the RedFish standard.

The way it works is by running a set of scripts that interact with the hardware using vendor tools/other methods while exposing a fake RedFish API that Metal3 can query.

The [app/](./app/) directory contains the FakeFish application. Inside the [custom_scripts](./app/custom_scripts/) folder we need to create the following scripts:

|Script|What should it do?|Env Vars|Script parameters|
|------|------------------|--------|-----------------|
|`poweron.sh`|Power on the server|BMC_ENDPOINT BMC_USERNAME BMC_PASSWORD|None|
|`poweroff.sh`|Power off the server|BMC_ENDPOINT BMC_USERNAME BMC_PASSWORD|None|
|`bootfromcdonce.sh`|Set server to boot from virtual CD once|BMC_ENDPOINT BMC_USERNAME BMC_PASSWORD|None|
|`mountcd.sh`|Mount the iso received in the server's virtual CD|BMC_ENDPOINT BMC_USERNAME BMC_PASSWORD| `$1` ISO FILE URL|
|`unmountcd.sh`|Unmount the iso from the server's virtual CD|BMC_ENDPOINT BMC_USERNAME BMC_PASSWORD|None|

The script names must match above naming, you can check the [dell_scripts](./dell_scripts/) folder to find example scripts with the correct naming.

> **NOTE**: Dell scripts linked above are only meant to show how someone could implement the required scripts to make custom hardware compatible with FakeFish. Dell hardware is supported by the `idrac-virtualmedia` provider in Metal3. **These scripts are unsupported/unmaintained** and should be taken as a reference, nothing else.

Users need to implement their own scripts, we will not maintain/add providers to this project.

A [Containerfile](./custom_scripts/Containerfile) is included, so users can build their own container image out of it.

## Building your own FakeFish container image

1. Place your custom scripts inside the [custom_scripts](./custom_scripts/) folder.
2. Run the build command:

    > **NOTE**: Check the Makefile vars to customize the output container image naming and tag.

    > **NOTE2**: If you plan to run self-signed TLS certs, add them to the app/ folder before running the make command and make sure the cert names are properly configured in the Containerfile.

    ~~~sh
    make build-custom
    ~~~

## Usage

You need a FakeFish process for each server you plan to install. Think of FakeFish like if it was a custom implementation of a BMC for that specific server.

Currently, FakeFish exposes the following arguments:

|Argument|What is it used for|Default|Required|
|--------|-------------------|-------|--------|
|`--tls-mode`|Configures TLS for FakeFish, three available modes: `adhoc` (FakeFish generated certs), `self-signed` (user provided certs), `disabled` (TLS disabled).|`adhoc`|No|
|`--cert-file`|Configures the certificate public key that will be used in `self-signed` tls mode.|`./cert.pem`|No|
|`--key-file`|Configures the certificate private key that will be used in `self-signed` tls mode.|`./cert.key`|No|
|`--remote-bmc` or `-r`|Defines the BMC IP a FakeFish instance will connect to.|`None`|Yes|
|`--listen-port` or `-p`|Defines the port a FakeFish instance will listen on.|`9000`|No|
|`--debug` or `-d`|Starts a FakeFish instance in debug mode.|`False`|No|

Since you will be potentially running multiple FakeFish instances, you will make use of the `--listen-port` argument to configure in which port a given FakeFish instance listens on and `--remote-bmc` to configure which BMC IP it provides service to. On top of that, you can do a bind mount for the folder containing the scripts for managing that specific server or use the scripts inside the container image.

An example can be found below:

> **NOTE**: Every container is mapped to a single BMC, but if more hosts are required, different ports can be used (9001, 9002,...)

~~~sh
podman run -p 9000:9000 -v $PWD/dell_scripts:/opt/fakefish/custom_scripts:z quay.io/mavazque/fakefish:latest --listen-port 9000 --remote-bmc 172.20.10.10

sudo firewall-cmd --add-port=9000/tcp
~~~

Then, in the `install-config.yaml` file, it is required to specify the IP where the container is running instead of the 'real' BMC:

~~~yaml
bmcAddress: redfish-virtualmedia://192.168.1.10:9000/redfish/v1/Systems/1
~~~

## Logs

In a successful execution you should see something like this in the logs:

- Starting FakeFish

    ~~~sh
    $ podman run -p 9000:9000 -v $PWD/dell_scripts:/opt/fakefish/custom_scripts:z quay.io/mavazque/fakefish:latest --listen-port 9000 --remote-bmc 172.20.10.10

     * Serving Flask app 'fakefish' (lazy loading)
     * Environment: production
       WARNING: This is a development server. Do not use it in a production deployment.
       Use a production WSGI server instead.
     * Debug mode: off
     * Running on all addresses.
       WARNING: This is a development server. Do not use it in a production deployment.
     * Running on https://10.19.3.25:9000/ (Press CTRL+C to quit)
    ~~~

- Provisioning Logs

    ~~~sh
    10.19.3.23 - - [20/Apr/2022 13:17:09] "GET /redfish/v1/Systems/1 HTTP/1.1" 200 -
    10.19.3.23 - - [20/Apr/2022 13:17:09] "GET /redfish/v1/Systems/1 HTTP/1.1" 200 -
    10.19.3.23 - - [20/Apr/2022 13:17:09] "GET /redfish/v1/Systems/1/BIOS HTTP/1.1" 404 -
    10.19.3.23 - - [20/Apr/2022 13:17:09] "GET /redfish/v1/Systems/1 HTTP/1.1" 200 -
    10.19.3.23 - - [20/Apr/2022 13:17:09] "GET /redfish/v1/Systems/1 HTTP/1.1" 200 -
    10.19.3.23 - - [20/Apr/2022 13:17:09] "GET /redfish/v1/Systems/1 HTTP/1.1" 200 -
    10.19.3.23 - - [20/Apr/2022 13:17:24] "GET /redfish/v1/Systems/1 HTTP/1.1" 200 -
    10.19.3.23 - - [20/Apr/2022 13:17:24] "GET /redfish/v1/Systems/1 HTTP/1.1" 200 -
    10.19.3.23 - - [20/Apr/2022 13:17:24] "GET /redfish/v1/Systems/1 HTTP/1.1" 200 -
    10.19.3.23 - - [20/Apr/2022 13:18:24] "GET /redfish/v1/Systems/1 HTTP/1.1" 200 -
    10.19.3.23 - - [20/Apr/2022 13:18:24] "GET /redfish/v1/Systems/1 HTTP/1.1" 200 -
    10.19.3.23 - - [20/Apr/2022 13:18:24] "GET /redfish/v1/Systems/1 HTTP/1.1" 200 -
    10.19.3.23 - - [20/Apr/2022 13:18:27] "GET /redfish/v1/Systems/1 HTTP/1.1" 200 -
    10.19.3.23 - - [20/Apr/2022 13:18:27] "GET /redfish/v1/Systems/1 HTTP/1.1" 200 -
    Security Alert: Certificate is invalid - self signed certificate
    Continuing execution. Use -S option for racadm to stop execution on certificate-related errors.
    Server is already powered OFF.                                               

    10.19.3.23 - - [20/Apr/2022 13:18:32] "POST /redfish/v1/Systems/1/Actions/ComputerSystem.Reset HTTP/1.1" 204 -
    10.19.3.23 - - [20/Apr/2022 13:18:33] "GET /redfish/v1/Systems/1 HTTP/1.1" 200 -
    10.19.3.23 - - [20/Apr/2022 13:18:33] "GET /redfish/v1/Systems/1 HTTP/1.1" 200 -
    10.19.3.23 - - [20/Apr/2022 13:18:33] "GET /redfish/v1/Systems/1 HTTP/1.1" 200 -
    10.19.3.23 - - [20/Apr/2022 13:18:33] "GET /redfish/v1/Managers/1 HTTP/1.1" 200 -
    10.19.3.23 - - [20/Apr/2022 13:18:33] "GET /redfish/v1/Managers/1/VirtualMedia HTTP/1.1" 200 -
    10.19.3.23 - - [20/Apr/2022 13:18:33] "GET /redfish/v1/Managers/1/VirtualMedia/Cd HTTP/1.1" 200 -
    10.19.3.23 - - [20/Apr/2022 13:18:33] "GET /redfish/v1/Systems/1 HTTP/1.1" 200 -
    10.19.3.23 - - [20/Apr/2022 13:18:33] "GET /redfish/v1/Systems/1 HTTP/1.1" 200 -
    10.19.3.23 - - [20/Apr/2022 13:18:33] "GET /redfish/v1/Managers/1 HTTP/1.1" 200 -
    10.19.3.23 - - [20/Apr/2022 13:18:34] "GET /redfish/v1/Managers/1/VirtualMedia HTTP/1.1" 200 -
    10.19.3.23 - - [20/Apr/2022 13:18:34] "GET /redfish/v1/Managers/1/VirtualMedia/Cd HTTP/1.1" 200 -
    Security Alert: Certificate is invalid - self signed certificate
    Continuing execution. Use -S option for racadm to stop execution on certificate-related errors.
    Disable Remote File Started. Please check status using -s                    
    option to know Remote File Share is ENABLED or DISABLED.

    Security Alert: Certificate is invalid - self signed certificate
    Continuing execution. Use -S option for racadm to stop execution on certificate-related errors.
    Remote Image is now Configured                                               

    ShareName http://10.19.3.23:6180/redfish/boot-dc055836-d26c-4256-ba6c-222e8d4559be.iso
    10.19.3.23 - - [20/Apr/2022 13:18:48] "POST /redfish/v1/Managers/1/VirtualMedia/Cd/Actions/VirtualMedia.InsertMedia HTTP/1.1" 204 -
    10.19.3.23 - - [20/Apr/2022 13:18:48] "GET /redfish/v1/Systems/1 HTTP/1.1" 200 -
    Security Alert: Certificate is invalid - self signed certificate
    Continuing execution. Use -S option for racadm to stop execution on certificate-related errors.
    [Key=iDRAC.Embedded.1#VirtualMedia.1]                                        
    Object value modified successfully

    Security Alert: Certificate is invalid - self signed certificate
    Continuing execution. Use -S option for racadm to stop execution on certificate-related errors.
    [Key=iDRAC.Embedded.1#ServerBoot.1]                                          
    Object value modified successfully

    10.19.3.23 - - [20/Apr/2022 13:18:58] "PATCH /redfish/v1/Systems/1 HTTP/1.1" 204 -
    10.19.3.23 - - [20/Apr/2022 13:18:58] "GET /redfish/v1/Systems/1 HTTP/1.1" 200 -
    10.19.3.23 - - [20/Apr/2022 13:18:58] "GET /redfish/v1/Systems/1 HTTP/1.1" 200 -
    Security Alert: Certificate is invalid - self signed certificate
    Continuing execution. Use -S option for racadm to stop execution on certificate-related errors.
    Server power operation successful                                            

    10.19.3.23 - - [20/Apr/2022 13:19:04] "POST /redfish/v1/Systems/1/Actions/ComputerSystem.Reset HTTP/1.1" 204 -
    10.19.3.23 - - [20/Apr/2022 13:19:05] "GET /redfish/v1/Systems/1 HTTP/1.1" 200 -
    ~~~

- Deprovisioning Logs

    ~~~sh
    10.19.3.23 - - [20/Apr/2022 13:23:29] "GET /redfish/v1/Systems/1 HTTP/1.1" 200 -
    10.19.3.23 - - [20/Apr/2022 13:23:29] "GET /redfish/v1/Managers/1 HTTP/1.1" 200 -
    10.19.3.23 - - [20/Apr/2022 13:23:29] "GET /redfish/v1/Managers/1/VirtualMedia HTTP/1.1" 200 -
    10.19.3.23 - - [20/Apr/2022 13:23:29] "GET /redfish/v1/Managers/1/VirtualMedia/Cd HTTP/1.1" 200 -
    Security Alert: Certificate is invalid - self signed certificate
    Continuing execution. Use -S option for racadm to stop execution on certificate-related errors.
    Disable Remote File Started. Please check status using -s                    
    option to know Remote File Share is ENABLED or DISABLED.

    10.19.3.23 - - [20/Apr/2022 13:23:55] "POST /redfish/v1/Managers/1/VirtualMedia/Cd/Actions/VirtualMedia.EjectMedia HTTP/1.1" 204 -
    10.19.3.23 - - [20/Apr/2022 13:23:55] "GET /redfish/v1/Systems/1 HTTP/1.1" 200 -
    10.19.3.23 - - [20/Apr/2022 13:23:55] "GET /redfish/v1/Managers/1 HTTP/1.1" 200 -
    10.19.3.23 - - [20/Apr/2022 13:23:55] "GET /redfish/v1/Managers/1/VirtualMedia HTTP/1.1" 200 -
    10.19.3.23 - - [20/Apr/2022 13:23:55] "GET /redfish/v1/Managers/1/VirtualMedia/Cd HTTP/1.1" 200 -
    10.19.3.23 - - [20/Apr/2022 13:23:55] "GET /redfish/v1/Systems/1 HTTP/1.1" 200 -
    10.19.3.23 - - [20/Apr/2022 13:23:56] "GET /redfish/v1/Systems/1 HTTP/1.1" 200 -
    Security Alert: Certificate is invalid - self signed certificate
    Continuing execution. Use -S option for racadm to stop execution on certificate-related errors.
    Server power operation successful                                            

    10.19.3.23 - - [20/Apr/2022 13:24:09] "POST /redfish/v1/Systems/1/Actions/ComputerSystem.Reset HTTP/1.1" 204 -
    10.19.3.23 - - [20/Apr/2022 13:24:10] "GET /redfish/v1/Systems/1 HTTP/1.1" 200 -
    ~~~