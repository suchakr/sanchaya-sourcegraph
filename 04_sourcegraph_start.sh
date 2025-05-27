#!/bin/bash
set -euo pipefail

echo "Stage 4: Starting Sourcegraph services ..."

mkdir -p ./.checkpoints

if [ -f ./.checkpoints/04_sourcegraph_start.done ]; then
    echo "Stage 4 already completed."
    exit 0
fi

# Clean up any existing Docker resources to prevent conflicts
# echo "Cleaning up any existing Docker resources..."
# sudo docker-compose down --volumes || true
# sudo docker rm -f $(sudo docker ps -aq) || true


# Pull the latest images
echo "Pulling latest Docker images..."
sudo docker compose pull

# Ensure config directory exists
mkdir -p ./config

FINAL_URL="http://localhost:7080"

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

echo "🚀 Starting Sourcegraph services ..."
sudo docker compose -f docker-compose.yml -f docker-compose.override.yml -f docker-compose.resource.yml up -d

# Wait for services to be healthy
echo "⏳ Waiting for services to be healthy..."
sleep 30

# Verify core services are running
if ! sudo docker compose ps | grep -q "Up"; then
    echo "❌ Error: Some services failed to start"
    sudo docker compose ps
    exit 1
fi

# Create checkpoint
touch ./.checkpoints/04_sourcegraph_start.done
echo "✅ Stage 4: Sourcegraph services started successfully"
echo "🌟 You can now access Sourcegraph at $FINAL_URL"
