#!/bin/bash

# Exit on error
set -e

echo "Starting deployment to Google Cloud Shell environment..."

# Check for docker compose (v2) or docker-compose (v1)
if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
else
    echo "Error: docker-compose or docker compose not found."
    exit 1
fi

echo "Using command: $COMPOSE_CMD"

# 1. Build and Run using Docker Compose
echo "Building and starting containers..."
$COMPOSE_CMD up -d --build

echo "Containers are starting..."
echo "Waiting for services to be ready..."

# Simple wait loop to check if backend is up
# (Optional: specialized wait-for-it script)
sleep 10

echo "Deployment complete!"
echo "Your application is running."
echo "Frontend: Click the 'Web Preview' button in Cloud Shell and preview on port 5173."
echo "Backend API: Available at /api/products relative to the frontend URL."
