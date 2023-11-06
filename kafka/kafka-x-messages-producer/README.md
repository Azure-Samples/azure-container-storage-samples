# Development Instructions

## Compile and create Docker image

```azurecli-interactive
cd /kafka/kafka-x-messages-producer

export CGO_ENABLED=1
go build -tags musl ./...

docker build -t jorgearteiro/kafka-x-messages-producer:0.9.0 .

docker push jorgearteiro/kafka-x-messages-producer:0.9.0
```

## Check size of the disks

You can check size of attached disks, remoting on the kafka controller pods and running the following commands.

```azurecli-interactive
du -chs /bitnami/kafka/data

watch -n 1 -d du -s /bitnami/kafka/data
```

