
## Compile and create Docker image

```azurecli-interactive
cd /kafka/kafka-x-messages-producer

export CGO_ENABLED=1
go build -tags musl ./...

docker build -t jorgearteiro/kafka-x-messages-producer:0.4.0 .

docker push -t jorgearteiro/kafka-x-messages-producer:0.4.0 .
```

## Check size od the disks

```azurecli-interactive
du -chs /bitnami/kafka/data

watch -n 1 -d du -s /bitnami/kafka/data
```

## Create Pod to Produce messages

```azurecli-interactive
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: kafka-x-messages-producer1
  namespace: kafka
spec:
  containers:
  - name: kafka-x-messages-producer
    image: docker.io/jorgearteiro/kafka-x-messages-producer:0.4.0
    command: ["./main"]
    env:
    - name: NUM_MESSAGES
      value: "1000000"
    - name: KAFKA_ADDR
      value: "kafka.kafka.svc.cluster.local:9092"
    - name: KAFKA_USER
      value: "user1"
EOF
```