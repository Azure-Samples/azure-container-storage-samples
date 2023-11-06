# kafka Message Producer

Kafka Message producer is a small Go lang application to generate X number of messages and ingest to Kafka. It's using confluent-kafka-go library.
The kafka-x-messages-producer.yaml file requires some environment variables and the kafka user1 password as a secret. Environment variables are: NUM_MESSAGES, KAFKA_TOPIC, KAFKA_ADDR, KAFKA_USER and KAFKA_PASSWORD(as kubernetes secret).

## Create a AKS - Azure Kubernetes Services Cluster

```azurecli-interactive
export AZURE_SUBSCRIPTION_ID=<your_subscriptionID>
export AZURE_RESOURCE_GROUP="aks-kafka-san"
export AZURE_CLUSTER_NAME="aks-kafka-san"

# existing grafana and azure monitoring
grafanaId=$(az grafana show --name grafana-azure-ase --resource-group aks-azure --query id --output tsv)
azuremonitorId=$(az resource show --resource-group aks-azure --name grafana-azure-ase --resource-type "Microsoft.Monitor/accounts" --query id --output tsv)

az group create --name $AZURE_RESOURCE_GROUP --location australiaeast
az aks create -g $AZURE_RESOURCE_GROUP -n $AZURE_CLUSTER_NAME --generate-ssh-keys \
       --node-count 3 \
       --os-sku AzureLinux \
       --enable-azure-container-storage elasticSan \
       --node-vm-size standard_d8s_v5 \
       --max-pods=250 \
       --enable-azure-monitor-metrics \
       --azure-monitor-workspace-resource-id $azuremonitorId \
       --grafana-resource-id $grafanaId 
```


## Deploy Kafka from Bitnami using Helm

```azurecli-interactive
# Install Kafka using HELM
helm upgrade kafka --namespace kafka --create-namespace \
  --set controller.replicaCount=3 \
  --set global.storageClass=acstor-elasticSan \
  --set controller.heapOpts="-Xmx2048m -Xms2048m" \
  --set controller.persistence.enabled=True \
  --set controller.persistence.size=1Ti \
  --set controller.logPersistence.enabled=True \
  --set controller.logPersistence.size=100Gi \
  --set controller.resources.limits.cpu=2 \
  --set controller.resources.limits.memory=4Gi \
  --set controller.resources.requests.cpu=1 \
  --set controller.resources.requests.memory=2Gi \
  --set metrics.jmx.enabled=True \
  oci://registry-1.docker.io/bitnamicharts/kafka
```

## Create secret for default kafka user1 generated on the installation
```azurecli-interactive
kubectl create secret generic kafka-user-password \
--namespace=kafka \
--from-literal=password="$(kubectl get secret kafka-user-passwords --namespace kafka -o jsonpath='{.data.client-passwords}' | base64 -d | cut -d , -f 1)"
```
## Create Deployment to Produce X messages

```azurecli-interactive
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kafka-x-messages-producer
  namespace: kafka
spec:
  replicas: 100
  selector:
    matchLabels:
      app: kafka-x-messages-producer
  template:
    metadata:
      labels:
        app: kafka-x-messages-producer
    spec:
      containers:
      - name: kafka-x-messages-producer
        image: docker.io/jorgearteiro/kafka-x-messages-producer:0.9.0
        command: ["./main"]
        env:
        - name: NUM_MESSAGES
          value: "10000000"
        - name: KAFKA_TOPIC
          value: "orders"
        - name: KAFKA_ADDR
          value: "kafka.kafka.svc.cluster.local:9092"
        - name: KAFKA_USER
          value: "user1"
        - name: KAFKA_PASSWORD
          valueFrom:
            secretKeyRef:
              name: kafka-user-password
              key: password
        resources:
          limits:
            cpu: "0.06"
            memory: "64Mi"
          requests:
            cpu: "0.01"
            memory: "32Mi"
```

## Creating Elastic San Pools using CRDs
Storage pools can also be created using Kubernetes CRDs, as described here. This CRD generates a storage class called "acstor-<your-storage-pool-name>"

