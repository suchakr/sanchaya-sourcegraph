#!/bin/bash
set -euo pipefail

# Configuration
PROJECT_ID=$(gcloud config get-value project)
ZONE="us-central1-a"
INSTANCE_NAME="sourcegraph-spot"
MACHINE_TYPE="e2-standard-8"  # Using e2 for better cost efficiency
DATA_DISK_NAME="sourcegraph-data"
DATA_DISK_SIZE="100GB"
STATIC_IP_NAME="sourcegraph-static-ip"

# Detect GCP username (will use the same as local user)
GCP_USERNAME=$(whoami)
echo "🔑 Using username: $GCP_USERNAME"

# Function to check if a resource exists
resource_exists() {
    local cmd=$1
    local resource=$2
    eval "$cmd $resource" &>/dev/null
}

echo "🚀 Allocating GCP resources for Sourcegraph..."

# Create static IP if it doesn't exist
echo "📍 Setting up static IP..."
if ! resource_exists "gcloud compute addresses describe --region=${ZONE%-*}" "$STATIC_IP_NAME"; then
    gcloud compute addresses create $STATIC_IP_NAME --region=${ZONE%-*}
fi

# Get the static IP address
STATIC_IP=$(gcloud compute addresses describe $STATIC_IP_NAME \
    --region=${ZONE%-*} \
    --format='get(address)')

# Create persistent disk if it doesn't exist
echo "💾 Setting up persistent disk..."
if ! resource_exists "gcloud compute disks describe --zone=$ZONE" "$DATA_DISK_NAME"; then
    gcloud compute disks create $DATA_DISK_NAME \
        --size=$DATA_DISK_SIZE \
        --type=pd-ssd \
        --zone=$ZONE
fi

# Create the VM instance
echo "🖥️  Creating Spot VM instance..."
if ! resource_exists "gcloud compute instances describe --zone=$ZONE" "$INSTANCE_NAME"; then
    gcloud compute instances create $INSTANCE_NAME \
        --zone=$ZONE \
        --machine-type=$MACHINE_TYPE \
        --network-interface=network-tier=PREMIUM,address=$STATIC_IP \
        --maintenance-policy=TERMINATE \
        --provisioning-model=SPOT \
        --instance-termination-action=STOP \
        --create-disk=auto-delete=yes,boot=yes,device-name=$INSTANCE_NAME,image-family=ubuntu-2204-lts,image-project=ubuntu-os-cloud,size=10 \
        --create-disk=name=$DATA_DISK_NAME,device-name=$DATA_DISK_NAME,mode=rw \
        --tags=http-server,https-server

    # Wait for VM to be ready
    echo "⏳ Waiting for VM to be ready..."
    sleep 30
fi

# Create firewall rules if they don't exist
echo "🔒 Setting up firewall rules..."
if ! resource_exists "gcloud compute firewall-rules describe" "allow-sourcegraph-web"; then
    gcloud compute firewall-rules create allow-sourcegraph-web \
        --direction=INGRESS \
        --priority=1000 \
        --network=default \
        --action=ALLOW \
        --rules=tcp:80,tcp:443,tcp:7080 \
        --source-ranges=0.0.0.0/0 \
        --target-tags=http-server,https-server
fi

# Install git and clone the repository on the VM
echo "📦 Installing git and cloning repository on VM..."
REPO_URL="https://github.com/suchakr/sanchaya-sourcegraph.git"
DEPLOY_DIR="~/sanchaya-sourcegraph"

gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command="sudo apt-get update && sudo apt-get install -y git && rm -rf $DEPLOY_DIR && git clone $REPO_URL $DEPLOY_DIR && chmod +x $DEPLOY_DIR/*.sh"

echo "✅ Resource allocation complete!"
echo "🌐 Static IP: $STATIC_IP"
echo ""
echo "You can now:"
echo "1. SSH into the VM:        gcloud compute ssh $INSTANCE_NAME --zone=$ZONE"
echo "2. Run stages manually:    cd ~/sanchaya-sourcegraph && ./01_docker_install.sh"
echo "   or"
echo "3. Use the wrapper:        cd ~/sanchaya-sourcegraph && ./deploy.sh"
