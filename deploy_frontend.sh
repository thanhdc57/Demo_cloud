#!/bin/bash
set -e

# Configuration
PROJECT_ID=$(gcloud config get-value project)
ZONE="us-central1-a"
FRONTEND_VM="demo-frontend"
BACKEND_VM="demo-backend"

echo "Deploying Frontend Update to $FRONTEND_VM..."

# Get Backend Internal IP (needed for Nginx config)
BACKEND_IP=$(gcloud compute instances describe $BACKEND_VM --zone=$ZONE --format='get(networkInterfaces[0].networkIP)')
echo "Backend Internal IP: $BACKEND_IP"

# Create archive
echo "Packaging Frontend..."
tar -czf frontend.tar.gz DemoCloud.Frontend

# Upload
echo "Uploading..."
gcloud compute scp frontend.tar.gz $FRONTEND_VM:~/ --zone=$ZONE

# Deploy on VM
echo "Running Remote Deployment..."
gcloud compute ssh $FRONTEND_VM --zone=$ZONE --command="
    set -e
    tar -xzf frontend.tar.gz
    cd DemoCloud.Frontend
    
    echo 'Building Frontend...'
    sudo docker build -t democloud-frontend .
    
    echo 'Restarting Frontend...'
    sudo docker rm -f frontend || true
    
    sudo docker run -d \
        --name frontend \
        -p 80:80 \
        -e BACKEND_HOST=$BACKEND_IP \
        --restart always \
        democloud-frontend
"

# Cleanup
rm frontend.tar.gz

echo "Frontend Updated Successfully!"
