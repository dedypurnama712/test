# Build stage
FROM golang:1.27-alpine AS builder

WORKDIR /app

COPY go.mod ./
COPY main.go ./

ARG VERSION=dev

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build \
    -trimpath \
    -ldflags="-s -w -X main.version=${VERSION}" \
    -o /app/app .

# Runtime stage
FROM scratch

WORKDIR /app

COPY --from=builder /app/app /app/app

EXPOSE 8080

ENTRYPOINT ["/app/app"]