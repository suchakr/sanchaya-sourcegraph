#!/bin/bash
set -euo pipefail

echo "Stage 1: Installing Docker and dependencies..."

# Setup directories with proper ownership
SOURCEGRAPH_HOME="/home/$(whoami)/sourcegraph"
sudo mkdir -p ${SOURCEGRAPH_HOME}/checkpoints
sudo chown -R $(whoami):$(whoami) ${SOURCEGRAPH_HOME}

if [ -f ${SOURCEGRAPH_HOME}/checkpoints/01_docker_install.done ]; then
    echo "Stage 1 already completed."
    exit 0
fi

# Install prerequisites
sudo apt-get update
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    jq

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Set up the stable repository
echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Install Docker Compose
DOCKER_COMPOSE_VERSION="1.29.2"
sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Add current user to docker group
sudo usermod -aG docker $USER

# Create checkpoint
touch ~/sourcegraph/checkpoints/01_docker_install.done
echo "✅ Stage 1: Docker installation complete"
