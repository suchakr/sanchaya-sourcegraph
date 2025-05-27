#!/bin/bash
set -euo pipefail

# Configuration
RESOURCE_GROUP="sourcegraph-rg"
LOCATION="eastus"
INSTANCE_NAME="sourcegraph-spot"  # Changed to match GCP instance name
VM_SIZE="Standard_D4s_v3"  # 4 vCPUs, 16 GB RAM, similar to e2-custom-4-17920
DATA_DISK_NAME="sourcegraph-data"
DATA_DISK_SIZE="100"  # in GB
PUBLIC_IP_NAME="sourcegraph-ip"
NSG_NAME="sourcegraph-nsg"

# Detect Azure username (will use the same as local user)
AZURE_USERNAME=$(whoami)
echo "🔑 Using username: $AZURE_USERNAME"

# Function to check if a resource exists
resource_exists() {
    local cmd=$1
    eval "$cmd" &>/dev/null
    return $?
}

echo "🚀 Allocating Azure resources for Sourcegraph..."

# Register required resource providers
echo "🔄 Registering required resource providers..."
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.Compute
az provider register --namespace Microsoft.Storage
echo "⏳ Waiting for provider registration to complete..."
az provider show -n Microsoft.Network --query "registrationState" -o tsv
az provider show -n Microsoft.Compute --query "registrationState" -o tsv
az provider show -n Microsoft.Storage --query "registrationState" -o tsv

# Create resource group if it doesn't exist
echo "📍 Setting up resource group..."
if ! resource_exists "az group show --name $RESOURCE_GROUP" "$RESOURCE_GROUP"; then
    az group create --name $RESOURCE_GROUP --location $LOCATION
fi

# Create public IP if it doesn't exist
echo "📍 Setting up public IP..."
if ! resource_exists "az network public-ip show --resource-group $RESOURCE_GROUP --name $PUBLIC_IP_NAME"; then
    az network public-ip create \
        --resource-group $RESOURCE_GROUP \
        --name $PUBLIC_IP_NAME \
        --allocation-method Static
fi

# Get the public IP address
PUBLIC_IP=$(az network public-ip show \
    --resource-group $RESOURCE_GROUP \
    --name $PUBLIC_IP_NAME \
    --query 'ipAddress' \
    --output tsv)

# Create virtual network if it doesn't exist
echo "🌐 Setting up virtual network..."
VNET_NAME="sourcegraph-vnet"
SUBNET_NAME="sourcegraph-subnet"
if ! resource_exists "az network vnet show --resource-group $RESOURCE_GROUP --name $VNET_NAME"; then
    az network vnet create \
        --resource-group $RESOURCE_GROUP \
        --name $VNET_NAME \
        --address-prefix 10.0.0.0/16 \
        --subnet-name $SUBNET_NAME \
        --subnet-prefix 10.0.0.0/24
fi

# Create network security group if it doesn't exist
echo "🔒 Setting up network security group..."
if ! resource_exists "az network nsg show --resource-group $RESOURCE_GROUP --name $NSG_NAME"; then
    az network nsg create \
        --resource-group $RESOURCE_GROUP \
        --name $NSG_NAME

    # Add security rules for HTTP, HTTPS, and Sourcegraph
    az network nsg rule create \
        --resource-group $RESOURCE_GROUP \
        --nsg-name $NSG_NAME \
        --name allow-http \
        --priority 1000 \
        --protocol Tcp \
        --destination-port-ranges 80 \
        --access Allow
    
    az network nsg rule create \
        --resource-group $RESOURCE_GROUP \
        --nsg-name $NSG_NAME \
        --name allow-https \
        --priority 1001 \
        --protocol Tcp \
        --destination-port-ranges 443 \
        --access Allow
    
    az network nsg rule create \
        --resource-group $RESOURCE_GROUP \
        --nsg-name $NSG_NAME \
        --name allow-sourcegraph \
        --priority 1002 \
        --protocol Tcp \
        --destination-port-ranges 7080 \
        --access Allow
    
    # Add SSH rule
    az network nsg rule create \
        --resource-group $RESOURCE_GROUP \
        --nsg-name $NSG_NAME \
        --name allow-ssh \
        --priority 1003 \
        --protocol Tcp \
        --destination-port-ranges 22 \
        --access Allow
fi

