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

# Ensure config directory exists
mkdir -p ./config

if [[ "$PROTOCOL" == "https" ]]; then
    echo "🔒 Setting up HTTPS deployment..."
    
    # Create .env from .env.gcp template
    sudo cp .env.gcp .env
    
    # Update the .env file with the correct IP address for HTTPS
    sudo sed -i "s|SG_PORT=443|SG_PORT=443|g" .env
    sudo sed -i "s|SG_EXTERNAL_URL=https://YOUR_VM_EXTERNAL_IP_OR_DOMAIN|SG_EXTERNAL_URL=https://$EXTERNAL_IP|g" .env
    sudo sed -i "s|SG_SITE_ADDRESS=YOUR_VM_EXTERNAL_IP_OR_DOMAIN|SG_SITE_ADDRESS=$EXTERNAL_IP|g" .env
    sudo sed -i "s|SG_HTTPS_ENABLED=true|SG_HTTPS_ENABLED=true|g" .env
    
    FINAL_URL="https://$EXTERNAL_IP"
else
    echo "🔓 Setting up HTTP deployment..."
    
    # Create .env from .env.gcp template
    sudo cp .env.gcp .env
    
    # Update the .env file with the correct IP address for HTTP
    sudo sed -i "s|SG_PORT=443|SG_PORT=7080|g" .env
    sudo sed -i "s|SG_EXTERNAL_URL=https://YOUR_VM_EXTERNAL_IP_OR_DOMAIN|SG_EXTERNAL_URL=http://$EXTERNAL_IP:7080|g" .env
    sudo sed -i "s|SG_SITE_ADDRESS=YOUR_VM_EXTERNAL_IP_OR_DOMAIN|SG_SITE_ADDRESS=$EXTERNAL_IP|g" .env
    sudo sed -i "s|SG_HTTPS_ENABLED=true|SG_HTTPS_ENABLED=false|g" .env
    
    FINAL_URL="http://$EXTERNAL_IP:7080"
fi

# Update site-config.json with the correct external URL
echo "🔄 Updating site-config.json with $PROTOCOL URL..."
if [ -f ./config/site-config.json ]; then
    # If file exists, update the externalURL
    if grep -q "externalURL" ./config/site-config.json; then
        sudo sed -i "s|\"externalURL\": \"[^\"]*\"|\"externalURL\": \"$FINAL_URL\"|g" ./config/site-config.json
    else
        # If externalURL doesn't exist, add it before the last closing brace
        sudo sed -i "s|}|,\n  \"externalURL\": \"$FINAL_URL\"\n}|g" ./config/site-config.json
    fi
else
    # If file doesn't exist, create it with basic configuration
    echo '{
  "externalURL": "'$FINAL_URL'",
  "auth.public": true,
  "auth.accessTokens.allow": "no-user-credentials"
}' | sudo tee ./config/site-config.json > /dev/null
fi

echo "🚀 Starting Sourcegraph services with ${PROTOCOL^^} configuration..."
sudo docker-compose -f docker-compose.yml -f docker-compose.override.yml up -d

if [[ "$PROTOCOL" == "https" ]]; then
    echo "⚠️  Note: It may take a few minutes for Let's Encrypt to issue a certificate."
    echo "⚠️  Make sure ports 80 and 443 are open in your firewall."
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
