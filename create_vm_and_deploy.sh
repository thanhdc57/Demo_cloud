#!/bin/bash

# Configuration
PROJECT_ID=$(gcloud config get-value project)
ZONE="us-central1-a"
VM_NAME="democloud-vm"
MACHINE_TYPE="e2-medium"
IMAGE_FAMILY="ubuntu-2204-lts"
IMAGE_PROJECT="ubuntu-os-cloud"

# Exit on error
set -e

echo "Starting deployment to Google Compute Engine..."

# 1. Enable Compute Engine API
echo "Enabling Compute Engine API (this may take a minute)..."
gcloud services enable compute.googleapis.com

# 2. Check if VM exists
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
        --tags=http-server,https-server \
        --scopes=cloud-platform
    
    echo "Wait for VM to initialize..."
    sleep 30
fi

# 3. Create firewall rule if it doesn't exist
if ! gcloud compute firewall-rules describe default-allow-http &> /dev/null; then
    echo "Creating HTTP firewall rule..."
    gcloud compute firewall-rules create default-allow-http \
        --allow=tcp:80 \
        --target-tags=http-server
fi

# 4. Prepare deployment script for the VM
cat <<EOF > remote_setup.sh
#!/bin/bash
set -e

# Update and install Docker
echo "Installing Docker..."
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch="\$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "\$(. /etc/os-release && echo "\$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Ensure docker-compose is available (alias if needed)
if ! command -v docker-compose &> /dev/null; then
    echo "Aliasing docker-compose to docker compose..."
    echo 'alias docker-compose="docker compose"' >> ~/.bashrc
    shopt -s expand_aliases
    alias docker-compose="docker compose"
fi

# Setup app directory
mkdir -p ~/app
cd ~/app

# Clean up any existing containers
echo "Stopping existing containers..."
sudo docker compose down || true
EOF

# 5. Copy files to VM
echo "Copying project files to VM..."
# Exclude heavy folders locally before copying (though scp follows .gitignore if we used rsync, simple scp copies everything)
# We will just copy the necessary source files.
# Using tar to bundle and standard gcloud compute scp
tar -czf app_bundle.tar.gz . --exclude=node_modules --exclude=obj --exclude=bin --exclude=.git --exclude=dist

gcloud compute scp app_bundle.tar.gz $VM_NAME:~/ --zone=$ZONE

# 6. Execute deployment on VM
echo "Executing deployment on VM..."
gcloud compute ssh $VM_NAME --zone=$ZONE --command="
    chmod +x remote_setup.sh
    ./remote_setup.sh
    
    # Unzip
    tar -xzf app_bundle.tar.gz -C ~/app
    
    cd ~/app
    
    # Build and Run
    echo 'Building and starting application...'
    sudo docker compose up -d --build
    
    echo 'Deployment successful!'
    echo 'Public IP:'
    curl -s ifconfig.me
"

# Clean up local tar
rm app_bundle.tar.gz

echo "------------------------------------------------"
echo "Deployment Complete."
echo "Get the External IP from above or run: gcloud compute instances list"
echo "Access the app at http://<EXTERNAL_IP>"
