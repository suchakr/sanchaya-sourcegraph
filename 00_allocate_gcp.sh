#!/bin/bash
set -euo pipefail

# Configuration - Cost Optimized (Inspired by Azure)
PROJECT_ID=$(gcloud config get-value project)
ZONE="us-central1-a"  # Cheapest zone
INSTANCE_NAME="sourcegraph-cost-optimized"
# Switch to e2-standard-2 (2 vCPUs, 8GB RAM) - matches Azure's burstable performance
MACHINE_TYPE="e2-standard-2"  # ~$48.91/month - 50% cheaper than e2-standard-4
BOOT_DISK_SIZE="50GB"  # Single disk approach like Azure, but bigger than 32GB for more headroom
STATIC_IP_NAME="sourcegraph-static-ip"

# Detect GCP username
GCP_USERNAME=$(whoami)
echo "🔑 Using username: $GCP_USERNAME"

# Function to check if a resource exists
resource_exists() {
    local cmd=$1
    local resource=$2
    eval "$cmd $resource" &>/dev/null
}

echo "🚀 Allocating cost-optimized GCP resources for Sourcegraph..."

# Create static IP if it doesn't exist
echo "📍 Setting up static IP..."
if ! resource_exists "gcloud compute addresses describe --region=${ZONE%-*}" "$STATIC_IP_NAME"; then
    gcloud compute addresses create $STATIC_IP_NAME --region=${ZONE%-*}
fi

# Get the static IP address
STATIC_IP=$(gcloud compute addresses describe $STATIC_IP_NAME \
    --region=${ZONE%-*} \
    --format='get(address)')

# Create the VM instance - NO SPOT/PREEMPTIBLE to avoid interruptions
echo "🖥️ Creating cost-optimized regular VM instance..."
if ! resource_exists "gcloud compute instances describe --zone=$ZONE" "$INSTANCE_NAME"; then
    gcloud compute instances create $INSTANCE_NAME \
        --zone=$ZONE \
        --machine-type=$MACHINE_TYPE \
        --network-interface=network-tier=PREMIUM,address=$STATIC_IP \
        --maintenance-policy=MIGRATE \
        --create-disk=auto-delete=yes,boot=yes,device-name=$INSTANCE_NAME,image-family=ubuntu-2204-lts,image-project=ubuntu-os-cloud,size=$BOOT_DISK_SIZE,type=pd-standard \
        --tags=http-server,https-server \
        --metadata=startup-script='#!/bin/bash
        # Create application directory
        mkdir -p /opt/sourcegraph
        chown -R '${GCP_USERNAME}':'${GCP_USERNAME}' /opt/sourcegraph
        # Create organized directory structure like Azure
        mkdir -p /home/'${GCP_USERNAME}'/sg
        chown -R '${GCP_USERNAME}':'${GCP_USERNAME}' /home/'${GCP_USERNAME}'/sg'

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
        --rules=tcp:80,tcp:443,tcp:7080,tcp:22 \
        --source-ranges=0.0.0.0/0 \
        --target-tags=http-server,https-server
fi

# Install git and clone repositories (like Azure setup)
echo "📦 Installing git and cloning repositories on VM..."
REPO_URL_SG="https://github.com/suchakr/sanchaya-sourcegraph.git"
DEPLOY_DIR_SG="/home/$GCP_USERNAME/sg/sanchaya-sourcegraph"

gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command="
    sudo apt-get update && 
    sudo apt-get install -y git && 
    sudo rm -rf $DEPLOY_DIR_SG && 
    mkdir -p /home/$GCP_USERNAME/sg && 
    git clone $REPO_URL_SG $DEPLOY_DIR_SG && 
    chmod +x $DEPLOY_DIR_SG/*.sh && 
    sudo chown -R $GCP_USERNAME:$GCP_USERNAME $DEPLOY_DIR_SG"

# Clone Zoekt repository like Azure
REPO_URL_ZKT="https://github.com/suchakr/sanchaya-zoekt.git"
DEPLOY_DIR_ZKT="/home/$GCP_USERNAME/sg/sanchaya-zoekt"

gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command="
    sudo rm -rf $DEPLOY_DIR_ZKT && 
    git clone $REPO_URL_ZKT $DEPLOY_DIR_ZKT && 
    chmod +x $DEPLOY_DIR_ZKT/*.sh && 
    sudo chown -R $GCP_USERNAME:$GCP_USERNAME $DEPLOY_DIR_ZKT"

echo "✅ Cost-optimized resource allocation complete!"
echo "🌐 Static IP: $STATIC_IP"
echo ""
echo "💰 Estimated monthly cost: ~\$55-60"
echo "🖥️  VM: e2-standard-2 (2 vCPUs, 8GB RAM) - Regular instance (no preemption)"
echo "💾 Storage: 50GB Standard Persistent Disk (boot disk only)"
echo "🌐 Network: Static IP (~\$2.90/month)"
echo ""
echo "💡 Cost savings vs original:"
echo "   - VM: ~\$50/month savings (e2-standard-2 vs e2-custom-4-17920)"
echo "   - Storage: ~\$15/month savings (50GB standard vs 100GB SSD + 10GB boot)"
echo "   - Reliability: No preemption interruptions"
echo ""
echo "You can now:"
echo "1. SSH into the VM:        gcloud compute ssh $INSTANCE_NAME --zone=$ZONE"
echo "2. Run stages manually:    cd ~/sg/sanchaya-sourcegraph && ./01_docker_install.sh"
echo "3. App data location:      /opt/sourcegraph"