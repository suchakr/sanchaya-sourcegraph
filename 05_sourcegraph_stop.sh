#!/bin/bash
set -euo pipefail

# Check if -v flag is provided for removing volumes
REMOVE_VOLUMES=false
while getopts "v" opt; do
  case $opt in
    v)
      REMOVE_VOLUMES=true
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

echo "🛑 Stopping Sourcegraph services..."

# Stop the containers
if [ "$REMOVE_VOLUMES" = true ]; then
  echo "Stopping and removing containers, networks, images, and volumes..."
  sudo docker-compose -f docker-compose.yml -f docker-compose.override.yml -f docker-compose.resource.yml down --volumes --remove-orphans
else
  echo "Stopping and removing containers, networks, and images (preserving volumes)..."
  sudo docker-compose -f docker-compose.yml -f docker-compose.override.yml -f docker-compose.resource.yml down --remove-orphans
fi

# Clean up the checkpoint from 04_sourcegraph_start.sh
if [ -f ./.checkpoints/04_sourcegraph_start.done ]; then
  echo "Removing checkpoint from 04_sourcegraph_start.sh..."
  rm ./.checkpoints/04_sourcegraph_start.done
fi

echo "✅ Sourcegraph services stopped successfully"
if [ "$REMOVE_VOLUMES" = true ]; then
  echo "⚠️  Note: All volumes have been removed. Data will be lost when restarting."
else
  echo "ℹ️  Note: Volumes have been preserved. Data will be retained when restarting."
fi
