#!/bin/bash
set -euo pipefail

echo "Stage 3: Preparing Sourcegraph deployment..."

if [ -f ./.checkpoints/03_sourcegraph_prep.done ]; then
    echo "Stage 3 already completed."
    exit 0
fi

# The repository is already cloned by the 00_allocate_resources.sh script
# We just need to create the necessary directories for Sourcegraph data
TARGET_DIR=/mnt/docker-data/sourcegraph-data
if [ ! -d "$TARGET_DIR" ]; then
    echo "Creating target directory: $TARGET_DIR"
    sudo mkdir -p "$TARGET_DIR"
else
    echo "Target directory already exists: $TARGET_DIR"
fi
# Check if the sourcegraph-data directory is empty
# Create necessary directories for Sourcegraph data
sudo mkdir -p $TARGET_DIR/{gitserver-0,repos,codeintel-db,pgsql,prometheus,redis-store,redis-cache,zoekt,codeinsights-db,caddy}

# Set ownership for services running as UID 999
sudo chown -R 999:999 $TARGET_DIR/{gitserver-0,repos,codeintel-db,pgsql,prometheus,redis-store,redis-cache,zoekt,codeinsights-db}
sudo chmod -R 755 $TARGET_DIR/{gitserver-0,repos,codeintel-db,pgsql,prometheus,redis-store,redis-cache,zoekt,codeinsights-db}
sudo chmod -R 777 $TARGET_DIR/gitserver-0

sudo chown -R 70:70 $TARGET_DIR/codeinsights-db
sudo chmod -R 750 $TARGET_DIR/codeinsights-db

sudo chown -R 70:70 $TARGET_DIR/codeintel-db
sudo chmod -R 750 $TARGET_DIR/codeintel-db

sudo chown -R 70:70 $TARGET_DIR/pgsql
sudo chmod -R 750 $TARGET_DIR/pgsql

# Set ownership and permissions for Caddy (needs root and stricter permissions for security)
sudo chown -R root:root $TARGET_DIR/caddy
sudo chmod -R 755 $TARGET_DIR/caddy

sudo chown -R root:root $TARGET_DIR/prometheus
sudo chmod -R 755 $TARGET_DIR/prometheus

sudo chown -R root:root $TARGET_DIR/zoekt
sudo chmod -R 777 $TARGET_DIR/zoekt

# Create checkpoint
mkdir -p ./.checkpoints
touch ./.checkpoints/03_sourcegraph_prep.done
echo "✅ Stage 3: Sourcegraph preparation complete"
