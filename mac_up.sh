#!/bin/zsh

# mac_up.sh - Script to create required directories and start Sourcegraph containers on macOS
# 
# This script:
# 1. Creates all necessary directories for Sourcegraph data
# 2. Starts the Docker containers with the correct configuration files

echo "🚀 Starting Sourcegraph containers for macOS..."

# Set the base directory for data storage
DATA_DIR="./sourcegraph-data"

# Create all required data directories
echo "📁 Creating data directories..."
mkdir -p \
  "$DATA_DIR/blobstore" \
  "$DATA_DIR/caddy" \
  "$DATA_DIR/codeinsights-db" \
  "$DATA_DIR/codeintel-db" \
  "$DATA_DIR/gitserver-0" \
  "$DATA_DIR/pgsql" \
  "$DATA_DIR/prometheus" \
  "$DATA_DIR/redis-cache" \
  "$DATA_DIR/redis-store" \
  "$DATA_DIR/repo-updater" \
  "$DATA_DIR/searcher-0" \
  "$DATA_DIR/sourcegraph-frontend-0" \
  "$DATA_DIR/sourcegraph-frontend-internal" \
  "$DATA_DIR/symbols-0" \
  "$DATA_DIR/worker" \
  "$DATA_DIR/zoekt"

# Start the containers using the Mac-specific configuration
echo "🐳 Starting Docker containers..."
docker compose --env-file .env.mac -f docker-compose.yml -f docker-compose.mac.yml up -d

echo "✅ Sourcegraph is starting up! It may take a few minutes to be fully ready."
echo "🌐 Once ready, you can access it at: http://localhost:7080"
