set -e -u -x
# get usernaem should be smth like first.last name
username=$1
group=$2
NAMESPACE=$username-ns

# create a directory where we will store all the artifacts for the user
mkdir -p $username
pushd $username
# create namespace for user [namespace will look like username-ns]
kubectl create namespace $NAMESPACE

#create user credentials
openssl genrsa -out $username.key 2048

# create certificate sing request with the key generated
openssl req -new -key $username.key -out $username.csr -subj "/CN=$username/O=$group"

# create a kubernetes csr with csr generated and approve it.
cat <<EOF | kubectl create -f -
apiVersion: certificates.k8s.io/v1beta1
kind: CertificateSigningRequest
metadata:
  name: csr-$username
spec:
  groups:
  - system:authenticated
  request: $(cat $username.csr | base64 | tr -d '\n')
  usages:
  - digital signature
  - key encipherment
  - client auth
EOF

# approve the csr: "only a kubernetes admin can approve the requests"
kubectl certificate approve csr-$username


# create a rolebinding to allow complete controle of user-namespace and cluster role binding to allow view only to other resources 
cat <<EOF | kubectl create -f -
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: $username-view-all
subjects:
- kind: User
  name: $username
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: view
  apiGroup: rbac.authorization.k8s.io
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: $username-edit-own-ns
  namespace: $NAMESPACE
subjects:
- kind: User
  name: $username
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: edit
  apiGroup: rbac.authorization.k8s.io
EOF


# assign resourcequota to user namespace
cat <<EOF | kubectl create -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-resources
  namespace: $NAMESPACE
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 6Gi
    limits.cpu: "8"
    limits.memory: 12Gi
    requests.nvidia.com/gpu: 2
EOF



# get signed user certificate 
kubectl get csr user-request-$username -o jsonpath='{.status.certificate}' | base64 --decode > $username.crt

## create kubeconfig file to give to the new user
# get current cluster
CURRENT_CONTEXT=$(kubectl config current-context)
CURRENT_CLUSTER=$(kubectl config get-contexts $CURRENT_CONTEXT | tail -1 | awk '{print $3}')
CURRENT_SERVER=$(kubectl config view -o jsonpath="{.clusters[?(@.name=='$CURRENT_CLUSTER')].cluster.server}")

kubectl config set-cluster $CURRENT_CLUSTER --insecure-skip-tls-verify=true --server=$CURRENT_SERVER --kubeconfig config-$username
kubectl config set-credentials $username --embed-certs=true --client-certificate=$username.crt --client-key=$username.key --kubeconfig config-$username
kubectl config set-context $CURRENT_CLUSTER-$username --cluster=$CURRENT_CLUSTER --user=$username --namespace=$username-ns  --kubeconfig config-$username
# set the context to the one we just created
kubectl  config use-context $CURRENT_CLUSTER-$username --kubeconfig config-$username

popd
