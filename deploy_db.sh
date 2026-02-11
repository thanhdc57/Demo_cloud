#!/bin/bash
set -e

# Configuration
ZONE="us-central1-a"
DB_VM="demo-db"

echo "Deploying Database Update to $DB_VM..."

gcloud compute ssh $DB_VM --zone=$ZONE --command="
    set -e
    # Stop existing
    sudo docker rm -f postgres || true
    
    # Run
    sudo docker run -d \
        --name postgres \
        -e POSTGRES_USER=postgres \
        -e POSTGRES_PASSWORD=postgres \
        -e POSTGRES_DB=democloud \
        -p 5432:5432 \
        -v postgres_data:/var/lib/postgresql/data \
        --restart always \
        postgres:15-alpine
        
    echo 'Database restarted.'
"
echo "Database Deployed Successfully!"
