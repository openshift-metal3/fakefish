# Running FakeFish on OCP

This document describes how FakeFish can be run in an OpenShift cluster. This may be useful when dealing with hardware that does not support RedFish and you still want to provision it from OpenShift using tooling like RHACM or Metal3.

## Preparing our FakeFish image

Before deploying FakeFish, we need our FakeFish image with the custom scripts we will be using for the hardware we plan to manage with FakeFish. You can refer to the [project's readme](https://github.com/openshift-metal3/fakefish/blob/main/README.md#building-your-own-fakefish-container-image) to see how you can build a custom FakeFish image with your scripts.

## Deploying FakeFish on OpenShift

Once you have your custom FakeFish image, we can get it deployed on OpenShift following the steps below.

**Considerations**

For this example we will not run FakeFish with TLS enabled, we will do TLS offloading using a `Edge` Route on OpenShift. Other options may use a `Passthrough` or `Reencrypt` Route depending on what you want to achieve.

We will run three FakeFish instances for our three servers that do not support RedFish, their IPs are 192.168.10.10, 192.168.10.20 and 192.168.10.30.

1. First, we create a namespace:

    ~~~sh
    oc create namespace fakefish
    ~~~

2. We can now create the deployments, services and routes for our FakeFish instances:

    ~~~sh
    FAKEFISH_IMAGE=quay.io/mavazque/fakefish:latest
    for bmc in 192.168.10.10 192.168.10.20 192.168.10.30
    do
        BMC_NAME=$(echo ${bmc} | tr "." "-")
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
              containers:
              - image: ${FAKEFISH_IMAGE}
                name: fakefish
                resources: {}
                args:
                - "--remote-bmc"
                - "${bmc}"
                - "--tls-mode"
                - "disabled"
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

3. At this point we should have something like this:

    ~~~sh
    $ oc -n fakefish get deployment,svc,route

    NAME                                     READY   UP-TO-DATE   AVAILABLE   AGE
    deployment.apps/fakefish-192-168-10-10   1/1     1            1           13m
    deployment.apps/fakefish-192-168-10-20   1/1     1            1           13m
    deployment.apps/fakefish-192-168-10-30   1/1     1            1           13m

    NAME                             TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
    service/fakefish-192-168-10-10   ClusterIP   172.30.108.129   <none>        9000/TCP   4m19s
    service/fakefish-192-168-10-20   ClusterIP   172.30.205.167   <none>        9000/TCP   4m17s
    service/fakefish-192-168-10-30   ClusterIP   172.30.171.112   <none>        9000/TCP   4m16s

    NAME                                              HOST/PORT                                                           PATH   SERVICES                 PORT   TERMINATION   WILDCARD
    route.route.openshift.io/fakefish-192-168-10-10   fakefish-192-168-10-10-fakefish.apps.mario-ipi.e2e.bos.redhat.com          fakefish-192-168-10-10   http   edge          None
    route.route.openshift.io/fakefish-192-168-10-20   fakefish-192-168-10-20-fakefish.apps.mario-ipi.e2e.bos.redhat.com          fakefish-192-168-10-20   http   edge          None
    route.route.openshift.io/fakefish-192-168-10-30   fakefish-192-168-10-30-fakefish.apps.mario-ipi.e2e.bos.redhat.com          fakefish-192-168-10-30   http   edge          None
    ~~~

4. And if we access one of the routes we can see that FakeFish will reply:

    ~~~sh
    $ curl -k https://fakefish-192-168-10-20-fakefish.apps.mario-ipi.e2e.bos.redhat.com/redfish/v1/

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

5. Now we just need to configure our install-config or baremetalhost to use this route as the RedFish endpoint like this:

    ~~~yaml
    apiVersion: metal3.io/v1alpha1
    kind: BareMetalHost
    metadata:
      name: master-0-sno
      namespace: openshift-machine-api
    spec:
      online: true
      bootMACAddress: de:ad:bb:f3:22:05
      automatedCleaningMode: disabled
      rootDeviceHints:
        deviceName: /dev/sda
      bmc:
        address: redfish-virtualmedia://fakefish-192-168-10-10-fakefish.apps.mario-ipi.e2e.bos.redhat.com/redfish/v1/Systems/1
        credentialsName: master-0-sno
        disableCertificateVerification: true
    ~~~