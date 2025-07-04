#!/bin/bash
set -e

# Configuration - matching the cost-optimized allocation script
PROJECT_ID=$(gcloud config get-value project)
ZONE="us-central1-a"
INSTANCE_NAME="sourcegraph-cost-optimized"  # Updated to match new instance name
STATIC_IP_NAME="sourcegraph-static-ip"
FIREWALL_RULE_NAME="allow-sourcegraph-web"  # Fixed to match actual rule name

echo "🧹 Starting cleanup of Sourcegraph GCP resources..."

# Delete the VM instance
echo "🗑️ Deleting VM instance: $INSTANCE_NAME"
if gcloud compute instances describe $INSTANCE_NAME --zone=$ZONE &>/dev/null; then
    gcloud compute instances delete $INSTANCE_NAME --zone=$ZONE --quiet
    echo "✅ VM instance deleted successfully."
else
    echo "ℹ️ VM instance not found, skipping."
fi

# Note: No separate data disk to delete in cost-optimized version (uses single boot disk)

# Delete the static IP address
echo "🗑️ Deleting static IP: $STATIC_IP_NAME"
if gcloud compute addresses describe $STATIC_IP_NAME --region=${ZONE%-*} &>/dev/null; then
    gcloud compute addresses delete $STATIC_IP_NAME --region=${ZONE%-*} --quiet
    echo "✅ Static IP deleted successfully."
else
    echo "ℹ️ Static IP not found, skipping."
fi

# Delete the firewall rule
echo "🗑️ Deleting firewall rule: $FIREWALL_RULE_NAME"
if gcloud compute firewall-rules describe $FIREWALL_RULE_NAME &>/dev/null; then
    gcloud compute firewall-rules delete $FIREWALL_RULE_NAME --quiet
    echo "✅ Firewall rule deleted successfully."
else
    echo "ℹ️ Firewall rule not found, skipping."
fi

echo "✨ Cleanup complete! All Sourcegraph resources have been removed."
echo "📝 You can now safely resume your work tomorrow without incurring additional charges."