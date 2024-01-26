# Running FakeFish on OCP for KubeVirt Endpoints

This document describes how FakeFish can be run in an OpenShift cluster for managing KubeVirt VMs. This may be useful when you want to use KubeVirt VMs as if they were baremetal nodes.

## Preparing our FakeFish image

Before deploying FakeFish, we need our FakeFish image with the KubeVirt custom scripts. You can refer to the [project's readme](https://github.com/openshift-metal3/fakefish/blob/main/README.md#building-your-own-fakefish-container-image) to see how you can build a custom FakeFish image with the scripts in [KubeVirt custom scripts folder](../kubevirt_scripts/).

## Deploying FakeFish on OpenShift

Once you have your custom FakeFish image, we can get it deployed on OpenShift following the steps below.

**Considerations**

For this example we will not run FakeFish with TLS enabled, we will do TLS offloading using a `Edge` Route on OpenShift. Other options may use a `Passthrough` or `Reencrypt` Route depending on what you want to achieve.

We will run three FakeFish instances for our three KubeVirt VMs, our VMs are created in the `virtual-cp` namespace and their names are `cp-node0`, `cp-node1` and `cp-node2`.

1. First, we create a namespace:

    ~~~sh
    oc create namespace fakefish
    ~~~

2. We create a secret with the KUBECONFIG to access the KubeVirt cluster.

    ~~~sh
    oc -n fakefish create secret generic kubevirt-cluster-kubeconfig --from-file=kubeconfig=/path/to/my/kubeconfig
    ~~~

3. We can now create the deployments, services, and routes for our FakeFish instances:

    > **IMPORTANT**: If you're using the scripts provided in the `kubevirt_scripts` folder, you must name the BMCs like `vm-name_vm-namespace`.

    ~~~sh
    FAKEFISH_IMAGE=<put_your_image_here>
    for bmc in cp-node0_virtual-cp cp-node1_virtual-cp cp-node2_virtual-cp
    do
        BMC_NAME=$(echo ${bmc} | tr "_" "-")
        cat <<EOF | oc apply -f -
        apiVersion: apps/v1
        kind: Deployment
        metadata:
          labels:
            app: fakefish-${BMC_NAME}
          name: fakefish-${BMC_NAME}
          namespace: fakefish
        spec:
          replicas: 1
          selector:
            matchLabels:
              app: fakefish-${BMC_NAME}
          strategy: {}
          template:
            metadata:
              labels:
                app: fakefish-${BMC_NAME}
            spec:
              volumes:
              - name: kubevirt-kubeconfig
                secret:
                  secretName: kubevirt-cluster-kubeconfig
              containers:
              - image: ${FAKEFISH_IMAGE}
                imagePullPolicy: Always
                name: fakefish
                resources: {}
                args:
                - "--remote-bmc"
                - "${bmc}"
                - "--tls-mode"
                - "disabled"
                volumeMounts:
                - name: kubevirt-kubeconfig
                  readOnly: true
                  mountPath: /var/tmp/
    EOF
        cat <<EOF | oc apply -f -
        apiVersion: v1
        kind: Service
        metadata:
          labels:
            app: fakefish-${BMC_NAME}
          name: fakefish-${BMC_NAME}
          namespace: fakefish
        spec:
          ports:
          - name: http
            port: 9000
            protocol: TCP
            targetPort: 9000
          selector:
            app: fakefish-${BMC_NAME}
          type: ClusterIP
    EOF
        cat <<EOF | oc apply -f -
        apiVersion: route.openshift.io/v1
        kind: Route
        metadata:
          name: fakefish-${BMC_NAME}
          namespace: fakefish
        spec:
          port:
            targetPort: http
          tls:
            termination: edge
          to:
            kind: "Service"
            name: fakefish-${BMC_NAME}
            weight: null
    EOF
    done
    ~~~

4. At this point we should have something like this:

    ~~~sh
    $ oc -n fakefish get deployment,svc,route

    NAME                                           READY   UP-TO-DATE   AVAILABLE   AGE
    deployment.apps/fakefish-cp-node0-virtual-cp   1/1     1            1           25m
    deployment.apps/fakefish-cp-node1-virtual-cp   1/1     1            1           25m
    deployment.apps/fakefish-cp-node2-virtual-cp   1/1     1            1           25m

    NAME                                   TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
    service/fakefish-cp-node0-virtual-cp   ClusterIP   172.30.148.110   <none>        9000/TCP   50m
    service/fakefish-cp-node1-virtual-cp   ClusterIP   172.30.143.245   <none>        9000/TCP   50m
    service/fakefish-cp-node2-virtual-cp   ClusterIP   172.30.6.241     <none>        9000/TCP   50m

    NAME                                                    HOST/PORT                                                PATH   SERVICES                       PORT   TERMINATION   WILDCARD
    route.route.openshift.io/fakefish-cp-node0-virtual-cp   fakefish-cp-node0-virtual-cp-fakefish.apps.example.com          fakefish-cp-node0-virtual-cp   http   edge          None
    route.route.openshift.io/fakefish-cp-node1-virtual-cp   fakefish-cp-node1-virtual-cp-fakefish.apps.example.com          fakefish-cp-node1-virtual-cp   http   edge          None
    route.route.openshift.io/fakefish-cp-node2-virtual-cp   fakefish-cp-node2-virtual-cp-fakefish.apps.example.com          fakefish-cp-node2-virtual-cp   http   edge          None
    ~~~

5. And if we access one of the routes we can see that FakeFish will reply:

    ~~~sh
    $ curl -k https://fakefish-cp-node0-virtual-cp-fakefish.apps.example.com/redfish/v1/

    {
        "@odata.type": "#ServiceRoot.v1_5_0.ServiceRoot",
        "Id": "FakeFishService",
        "Name": "FakeFish Service",
        "RedfishVersion": "1.5.0",
        "UUID": "not-that-production-ready",
        "Systems": {
            "@odata.id": "/redfish/v1/Systems"
        },
        "Managers": {
            "@odata.id": "/redfish/v1/Managers"
        },
        "@odata.id": "/redfish/v1/",
        "@Redfish.Copyright": "Copyright 2014-2016 Distributed Management Task Force, Inc. (DMTF). For the full DMTF copyright policy, see http://www.dmtf.org/about/policies/copyright."
    }
    ~~~

6. Now we just need to configure our install-config or baremetalhost to use this route as the RedFish endpoint like this:

    ~~~yaml
    apiVersion: metal3.io/v1alpha1
    kind: BareMetalHost
    metadata:
      name: control-plane-0
      namespace: openshift-machine-api
    spec:
      online: true
      bootMACAddress: de:ad:bb:f3:22:05
      automatedCleaningMode: disabled
      rootDeviceHints:
        deviceName: /dev/sda
      bmc:
        address: redfish-virtualmedia://fakefish-cp-node0-virtual-cp-fakefish.apps.example.com/redfish/v1/Systems/1
        credentialsName: control-plane-0
        disableCertificateVerification: true
    ~~~
