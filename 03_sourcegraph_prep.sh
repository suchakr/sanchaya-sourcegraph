#!/bin/bash
set -euo pipefail

echo "Stage 3: Preparing Sourcegraph deployment..."

if [ -f ~/sourcegraph/checkpoints/03_sourcegraph_prep.done ]; then
    echo "Stage 3 already completed."
    exit 0
fi

# Clone the customized Sourcegraph Docker Compose repository
DEPLOY_DIR="$HOME/deploy-sourcegraph-docker"
REPO_URL="https://github.com/suchakr/sanchaya-sourcegraph.git"

# Ensure clean state
rm -rf "${DEPLOY_DIR}"
git clone "${REPO_URL}" "${DEPLOY_DIR}"
cd "${DEPLOY_DIR}"

# Create necessary directories for Sourcegraph data
sudo mkdir -p /mnt/docker-data/sourcegraph-data/{gitserver,repos,codeintel-db,pgsql}
sudo chown -R 999:999 /mnt/docker-data/sourcegraph-data/{gitserver,repos,codeintel-db,pgsql}

# Copy our local configuration if available
if [ -d "$HOME/sourcegraph-config" ]; then
    sudo mkdir -p /etc/sourcegraph
    sudo cp -r $HOME/sourcegraph-config/* /etc/sourcegraph/
fi

# Create checkpoint
mkdir -p ~/sourcegraph/checkpoints
touch ~/sourcegraph/checkpoints/03_sourcegraph_prep.done
echo "✅ Stage 3: Sourcegraph preparation complete"
