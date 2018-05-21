Add users to your kubernetes cluster, setup RBAC and limite their usable resource quota.
============================================================================================

Storyline
----------

I created a kubernetes cluster and I have admin role. Now, I want to add users to my cluster while giving them access only to their namespace and limit their resource usage to a certain quota.
How can I do that?

let's suppose that we want to add a user Harry Potter to our cluster with username harry-potter who belongs to the actors group. The user should also be able to only create/delete/edit resources in his namespace harry-potter-ns


`NOTE:` if you want to go throught the quick way execute the following command otherwise contiune reading below:

	bash create_new_user.sh harry-potter actors


Add users to your kubernetes cluster
---------------------------------------

1. create namespace that the user will own:

		kubectl create namespace harry-potter-ns

2. create user credentials: 

		# create user key
		openssl genrsa -out harry-potter.key 2048
		# create a certificate sign request for the user, `note how CN: common name has the username and O: organization has the group
		openssl req -new -key harry-potter.key -out harry-potter.csr -subj "/CN=harry-potter/O=actors"

3. create a certificate signing request manifest from the csr we just created


		cat <<EOF | kubectl create -f -
		apiVersion: certificates.k8s.io/v1beta1
		kind: CertificateSigningRequest
		metadata:
		  name: csr-harry-potter
		spec:
		  groups:
		  - system:authenticated
		  request: $(cat harry-potter.csr | base64 | tr -d '\n')
		  usages:
		  - digital signature
		  - key encipherment
		  - client auth
		EOF

4. approve the signing request by k8s cluster Certificate Authority

		kubectl certificate approve csr-harry-potter


setup RBAC
-----------

at the end of this section user will only have edit access to his namespace and view access clusterwise

5. allow user to only view k8s resources in all namespaces by binding the view cluster role to the newely created user. we use a clusterrole because we want to assign user a cluster wise view rights


		cat <<EOF | kubectl create -f -
		kind: ClusterRoleBinding
		apiVersion: rbac.authorization.k8s.io/v1beta1
		metadata:
		  name: harry-potter-view-all
		subjects:
		- kind: User
		  name: harry-potter
		  apiGroup: rbac.authorization.k8s.io
		roleRef:
		  kind: ClusterRole
		  name: view
		  apiGroup: rbac.authorization.k8s.io
		EOF

6. allow user to have complete access over his/her namespace


		cat <<EOF | kubectl create -f -
		kind: RoleBinding
		apiVersion: rbac.authorization.k8s.io/v1beta1
		metadata:
		  name: harry-potter-edit-own-ns
		  namespace: harry-potter-ns
		subjects:
		- kind: User
		  name: harry-potter
		  apiGroup: rbac.authorization.k8s.io
		roleRef:
		  kind: ClusterRole
		  name: edit
		  apiGroup: rbac.authorization.k8s.io
		EOF

For more examples on [RBAC](docs/rbac.md)

setup resource quota for the user namespace
----------------------------------------------

7. assign resource quotas to the namespace where user will be working. change them accoding to your needs


		cat <<EOF | kubectl create -f -
		apiVersion: v1
		kind: ResourceQuota
		metadata:
		  name: compute-resources
		  namespace: harry-potter-ns
		spec:
		  hard:
		    requests.cpu: "4"
		    requests.memory: 6Gi
		    limits.cpu: "8"
		    limits.memory: 12Gi
		    requests.nvidia.com/gpu: 2
		EOF

For more examples on [Resource Quota](docs/resource_quota.md)

create a kubeconfig file ready to be sent to the user for cluster access
--------------------------------------------------------------------------

8. get the user signed certificate

		kubectl get csr csr-harry-potter -o jsonpath='{.status.certificate}' | base64 --decode > harry-potter.crt

9. get cluster name and server from our kubernetes config


		CURRENT_CONTEXT=$(kubectl config current-context)
		CURRENT_CLUSTER=$(kubectl config get-contexts $CURRENT_CONTEXT | tail -1 | awk '{print $3}')
		CURRENT_SERVER=$(kubectl config view -o jsonpath="{.clusters[?(@.name=='$CURRENT_CLUSTER')].cluster.server}")


10. create a cluster, user and context entry in a new user-config file for convenience and set the current context to the created context.


		kubectl config set-cluster $CURRENT_CLUSTER --insecure-skip-tls-verify=true --server=$CURRENT_SERVER --kubeconfig config-harry-potter
		kubectl config set-credentials harry-potter --embed-certs=true --client-certificate=harry-potter.crt --client-key=harry-potter.key --kubeconfig config-harry-potter
		kubectl config set-context $CURRENT_CLUSTER-harry-potter --cluster=$CURRENT_CLUSTER --user=harry-potter --namespace=harry-potter-ns  --kubeconfig config-harry-potter
		kubectl  config use-context $CURRENT_CLUSTER-harry-potter --kubeconfig config-harry-potter

congrats you have a new kubeconfig file `config-harry-potter` ready to be sent to the user. try to play with it and see if you can create new resources outside you namespace
