# Use an official Golang runtime as a parent image
FROM golang:1.21.3-alpine as builder

# Set the working directory to /app
WORKDIR /app

# Set the build argument for the app version number
ARG APP_VERSION=0.1.0

RUN apk --no-cache update && \
apk --no-cache add git gcc libc-dev

# Kafka Go client is based on the C library librdkafka
ENV CGO_ENABLED 1
ENV GOOS=linux
ENV GOARCH=amd64

# Copy the current directory contents into the container at /app
COPY . /app

# Build the app
RUN go build -tags musl -ldflags "-X main.version=$APP_VERSION" -o main .

# Run the app on alpine
FROM alpine:latest as runner

ARG APP_VERSION=0.1.0

# Copy the build output from the builder container
COPY --from=builder /app/main .

# Set the environment variable for the app version number
ENV APP_VERSION=$APP_VERSION

# Run the Go app when the container starts
CMD ["./main"]
