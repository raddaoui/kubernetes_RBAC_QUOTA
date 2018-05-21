# Configuring RBAC for Users in Your Kubernetes Cluster

## Introduction

This guide will go through the basic Kubernetes Role-Based Access Control (RBAC) API Objects. 
From Kubernetes 1.6 onwards, RBAC policies are enabled by default. RBAC policies are vital for the correct management of your cluster, as they allow you to specify which types of actions are permitted depending on the user and their role in your organization. Examples include:

- Secure your cluster by granting privileged operations (accessing secrets, for example) only to admin users.
- Force user authentication in your cluster.
- Limit resource creation (such as pods, persistent volumes, deployments) to specific namespaces. You can also use quotas to ensure that resource usage is limited and under control.
- Have a user only see resources in their authorized namespace. This allows you to isolate resources within your organization (for example, between departments).

This guide will show you how to work with RBAC so you can properly configure user access on your cluster.

## RBAC API Objects

One basic Kubernetes feature is that all its resources are modeled API objects, which allow CRUD (Create, Read, Update, Delete) operations. Examples of resources are Pods, PersistentVolumes, Configmaps, Deployment, Nodes, Secrets, Namespaces, etc.

The operation which can be performed over these resource are

- create: Create will create a specific resource.
- get: Get will retrieve a specific resource object by name.
- delete: Delete will delete a resource.
- list: List will retrieve all resource objects of a specific type within a namespace
- update: update lets a user update the entire resource spec.
- watch: Watch will stream results for an object(s) as it is updated. Similar to a callback, watch is used to respond to resource changes
- patch: patch will make partial changes to an existing resource

At a higher level, resources are associated with API Groups (for example, Pods belong to the core API group whereas Deployments belong to the apps API group). For more information about all available resources, operations, and API groups, check the Official Kubernetes API Reference.

To manage RBAC in Kubernetes, apart from resources and operations, we need the following elements:

- Rules: A rule is a set of operations (verbs) that can be carried out on a group of resources which belong to different API Groups.
- Roles and ClusterRoles: Both consist of rules. The difference between a Role and a ClusterRole is the scope: in a Role, the rules are applicable to a single namespace, whereas a ClusterRole is cluster-wide, so the rules are applicable to more than one namespace. ClusterRoles can define rules for cluster-scoped resources (such as nodes) as well. Both Roles and ClusterRoles are mapped as API Resources inside our cluster.
- Subjects: These correspond to the entity that attempts an operation in the cluster. There are three types of subjects:
  - User Accounts: These are global, and meant for humans or processes living outside the cluster. There is no associated resource API Object in the Kubernetes cluster.
  - Service Accounts: This kind of account is namespaced and meant for intra-cluster processes running inside pods, which want to authenticate against the API.
  - Groups: This is used for referring to multiple accounts. There are some groups created by default such as cluster-admin (explained in later sections).
- RoleBindings and ClusterRoleBindings: Just as the names imply, these bind subjects to roles (i.e. the operations a given user can perform). As for Roles and ClusterRoles, the difference lies in the scope: a RoleBinding will make the rules effective inside a namespace, whereas a ClusterRoleBinding will make the rules effective in all namespaces.

You can find examples of each API element in the Kubernetes [official documentation](https://kubernetes.io/docs/admin/authorization/rbac/).

Below is a genral example of clusterrole with maximium privlilages, this can be used as example to edit details to create our own clusterole.

### ClusterRole Example

```yaml
---
apiVersion: rbac.authorization.k8s.io/v1alpha1
kind: ClusterRole
metadata:
  name: cluster-read-all
rules:
  -
    apiGroups:
      - "" #core-api-group
      - apps
      - autoscaling
      - batch
      - extensions
      - policy
      - rbac.authorization.k8s.io
    resources:
      - componentstatuses
      - configmaps
      - daemonsets
      - deployments
      - events
      - endpoints
      - horizontalpodautoscalers
      - ingress
      - jobs
      - limitranges
      - namespaces
      - nodes
      - pods
      - persistentvolumes
      - persistentvolumeclaims
      - resourcequotas
      - replicasets
      - replicationcontrollers
      - serviceaccounts
      - services
    verbs:
      - get
      - watch
      - list
      - create
      - delete
      - update
      - patch
  - nonResourceURLs: ["*"]
    verbs:
      - get
      - watch
      - list
```

To divide a cluster between multiple users, there are existing cluster roles pre-configured to help with that. We can grant users admin privileges in their own namespace using admin cluster role or grant viewing permission in other namespaces using view cluster role.

The default ClusterRoles are a great place to start for a basic set of permissions. If you’re concerned about the complexity of roles but still want to implement RBAC in your cluster, you can start by using default cluster roles provided automatically by Kubernetes. These are visible in the output of kubectl get clusterrole, and four that you can use right away are:

```sh
$ kubectl get clusterroles

NAME                   KIND                                       RULES
admin                  ClusterRole.v1.rbac.authorization.k8s.io   11 item(s)
cluster-admin          ClusterRole.v1.rbac.authorization.k8s.io   2 item(s)
edit                   ClusterRole.v1.rbac.authorization.k8s.io   9 item(s)
view                   ClusterRole.v1.rbac.authorization.k8s.io   7 item(s)
… [truncated] …
```

With these roles, you can start to define who can interact with your cluster and in what way, and if you follow the **principle of least privilege**, you will grant additional privileges as necessary for work to proceed. Running ```kubectl describe clusterrole {name}``` will show you information about the ClusterRole, and if you get the information with ```-o yaml```, you can copy it, edit it, and create new Roles and ClusterRoles for your users and resources.

## Verifying Access

We have created the RoleBinding, but how does an administrator verify the Roles for a user? For this, we'll use the auth can-i command to impersonate users and test their accounts against the RBAC policies in place.

For example, to verify users1’s access to pods in the user-1 namespace:

```sh
$ kubectl auth can-i get pods --namespace user-1 --as user1
yes
```

Does user1 have access to create deployments in the user-1 namespace?

```sh
$ kubectl auth can-i create deployments --namespace user-1 --as user1
no
```
