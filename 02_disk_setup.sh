#!/bin/bash
set -euo pipefail

echo "Stage 2: Setting up persistent disk..."

if [ -f ~/sourcegraph/checkpoints/02_disk_setup.done ]; then
    echo "Stage 2 already completed."
    exit 0
fi

# Constants
DOCKER_DATA_ROOT="/mnt/docker-data"
PERSISTENT_DISK_DEVICE="/dev/sdb"
PERSISTENT_DISK_LABEL="sourcegraph"

# Check if disk is already formatted
device_fs=$(sudo lsblk "${PERSISTENT_DISK_DEVICE}" --noheadings --output fsType)
if [ "${device_fs}" == "" ]; then
    echo "Formatting disk..."
    sudo mkfs.ext4 -m 0 -E lazy_itable_init=0,lazy_journal_init=0,discard "${PERSISTENT_DISK_DEVICE}"
fi

# Label the disk
sudo e2label "${PERSISTENT_DISK_DEVICE}" "${PERSISTENT_DISK_LABEL}"

# Create mount point and mount disk
sudo mkdir -p "${DOCKER_DATA_ROOT}"
sudo mount -o discard,defaults "${PERSISTENT_DISK_DEVICE}" "${DOCKER_DATA_ROOT}"

# Add to fstab for persistent mounting
echo "LABEL=${PERSISTENT_DISK_LABEL}  ${DOCKER_DATA_ROOT}  ext4  discard,defaults,nofail  0  2" | sudo tee -a /etc/fstab

# Configure Docker to use the mounted volume
sudo mkdir -p /etc/docker
echo '{
    "data-root": "/mnt/docker-data"
}' | sudo tee /etc/docker/daemon.json

# Restart Docker to apply changes
sudo systemctl restart docker

# Create checkpoint
touch ~/sourcegraph/checkpoints/02_disk_setup.done
echo "✅ Stage 2: Disk setup complete"
