# Disable the enterprise repository
sed -i 's|^deb https://enterprise.proxmox.com|# deb https://enterprise.proxmox.com|' /etc/apt/sources.list.d/pve-enterprise.list

# Add the public no-subscription repositories
echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-no-subscription.list
echo "deb http://download.proxmox.com/debian/ceph-quincy bookworm no-subscription" > /etc/apt/sources.list.d/ceph.list

# Download the Proxmox GPG key
wget -qO /etc/apt/trusted.gpg.d/proxmox-release.gpg https://enterprise.proxmox.com/debian/proxmox-release-bookworm.gpg

# Update package lists
apt update
