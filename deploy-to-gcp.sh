#!/bin/zsh
set -e

# Configuration
PROJECT_ID=$(gcloud config get-value project)
ZONE="us-central1-a"
INSTANCE_NAME="sourcegraph-spot"
MACHINE_TYPE="e2-standard-8"  # Increased from e2-standard-4 for better performance
DATA_DISK_NAME="sourcegraph-data"
DATA_DISK_SIZE="100GB"
STATIC_IP_NAME="sourcegraph-static-ip"
GITHUB_REPO="https://github.com/suchakr/sanchaya-sourcegraph.git"

# Checkpoint management functions
check_stage() {
    local stage=$1
    gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command="[[ -f /sourcegraph-data/.stage_${stage}_complete ]]"
    return $?
}

mark_stage_complete() {
    local stage=$1
    gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command="touch /sourcegraph-data/.stage_${stage}_complete"
}

# Function to check if a resource exists and print status
resource_exists() {
    local cmd=$1
    local resource=$2
    
    # Execute command and capture output - redirect stderr to stdout
    local output
    # Use eval to properly execute the command with arguments
    output=$(eval "$cmd $resource" 2>&1)
    local exit_code=$?
    
    # For debugging
    echo "DEBUG: Checking resource: $resource with cmd: $cmd"
    echo "DEBUG: Exit code: $exit_code"
    
    if [ $exit_code -eq 0 ]; then
        echo "DEBUG: Resource exists: $resource"
        return 0
    else
        echo "DEBUG: Resource does not exist: $resource"
        echo "DEBUG: Output: $output"
        if [[ $output == *"operation was aborted"* ]]; then
            return 2
        fi
        return 1
    fi
}

echo "🚀 Starting Sourcegraph deployment to GCP Spot VM..."
echo "🔍 Checking existing resources..."

# Check if we're already running
if resource_exists "gcloud compute instances describe --zone=$ZONE" "$INSTANCE_NAME"; then
    echo "⚠️  Instance $INSTANCE_NAME already exists. Skipping creation."
    EXTERNAL_IP=$(gcloud compute instances describe $INSTANCE_NAME \
        --zone=$ZONE \
        --format='get(networkInterfaces[0].accessConfigs[0].natIP)')
else
    # Check and handle persistent disk
    echo "💾 Checking persistent disk..."
    if resource_exists "gcloud compute disks describe --zone=$ZONE" "$DATA_DISK_NAME"; then
        echo "✓ Using existing persistent disk: $DATA_DISK_NAME"
        # Verify disk is the correct size and type
        DISK_INFO=$(gcloud compute disks describe $DATA_DISK_NAME --zone=$ZONE --format="csv[no-heading](sizeGb,type)")
        CURRENT_SIZE=$(echo $DISK_INFO | cut -d',' -f1)
        CURRENT_TYPE=$(echo $DISK_INFO | cut -d',' -f2)
        if [[ $CURRENT_SIZE -lt ${DATA_DISK_SIZE%GB} ]]; then
            echo "📈 Resizing disk from ${CURRENT_SIZE}GB to $DATA_DISK_SIZE..."
            gcloud compute disks resize $DATA_DISK_NAME --size=$DATA_DISK_SIZE --zone=$ZONE --quiet
        fi
    else
        echo "📀 Creating new persistent disk for Sourcegraph data..."
        gcloud compute disks create $DATA_DISK_NAME \
            --size=$DATA_DISK_SIZE \
            --type=pd-ssd \
            --zone=$ZONE
    fi

    # Create static IP if it doesn't exist
    echo "📍 Setting up static IP..."
    if ! resource_exists "gcloud compute addresses describe --region=${ZONE%-*}" "$STATIC_IP_NAME"; then
        gcloud compute addresses create $STATIC_IP_NAME --region=${ZONE%-*}
    else
        echo "🔍 Using existing static IP: $STATIC_IP_NAME"
    fi

    # Get the static IP address
    STATIC_IP=$(gcloud compute addresses describe $STATIC_IP_NAME \
        --region=${ZONE%-*} \
        --format='get(address)')

    # Create Spot VM with static IP
    echo "💻 Creating Spot VM instance..."
    gcloud compute instances create $INSTANCE_NAME \
        --machine-type=$MACHINE_TYPE \
        --zone=$ZONE \
        --boot-disk-size=20GB \
        --boot-disk-type=pd-standard \
        --image-family=debian-11 \
        --image-project=debian-cloud \
        --provisioning-model=SPOT \
        --instance-termination-action=STOP \
        --maintenance-policy=TERMINATE \
        --disk="name=${DATA_DISK_NAME},device-name=${DATA_DISK_NAME},mode=rw,boot=no" \
        --address=$STATIC_IP \
        --tags=http-server,https-server

    EXTERNAL_IP=$STATIC_IP
