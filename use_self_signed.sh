#!/bin/bash
set -euo pipefail

echo "Switching Sourcegraph to HTTPS with self-signed certificate..."

# Get the server's external IP
EXTERNAL_IP=$(curl -s ifconfig.me)
echo "📍 Detected external IP: $EXTERNAL_IP"

# Stop Sourcegraph services
echo "Stopping existing Sourcegraph services..."
./05_sourcegraph_stop.sh

# Update .env file
echo "Updating environment configuration..."
sudo cp .env.gcp .env
sudo sed -i "s|SG_PORT=443|SG_PORT=443|g" .env
sudo sed -i "s|SG_EXTERNAL_URL=https://YOUR_VM_EXTERNAL_IP_OR_DOMAIN|SG_EXTERNAL_URL=https://$EXTERNAL_IP|g" .env
sudo sed -i "s|SG_SITE_ADDRESS=YOUR_VM_EXTERNAL_IP_OR_DOMAIN|SG_SITE_ADDRESS=$EXTERNAL_IP|g" .env
sudo sed -i "s|SG_HTTPS_ENABLED=true|SG_HTTPS_ENABLED=true|g" .env
sudo sed -i "s|SG_CADDY_CONFIG=./caddy/builtins/https.lets-encrypt-prod.Caddyfile|SG_CADDY_CONFIG=./caddy/builtins/https.self-signed.Caddyfile|g" .env

# Update site-config.json
echo "Updating site configuration..."
FINAL_URL="https://$EXTERNAL_IP"

# Create the config directory if it doesn't exist
mkdir -p ./config

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

# Clean up the Caddy data directory to ensure we start fresh
echo "Cleaning up existing Caddy data..."
sudo rm -rf /mnt/docker-data/sourcegraph-data/caddy/*

# Start Sourcegraph with the new configuration
echo "Starting Sourcegraph with self-signed certificate..."
sudo docker-compose -f docker-compose.yml -f docker-compose.override.yml -f docker-compose.resource.yml up -d

echo "⚠️ Note: Your browser will show a security warning when you access https://$EXTERNAL_IP"
echo "⚠️ You'll need to click 'Advanced' and then 'Proceed anyway' (or similar) to access the site."
echo "⚠️ The connection will still be encrypted, but the certificate is self-signed."

# Wait for services to start
echo "⏳ Waiting for services to start (this may take a minute)..."
sleep 30

# Check if services are running
if sudo docker-compose ps | grep -q "Up"; then
    echo "✅ Sourcegraph is now running with HTTPS (self-signed certificate)"
    echo "✅ You can access it at: https://$EXTERNAL_IP"
else
    echo "❌ There was an issue starting some services."
    sudo docker-compose ps
fi
