#!/usr/bin/env bash

set -e

# 📁 Chemins
WORKDIR="./pve-qemu"
PATCH_DIR="$HOME/Hypervisor-Phantom/Hypervisor-Phantom/patches/QEMU"
QEMU_VERSION="10.0.2"
QEMU_COMMIT="ff3419cbacdc9ad0715c716afeed65bb21a2bbbc"

echo "[+] Nettoyage précédent..."
rm -rf "$WORKDIR"
git clone https://git.proxmox.com/git/pve-qemu.git "$WORKDIR" --recursive
cd "$WORKDIR"

echo "[+] Application des patchs Hypervisor Phantom..."
patch -p1 -d qemu < "$PATCH_DIR/intel-qemu-10.0.2.patch"
patch -p1 -d qemu < "$PATCH_DIR/libnfs6-qemu-10.0.2.patch"

echo "[+] Compilation du paquet .deb personnalisé..."
#make deb -j"$(nproc)"

echo "✅ Compilation terminée avec succès. Les paquets .deb sont dans: $HOME"
