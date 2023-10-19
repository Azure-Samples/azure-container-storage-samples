#!/usr/bin/env bash

set -euo pipefail
#
# Define common functions.
#
printhelp() {
  cat <<EOF
acstor-install.sh: Installs the ACStor K8s ARC Extension on the given cluster.

Options:
  -s, --subscription : The subscription identifier. Defaults to the current subscription.
  -g, --resource-group [Required] : The resource group name.
  -c --cluster-name : The name of the cluster where ACStor is to be installed.
  -n --nodepool-name : The name of the nodepool. Defaults to the first nodepool in the cluster.
  -r --release-train : The release train for the installation. Defaults to prod
EOF
}

echoerr() {
  printf "%s\n\n" "$*" >&2
}

trap_push() {
  local SIGNAL="${2:?Signal required}"
  HANDLERS="$( trap -p ${SIGNAL} | cut -f2 -d \' )";
  trap "${1:?Handler required}${HANDLERS:+;}${HANDLERS}" "${SIGNAL}"
}

retry() {
  local MAX_ATTEMPTS=$1
  local SLEEP_INTERVAL=$2
  shift 2

  local ATTEMPT=1
  while true;
  do
    ("$@") && break || true

    echoerr "Command '$1' failed $ATTEMPT of $MAX_ATTEMPTS attempts."

    ATTEMPT=$((ATTEMPT + 1))
    if [[ $ATTEMPT -ge $MAX_ATTEMPTS ]]; then
      return 1
    fi

    echoerr "Retry after $SLEEP_INTERVAL seconds..."
    sleep $SLEEP_INTERVAL
  done
}

while [[ $# -gt 0 ]]
do
  ARG="$1"
  case $ARG in
    -c|--cluster-name)
      AZURE_CLUSTER_DNS_NAME="$2"
      shift 2 # skip the option arguments
      ;;
    -n|--nodepool-name)
      NODEPOOL_NAME="$2"
      shift 2 # skip the option arguments
      ;;
    -g|--resource-group)
      AZURE_RESOURCE_GROUP="$2"
      shift 2 # skip the option arguments
      ;;
    -s|--subscription)
      AZURE_SUBSCRIPTION_ID="$2"
      shift 2 # skip the option arguments
      ;;
    -r|--release-train)
      RELEASE_TRAIN="$2"
      shift 2 # skip the option arguments
      ;;
    -?|--help)
      printhelp
      exit 1
      ;;

    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

#
# Install required tools if necessary.
#
if [[ -z "$(command -v az)" ]]; then
  echo "Azure CLI not installed. Please visit https://learn.microsoft.com/en-us/cli/azure/install-azure-cli to install."
  exit 1
fi

if [[ -z "$(command -v kubectl)" ]]; then
  echo "kubectl not installed. Please visit https://kubernetes.io/docs/tasks/tools/ to install."
  exit 1
fi

if [[ -z ${AZURE_RESOURCE_GROUP:-} ]]; then
  echoerr "ERROR: The --resource-group option is required."
  printhelp
  exit 1
else echo Resource Group - $AZURE_RESOURCE_GROUP
fi

# Set Default Subscription ID
if [[ -z ${AZURE_SUBSCRIPTION_ID:-} ]]; then
  AZURE_SUBSCRIPTION_ID=$(az account show -o tsv --query id)
  echo SubscriptionId - $AZURE_SUBSCRIPTION_ID
fi

# Use connected cluster
if [[ -z ${AZURE_CLUSTER_DNS_NAME:-} ]]; then
  AZURE_CLUSTER_DNS_NAME=$(kubectl config current-context)
  echo Cluster Name - $AZURE_CLUSTER_DNS_NAME
fi
# Use default nodepool
if [[ -z ${NODEPOOL_NAME:-} ]]; then
  NODEPOOL_NAME=$(az aks show --resource-group $AZURE_RESOURCE_GROUP --name $AZURE_CLUSTER_DNS_NAME -o tsv --query 'agentPoolProfiles[0].name')
  echo NodePool - $NODEPOOL_NAME
fi
# Set Default extension name
if [[ -z ${AZURE_CLUSTER_DNS_NAME:-} ]]; then
  echo kubectl context not set, --cluster-name must be provided or context must be set.
  exit 1
fi
# Set Default release train
if [[ -z ${RELEASE_TRAIN:-} ]]; then
  RELEASE_TRAIN=stable
fi

echo $RELEASE_TRAIN

