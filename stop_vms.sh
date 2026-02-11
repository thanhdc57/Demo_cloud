#!/bin/bash
PROJECT_ID=$(gcloud config get-value project)
ZONE="us-central1-a"
VMS="demo-frontend demo-backend demo-db"

echo "Stopping VMs to save cost..."
gcloud compute instances stop $VMS --zone=$ZONE
echo "All VMs stopped."
