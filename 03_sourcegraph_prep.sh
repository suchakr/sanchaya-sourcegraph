#!/bin/bash
set -euo pipefail

echo "Stage 3: Preparing Sourcegraph deployment..."

if [ -f ./.checkpoints/03_sourcegraph_prep.done ]; then
    echo "Stage 3 already completed."
    exit 0
fi

# The repository is already cloned by the 00_allocate_resources.sh script
# We just need to create the necessary directories for Sourcegraph data

# Create necessary directories for Sourcegraph data
mkdir -p ./sourcegraph-data/{gitserver-0,repos,codeintel-db,pgsql,prometheus,redis-store,redis-cache,zoekt,codeinsights-db,caddy}

# Set ownership for services running as UID 999
sudo chown -R 999:999 ./sourcegraph-data/{gitserver-0,repos,codeintel-db,pgsql,prometheus,redis-store,redis-cache,zoekt,codeinsights-db}
sudo chmod -R 755 ./sourcegraph-data/{gitserver-0,repos,codeintel-db,pgsql,prometheus,redis-store,redis-cache,zoekt,codeinsights-db}

sudo chown -R 70:70 ./sourcegraph-data/codeinsights-db
sudo chmod -R 750 ./sourcegraph-data/codeinsights-db

sudo chown -R 70:70 ./sourcegraph-data/codeintel-db
sudo chmod -R 750 ./sourcegraph-data/codeintel-db

sudo chown -R 70:70 ./sourcegraph-data/pgsql
sudo chmod -R 750 ./sourcegraph-data/pgsql

# Set ownership and permissions for Caddy (needs root and stricter permissions for security)
sudo chown -R root:root ./sourcegraph-data/caddy
sudo chmod -R 755 ./sourcegraph-data/caddy

sudo chown -R root:root ./sourcegraph-data/prometheus
sudo chmod -R 755 ./sourcegraph-data/prometheus

sudo chown -R root:root ./sourcegraph-data/zoekt
sudo chmod -R 755 ./sourcegraph-data/zoekt

# Create checkpoint
mkdir -p ./.checkpoints
touch ./.checkpoints/03_sourcegraph_prep.done
echo "✅ Stage 3: Sourcegraph preparation complete"
