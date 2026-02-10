#!/bin/bash

# Configuration
PROJECT_ID=$(gcloud config get-value project)
ZONE="us-central1-a"
MACHINE_TYPE="e2-micro"
IMAGE_FAMILY="ubuntu-2204-lts"
IMAGE_PROJECT="ubuntu-os-cloud"

# VM Names
DB_VM="demo-db"
BACKEND_VM="demo-backend"
FRONTEND_VM="demo-frontend"

# Exit on error
set -e

echo "Starting distributed deployment to 3 Google Compute Engine VMs..."

# 1. Enable Compute Engine API
echo "Enabling Compute Engine API..."
gcloud services enable compute.googleapis.com

# Function to create VM
# Create startup script file
cat <<EOF > startup.sh
#! /bin/bash
apt-get update
apt-get install -y ca-certificates curl gnupg
# Add Docker's official GPG key:
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
# Add the repository to Apt sources:
echo \
  "deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  \$(. /etc/os-release && echo "\$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Setup App Directory
mkdir -p /home/$USER/app
chown -R $USER:$USER /home/$USER/app
EOF

create_vm() {
    local VM_NAME=$1
    local TAGS=$2
    if gcloud compute instances describe $VM_NAME --zone=$ZONE &> /dev/null; then
        echo "VM '$VM_NAME' already exists."
    else
        echo "Creating VM '$VM_NAME'..."
        gcloud compute instances create $VM_NAME \
            --project=$PROJECT_ID \
            --zone=$ZONE \
            --machine-type=$MACHINE_TYPE \
            --image-family=$IMAGE_FAMILY \
            --image-project=$IMAGE_PROJECT \
            --tags=$TAGS \
            --scopes=cloud-platform \
            --metadata-from-file=startup-script=startup.sh
    fi
}

# 2. Create VMs
create_vm $DB_VM "db-server"
create_vm $BACKEND_VM "backend-server"
create_vm $FRONTEND_VM "http-server,https-server"

echo "Waiting for VMs to initialize..."

# Function to wait for Docker
wait_for_docker() {
    local VM=$1
    echo "Waiting for Docker to be ready on $VM..."
    # Loop up to 5 minutes
    for i in {1..30}; do
        if gcloud compute ssh $VM --zone=$ZONE --command="command -v docker" &> /dev/null; then
            echo "Docker is ready on $VM."
            return 0
        fi
        echo "Docker not yet ready on $VM. Retrying in 10s..."
        sleep 10
    done
    echo "Error: Docker failed to install on $VM."
    return 1
}

# Wait for all VMs
wait_for_docker $DB_VM
wait_for_docker $BACKEND_VM
wait_for_docker $FRONTEND_VM

# 3. Network Configuration
# Get Internal IPs
DB_IP=$(gcloud compute instances describe $DB_VM --zone=$ZONE --format='get(networkInterfaces[0].networkIP)')
BACKEND_IP=$(gcloud compute instances describe $BACKEND_VM --zone=$ZONE --format='get(networkInterfaces[0].networkIP)')
FRONTEND_IP=$(gcloud compute instances describe $FRONTEND_VM --zone=$ZONE --format='get(networkInterfaces[0].networkIP)')

echo "Internal IPs: DB=$DB_IP, Backend=$BACKEND_IP, Frontend=$FRONTEND_IP"

# Firewall Rules
# Allow HTTP for Frontend
if ! gcloud compute firewall-rules describe allow-http-frontend &> /dev/null; then
    gcloud compute firewall-rules create allow-http-frontend --allow=tcp:80 --target-tags=http-server
fi

# Allow Internal Communication (usually allowed by default in 'default' network, but ensuring)
if ! gcloud compute firewall-rules describe allow-internal-custom &> /dev/null; then
     gcloud compute firewall-rules create allow-internal-custom --allow=tcp:0-65535,udp:0-65535,icmp --source-ranges=10.128.0.0/9
fi

# 4. Deploy Database
echo "Deploying Database to $DB_VM..."
gcloud compute ssh $DB_VM --zone=$ZONE --command="
    # Stop existing
    sudo docker rm -f postgres || true
    
    sudo docker run -d \
        --name postgres \
        -e POSTGRES_USER=postgres \
        -e POSTGRES_PASSWORD=postgres \
        -e POSTGRES_DB=democloud \
        -p 5432:5432 \
        -v postgres_data:/var/lib/postgresql/data \
        --restart always \
        postgres:15-alpine
"

# 5. Deploy Backend
echo "Deploying Backend to $BACKEND_VM..."
# Copy Backend Source
tar -czf backend.tar.gz DemoCloud.Backend
gcloud compute scp backend.tar.gz $BACKEND_VM:~/ --zone=$ZONE

gcloud compute ssh $BACKEND_VM --zone=$ZONE --command="
    tar -xzf backend.tar.gz
    cd DemoCloud.Backend
    
    # Validation: List files to ensure we are in correct dir
    ls -F
    
    # We need to adjust the Dockerfile because we are building from within the project dir, 
    # but the original Dockerfile expects to be at solution level.
    # We will create a modified Dockerfile for this specific deployment.
    cat <<EOF > Dockerfile.vm
# Build Stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY DemoCloud.Backend.csproj ./
RUN dotnet restore "./DemoCloud.Backend.csproj"
COPY . .
WORKDIR "/src/."
RUN dotnet build "DemoCloud.Backend.csproj" -c Release -o /app/build

# Publish Stage
FROM build AS publish
RUN dotnet publish "DemoCloud.Backend.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Final Stage
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "DemoCloud.Backend.dll"]
EOF

    echo 'Building Backend with modified Dockerfile...'
    sudo docker build -t democloud-backend -f Dockerfile.vm .
    
    echo 'Running Backend...'
    # Stop existing
    sudo docker rm -f backend || true
    
    sudo docker run -d \
        --name backend \
        -p 8080:8080 \
        -e ConnectionStrings__DefaultConnection='Host=$DB_IP;Database=democloud;Username=postgres;Password=postgres' \
        -e ASPNETCORE_ENVIRONMENT=Development \
        --restart always \
        democloud-backend
"

# 6. Deploy Frontend
echo "Deploying Frontend to $FRONTEND_VM..."
# Copy Frontend Source
tar -czf frontend.tar.gz DemoCloud.Frontend
gcloud compute scp frontend.tar.gz $FRONTEND_VM:~/ --zone=$ZONE

gcloud compute ssh $FRONTEND_VM --zone=$ZONE --command="
    tar -xzf frontend.tar.gz
    cd DemoCloud.Frontend
    
    echo 'Building Frontend...'
    sudo docker build -t democloud-frontend .
    
    echo 'Running Frontend...'
    sudo docker rm -f frontend || true
    
    # IMPORTANT: Nginx proxies to Backend Internal IP
    sudo docker run -d \
        --name frontend \
        -p 80:80 \
        -e BACKEND_HOST=$BACKEND_IP \
        --restart always \
        democloud-frontend
"

# Get Frontend External IP
FRONTEND_EXT_IP=$(gcloud compute instances describe $FRONTEND_VM --zone=$ZONE --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

# Cleanup
rm backend.tar.gz frontend.tar.gz

echo "------------------------------------------------"
echo "Distributed Deployment Complete!"
echo "Frontend is accessible at: http://$FRONTEND_EXT_IP"
echo "Backend is running internally at: $BACKEND_IP"
echo "Database is running internally at: $DB_IP"