if [ -z ${AZURE_SUBSCRIPTION_ID:-} ] || [ -z ${NODEPOOL_NAME:-} ]; then
  echo Error in getting default values for SubscriptionId and NodePool. Please try again.
  exit 1
fi
# Assign Contributor role to AKS managed identity
export AKS_MI_OBJECT_ID=$(az aks show --name $AZURE_CLUSTER_DNS_NAME --resource-group $AZURE_RESOURCE_GROUP --query "identityProfile.kubeletidentity.objectId" -o tsv)
export AKS_NODE_RG=$(az aks show --name $AZURE_CLUSTER_DNS_NAME --resource-group $AZURE_RESOURCE_GROUP --query "nodeResourceGroup" -o tsv)
az role assignment create --assignee $AKS_MI_OBJECT_ID --role "Contributor" --scope "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$AZURE_RESOURCE_GROUP"

read -e -p "Would you like to install ACStor using the above parameters? Proceed Y/N " choice
[[ "$choice" == [Yy]* ]] && echo "Installing AcStor.." || exit 1

# Set the Azure subscription context
az account set --subscription $AZURE_SUBSCRIPTION_ID

# Register Resource Providers
az provider register --namespace Microsoft.ContainerService --wait 
az provider register --namespace Microsoft.KubernetesConfiguration --wait

# Connect to the cluster
az aks get-credentials --resource-group $AZURE_RESOURCE_GROUP --name $AZURE_CLUSTER_DNS_NAME

# Label the nodepool
az aks nodepool update --resource-group $AZURE_RESOURCE_GROUP --cluster-name $AZURE_CLUSTER_DNS_NAME --name $NODEPOOL_NAME --labels acstor.azure.com/io-engine=acstor
sleep 15

# Install ACStor
export EXTENSION_NAME=acstor
az k8s-extension create --cluster-type managedClusters --cluster-name $AZURE_CLUSTER_DNS_NAME --resource-group $AZURE_RESOURCE_GROUP --name $EXTENSION_NAME --extension-type microsoft.azurecontainerstorage --scope cluster --release-train $RELEASE_TRAIN --release-namespace acstor

# Wait for the storage pool extension to be ready
sleep 30

# Install Kafka
read -e -p "Would you like to install Kafka Kubernetes Apps Extension from bitnami using the above Elastic SAN parameters? Proceed Y/N " choice
[[ "$choice" == [Yy]* ]] && echo "Installing Kafka Kubernetes Apps Extension from Azure Marketplace using SAN Elastic Container Storage.." || exit 1

# Assign Contributor role to AKS managed identity for the SubscriptionID as Elastic SAN requires it.
az role assignment create --assignee $AKS_MI_OBJECT_ID --role "Contributor" --scope "/subscriptions/$AZURE_SUBSCRIPTION_ID"

# Wait assignment to propagate
sleep 60

export KAFKA_SAN_NAME=san1
export EXTENSION_NAME=kafka
export KAFKA_PLAN_NAME=main
export KAFKA_PLAN_OFFERID=kafka-cnab
export KAFKA_PLAN_PUBLISHER=bitnami
export KAFKA_RELEASE_TRAIN=stable
export KAFKA_RELEASE_NAMESPACE=kafka
export KAFKA_EXTENSION_TYPE=Bitnami.KafkaMain
export KAFKA_STORAGE_CLASS=acstor-$KAFKA_SAN_NAME # storage class is generated after storage pool is created

# Create san-storagepool.yaml (make sure you update name if you change KAFKA_SAN_NAME)
kubectl apply -f - <<EOF
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
EOF

# Wait for the storage pool to be ready and storage account be created
sleep 300

# Accept Marketplace offer
az vm image terms accept --offer $KAFKA_PLAN_OFFERID --plan $KAFKA_PLAN_NAME --publisher $KAFKA_PLAN_PUBLISHER

# Install Kafka Extension from Marketplace 
az k8s-extension create --cluster-type managedClusters --cluster-name $AZURE_CLUSTER_DNS_NAME --resource-group $AZURE_RESOURCE_GROUP --name $EXTENSION_NAME --extension-type $KAFKA_EXTENSION_TYPE --scope cluster --release-train $KAFKA_RELEASE_TRAIN --release-namespace $KAFKA_RELEASE_NAMESPACE --plan-name $KAFKA_PLAN_NAME --plan-product $KAFKA_PLAN_OFFERID --plan-publisher $KAFKA_PLAN_PUBLISHER --configuration-settings global.storageClass=$KAFKA_STORAGE_CLASS
