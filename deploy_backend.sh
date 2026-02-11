#!/bin/bash
set -e

# Configuration
PROJECT_ID=$(gcloud config get-value project)
ZONE="us-central1-a"
BACKEND_VM="demo-backend"
DB_VM="demo-db"

echo "Deploying Backend Update to $BACKEND_VM..."

# Get DB Internal IP
DB_IP=$(gcloud compute instances describe $DB_VM --zone=$ZONE --format='get(networkInterfaces[0].networkIP)')
echo "DB Internal IP: $DB_IP"

# Create archive
echo "Packaging Backend..."
tar -czf backend.tar.gz DemoCloud.Backend

# Upload Archive
echo "Uploading..."
gcloud compute scp backend.tar.gz $BACKEND_VM:~/ --zone=$ZONE

# Create Deployment ScriptLocally
cat <<EOF > deploy_backend_logic.sh
#!/bin/bash
set -e
tar -xzf backend.tar.gz
cd DemoCloud.Backend

# Create Dockerfile.vm
cat <<DOCKERFILE > Dockerfile.vm
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
ENTRYPOINT dotnet DemoCloud.Backend.dll
DOCKERFILE

# Build and Run
echo 'Building Backend...'
sudo docker build -t democloud-backend -f Dockerfile.vm .

echo 'Restarting Backend...'
sudo docker rm -f backend || true

# Run container
sudo docker run -d \\
    --name backend \\
    -p 8080:8080 \\
    -e ConnectionStrings__DefaultConnection='Host=$DB_IP;Database=democloud;Username=postgres;Password=postgres' \\
    -e ASPNETCORE_ENVIRONMENT=Development \\
    --restart always \\
    democloud-backend

# Wait and Check
sleep 5
if [ "\$(sudo docker inspect -f '{{.State.Running}}' backend)" = "true" ]; then
    echo "Backend container is RUNNING."
else
    echo "Backend container FAILED to start. Logs:"
    sudo docker logs backend
    exit 1
fi
EOF

# Upload and Run Script
chmod +x deploy_backend_logic.sh
gcloud compute scp deploy_backend_logic.sh $BACKEND_VM:~/ --zone=$ZONE
echo "Running Remote Deployment..."
gcloud compute ssh $BACKEND_VM --zone=$ZONE --command="./deploy_backend_logic.sh"

# Cleanup
rm backend.tar.gz deploy_backend_logic.sh

echo "Backend Updated Successfully!"
