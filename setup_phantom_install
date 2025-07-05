#!/bin/bash

set -e

confirm() {
  read -p "$1 (y/N): " answer
  case "$answer" in
    [Yy]*) return 0 ;;
    *) echo "Skipped."; return 1 ;;
  esac
}

echo "=== Proxmox QEMU Fix Script ==="

# Step 1: Purge virtiofsd
if confirm "Step 1 - Do you want to purge virtiofsd (causes conflict with QEMU 7.2)?"; then
  touch /please-remove-proxmox-ve
  apt purge -y virtiofsd || true
fi

# Step 2: Install specific version of QEMU
if confirm "Step 2 - Install qemu-system-x86 version 7.2 (required for Proxmox compatibility)?"; then
  apt install -y qemu-system-x86=1:7.2+dfsg-7+deb12u13
fi

# Step 3: Remove proxmox hook override
if confirm "Step 3 - Remove /please-remove-proxmox-ve file to re-enable safety hook?"; then
  rm -f /please-remove-proxmox-ve
fi

# Step 4: Reinstall proxmox-ve if in 'rc' (removed config) state
if confirm "Step 4 - Check and reinstall proxmox-ve if partially removed?"; then
  if dpkg -l | grep -q "^rc.*proxmox-ve"; then
    echo ">>> Reinstalling proxmox-ve..."
    apt install -y proxmox-ve --install-recommends
  else
    echo ">>> proxmox-ve is already installed correctly."
  fi
fi

# Step 5: Hold packages to prevent future upgrade issues
if confirm "Step 5 - Put qemu-system-x86 and virtiofsd on hold to avoid conflicts?"; then
  apt-mark hold qemu-system-x86 virtiofsd
fi

# Step 6: Final status check
echo ""
echo "=== Installed package versions ==="
dpkg -l | grep -E "qemu-system-x86|virtiofsd|proxmox-ve" || echo "None of the target packages are installed."
echo "---"
qemu-system-x86_64 --version || echo "QEMU binary not found"

# Step 7: Optional - Remove bookworm-backports from sources.list
if confirm "Step 7 - Remove bookworm-backports from sources.list to avoid future conflicts?"; then
  sed -i '/bookworm-backports/d' /etc/apt/sources.list
  apt update
fi

echo ""
echo "✅ Done. Your Proxmox system should now be stable with QEMU 7.2."
