#!/bin/bash
set -e

# Configuration
RESOURCE_GROUP="sourcegraph-rg"
LOCATION="eastus"
INSTANCE_NAME="sourcegraph-spot"  # Changed to match GCP instance name
VM_SIZE="Standard_D4s_v3"
DATA_DISK_NAME="sourcegraph-data"
PUBLIC_IP_NAME="sourcegraph-ip"
NSG_NAME="sourcegraph-nsg"
VNET_NAME="sourcegraph-vnet"
NIC_NAME="sourcegraph-nic"

echo "🧹 Starting cleanup of Sourcegraph Azure resources..."

# Simply delete the entire resource group
# This will automatically delete all resources in the group in the correct order
echo "🗑️ Deleting resource group: $RESOURCE_GROUP"
if az group show --name $RESOURCE_GROUP &>/dev/null; then
    echo "  ⏳ This might take a few minutes..."
    az group delete --name $RESOURCE_GROUP --yes
    echo "✅ Resource group and all contained resources deleted successfully."
else
    echo "ℹ️ Resource group not found, nothing to clean up."
fi

echo "✨ Cleanup complete! All Sourcegraph resources have been removed or deletion has been initiated."
echo "📝 You can now safely resume your work tomorrow without incurring additional charges."
