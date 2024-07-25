# Azure Container Storage Ephemeral Disk

Azure Container Storage is a cloud-based volume management, deployment, and orchestration service built natively for containers.
On this demo, you use Ephemeral local NVMe Disks of your AKS cluster nodes as back-end storage for your Kubernetes workloads.
We are going to use the Azure Contianer Storage Ephemeral replicate volumes to create the Cassandra DB required volumes during the Helm Chart installation.

## Create a AKS - Azure Kubernetes Services Cluster

```azurecli-interactive
export AZURE_SUBSCRIPTION_ID=<your_subscriptionID>
export AZURE_RESOURCE_GROUP="aks-cassandra-ephemeral"
export AZURE_CLUSTER_NAME="aks-cassandra-ephemeral"

# existing grafana and azure monitoring
grafanaId=$(az grafana show --name grafana-azure-ase --resource-group aks-azure --query id --output tsv)
azuremonitorId=$(az resource show --resource-group aks-azure --name grafana-azure-ase --resource-type "Microsoft.Monitor/accounts" --query id --output tsv)

az group create --name $AZURE_RESOURCE_GROUP --location australiaeast
az aks create -g $AZURE_RESOURCE_GROUP -n $AZURE_CLUSTER_NAME --generate-ssh-keys \
       --node-count 3 \
       --os-sku AzureLinux \
       --enable-azure-container-storage ephemeralDisk \
       --storage-pool-option NVMe \
       --node-vm-size Standard_L8s_v3 \
       --max-pods=250 \
       --enable-azure-monitor-metrics \
       --azure-monitor-workspace-resource-id $azuremonitorId \
       --grafana-resource-id $grafanaId 

az aks get-credentials --resource-group $AZURE_RESOURCE_GROUP --name $AZURE_CLUSTER_NAME --overwrite-existing

kubectl delete sp -n acstor ephemeraldisk-nvme
```


## Creating a replicated Ephemeral Storage pool using CRDs
Storage pools can also be created using Kubernetes CRDs, as described here. This CRD generates a storage class called "acstor-(your-storage-pool-name-here)"

```azurecli-interactive
kubectl apply -f - <<EOF
apiVersion: containerstorage.azure.com/v1
kind: StoragePool
metadata:
  name: ephemeraldisk-nvme
  namespace: acstor
spec:
  poolType:
    ephemeralDisk:
      diskType: nvme
      replicas: 3
EOF
```
Storage Class generated will be called "acstor-ephemeraldisk-nvme"

## Deploy Cassandra from Bitnami using Helm

```azurecli-interactive
# Install Cassandra using HELM
 helm install cassandra --namespace cassandra --create-namespace \
  --set replicaCount=3 \
  --set global.storageClass=acstor-ephemeraldisk-nvme \
  --set metrics.enabled=True \
  --set persistence.enabled=True \
  --set persistence.StorageClass=acstor-ephemeraldisk-nvme \
  --set persistence.size=8Gi \
  --set resources.limits.cpu=4 \
  --set resources.limits.memory=8Gi \
  --set resources.requests.cpu=2 \
  --set resources.requests.memory=4Gi \
  oci://registry-1.docker.io/bitnamicharts/cassandra
```