# Create network interface if it doesn't exist
echo "🖧 Setting up network interface..."
NIC_NAME="sourcegraph-nic"
if ! resource_exists "az network nic show --resource-group $RESOURCE_GROUP --name $NIC_NAME"; then
    az network nic create \
        --resource-group $RESOURCE_GROUP \
        --name $NIC_NAME \
        --vnet-name $VNET_NAME \
        --subnet $SUBNET_NAME \
        --network-security-group $NSG_NAME \
        --public-ip-address $PUBLIC_IP_NAME
fi

# Create data disk if it doesn't exist
echo "💾 Setting up data disk..."
if ! resource_exists "az disk show --resource-group $RESOURCE_GROUP --name $DATA_DISK_NAME"; then
    az disk create \
        --resource-group $RESOURCE_GROUP \
        --name $DATA_DISK_NAME \
        --size-gb $DATA_DISK_SIZE \
        --sku Premium_LRS
fi

# Create the VM instance
echo "🖥️ Creating VM instance..."
if ! resource_exists "az vm show --resource-group $RESOURCE_GROUP --name $INSTANCE_NAME"; then
    az vm create \
        --resource-group $RESOURCE_GROUP \
        --name $INSTANCE_NAME \
        --image Ubuntu2204 \
        --size $VM_SIZE \
        --admin-username $AZURE_USERNAME \
        --generate-ssh-keys \
        --nics $NIC_NAME \
        --os-disk-size-gb 30

    # Attach data disk
    az vm disk attach \
        --resource-group $RESOURCE_GROUP \
        --vm-name $INSTANCE_NAME \
        --name $DATA_DISK_NAME \
        --lun 0

    # Wait for VM to be ready
    echo "⏳ Waiting for VM to be ready..."
    sleep 30
    
    # Initialize the full disk space
    echo "💾 Initializing the full disk for use..."
    az vm run-command invoke \
        --resource-group $RESOURCE_GROUP \
        --name $INSTANCE_NAME \
        --command-id RunShellScript \
        --scripts "sudo parted /dev/sdb --script mklabel gpt && sudo parted /dev/sdb --script mkpart primary ext4 0% 100% && sudo mkfs.ext4 /dev/sdb1 && sudo mkdir -p /mnt && sudo mount /dev/sdb1 /mnt && echo '/dev/sdb1 /mnt ext4 defaults,nofail 0 2' | sudo tee -a /etc/fstab && sudo chown -R $AZURE_USERNAME:$AZURE_USERNAME /mnt"
fi

# Install git and clone the repository on the VM
echo "📦 Installing git and cloning repository on VM..."
REPO_URL_SG="https://github.com/suchakr/sanchaya-sourcegraph.git"
DEPLOY_DIR_SG="/home/$AZURE_USERNAME/sg/sanchaya-sourcegraph"
mkdir -p $DEPLOY_DIR_SG

az vm run-command invoke \
    --resource-group $RESOURCE_GROUP \
    --name $INSTANCE_NAME \
    --command-id RunShellScript \
    --scripts "sudo apt-get update && sudo apt-get install -y git && sudo rm -rf $DEPLOY_DIR_SG && git clone $REPO_URL_SG $DEPLOY_DIR_SG && chmod +x $DEPLOY_DIR_SG/*.sh && sudo chown -R $AZURE_USERNAME:$AZURE_USERNAME $DEPLOY_DIR_SG"

REPO_URL_ZKT="https://github.com/suchakr/sanchaya-zoekt.git"
DEPLOY_DIR_ZKT="/home/$AZURE_USERNAME/sg/sanchaya-zoekt"
mkdir -p $DEPLOY_DIR_ZKT
az vm run-command invoke \
    --resource-group $RESOURCE_GROUP \
    --name $INSTANCE_NAME \
    --command-id RunShellScript \
    --scripts "sudo rm -rf $DEPLOY_DIR_ZKT && git clone $REPO_URL_ZKT $DEPLOY_DIR_ZKT && chmod +x $DEPLOY_DIR_ZKT/*.sh && sudo chown -R $AZURE_USERNAME:$AZURE_USERNAME $DEPLOY_DIR_ZKT"

echo "✅ Resource allocation complete!"
echo "🌐 Public IP: $PUBLIC_IP"
echo ""
echo "You can now:"
echo "1. SSH into the VM:        ssh $AZURE_USERNAME@$PUBLIC_IP"
echo "2. Run stages manually:    cd ~/sg/sanchaya-sourcegraph && ./01_docker_install.sh"

