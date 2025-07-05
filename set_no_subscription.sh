#!/bin/bash

set -e

# Disable the enterprise repository
sed -i 's|^deb https://enterprise.proxmox.com|# deb https://enterprise.proxmox.com|' /etc/apt/sources.list.d/pve-enterprise.list

# Add the public no-subscription repositories
echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-no-subscription.list
echo "deb http://download.proxmox.com/debian/ceph-quincy bookworm no-subscription" > /etc/apt/sources.list.d/ceph.list

# Add deb-src entries if not already present
grep -q "^deb-src .*pve" /etc/apt/sources.list.d/pve-no-subscription.list 2>/dev/null || \
  echo "deb-src http://download.proxmox.com/debian/pve bookworm pve-no-subscription" >> /etc/apt/sources.list.d/pve-no-subscription.list

grep -q "^deb-src .*debian" /etc/apt/sources.list || \
  echo "deb-src http://deb.debian.org/debian bookworm main contrib" >> /etc/apt/sources.list

# Download the Proxmox GPG key
wget -qO /etc/apt/trusted.gpg.d/proxmox-release.gpg https://enterprise.proxmox.com/debian/proxmox-release-bookworm.gpg

# Update package lists
apt update

# Install required build tools
apt install -y git build-essential devscripts equivs

# Download the source code for pve-qemu-kvm
apt source pve-qemu-kvm
