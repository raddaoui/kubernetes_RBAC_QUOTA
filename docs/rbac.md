#Configuring RBAC for Users in Your Kubernetes Cluster

##Introduction

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

- create
- get
- delete 
- list
- udpate
- edit
- watch
- exec

At a higher level, resources are associated with API Groups (for example, Pods belong to the core API group whereas Deployments belong to the apps API group). For more information about all available resources, operations, and API groups, check the Official Kubernetes API Reference.

To manage RBAC in Kubernetes, apart from resources and operations, we need the following elements:

- Rules: A rule is a set of operations (verbs) that can be carried out on a group of resources which belong to different API Groups.
- Roles and ClusterRoles: Both consist of rules. The difference between a Role and a ClusterRole is the scope: in a Role, the rules are applicable to a single namespace, whereas a ClusterRole is cluster-wide, so the rules are applicable to more than one namespace. ClusterRoles can define rules for cluster-scoped resources (such as nodes) as well. Both Roles and ClusterRoles are mapped as API Resources inside our cluster.
- Subjects: These correspond to the entity that attempts an operation in the cluster. There are three types of subjects:
	- User Accounts: These are global, and meant for humans or processes living outside the cluster. There is no associated resource API Object in the Kubernetes cluster.
	- Service Accounts: This kind of account is namespaced and meant for intra-cluster processes running inside pods, which want to authenticate against the API.
	- Groups: This is used for referring to multiple accounts. There are some groups created by default such as cluster-admin (explained in later sections).
- RoleBindings and ClusterRoleBindings: Just as the names imply, these bind subjects to roles (i.e. the operations a given user can perform). As for Roles and ClusterRoles, the difference lies in the scope: a RoleBinding will make the rules effective inside a namespace, whereas a ClusterRoleBinding will make the rules effective in all namespaces.

You can find examples of each API element in the Kubernetes official documentation.

The RBAC API covers four top-level types which will be covered in this section.

### Roles and ClusterRole

In the RBAC API, a role contains rules that represent a set of permissions. 
**Note: Permissions are purely additive (there are no “deny” rules)**
A Role can only be used to grant access to resources within a single namespace. Here’s an example Role in the “user-1” namespace that can be used to grant read access to pods:

```yaml
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: default
  name: pod-reader
rules:
- apiGroups: [""] # "" indicates the core API group
  resources: ["pods"]
  verbs: ["get", "watch", "list"]
```
A ClusterRole can be used to grant the same permissions as a Role, but because they are cluster-scoped, they can also be used to grant access to:

- cluster-scoped resources (like nodes)
- non-resource endpoints (like “/healthz”)
- namespaced resources (like pods) across all namespaces (needed to run kubectl get pods --all-namespaces, for example)

The following ClusterRole can be used to grant read access to secrets in any particular namespace, or across all namespaces (depending on how it is bound):

```yaml
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  # "namespace" omitted since ClusterRoles are not namespaced
  name: secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "watch", "list"]
```
To divide a cluster between multiple users, there are existing cluster roles pre-configured to help with that. We can grant users admin privileges in their own namespace using admin cluster role or grant viewing permission in other namespaces using view cluster role.

The default ClusterRoles are a great place to start for a basic set of permissions. If you’re concerned about the complexity of roles but still want to implement RBAC in your cluster, you can start by using default cluster roles provided automatically by Kubernetes. These are visible in the output of kubectl get clusterrole, and four that you can use right away are:

```
$ kubectl get clusterroles

NAME                   KIND                                       RULES
admin                  ClusterRole.v1.rbac.authorization.k8s.io   11 item(s)
cluster-admin          ClusterRole.v1.rbac.authorization.k8s.io   2 item(s)
edit                   ClusterRole.v1.rbac.authorization.k8s.io   9 item(s)
view                   ClusterRole.v1.rbac.authorization.k8s.io   7 item(s)
… [truncated] …
```

With these roles, you can start to define who can interact with your cluster and in what way, and if you follow the **principle of least privilege**, you will grant additional privileges as necessary for work to proceed. Running ```kubectl describe clusterrole {name}``` will show you information about the ClusterRole, and if you get the information with ```-o yaml```, you can copy it, edit it, and create new Roles and ClusterRoles for your users and resources.

###RoleBinding and ClusterRoleBinding

A role binding grants the permissions defined in a role to a user or set of users. It holds a list of subjects (users, groups, or service accounts), and a reference to the role being granted. Permissions can be granted within a namespace with a RoleBinding, or cluster-wide with a ClusterRoleBinding.

A RoleBinding may reference a Role in the same namespace. The following RoleBinding grants the “pod-reader” role to the user “user1@email.com” within the “user-1” namespace. This allows “user1” to read pods in the “user-1” namespace.

```yaml
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: read-pods
  namespace: user-1
subjects:
- kind: User
  name: user1@email.com # Name is case sensitive
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```
A RoleBinding may also reference a ClusterRole to grant the permissions to namespaced resources defined in the ClusterRole within the RoleBinding’s namespace. This allows administrators to define a set of common roles for the entire cluster, then reuse them within multiple namespaces.
For instance, even though the following RoleBinding refers to a ClusterRole, “user2” (the subject, case sensitive) will only be able to read secrets in the “user-2” namespace (the namespace of the RoleBinding).

```yaml
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: read-secrets
  namespace: user-2 # This only grants permissions within the "development" namespace.
subjects:
- kind: User
  name: user2@email.com # Name is case sensitive
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: secret-reader
  apiGroup: rbac.authorization.k8s.io
```

Finally, a ClusterRoleBinding may be used to grant permission at the cluster level and in all namespaces. The following ClusterRoleBinding allows any user in the group “manager” to read secrets in any namespace.

```yaml
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: read-secrets-global
subjects:
- kind: Group
  name: manager # Name is case sensitive
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: secret-reader
  apiGroup: rbac.authorization.k8s.io
```
##Verifying Access
We have created the RoleBinding, but how does an administrator verify the Roles for a user? For this, we'll use the auth can-i command to impersonate users and test their accounts against the RBAC policies in place.

For example, to verify users1’s access to pods in the user-1 namespace:

```
$ kubectl auth can-i get pods --namespace user-1 --as user1
yes
```
Does user1 have access to create deployments in the user-1 namespace?

```
$ kubectl auth can-i create deployments --namespace dev --as joe
no
```
##Common Cluster RBAC Policies for Users

**Default Role**
Given to all users in the system, would help in discovery and common read only operations

```yaml
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1alpha1
metadata:
  name: default-reader
rules:
  - apiGroups: [""]
    resources:
      - componentstatuses
      - events
      - endpoints
      - namespaces
      - nodes
      - persistentvolumes
      - resourcequotas
      - services
    verbs: ["get", "watch", "list"]
  - nonResourceURLs: ["*"]
    verbs: ["get", "watch", "list"]
```
Appropriate binding would be:

```yaml
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1alpha1
metadata:
  name: default-reader-role-binding
subjects:
  - kind: User
    name: "*"
roleRef:
  kind: ClusterRole
  name: default-reader
  apiVersion: rbac.authorization.k8s.io/v1alpha1
```

**Read all**

Can be given to pseudo admins (like schedulers), for readonly operations. Not given by default to anyone. Can read everything except secrets

```yaml
---
apiVersion: rbac.authorization.k8s.io/v1alpha1
kind: ClusterRole
metadata:
  name: cluster-read-all
rules:
  -
    apiGroups:
      - ""
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
  - nonResourceURLs: ["*"]
    verbs:
      - get
      - watch
      - list

```