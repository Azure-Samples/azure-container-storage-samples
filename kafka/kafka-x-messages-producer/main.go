package main

import (
	"encoding/json"
	"fmt"
	"log"
	"math/rand"
	"os"
	"strconv"

	"github.com/confluentinc/confluent-kafka-go/v2/kafka"
	
)

type order struct {
	OrderID    string `json:"orderId"`
	CustomerID string `json:"customerId"`
	Items      []item `json:"items"`
	Status     status `json:"status"`
}

type status int

const (
	Pending status = iota
	Processing
	Complete
)

type item struct {
	Product  int     `json:"productId"`
	Quantity int     `json:"quantity"`
	Price    float64 `json:"price"`
}

func main() {
	//read environment variables
	var addr string
	kafkaAddr := os.Getenv("KAFKA_ADDR")
	if kafkaAddr == "" {
		addr = "kafka.kafka.svc.cluster.local:9092"
	} else {
		addr = kafkaAddr
	}

	var numMessages int
	numMessagesStr := os.Getenv("NUM_MESSAGES")
	if numMessagesStr == "" {
		numMessages = 1000
	} else {
		numMessages, _ = strconv.Atoi(numMessagesStr)
	}

	// set up kafka writer
	topic := "orders"

	// read environment variables
	user := "user1"
	password := "VOIgRUQ1PO"

	// Create a producer instance with the given configuration
	p, err := kafka.NewProducer(&kafka.ConfigMap{
		"bootstrap.servers": addr,
		"sasl.mechanism":    "SCRAM-SHA-256",
		"security.protocol": "SASL_PLAINTEXT",
		"sasl.username":     user,
		"sasl.password":     password,
	})
	if err != nil {
		panic(err)
	}

	// Close the producer on exit
	defer p.Close()
	
	// produce X number of messages
	for i := 0; i < numMessages; i++ {
		order := generateOrder()
		orderBytes, err := json.Marshal(order)
		if err != nil {
			log.Fatal("failed to marshal order:", err)
		}

		err = p.Produce(&kafka.Message{
			TopicPartition: kafka.TopicPartition{Topic: &topic, Partition: kafka.PartitionAny},
			Key:   []byte(order.OrderID),
			Value: orderBytes,
		},nil)
		if err != nil {
			fmt.Printf("Failed to produce message: %v\n", err)
		}

		// Wait for delivery report
		e := <-p.Events()
		m := e.(*kafka.Message)
		if m.TopicPartition.Error != nil {
			fmt.Printf("Delivery failed for message with order ID %s\n", order.OrderID)
		} else {
			fmt.Printf("Delivered message with order ID %s\n", order.OrderID)
		}

		
	}

}

func generateOrder() order {
	orderID := strconv.Itoa(rand.Intn(1000000000))
	customerID := strconv.Itoa(rand.Intn(10000))
	numItems := rand.Intn(5) + 1
	items := make([]item, numItems)
	for i := 0; i < numItems; i++ {
		items[i] = generateItem()
	}
	status := status(rand.Intn(3))
	return order{
		OrderID:    orderID,
		CustomerID: customerID,
		Items:      items,
		Status:     status,
	}
}

func generateItem() item {
	productID := rand.Intn(100)
	quantity := rand.Intn(10) + 1
	price := float64(rand.Intn(10000)) / 100
	return item{
		Product:  productID,
		Quantity: quantity,
		Price:    price,
	}
}

