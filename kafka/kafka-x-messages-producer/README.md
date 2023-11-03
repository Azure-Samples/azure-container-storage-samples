
## Compile and create Docker image

```azurecli-interactive
cd /kafka/kafka-x-messages-producer

export CGO_ENABLED=1
go build -tags musl ./...

docker build -t jorgearteiro/kafka-x-messages-producer:0.9.0 .

docker push -t jorgearteiro/kafka-x-messages-producer:0.9.0 .
```

## Check size od the disks

```azurecli-interactive
du -chs /bitnami/kafka/data

watch -n 1 -d du -s /bitnami/kafka/data
```

## Create Pod to Produce messages

```azurecli-interactive
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kafka-x-messages-producer
  namespace: kafka
spec:
  replicas: 10
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