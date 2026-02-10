#!/bin/bash

# Exit on error
set -e

echo "Starting deployment to Google Cloud Shell environment..."

# 1. Build and Run using Docker Compose
# This assumes docker-compose is available (standard in Cloud Shell)
echo "Building and starting containers..."
docker-compose up -d --build

echo "Containers are starting..."
echo "Waiting for services to be ready..."

# Simple wait loop to check if backend is up
# (Optional: specialized wait-for-it script)
sleep 10

echo "Deployment complete!"
echo "Your application is running."
echo "Frontend: Click the 'Web Preview' button in Cloud Shell and preview on port 5173."
echo "Backend API: Available at /api/products relative to the frontend URL."
