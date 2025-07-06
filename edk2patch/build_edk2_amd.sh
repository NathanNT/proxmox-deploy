#!/usr/bin/env bash
set -euo pipefail

# --- Configuration ---
EDK2_VERSION="edk2-stable202505"
SRC_DIR="/root/edk2_build/src"
EDK2_URL="https://github.com/tianocore/edk2.git"
PATCH_DIR="/root/Hypervisor-Phantom/Hypervisor-Phantom/patches/EDK2"
OVMF_PATCH="amd-${EDK2_VERSION}.patch"
OVMF_CODE_DEST_DIR="/usr/local/share/edk2-custom/x64"
LOG_FILE="/var/log/edk2_build.log"
BGRT_IMAGE="/root/image.bmp"

mkdir -p "$SRC_DIR" "$OVMF_CODE_DEST_DIR"
touch "$LOG_FILE"

echo "[*] Installing required packages..."
apt update
apt install -y build-essential uuid-dev acpica-tools git nasm \
  python3 python-is-python3 python3-pip curl

echo "[*] Installing virt-firmware..."
python3 -m pip install --break-system-packages virt-firmware

cd "$SRC_DIR"

if [ -d "$EDK2_VERSION" ]; then
  echo "[*] Removing existing source directory"
  rm -rf "$EDK2_VERSION"
fi

echo "[*] Cloning EDK2..."
git clone --single-branch --depth=1 --branch "$EDK2_VERSION" "$EDK2_URL" "$EDK2_VERSION" &>> "$LOG_FILE"
cd "$EDK2_VERSION"

echo "[*] Initializing submodules..."
git submodule update --init &>> "$LOG_FILE"

echo "[*] Applying AMD patch..."
git apply "$PATCH_DIR/$OVMF_PATCH" &>> "$LOG_FILE"

if [ -f "$BGRT_IMAGE" ]; then
  cp -f "$BGRT_IMAGE" "MdeModulePkg/Logo/Logo.bmp"
  echo "[*] BGRT image copied"
else
  echo "[!] BGRT image not found: $BGRT_IMAGE"
fi

export WORKSPACE="$(pwd)"
export EDK_TOOLS_PATH="$WORKSPACE/BaseTools"
export CONF_PATH="$WORKSPACE/Conf"

echo "[*] Building BaseTools..."
make -C BaseTools &>> "$LOG_FILE"
source edksetup.sh

echo "[*] Compiling OVMF firmware..."
build \
  -a X64 \
  -p OvmfPkg/OvmfPkgX64.dsc \
  -b RELEASE \
  -t GCC5 \
  -n $(nproc) \
  -s -q \
  --define SECURE_BOOT_ENABLE=TRUE \
  --define TPM_CONFIG_ENABLE=TRUE \
  --define TPM_ENABLE=TRUE \
  --define TPM1_ENABLE=TRUE \
  --define TPM2_ENABLE=TRUE \
  &>> "$LOG_FILE"

echo "[*] Converting to qcow2..."
qemu-img convert -f raw -O qcow2 \
  "Build/OvmfX64/RELEASE_GCC5/FV/OVMF_CODE.fd" \
  "$OVMF_CODE_DEST_DIR/OVMF_CODE.secboot.4m.qcow2"

qemu-img convert -f raw -O qcow2 \
  "Build/OvmfX64/RELEASE_GCC5/FV/OVMF_VARS.fd" \
  "$OVMF_CODE_DEST_DIR/OVMF_VARS.4m.qcow2"

chmod 644 "$OVMF_CODE_DEST_DIR"/*.qcow2

echo "[✓] Build complete. Firmware installed in $OVMF_CODE_DEST_DIR"
