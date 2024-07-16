# Running Elasticsearch with Azure Container Storage

This repo contains the code and instructions to deploy Azure Container Storage using CLI and deploy a ElasticSearch workload.

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
az aks create -n <cluster-name> -g <resource-group-name> --node-vm-size Standard_D8ds_v4 --node-count 3 --enable-azure-container-storage azureDisk --node-count 5 --nodepool-name systempool

# Connect to the AKS cluster
az aks get-credentials --resource-group <resource-group-name> --name <cluster-name>


 # Add a user nodepool
  az aks nodepool add --cluster-name <cluster-name> --mode User --name espoolz1 --node-vm-size Standard_D8ds_v4 --resource-group <resource-group-name> --zones 1 --enable-cluster-autoscaler --max-count 12 --min-count 5 --node-count 5--labels app=es

 # Label the user node pool
 az aks nodepool update --resource-group <resource-group-name> --cluster-name <cluster-name> --name espoolz1 --labels acstor.azure.com/io-engine=acstor
```

## Elastic Search deployment 

### Prepare The Cluster 
We will use the "acstor-azuredisk" storage class. We will use helm to install the ElasticSearch, we will rely on the ElasticSearch chart provided by bitnami as its the easiest one to navigate. 

We will create our own values file (in this repo you can use values_acs.yaml) where we you can modify/adjust the following values according to your need: 

1. Adjust the affinity and taints to match our node pools 
2. adjust the number of replicas and the scaling parameters for master, data, and coordinating, and ingestion nodes
3. configure the storage class 
4. optionally make the elastic search service accessible using a load balancer 
5. enable HPA for all the nodes 
   

### Add the bitnami repository
```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
```

### Deploy ElasticSearch
Now that we have configured the charts, we are ready to deploy the ES cluster 

```bash
# Create the namespace
kubectl create namespace elasticsearch

# Install elastic search using the values file 
helm install elasticsearch-v1 bitnami/elasticsearch -n elasticsearch --values values_acs.yaml

# Validate the installation, it will take around 5 minutes for all the pods to move to a 'READY' state 
watch kubectl get pods -o wide -n elasticsearch


# Check the service so we can access elastic search
kubectl get svc -n elasticsearch elasticsearch-v1
```

###  Port forward to local host
```shell
kubectl -n elasticsearch port-forward svc/elasticsearch-v1 <Use the port from above command> &

# Use curl command to connectoto the elasticsearch command
curl http://localhost:<Use the port from above command>/ 
```

## Ingesting some sample data into our ElasticSearch delpoyment

### Create an index 
```shell
##create an index called "acstor" with 3 replicas 
curl -X PUT "http://$esip:9200/acstor" -H "Content-Type: application/json" -d '{
  "settings": {
    "number_of_replicas": 3
  }
}'
```

### Test the index 
```shell
curl -X GET "http://localhost:<use your port number>/acstor" 
```

### Install docker
Find the link for Docker installation here - https://docs.docker.com/engine/install/

### Download the Dockerfile, ingest_logs.py and ingest-job.yaml from the repo and follow the instructions below to build the docker image

```shell
# Create an azure container registry (acr) from the portal.Change the registry name to match yours
#Point the folder to the one having docker file
az acr login --name <Your registry name>
az acr update --name <Your registry name> --anonymous-pull-enabled
docker build -t <Your registry name>.azurecr.io/my-ingest-image:1.0 .
docker push <Your registry name>.azurecr.io/my-ingest-image:1.0 
```

### Run the job (remember to change the image name to yours in ingest-job.yaml)
```shell
cd .\DockerImage\
kubectl apply -f ingest-job.yaml
```
### Verify the job is running
```shell
kubectl logs -l app=log-ingestion
```

### Show live pod status 
```shell
while($true) {
    kubectl get pods -n elasticsearch
    Start-Sleep -Seconds 2
} 
```
