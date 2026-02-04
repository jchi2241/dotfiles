#!/bin/bash
set -e  # Exit on any error

# Setup 32GB swap with low swappiness
# NOTE: Requires sudo - run in terminal or with: sudo ./install-swap.sh

SWAP_SIZE="32G"
SWAPPINESS=10

# Check if running on Linux
if [[ "$(uname -s)" != "Linux" ]]; then
    echo "Error: This script only runs on Linux."
    exit 1
fi

# Check if running with sudo capability
if ! sudo -n true 2>/dev/null; then
    echo "Error: sudo requires password. Run in a terminal or use: sudo ./install-swap.sh"
    exit 1
fi

# Create swapfile if it doesn't exist
if [ ! -f /swapfile ]; then
    echo "Creating ${SWAP_SIZE} swapfile..."
    sudo fallocate -l $SWAP_SIZE /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile

    # Add to fstab if not already there
    if ! grep -q '/swapfile' /etc/fstab; then
        echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab >/dev/null
    fi
    echo "Swapfile created and enabled."
else
    echo "Swapfile already exists, skipping creation."
fi

# Set swappiness if not already configured
if [ ! -f /etc/sysctl.d/99-swappiness.conf ]; then
    echo "Setting swappiness to ${SWAPPINESS}..."
    echo "vm.swappiness=${SWAPPINESS}" | sudo tee /etc/sysctl.d/99-swappiness.conf >/dev/null
    sudo sysctl -p /etc/sysctl.d/99-swappiness.conf
    echo "Swappiness configured."
else
    echo "Swappiness config already exists, skipping."
fi

echo "Swap setup complete."
swapon --show
