#!/bin/bash

set -e

CONTAINER_NAME="devops-app"
BINARY_PATH="/app/app"
NEW_BINARY="./app"
BACKUP_PATH="/tmp/app.backup"

echo "================================"
echo "Starting deployment"
echo "================================"

echo "[1/5] Checking container..."
if ! docker inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
    echo "ERROR: Container $CONTAINER_NAME not found"
    exit 1
fi

echo "[2/5] Backing up current binary..."
docker cp "$CONTAINER_NAME:$BINARY_PATH" "$BACKUP_PATH"

echo "[3/5] Copying new binary..."
docker cp "$NEW_BINARY" "$CONTAINER_NAME:$BINARY_PATH"

echo "[4/5] Restarting container..."
docker restart "$CONTAINER_NAME"

echo "[5/5] Health check..."
sleep 3

if curl -f http://localhost:8080/health >/dev/null 2>&1; then
    echo "Deployment successful."
    echo "New binary is running."
    exit 0
fi

echo "ERROR: Health check failed."
echo "Starting rollback..."

echo "Restoring previous binary..."
docker cp "$BACKUP_PATH" "$CONTAINER_NAME:$BINARY_PATH"

echo "Restarting container with previous binary..."
docker restart "$CONTAINER_NAME"

sleep 3

if curl -f http://localhost:8080/health >/dev/null 2>&1; then
    echo "Rollback successful."
    exit 1
else
    echo "CRITICAL: Rollback failed."
    exit 2
fi
