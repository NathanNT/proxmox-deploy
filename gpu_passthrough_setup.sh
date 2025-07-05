#!/bin/bash

set -e

echo "=== Configuring GPU Passthrough ==="

# Detect GPU vendor
GPU_VENDOR=$(lspci | grep -E "VGA|3D" | grep -E "AMD|Intel" | awk '{print $5}' | head -n1)

if [[ "$GPU_VENDOR" == "AMD" ]]; then
  IOMMU_FLAG="amd_iommu=on"
  echo "Detected AMD GPU"
elif [[ "$GPU_VENDOR" == "Intel" ]]; then
  IOMMU_FLAG="intel_iommu=on"
  echo "Detected Intel GPU"
else
  echo "Unsupported or undetected GPU vendor. Only AMD and Intel are supported in this script."
  exit 1
fi

# Add vfio modules to /etc/modules if not present
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

# Update /etc/kernel/cmdline if it exists (for systemd-boot systems)
if [[ -f /etc/kernel/cmdline ]]; then
  echo "Adding IOMMU options to /etc/kernel/cmdline"
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

echo "GPU passthrough configuration complete. Please reboot the system."
