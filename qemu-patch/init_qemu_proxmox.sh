#!/usr/bin/env bash

set -e

# 📁 Chemins
WORKDIR="$HOME/pve-qemu"
PATCH_DIR="$HOME/Hypervisor-Phantom/Hypervisor-Phantom/patches/QEMU"
QEMU_VERSION="10.0.2"
QEMU_COMMIT="ff3419cbacdc9ad0715c716afeed65bb21a2bbbc"

echo "[+] Nettoyage précédent..."
rm -rf "$WORKDIR"
git clone https://git.proxmox.com/git/pve-qemu.git "$WORKDIR"
cd "$WORKDIR"

echo "[+] Suppression du submodule QEMU par défaut"
rm -rf submodules/qemu

echo "[+] Clonage de QEMU v$QEMU_VERSION depuis GitLab..."
git clone --branch "v$QEMU_VERSION" https://gitlab.com/qemu-project/qemu.git submodules/qemu
cd submodules/qemu
git checkout "$QEMU_COMMIT"
cd ../..

echo "[+] Application des patchs Hypervisor Phantom..."
patch -p1 -d submodules/qemu < "$PATCH_DIR/amd-qemu-10.0.2.patch"
patch -p1 -d submodules/qemu < "$PATCH_DIR/libnfs6-qemu-10.0.2.patch"

echo "[+] Téléchargement des subprojects Meson requis..."
cd submodules/qemu
meson subprojects download
cd ../..

echo "[+] Compilation du paquet .deb personnalisé..."
make deb -j"$(nproc)"

echo "✅ Compilation terminée avec succès. Les paquets .deb sont dans: $HOME"
