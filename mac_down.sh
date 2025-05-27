#!/bin/zsh

# mac_down.sh - Script to stop Sourcegraph containers on macOS

echo "🛑 Stopping Sourcegraph containers..."

# Stop the containers using the Mac-specific configuration
docker compose --env-file .env.mac -f docker-compose.yml -f docker-compose.mac.yml down

echo "✅ Sourcegraph containers have been stopped."
