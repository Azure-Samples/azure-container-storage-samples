
# Installing Azure Marketplace bitnami Kafka on AKS with Azure Container Storage Elastic SAN

## Prerequisites

- If you don't have an Azure subscription, create a [free account](https://azure.microsoft.com/free/?WT.mc_id=A261C142F) before you begin.

- This article requires version 2.0.64 or later of the Azure CLI. See [How to install the Azure CLI](https://github.com/MicrosoftDocs/azure-docs/blob/main/cli/azure/install-azure-cli). If you're using the Bash environment in Azure Cloud Shell, the latest version is already installed. If you plan to run the commands locally instead of in Azure Cloud Shell, be sure to run them with administrative privileges. For more information, see [Quickstart for Bash in Azure Cloud Shell](https://github.com/MicrosoftDocs/azure-docs/blob/main/articles/cloud-shell/quickstart.md).

- You'll need the Kubernetes command-line client, `kubectl`. It's already installed if you're using Azure Cloud Shell, or you can install it locally by running the `az aks install-cli` command.

- Optional: We'd like input on how you plan to use Azure Container Storage. Please complete this [short survey](https://aka.ms/AzureContainerStoragePreviewSignUp).

- You'll need an AKS cluster with an appropriate [virtual machine type](https://github.com/MicrosoftDocs/azure-docs/blob/main/articles/storage/container-storage/install-container-storage-aks.md#vm-types). If you don't already have an AKS cluster, follow [these instructions](https://github.com/MicrosoftDocs/azure-docs/blob/main/articles/storage/container-storage/install-container-storage-aks.md#getting-started) to create one.

## Getting started

- Take note of your Azure subscription ID. We recommend using a subscription on which you have an [Owner](https://github.com/MicrosoftDocs/azure-docs/blob/main/articles/role-based-access-control/built-in-roles.md#owner) role. If you don't have access to one, you can still proceed, but you'll need admin assistance to complete the steps in this article.

- [Launch Azure Cloud Shell](https://shell.azure.com), or if you're using a local installation, sign in to the Azure CLI by using the [az login](https://github.com/MicrosoftDocs/azure-docs/blob/main/cli/azure/reference-index#az-login) command.

- If you're using Azure Cloud Shell, you might be prompted to mount storage. Select the Azure subscription where you want to create the storage account and select **Create**.

## Set subscription context

Set your Azure subscription context using the `az account set` command. You can view the subscription IDs for all the subscriptions you have access to by running the `az account list --output table` command. Remember to replace `<subscription-id>` with your subscription ID.

```azurecli-interactive
az account set --subscription <subscription-id>
```

## Register resource providers

The `Microsoft.ContainerService` and `Microsoft.KubernetesConfiguration` resource providers must be registered on your Azure subscription. To register these providers, run the following command:

```azurecli-interactive
az provider register --namespace Microsoft.ContainerService --wait 
az provider register --namespace Microsoft.KubernetesConfiguration --wait 
```

## Create a resource group

An Azure resource group is a logical group that holds your Azure resources that you want to manage as a group. When you create a resource group, you're prompted to specify a location. This location is:

* The storage location of your resource group metadata.
* Where your resources will run in Azure if you don't specify another region during resource creation.

Create a resource group using the `az group create` command. Replace `<resource-group-name>` with the name of the resource group you want to create, and replace `<location>` with an Azure region such as *australiaeast*, *eastus*, *westus2*, *westus3*, or *westeurope*.

```azurecli-interactive
az group create --name <resource-group-name> --location <location>
```

If the resource group was created successfully, you'll see output similar to this:

```json
{
  "id": "/subscriptions/<guid>/resourceGroups/myContainerStorageRG",
  "location": "australiaeast",
  "managedBy": null,
  "name": "myContainerStorageRG",
  "properties": {
    "provisioningState": "Succeeded"
  },
  "tags": null
}
```

## Choose a data storage option and virtual machine type

To use Azure Container Storage, you'll need a node pool of at least three Linux VMs. Each VM should have a minimum of four virtual CPUs (vCPUs). Azure Container Storage will consume one core for I/O processing on every VM the extension is deployed to.

We are going to use use Azure Elastic SAN Preview with Azure Container Storage, then we need a [general purpose VM type](https://github.com/MicrosoftDocs/azure-docs/blob/main/articles/virtual-machines/sizes-general.md) such as **standard_d4s_v5** for the cluster nodes.

> [!IMPORTANT]
> You must choose a VM type that supports [Azure premium storage](https://github.com/MicrosoftDocs/azure-docs/blob/main/articles/virtual-machines/premium-storage-performance.md).

## Create AKS cluster

Run the following command to create a Linux-based AKS cluster and enable a system-assigned managed identity. If you already have an AKS cluster you want to use, you can skip this step.

Replace `<resource-group>` with the name of the resource group you created, `<cluster-name>` with the name of the cluster you want to create, and `<vm-type>` with the VM type you selected in the previous step. In this example, we'll create a cluster with three nodes. Increase the `--node-count` if you want a larger cluster. We are using VM size standard_d4s_v5

```azurecli-interactive
az aks create -g <resource-group> -n <cluster-name> --node-count 3 -s <vm-type> --generate-ssh-keys
```

The deployment will take a few minutes to complete.

> [!NOTE]
> When you create an AKS cluster, AKS automatically creates a second resource group to store the AKS resources. This second resource group follows the naming convention `MC_YourResourceGroup_YourAKSClusterName_Region`. For more information, see [Why are two resource groups created with AKS?](https://github.com/MicrosoftDocs/azure-docs/blob/main/articles/aks/faq.md#why-are-two-resource-groups-created-with-aks).

## Connect to the cluster

To connect to the cluster, use the Kubernetes command-line client, `kubectl`.

1. Configure `kubectl` to connect to your cluster using the `az aks get-credentials` command. The following command:

    * Downloads credentials and configures the Kubernetes CLI to use them.
    * Uses `~/.kube/config`, the default location for the Kubernetes configuration file. You can specify a different location for your Kubernetes configuration file using the *--file* argument.

    ```azurecli-interactive
    az aks get-credentials --resource-group <resource-group> --name <cluster-name>
    ```

2. Verify the connection to your cluster using the `kubectl get` command. This command returns a list of the cluster nodes.

    ```azurecli-interactive
    kubectl get nodes
    ```

3. The following output example shows the nodes in your cluster. Make sure the status for all nodes shows *Ready*:

    ```output
    NAME                                STATUS   ROLES   AGE   VERSION
    aks-nodepool1-34832848-vmss000000   Ready    agent   80m   v1.25.6
    aks-nodepool1-34832848-vmss000001   Ready    agent   80m   v1.25.6
    aks-nodepool1-34832848-vmss000002   Ready    agent   80m   v1.25.6
    ```
    
    Take note of the name of your node pool. In this example, it would be **nodepool1**.

## Install Azure Container Storage and kafka extensions

Follow these instructions to install Azure Container Storage and Kafka extensions on your AKS cluster using an installation script.

1. Run the `az login` command to sign in to Azure.

1. Download and save [this shell script](kafka-acstor-install.sh).

1. Navigate to the directory where the file is saved using the `cd` command. For example, `cd C:\Users\Username\Downloads`.
   
1. Run the following command to change the file permissions:

   ```bash
   chmod +x kafka-acstor-install.sh 
   ```

1. Run the installation script and specify the parameters.
   
   | **Flag** | **Parameter**      | **Description** |
   |----------|----------------|-------------|
   | -s   | --subscription | The subscription identifier. Defaults to the current subscription.|
   | -g   | --resource-group | The resource group name.|
   | -c   | --cluster-name | The name of the cluster where Azure Container Storage is to be installed.|
   | -n   | --nodepool-name | The name of the nodepool. Defaults to the first nodepool in the cluster.|
   | -r   | --release-train | The release train for the installation. Defaults to stable.|
   
   For example:

   ```bash
   bash ./kafka-acstor-install.sh -g <resource-group-name> -s <subscription-id> -c <cluster-name> -n <nodepool-name> -r <release-train-name>
   ```

The script installs 2 extensions acstor and Kafka. Installation takes 10-15 minutes to complete. You can check if the installation completed correctly by running the following command and ensuring that `provisioningState` says **Succeeded**:

```azurecli-interactive
az k8s-extension list --cluster-name <cluster-name> --resource-group <resource-group> --cluster-type managedClusters -o table
```

Installation Script also creates a Storage pool on AKS as follows

```yaml
apiVersion: containerstorage.azure.com/v1alpha1
kind: StoragePool
metadata:
  name: san1
  namespace: acstor
spec:
  poolType:
    elasticSan: {}
  resources:
    requests: {"storage": 1Ti}
```
When the StoragePool is created, a new storage classes is also created that you can use for your Kubernetes workloads. On this example it's called `acstor-san1`

Congratulations, you've successfully installed Azure Container Storage(acstor) and Kafka. 

## For reference: my example cluster commands

Make sure you set all variables AKS_SUBSCRIPTIONID, AKS_RESOURCE_GROUP_NAME, AKS_CLUSTER_NAME, AKS_CLUSTER_LOCATION, AKS_VM_SIZE and AKS_NODEPOOL_NAME, before running the commands.

```azurecli-interactive
export AKS_SUBSCRIPTIONID=<your-subscription-id>
export AKS_RESOURCE_GROUP_NAME=aks-kafka
export AKS_CLUSTER_NAME=aks-kafka
export AKS_CLUSTER_LOCATION=australiaeast
export AKS_VM_SIZE=standard_d4s_v5
export AKS_NODEPOOL_NAME=nodepool1
az group create --name $AKS_RESOURCE_GROUP_NAME --location $AKS_CLUSTER_LOCATION
az aks create -g $AKS_RESOURCE_GROUP_NAME -n $AKS_CLUSTER_NAME --node-count 3 -s $AKS_VM_SIZE --generate-ssh-keys
sleep 60
bash ./kafka-acstor-install.sh -g $AKS_RESOURCE_GROUP_NAME -s $AKS_SUBSCRIPTIONID -c $AKS_CLUSTER_NAME -n $AKS_NODEPOOL_NAME -r stable
```
