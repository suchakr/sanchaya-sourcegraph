#!/bin/bash
set -euo pipefail

echo "Stage 3: Preparing Sourcegraph deployment..."

if [ -f ~/sourcegraph/checkpoints/03_sourcegraph_prep.done ]; then
    echo "Stage 3 already completed."
    exit 0
fi

# The repository is already cloned by the 00_allocate_resources.sh script
# We just need to create the necessary directories for Sourcegraph data

# Create necessary directories for Sourcegraph data
sudo mkdir -p /mnt/docker-data/sourcegraph-data/{gitserver,repos,codeintel-db,pgsql}
sudo chown -R 999:999 /mnt/docker-data/sourcegraph-data/{gitserver,repos,codeintel-db,pgsql}

# Copy our local configuration if available
if [ -d "$HOME/sanchaya-sourcegraph/config" ]; then
    sudo mkdir -p /etc/sourcegraph
    sudo cp -r $HOME/sanchaya-sourcegraph/config/* /etc/sourcegraph/
fi

# Create checkpoint
mkdir -p ~/sourcegraph/checkpoints
touch ~/sourcegraph/checkpoints/03_sourcegraph_prep.done
echo "✅ Stage 3: Sourcegraph preparation complete"
