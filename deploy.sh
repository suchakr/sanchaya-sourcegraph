#!/bin/zsh
set -euo pipefail

# Configuration
ZONE="us-central1-a"
INSTANCE_NAME="sourcegraph-spot"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🚀 Starting Sourcegraph deployment..."

# Step 1: Allocate resources if needed
echo "${YELLOW}Phase 1: Resource Allocation${NC}"
./00_allocate_resources.sh

# Function to run a stage script on the VM
run_stage() {
    local stage=$1
    local script_name=$2
    echo "${YELLOW}Running $script_name...${NC}"
    gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command="sudo /bin/bash ~/$script_name"
}

# Step 2: Run each stage in sequence
echo "${YELLOW}Phase 2: Installation Stages${NC}"

# Run each stage
run_stage 1 "01_docker_install.sh"
run_stage 2 "02_disk_setup.sh"
run_stage 3 "03_sourcegraph_prep.sh"
run_stage 4 "04_sourcegraph_start.sh"

# Get the instance's external IP
EXTERNAL_IP=$(gcloud compute instances describe $INSTANCE_NAME \
    --zone=$ZONE \
    --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

echo "${GREEN}✅ Sourcegraph deployment complete!${NC}"
echo "${GREEN}🌐 You can access Sourcegraph at: http://$EXTERNAL_IP:7080${NC}"
echo
echo "To manage the deployment:"
echo "1. SSH into the VM:            gcloud compute ssh $INSTANCE_NAME --zone=$ZONE"
echo "2. View Docker status:         docker ps"
echo "3. View logs:                  docker-compose logs -f"
echo "4. Restart specific service:   docker-compose restart <service-name>"