```azurecli-interactive
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
```
Storage Class generated will be called "acstor-san1"
# kafka Message Producer

Kafka Message producer is a small Go lang application to generate X number of messages and ingest to Kafka. It's using confluent-kafka-go library.
The kafka-x-messages-producer.yaml file requires some environment variables and the kafka user1 password as a secret. Environment variables are: NUM_MESSAGES, KAFKA_TOPIC, KAFKA_ADDR, KAFKA_USER and KAFKA_PASSWORD(as kubernetes secret).

## Create a AKS - Azure Kubernetes Services Cluster

```azurecli-interactive
export AZURE_SUBSCRIPTION_ID=<your_subscriptionID>
export AZURE_RESOURCE_GROUP="aks-kafka-san"
export AZURE_CLUSTER_NAME="aks-kafka-san"

# existing grafana and azure monitoring
grafanaId=$(az grafana show --name grafana-azure-ase --resource-group aks-azure --query id --output tsv)
azuremonitorId=$(az resource show --resource-group aks-azure --name grafana-azure-ase --resource-type "Microsoft.Monitor/accounts" --query id --output tsv)

az group create --name $AZURE_RESOURCE_GROUP --location australiaeast
az aks create -g $AZURE_RESOURCE_GROUP -n $AZURE_CLUSTER_NAME --generate-ssh-keys \
       --node-count 3 \
       --os-sku AzureLinux \
       --enable-azure-container-storage elasticSan \
       --node-vm-size standard_d8s_v5 \
       --max-pods=250 \
       --enable-azure-monitor-metrics \
       --azure-monitor-workspace-resource-id $azuremonitorId \
       --grafana-resource-id $grafanaId 
```


## Deploy Kafka from Bitnami using Helm

```azurecli-interactive
# Install Kafka using HELM
helm upgrade kafka --namespace kafka --create-namespace \
  --set controller.replicaCount=3 \
  --set global.storageClass=acstor-elasticSan \
  --set controller.heapOpts="-Xmx2048m -Xms2048m" \
  --set controller.persistence.enabled=True \
  --set controller.persistence.size=1Ti \
  --set controller.logPersistence.enabled=True \
  --set controller.logPersistence.size=100Gi \
  --set controller.resources.limits.cpu=2 \
  --set controller.resources.limits.memory=4Gi \
  --set controller.resources.requests.cpu=1 \
  --set controller.resources.requests.memory=2Gi \
  --set metrics.jmx.enabled=True \
  oci://registry-1.docker.io/bitnamicharts/kafka
```

## Create secret for default kafka user1 generated on the installation
```azurecli-interactive
kubectl create secret generic kafka-user-password \
--namespace=kafka \
--from-literal=password="$(kubectl get secret kafka-user-passwords --namespace kafka -o jsonpath='{.data.client-passwords}' | base64 -d | cut -d , -f 1)"
```
## Create Deployment to Produce X messages

```azurecli-interactive
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kafka-x-messages-producer
  namespace: kafka
spec:
  replicas: 100
  selector:
    matchLabels:
      app: kafka-x-messages-producer
  template:
    metadata:
      labels:
        app: kafka-x-messages-producer
    spec:
      containers:
      - name: kafka-x-messages-producer
        image: docker.io/jorgearteiro/kafka-x-messages-producer:0.9.0
        command: ["./main"]
        env:
        - name: NUM_MESSAGES
          value: "10000000"
        - name: KAFKA_TOPIC
          value: "orders"
        - name: KAFKA_ADDR
          value: "kafka.kafka.svc.cluster.local:9092"
        - name: KAFKA_USER
          value: "user1"
        - name: KAFKA_PASSWORD
          valueFrom:
            secretKeyRef:
              name: kafka-user-password
              key: password
        resources:
          limits:
            cpu: "0.06"
            memory: "64Mi"
          requests:
            cpu: "0.01"
            memory: "32Mi"
```

## Creating Elastic San Pools using CRDs
Storage pools can also be created using Kubernetes CRDs, as described here. This CRD generates a storage class called "acstor-<your-storage-pool-name>"

```azurecli-interactive
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
```
Storage Class generated will be called "acstor-san1"
