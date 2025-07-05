#!/bin/bash

set -e

echo "=== Configuring IOMMU for GPU Passthrough ==="

# Detect CPU vendor (Intel or AMD)
CPU_VENDOR=$(lscpu | grep "Vendor ID" | awk '{print $3}')

if [[ "$CPU_VENDOR" == "GenuineIntel" ]]; then
  IOMMU_FLAG="intel_iommu=on"
  echo "Detected Intel CPU"
elif [[ "$CPU_VENDOR" == "AuthenticAMD" ]]; then
  IOMMU_FLAG="amd_iommu=on"
  echo "Detected AMD CPU"
else
  echo "Unsupported or unknown CPU vendor. Only Intel and AMD are supported."
  exit 1
fi

# Add vfio modules to /etc/modules
echo "Adding vfio modules to /etc/modules"
for mod in vfio vfio_iommu_type1 vfio_pci vfio_virqfd; do
  grep -qxF "$mod" /etc/modules || echo "$mod" >> /etc/modules
done

# Update GRUB with IOMMU options
echo "Enabling IOMMU in GRUB"
if grep -q "GRUB_CMDLINE_LINUX" /etc/default/grub; then
  sed -i "s/GRUB_CMDLINE_LINUX=\"\(.*\)\"/GRUB_CMDLINE_LINUX=\"\1 $IOMMU_FLAG iommu=pt\"/" /etc/default/grub
else
  echo "GRUB_CMDLINE_LINUX=\"$IOMMU_FLAG iommu=pt\"" >> /etc/default/grub
fi

# If using systemd-boot (common on ZFS installs), update kernel cmdline
if [[ -f /etc/kernel/cmdline ]]; then
  echo "Adding IOMMU flags to /etc/kernel/cmdline"
  if ! grep -q "$IOMMU_FLAG" /etc/kernel/cmdline; then
    echo "$(cat /etc/kernel/cmdline) $IOMMU_FLAG iommu=pt" > /etc/kernel/cmdline
  fi
  proxmox-boot-tool refresh
fi

# Update GRUB and initramfs
echo "Updating GRUB"
update-grub

echo "Updating initramfs"
update-initramfs -u -k all

echo "IOMMU setup complete. Reboot required for changes to take effect."
