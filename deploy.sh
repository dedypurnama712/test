#!/bin/bash

set -u

CONTAINER_NAME="devops-app"
BINARY_PATH="/app/app"
NEW_BINARY="./app-hotfix"
BACKUP_PATH="./app.backup"

echo "========================================"
echo "Starting binary deployment"
echo "========================================"

echo "[1/6] Checking container..."
if ! docker inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
    echo "ERROR: Container $CONTAINER_NAME not found"
    exit 1
fi

echo "[2/6] Checking new binary..."
if [ ! -f "$NEW_BINARY" ]; then
    echo "ERROR: New binary $NEW_BINARY not found"
    exit 1
fi

echo "[3/6] Backing up current binary..."
docker cp "$CONTAINER_NAME:$BINARY_PATH" "$BACKUP_PATH"

echo "[4/6] Replacing binary..."
docker cp "$NEW_BINARY" "$CONTAINER_NAME:$BINARY_PATH"

echo "[5/6] Restarting container..."
docker restart "$CONTAINER_NAME"

echo "[6/6] Health check..."
sleep 3

if curl -f http://localhost:8080/health >/dev/null 2>&1; then
    echo "========================================"
    echo "Deployment successful."
    echo "New binary is running."
    echo "========================================"
    rm -f "$BACKUP_PATH"
    exit 0
fi

echo "========================================"
echo "ERROR: Health check failed."
echo "Starting rollback..."
echo "========================================"

echo "[ROLLBACK 1/3] Restoring previous binary..."
docker cp "$BACKUP_PATH" "$CONTAINER_NAME:$BINARY_PATH"

echo "[ROLLBACK 2/3] Restarting container..."
docker restart "$CONTAINER_NAME"

echo "[ROLLBACK 3/3] Verifying rollback..."
sleep 3

if curl -f http://localhost:8080/health >/dev/null 2>&1; then
    echo "========================================"
    echo "Rollback successful."
    echo "Previous binary restored."
    echo "========================================"
    rm -f "$BACKUP_PATH"
    exit 1
else
    echo "========================================"
    echo "CRITICAL: Rollback failed."
    echo "Manual intervention required."
    echo "========================================"
    exit 2
fi
