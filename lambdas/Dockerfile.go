# Shared Go Lambda builder image
# This Dockerfile is used to build all Go Lambda functions
FROM golang:1.21-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git zip

WORKDIR /build

# Environment for Lambda compilation
ENV CGO_ENABLED=0
ENV GOOS=linux
ENV GOARCH=amd64

#------------------------------------------------------------------------------
# Stage: poll-lambda - RSS polling Lambda function
#------------------------------------------------------------------------------
FROM builder AS poll-lambda-builder

# Copy go module files first for better caching
COPY poll-lambda-go/go.mod poll-lambda-go/go.sum ./
RUN go mod download

# Copy source code
COPY poll-lambda-go/main.go ./

# Build the Lambda binary
RUN go build -tags lambda.norpc -ldflags="-s -w" -o bootstrap main.go

#------------------------------------------------------------------------------
# Stage: merge-lambda - Transcript merging Lambda function
#------------------------------------------------------------------------------
FROM builder AS merge-lambda-builder

# Copy go module files first for better caching
COPY merge-transcript-lambda-go/go.mod merge-transcript-lambda-go/go.sum ./
RUN go mod download

# Copy source code
COPY merge-transcript-lambda-go/main.go ./

# Build the Lambda binary
RUN go build -tags lambda.norpc -ldflags="-s -w" -o bootstrap main.go

#------------------------------------------------------------------------------
# Stage: poll-lambda-package - Creates deployment package for poll Lambda
#------------------------------------------------------------------------------
FROM alpine:latest AS poll-lambda-package

RUN apk add --no-cache zip

WORKDIR /package

COPY --from=poll-lambda-builder /build/bootstrap ./bootstrap
RUN chmod +x bootstrap && zip -9 poll-lambda.zip bootstrap

#------------------------------------------------------------------------------
# Stage: merge-lambda-package - Creates deployment package for merge Lambda
#------------------------------------------------------------------------------
FROM alpine:latest AS merge-lambda-package

RUN apk add --no-cache zip

WORKDIR /package

COPY --from=merge-lambda-builder /build/bootstrap ./bootstrap
RUN chmod +x bootstrap && zip -9 merge-lambda.zip bootstrap

#------------------------------------------------------------------------------
# Stage: aws-runtime - Minimal runtime for AWS Lambda (optional ECR deployment)
#------------------------------------------------------------------------------
FROM public.ecr.aws/lambda/provided:al2023 AS poll-lambda-runtime

COPY --from=poll-lambda-builder /build/bootstrap ${LAMBDA_RUNTIME_DIR}/bootstrap
RUN chmod +x ${LAMBDA_RUNTIME_DIR}/bootstrap

CMD ["bootstrap"]

FROM public.ecr.aws/lambda/provided:al2023 AS merge-lambda-runtime

COPY --from=merge-lambda-builder /build/bootstrap ${LAMBDA_RUNTIME_DIR}/bootstrap
RUN chmod +x ${LAMBDA_RUNTIME_DIR}/bootstrap

CMD ["bootstrap"]
