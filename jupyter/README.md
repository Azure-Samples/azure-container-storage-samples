# Scaling JupyterHub with Azure Container Storage

This repo contains the code and instructions to deploy Azure Container Storage using CLI and deploy a JupyterHub workload.

You can read more about Azure Container Storage [here](https://learn.microsoft.com/en-us/azure/storage/container-storage/container-storage-introduction) - the industry’s first platform-managed container native storage service in the public cloud, providing highly scalable, cost-effective persistent volumes, built natively for containers.

## Getting Started with Azure Container Storage

### Pre-requisites
If you are running in CloudShell, you do not need to install Azure CLI or Kubectl, but we recommend running on your local terminal as there is a JupyterHub specific step that doesn't work on CloudShell.
* Install [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-windows?tabs=azure-cli#install-or-update)
* Install [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/#install-kubectl-binary-with-curl-on-windows)

### Installation

```bash
# Upgrade to the latest version of the aks-preview cli extension by running the following command.
az extension add --upgrade --name aks-preview

# Add or upgrade to the latest version of k8s-extension by running the following command.
az extension add --upgrade --name k8s-extension

# Set subscription context
az account set --subscription <subscription-id>

# Register resoure providers
az provider register --namespace Microsoft.ContainerService --wait 
az provider register --namespace Microsoft.KubernetesConfiguration --wait

# Create a resource group
az group create --name <resource-group-name> --location <location>

# Create an AKS cluster with Azure Container Storage extension enabled. This will create a StoragePool of type Azure Disk by default. If you want to update the defaults (pool name, pool size or SKU), you can do so by using the parameters here: https://learn.microsoft.com/en-us/azure/storage/container-storage/container-storage-aks-quickstart#create-a-new-aks-cluster-and-install-azure-container-storage
az aks create -n <cluster-name> -g <resource-group-name> --node-vm-size Standard_D4s_v3 --node-count 3 --enable-azure-container-storage azureDisk

# Connect to the AKS cluster
az aks get-credentials --resource-group <resource-group-name> --name <cluster-name>

# Display available storage pools, you should see one created when Azure Container Storage was enabled
kubectl get sp -n acstor

# Display storage classes - there should be 3 storage classes created for you: 1) acstor-azuredisk 2) acstor-azuredisk-internal 3) acstor-azuredisk-internal-azuredisk
kubectl get sc
```
You will only use the acstor-azuredisk storage class. The other ones are internal for ACStor. 

## JupyterHub
![Alt text](image.png)
This code sample will create a JupyterHub environment for an admin user. We'll create also create additional users to represent students from Contoso School. Each time a user logs in, they will be allocated a JupyterHub session in the form of a pod in the cluster, and the pod will have a persistent volume attached to store the state of the session.

### Pre-requisites
* Install [Python](https://www.python.org/downloads/windows/) 
* Install the [requests](https://pypi.org/project/requests/) Python library
* Install [Chocolatey](https://chocolatey.org/install) to install helm

### Deployment

1. Create config.yaml file to specify that each single user that will be created will be provisioned 1 Gi of storage, from a StorageClass created via Azure Container Storage.

```bash
code config.yaml
```
```bash
singleuser:
  storage:
    capacity: 1Gi
    dynamic:
      storageClass: acstor-azuredisk
hub:
  config:
    JupyterHub:
      admin_access: false
    Authenticator:
      admin_users:
        - admin
```
2. Install JupyterHub


```bash
choco install kubernetes-helm
```

```bash
helm repo add jupyterhub https://jupyterhub.github.io/helm-chart/
helm repo update
```
This command will install JupyterHub using the information provided on config.yaml, and creating a namespace (jhub1) where the demo resources will sit.
```bash
helm upgrade --cleanup-on-fail --install jhub1 jupyterhub/jupyterhub --namespace jhub1 --create-namespace --values config.yaml
```
```bash
kubectl get service --namespace jhub1
```

3. Port forward to connect to the service

Note: We recommend trying this from your computer's local terminal (vs CloudShell), otherwise port forwarding won't work.
```bash
kubectl --namespace=jhub1 port-forward service/proxy-public 8080:http
```

#### Create additional user sessions
1. From the browser - log on to: http://localhost:8080/ using the credentials from the config.yaml file (username: admin).

2. Generate a token from http://localhost:8080/hub/token. Tokens are sent to the Hub for verification. The Hub replies with a JSON model describing the authenticated user.

3. Update the value of the token in the 'api_token' parameter in the Python script (user_creation.py)

4. Run python script
```bash
py user_creation.py
```

5. Run these commands in your cluster to get the pods and PVCs. You will see how the pods start to initialize along with their PVCs.
```bash
kubectl get pvc -n jhub1
kubectl get pods -n jhub1
```