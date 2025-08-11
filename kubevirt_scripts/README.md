
# OCP scripts

These scripts are derivitives of the scripts in this repositories `kubevirt_scripts` directory and then modified to use populators to create the PVC for the CDROM ISO.


## Building

The container image can be built by running `make build-ocp`.


## Certificate issues

If you get certificate errors in the logs indicating issues with SAN IDs, you can try disabling TLS on virtual media.
Be aware this is less secure than using TLS, use with caution.

``` sh
oc edit provisionings.metal3.io provisioning-configuration
```

``` yaml
apiVersion: metal3.io/v1alpha1
kind: Provisioning
metadata:
  name: provisioning-configuration
spec:
  disableVirtualMediaTLS: true

[ OUTPUT TRUNCATED ]
```

