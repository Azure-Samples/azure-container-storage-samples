# Introduction

## Getting Started with Azure Container Storage

This repo contains the code and instructions to deploy Azure Container Storage using CLI and deploy Jupyter & Kafka workloads.

### Pre-requisites
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

# Create an AKS cluster with Azure Container Storage extension enabled
az aks create -n <cluster-name> -g <resource-group-name> --node-vm-size Standard_D4s_v3 --node-count 3 --enable-azure-container-storage azureDisk

# Connect to the AKS cluster
az aks get-credentials --resource-group <resource-group-name> --name <cluster-name>

# Display available storage pools, one was created when Azure Container Storage was enabled
kubectl get sp -n acstor

# Display storage classes - there should be a storage class created that corresponds to the storage pool
kubectl get sc
```

## Jupyterhub

### Pre-requisites
* Install [Python](https://www.python.org/downloads/windows/) 
* Install [requests](https://pypi.org/project/requests/) Python library
* Install [Chocolatey](https://chocolatey.org/install) to install helm

### Deployment

1. Create config.yaml file to specify that each single user that will be created will get provisioned 1 Gi of storage, from a StorageClass created via Azure Container Storage.

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
2. Install jupyterhub


```bash
(if not running on Cloud Shell) choco install kubernetes-helm
```

```bash
helm repo add jupyterhub https://jupyterhub.github.io/helm-chart/
helm repo update
```
This is installing JupyterHub using the information provided on config.yaml, and creating a namespace (jhub1) where the demo resources will sit.
```bash
helm upgrade --cleanup-on-fail --install jhub1 jupyterhub/jupyterhub --namespace jhub1 --create-namespace --values config.yaml
```
```bash
kubectl get service --namespace jhub1
```

3. Port forward to connect to the service
```bash
kubectl --namespace=jhub1 port-forward service/proxy-public 8080:http
```
Note: If the port-forward doesn't work from CloudShell, you can try using your computer's local terminal

#### Create additional user sessions
1. From the browser - log on to: http://localhost:8080/ using the credentials from the config.yaml file (username: admin).

2. Generate the token from http://localhost:8080/hub/token. Tokens are sent to the Hub for verification. The Hub replies with a JSON model describing the authenticated user.

3. Update the value of the token in the 'api_token' parameter in the Python script (user_creation.py)

4. Run python script
```bash
py user_creation.py
```

5. Run these commands in your cluster to get the pods and PVCs
```bash
kubectl get pvc -n jhub1
kubectl get pods -n jhub1
```