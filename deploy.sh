#!/bin/bash

CONTAINER_NAME="devops-app"
BINARY_PATH="/app/app"
NEW_BINARY="./app-hotfix"
BACKUP_PATH="/tmp/app.backup"

echo "[1/6] Checking container..."

if ! docker inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
    echo "ERROR: Container $CONTAINER_NAME not found"
    exit 1
fi

echo "[2/6] Backing up current binary..."

if ! docker cp "$CONTAINER_NAME:$BINARY_PATH" "$BACKUP_PATH"; then
    echo "ERROR: Failed to backup current binary"
    exit 1
fi

echo "[3/6] Copying new binary..."

if ! docker cp "$NEW_BINARY" "$CONTAINER_NAME:$BINARY_PATH"; then
    echo "ERROR: Failed to copy new binary"
    echo "Starting rollback..."

    docker cp "$BACKUP_PATH" "$CONTAINER_NAME:$BINARY_PATH"
    docker restart "$CONTAINER_NAME"

    echo "Rollback completed."
    exit 1
fi

echo "[4/6] Restarting container..."

if ! docker restart "$CONTAINER_NAME"; then
    echo "ERROR: Container restart failed"
    echo "Starting rollback..."

    docker cp "$BACKUP_PATH" "$CONTAINER_NAME:$BINARY_PATH"
    docker restart "$CONTAINER_NAME"

    echo "Rollback completed."
    exit 1
fi

echo "[5/6] Health check..."

sleep 3

if curl -f http://localhost:8080/health >/dev/null 2>&1; then
    echo "Deployment successful."
    echo "New binary is running."
    exit 0
fi

echo "ERROR: Health check failed."
echo "Starting rollback..."

echo "[6/6] Restoring previous binary..."

if ! docker cp "$BACKUP_PATH" "$CONTAINER_NAME:$BINARY_PATH"; then
    echo "CRITICAL: Failed to restore backup."
    exit 2
fi

echo "Restarting container with previous binary..."

if ! docker restart "$CONTAINER_NAME"; then
    echo "CRITICAL: Rollback restart failed."
    exit 2
fi

sleep 3

if curl -f http://localhost:8080/health >/dev/null 2>&1; then
    echo "Rollback successful."
    echo "Previous binary is running."
    exit 1
else
    echo "CRITICAL: Rollback failed."
    exit 2
fi