fi

# Wait for VM to be ready
echo "⏳ Waiting for VM to be ready..."
until gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command="echo 'VM is ready'" &>/dev/null; do
    sleep 5
done

# Get the VM's external IP
EXTERNAL_IP=$(gcloud compute instances describe $INSTANCE_NAME \
    --zone=$ZONE \
    --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

echo "🌍 VM External IP: $EXTERNAL_IP"

# Begin staged deployment
echo "🛠️ Starting staged deployment..."

# Stage 1: Install Docker and dependencies
if ! check_stage "docker_install"; then
    echo "📦 Stage 1: Installing Docker and dependencies..."
    gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command="bash -s" -- << 'STAGE1'
export DEBIAN_FRONTEND=noninteractive
sudo -E apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common git
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
sudo apt-get update
sudo apt-get install -y docker-ce docker-compose-plugin
sudo usermod -aG docker $USER
STAGE1

    mark_stage_complete "docker_install"
fi

# Stage 2: Clone and configure Sourcegraph
if ! check_stage "sourcegraph_setup"; then
    echo "📦 Stage 2: Cloning and configuring Sourcegraph..."
    gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command="bash -s" -- << 'STAGE2'
# Clone Sourcegraph configuration from repository
cd ~
rm -rf sourcegraph
git clone https://github.com/suchakr/sanchaya-sourcegraph.git sourcegraph
cd sourcegraph

# Update site-config.json with the VM's external IP
sed -i "s|\"externalURL\": \"http://localhost:7080\"|\"externalURL\": \"http://$EXTERNAL_IP\"|g" \
    ~/sourcegraph/config/site-config.json
STAGE2

    mark_stage_complete "sourcegraph_setup"
fi

# Stage 3: Setup data directories and permissions
if ! check_stage "data_setup"; then
    echo "📦 Stage 3: Setting up data directories and permissions..."
    gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command="bash -s" -- << 'STAGE3'
# Setup data directory with proper permissions
if ! mountpoint -q /sourcegraph-data; then
    echo "📁 Setting up data volume..."
    sudo mkfs.ext4 -m 0 -E lazy_itable_init=0,lazy_journal_init=0,discard /dev/sdb || true
    sudo mkdir -p /sourcegraph-data
    sudo mount -o discard,defaults /dev/sdb /sourcegraph-data
    
    # Make mount persistent
    UUID=$(sudo blkid -s UUID -o value /dev/sdb)
    echo "UUID=$UUID /sourcegraph-data ext4 discard,defaults,nofail 0 2" | sudo tee -a /etc/fstab
fi

# Create and set proper permissions for data directories
echo "📂 Setting up data directories with correct permissions..."
sudo mkdir -p /sourcegraph-data/{gitserver,pgsql,codeintel-db,codeinsights-db,redis-cache,redis-store,blobstore,zoekt,caddy,prometheus}

# Set correct permissions for database directories
sudo chown -R 999:999 /sourcegraph-data/pgsql
sudo chown -R 999:999 /sourcegraph-data/codeintel-db
sudo chown -R 999:999 /sourcegraph-data/codeinsights-db

# Set permissions for other directories
sudo chown -R $USER:$USER /sourcegraph-data/gitserver
sudo chown -R $USER:$USER /sourcegraph-data/redis-cache
sudo chown -R $USER:$USER /sourcegraph-data/redis-store
sudo chown -R $USER:$USER /sourcegraph-data/blobstore
sudo chown -R $USER:$USER /sourcegraph-data/zoekt
sudo chown -R $USER:$USER /sourcegraph-data/caddy
sudo chown -R $USER:$USER /sourcegraph-data/prometheus

# Setup logging directory for spot events
sudo mkdir -p /sourcegraph-data/logs
sudo chown -R $USER:$USER /sourcegraph-data/logs
STAGE3

    mark_stage_complete "data_setup"
fi

# Stage 4: Configure startup script and systemd service
if ! check_stage "service_setup"; then
    echo "📦 Stage 4: Configuring startup script and systemd service..."
    gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command="bash -s" -- << 'STAGE4'

# Setup logging directory for spot events
sudo mkdir -p /sourcegraph-data/logs
sudo chown -R $USER:$USER /sourcegraph-data/logs

# Setup automatic restart with IP monitoring
cat > /tmp/sourcegraph-startup.sh << 'EOFSCRIPT'
#!/bin/bash
set -e

# Function to log events with timestamp
log_event() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> /sourcegraph-data/logs/spot_events.log
}

