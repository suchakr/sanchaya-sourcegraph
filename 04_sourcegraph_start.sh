#!/bin/bash
set -euo pipefail

# Default to HTTP if no argument is provided
PROTOCOL=${1:-http}

echo "Stage 4: Starting Sourcegraph services with ${PROTOCOL^^} protocol..."

mkdir -p ./.checkpoints

if [ -f ./.checkpoints/04_sourcegraph_start.done ]; then
    echo "Stage 4 already completed."
    exit 0
fi

# We're already in the correct directory since the script is run from the project root

# Clean up any existing Docker resources to prevent conflicts
echo "Cleaning up any existing Docker resources..."
sudo docker-compose down --volumes || true
sudo docker rm -f $(sudo docker ps -aq) || true

# Get the server's external IP
EXTERNAL_IP=$(curl -s ifconfig.me)
echo "📍 Detected external IP: $EXTERNAL_IP"

# Pull the latest images
echo "Pulling latest Docker images..."
sudo docker-compose pull

if [[ "$PROTOCOL" == "https" ]]; then
    echo "🔒 Setting up HTTPS deployment..."
    
    # Create .env.https from .env.gcp template
    sudo cp .env.gcp .env.https
    
    # Update the .env.https file with the correct IP address
    sudo sed -i "s|SG_PORT=443|SG_PORT=443|g" .env.https
    sudo sed -i "s|SG_EXTERNAL_URL=https://YOUR_VM_EXTERNAL_IP_OR_DOMAIN|SG_EXTERNAL_URL=https://$EXTERNAL_IP|g" .env.https
    sudo sed -i "s|SG_SITE_ADDRESS=YOUR_VM_EXTERNAL_IP_OR_DOMAIN|SG_SITE_ADDRESS=$EXTERNAL_IP|g" .env.https
    sudo sed -i "s|SG_HTTPS_ENABLED=true|SG_HTTPS_ENABLED=true|g" .env.https
    
    echo "🚀 Starting Sourcegraph services with HTTPS configuration..."
    sudo docker-compose -f docker-compose.yml -f docker-compose.override.yml --env-file .env.https up -d
    
    FINAL_URL="https://$EXTERNAL_IP"
    echo "⚠️  Note: It may take a few minutes for Let's Encrypt to issue a certificate."
    echo "⚠️  Make sure ports 80 and 443 are open in your firewall."
else
    echo "🔓 Setting up HTTP deployment..."
    
    # For HTTP, we'll use the default .env file
    echo "🚀 Starting Sourcegraph services with HTTP configuration..."
    sudo docker-compose -f docker-compose.yml -f docker-compose.override.yml up -d
    
    FINAL_URL="http://$EXTERNAL_IP:7080"
fi

# Wait for services to be healthy
echo "⏳ Waiting for services to be healthy..."
sleep 30

# Verify core services are running
if ! sudo docker-compose ps | grep -q "Up"; then
    echo "❌ Error: Some services failed to start"
    sudo docker-compose ps
    exit 1
fi

# Create checkpoint
touch ./.checkpoints/04_sourcegraph_start.done
echo "✅ Stage 4: Sourcegraph services started successfully"
echo "🌟 You can now access Sourcegraph at $FINAL_URL"
