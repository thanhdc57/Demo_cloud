#!/bin/bash
PROJECT_ID=$(gcloud config get-value project)
ZONE="us-central1-a"
VMS="demo-frontend demo-backend demo-db"

echo "Starting VMs..."
gcloud compute instances start $VMS --zone=$ZONE

echo "Waiting for services to recover..."
# Optional: Wait loop or check health
echo "VMs started. It may take a minute for containers to be ready."