# Function to get current static IP
get_static_ip() {
    curl -s "http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip" -H "Metadata-Flavor: Google"
}

# Function to check service health
check_health() {
    local retries=5
    local wait=10
    local attempt=1
    
    while [ $attempt -le $retries ]; do
        if curl -s -o /dev/null -w "%{http_code}" "http://localhost:7080" | grep -q "200\|302"; then
            return 0
        fi
        log_event "Health check attempt $attempt failed, retrying in ${wait}s..."
        sleep $wait
        attempt=$((attempt + 1))
    done
    return 1
}

# Ensure data volume is mounted
if ! mountpoint -q /sourcegraph-data; then
    sudo mount -o discard,defaults /dev/sdb /sourcegraph-data
    log_event "Mounted data volume"
fi

# Start Sourcegraph with resource limits
cd ~/sourcegraph
docker compose -f docker-compose.yaml -f docker-compose.override.yml -f docker-compose.resource.yml down || true
docker compose -f docker-compose.yaml -f docker-compose.override.yml -f docker-compose.resource.yml up -d

# Wait for services to be healthy
log_event "Waiting for services to be healthy..."
if check_health; then
    log_event "Services started successfully"
else
    log_event "Services failed to start properly"
fi

# Monitor and log preemption events
while true; do
    sleep 60
    if ! check_health; then
        log_event "Service health check failed, attempting recovery..."
        docker compose -f docker-compose.yaml -f docker-compose.override.yml -f docker-compose.resource.yml restart
        if check_health; then
            log_event "Service recovered successfully"
        else
            log_event "Service recovery failed"
        fi
    fi
done
EOFSCRIPT

chmod +x /tmp/sourcegraph-startup.sh
sudo mv /tmp/sourcegraph-startup.sh /usr/local/bin/

# Setup systemd service for automatic startup and recovery
cat > /tmp/sourcegraph.service << 'EOF'
[Unit]
Description=Sourcegraph Service
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$USER
ExecStart=/usr/local/bin/sourcegraph-startup.sh
Restart=always
RestartSec=10
StartLimitInterval=0

[Install]
WantedBy=multi-user.target
EOF

sudo mv /tmp/sourcegraph.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable sourcegraph.service
sudo systemctl start sourcegraph.service
STAGE4

    mark_stage_complete "service_setup"
fi

# Create firewall rules if they don't exist
if ! gcloud compute firewall-rules describe sourcegraph-http-https &>/dev/null; then
    echo "🔒 Creating firewall rules..."
    gcloud compute firewall-rules create sourcegraph-http-https \
        --allow=tcp:80,tcp:443,tcp:7080 \
        --target-tags=http-server,https-server \
        --description="Allow HTTP/HTTPS access to Sourcegraph"
fi

# Cleanup
rm -rf $TEMP_DIR sourcegraph-deploy.tar.gz

# Get the final URL
STATIC_IP=$(gcloud compute addresses describe $STATIC_IP_NAME --region=${ZONE%-*} --format='get(address)')
DOMAIN="${STATIC_IP//./-}.nip.io"

echo "✅ Deployment complete!"
echo "🌐 You can access Sourcegraph at: http://$DOMAIN"
echo "⚠️  Note: It may take a few minutes for all services to start up completely."
echo "📊 Monitor deployment:"
echo "   - Check status: gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command='cd ~/sourcegraph && docker compose ps'"
echo "   - View logs: gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command='cd ~/sourcegraph && docker compose logs -f'"
echo "   - Check spot events: gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command='cat /sourcegraph-data/logs/spot_events.log'"
