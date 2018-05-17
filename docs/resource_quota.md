# Configuring Resource Quota per Namespace in your Kubernetes Cluster

## Overview

A resource quota, defined by a ResourceQuota object, provides constraints that limit aggregate resource consumption per namespace. It can limit the quantity of objects that can be created in a namespace by type, as well as the total amount of compute resources that may be consumed by resources in that namespace. If creating or updating a resource violates a quota constraint, the request will fail with HTTP status code 403 FORBIDDEN with a message explaining the constraint that would have been violated.

## Resources Managed by Qouta

| Resource Quota Type  |  Description |
|---|---|
| **Compute**  | **requests.cpu </br> requests.memory </br> limits.cpu </br> limits.memory**   |
| **Storage** |  **`<storage-class.name>`.storageclass.storage.k8s.io/requests.storage </br> `<storage-class.name>`.storageclass.storage.k8s.io/persistentvolumeclaims </br> persistentvolumeclaims </br> requests.storage** |
| **Object Count** | **pods </br> services </br> services.loadbalancers </br> services.nodeports </br> persitentvolumeclaims </br> resourcequotas </br> replicationcontrollers </br> configmaps </br> secrets**   |
| **Extended resources**|  **requests.nvidia.com/gpu** [more](https://kubernetes.io/docs/tasks/configure-pod-container/extended-resource/)  |

### Resource Quota Example

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-resources
spec:
hard:
    requests.cpu: "8"
    requests.memory: 32Gi
    limits.cpu: "16"
    limits.memory: 64Gi
    pods: "20"
    persistentvolumeclaims: "5"
    replicationcontrollers: "20"
    services: "20"
    services.loadbalancers: "5"
```

If quota is enabled in a namespace for compute resources like cpu and memory, users must specify requests or limits for those values; otherwise, the quota system may reject pod creation. Use the [LimitRange] (https://kubernetes.io/docs/tasks/administer-cluster/memory-default-namespace/) admission controller to force defaults for pods that make no compute resource requirements.
Here is example for limits manifest that you can create, which takes care of default values for pods that didn’t specify them:

 ```yaml
 apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
spec:
  limits:
  - default:
      cpu: 200m
      memory: 512Mi
    defaultRequest:
      cpu: 100m
      memory: 256Mi
    type: Container
 ```

What happens when we exceed a Resource Quota with a high level controller like Deployment:

```yaml
kubectl describe deploy/gateway-quota
Name:            gateway-quota
Namespace:        fail
CreationTimestamp:    Sat, 11 Feb 2017 16:33:16 -0500
Labels:            app=gateway
Selector:        app=gateway
Replicas:        1 updated | 3 total | 1 available | 2 unavailable
StrategyType:        RollingUpdate
MinReadySeconds:    0
RollingUpdateStrategy:    1 max unavailable, 1 max surge
OldReplicaSets:        
NewReplicaSet:        gateway-quota-551394438 (1/3 replicas created)
Events:
  FirstSeen    LastSeen    Count   From                SubObjectPath   Type        Reason          Message
  ---------    --------    -----   ----                -------------   --------    ------          -------
  9m        9m      1   {deployment-controller }            Normal      ScalingReplicaSet   Scaled up replica set gateway-quota-551394438 to 1
  5m        5m      1   {deployment-controller }            Normal      ScalingReplicaSet   Scaled up replica set gateway-quota-551394438 to 3
```

Lastline in description shows the ReplicaSet was told to scale to 3. Let's inspect the ReplicaSet using describe

```yaml
kubectl describe replicaset gateway-quota-551394438
Name:        gateway-quota-551394438
Namespace:    fail
Image(s):    nginx
Selector:    app=gateway,pod-template-hash=551394438
Labels:        app=gateway
        pod-template-hash=551394438
Replicas:    1 current / 3 desired
Pods Status:    1 Running / 0 Waiting / 0 Succeeded / 0 Failed
No volumes.
Events:
  FirstSeen    LastSeen    Count   From                SubObjectPath   Type        Reason          Message
  ---------    --------    -----   ----                -------------   --------    ------          -------
  11m        11m     1   {replicaset-controller }            Normal      SuccessfulCreate    Created pod: gateway-quota-551394438-pix5d
  11m        30s     33  {replicaset-controller }            Warning     FailedCreate        Error creating: pods "gateway-quota-551394438-" is forbidden: exceeded quota: compute-resources, requested: pods=1, used: pods=1, limited: pods=1
```

Steps to take in case of pending jobs:

- Ask your cluster admin to increase the Quota for this namespace
- Delete or scale back other Deployments in this namespace

**Note**: Setting a lower resource quota after creating resources does not rollback the existing resources, it waits for them to be completed and rejects new resources being created which do not follow the resource quota criteria.