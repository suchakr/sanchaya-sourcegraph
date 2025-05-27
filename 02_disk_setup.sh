#!/bin/bash
set -euo pipefail

echo "Stage 2: Setting up persistent disk..."

mkdir -p ./.checkpoints

if [ -f ./.checkpoints/02_disk_setup.done ]; then
    echo "Stage 2 already completed."
    exit 0
fi

# Constants
DOCKER_DATA_ROOT="/mnt/docker-data"
PERSISTENT_DISK_DEVICE="/dev/sdb"
PERSISTENT_DISK_LABEL="sourcegraph"

# Check for existing partitions
echo "Checking disk partitioning..."
PARTITION_COUNT=$(sudo fdisk -l "${PERSISTENT_DISK_DEVICE}" | grep "^/dev" | wc -l)

if [ "${PARTITION_COUNT}" -eq 0 ]; then
    echo "Creating new GPT partition table and partition..."
    sudo parted ${PERSISTENT_DISK_DEVICE} --script mklabel gpt
    sudo parted ${PERSISTENT_DISK_DEVICE} --script mkpart primary ext4 0% 100%
    sudo mkfs.ext4 -m 0 -E lazy_itable_init=0,lazy_journal_init=0,discard "${PERSISTENT_DISK_DEVICE}1"
    # Label the partition, not the disk
    sudo e2label "${PERSISTENT_DISK_DEVICE}1" "${PERSISTENT_DISK_LABEL}"
    MOUNT_DEVICE="${PERSISTENT_DISK_DEVICE}1"
else
    echo "Disk already has partitions, using first partition..."
    MOUNT_DEVICE="${PERSISTENT_DISK_DEVICE}1"
fi

# Create mount point and mount disk
sudo mkdir -p "${DOCKER_DATA_ROOT}"
sudo mount -o discard,defaults "${MOUNT_DEVICE}" "${DOCKER_DATA_ROOT}"

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
touch ./.checkpoints/02_disk_setup.done
echo "✅ Stage 2: Disk setup complete"
