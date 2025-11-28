#!/bin/bash
set -euo pipefail

echo "Stage 4: Starting Sourcegraph services ..."

mkdir -p ./.checkpoints

if [ -f ./.checkpoints/04_sourcegraph_start.done ]; then
    echo "Stage 4 already completed."
    exit 0
fi

# Pull the latest images
if [[ "$(uname)" == "Darwin" ]]; then
  echo "Pulling images (macOS)..."
  docker compose pull
else
  echo "Pulling images (Linux)..."
  sudo docker compose pull
fi

# Ensure config directory exists
mkdir -p ./config

FINAL_URL="http://localhost:7080"

if [[ "$(uname)" == "Darwin" ]]; then
  # macOS: create default config if missing (no sudo, avoid GNU sed differences)
  if [ ! -f ./config/site-config.json ]; then
    cat > ./config/site-config.json <<EOF
{
  "externalURL": "$FINAL_URL",
  "auth.public": true,
  "auth.accessTokens.allow": "no-user-credentials"
}
EOF
  else
    echo "Note: ./config/site-config.json exists; leaving as-is on macOS."
  fi
else
  # Linux: preserve existing behavior to ensure externalURL is set
  if [ -f ./config/site-config.json ]; then
      if grep -q "externalURL" ./config/site-config.json; then
          sudo sed -i "s|\"externalURL\": \"[^\"]*\"|\"externalURL\": \"$FINAL_URL\"|g" ./config/site-config.json
      else
          sudo sed -i "s|}|,\n  \"externalURL\": \"$FINAL_URL\"\n}|g" ./config/site-config.json
      fi
  else
      echo '{
  "externalURL": "'$FINAL_URL'",
  "auth.public": true,
  "auth.accessTokens.allow": "no-user-credentials"
}' | sudo tee ./config/site-config.json > /dev/null
  fi
fi

echo "🚀 Starting Sourcegraph services ..."
if [[ "$(uname)" == "Darwin" ]]; then
  docker compose -f docker-compose.yml -f docker-compose.mac.yml -f docker-compose.override.mac.yml up -d
else
  sudo docker compose -f docker-compose.yml -f docker-compose.override.linux.yml -f docker-compose.resource.yml up -d
fi

# Wait for services to be healthy
echo "⏳ Waiting for services to be healthy..."
sleep 30

# Verify core services are running
if [[ "$(uname)" == "Darwin" ]]; then
  if ! docker compose ps | grep -q "Up"; then
      echo "❌ Error: Some services failed to start"
      docker compose ps
      exit 1
  fi
else
  if ! sudo docker compose ps | grep -q "Up"; then
      echo "❌ Error: Some services failed to start"
      sudo docker compose ps
      exit 1
  fi
fi

# Create checkpoint
touch ./.checkpoints/04_sourcegraph_start.done
echo "✅ Stage 4: Sourcegraph services started successfully"
echo "🌟 You can now access Sourcegraph at $FINAL_URL"
