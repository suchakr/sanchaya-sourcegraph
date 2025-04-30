#!/bin/bash
set -euo pipefail

echo "Stage 4: Starting Sourcegraph services..."

if [ -f ~/sourcegraph/checkpoints/04_sourcegraph_start.done ]; then
    echo "Stage 4 already completed."
    exit 0
fi

cd $HOME/sanchaya-sourcegraph

# Pull the latest images
sudo docker-compose pull

# Start the services
sudo docker-compose up -d

# Wait for services to be healthy
echo "Waiting for services to be healthy..."
sleep 30

# Verify core services are running
if ! sudo docker-compose ps | grep -q "Up"; then
    echo "Error: Some services failed to start"
    sudo docker-compose ps
    exit 1
fi

# Create checkpoint
mkdir -p ~/sourcegraph/checkpoints
touch ~/sourcegraph/checkpoints/04_sourcegraph_start.done
echo "✅ Stage 4: Sourcegraph services started successfully"
echo "🌟 You can now access Sourcegraph at http://$(curl -s ifconfig.me):7080"
