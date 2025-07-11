#!/usr/bin/env bash
#
# OVMF builder autonome – juillet 2025
#

set -euo pipefail

CLR_RESET='\e[0m' CLR_RED='\e[31m' CLR_GRN='\e[32m'
log()  { printf "${CLR_GRN}[INFO]${CLR_RESET} %s\n" "$*"; }
err()  { printf "${CLR_RED}[ERREUR]${CLR_RESET} %s\n" "$*" >&2; }
fatal(){ err "$*"; exit 1; }

detect_distro() { source /etc/os-release; echo "${ID}"; }

install_pkgs() {
  local d=$1; shift
  local -a p=("$@")
  case "$d" in
    debian|ubuntu) apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y "${p[@]}" ;;
    fedora) dnf install -y "${p[@]}" ;;
    arch) pacman -Sy --noconfirm --needed "${p[@]}" ;;
    opensuse*|suse|sles) zypper --non-interactive install "${p[@]}" ;;
    *) log "Distribution inconnue, installation auto ignorée" ;;
  esac
}

DISTRO=$(detect_distro)
REQUIRED_PKGS=(git gcc g++ make nasm python3 qemu-utils python3-virt-firmware)
install_pkgs "$DISTRO" "${REQ_PKGS[@]}"

CPU_VENDOR=$(awk -F: '/vendor_id/{print $2; exit}' /proc/cpuinfo | tr -d ' ')
CPU_VENDOR=${CPU_VENDOR/GenuineIntel/intel}
CPU_VENDOR=${CPU_VENDOR/AuthenticAMD/amd}

EDK2_VERSION="edk2-stable202505"
SRC_DIR="/root/edk2-src"
PATCH_DIR="/root/patches"
OVMF_PATCH="${CPU_VENDOR}-${EDK2_VERSION}.patch"
FIRMWARE_DIR="/root/firmwares"
VARS_IN="$FIRMWARE_DIR/OVMF_VARS.4m.qcow2"
VARS_SECURE="$FIRMWARE_DIR/OVMF_VARS.secboot.4m.qcow2"

reset_workspace() {
  rm -rf "$FIRMWARE_DIR" "$SRC_DIR"
  mkdir -p "$FIRMWARE_DIR"
}

build_ovmf() {
  log "Clonage EDK2"
  git clone --depth=1 --branch "$EDK2_VERSION" https://github.com/tianocore/edk2.git "$SRC_DIR"
  pushd "$SRC_DIR" >/dev/null
  git submodule update --init

  [[ -f "$PATCH_DIR/$OVMF_PATCH" ]] || fatal "Patch manquant : $PATCH_DIR/$OVMF_PATCH"
  git apply "$PATCH_DIR/$OVMF_PATCH"
  log "Patch appliqué : $OVMF_PATCH"

  export WORKSPACE="$SRC_DIR"
  export EDK_TOOLS_PATH="$SRC_DIR/BaseTools"
  export CONF_PATH="$SRC_DIR/Conf"

  log "Compilation BaseTools"
  make -C BaseTools
  export PYTHON_COMMAND=python3
  source edksetup.sh

  log "Compilation OVMF"
  build -a X64 -p OvmfPkg/OvmfPkgX64.dsc -b RELEASE -t GCC5 \
        --define SECURE_BOOT_ENABLE=TRUE \
        --define TPM_ENABLE=TRUE

  log "Conversion en qcow2"
  qemu-img convert -f raw -O qcow2 Build/OvmfX64/RELEASE_GCC5/FV/OVMF_CODE.fd "$FIRMWARE_DIR/OVMF_CODE.secboot.4m.qcow2"
  qemu-img convert -f raw -O qcow2 Build/OvmfX64/RELEASE_GCC5/FV/OVMF_VARS.fd "$VARS_IN"

  popd >/dev/null
  log "Firmware prêt dans $FIRMWARE_DIR"
}

inject_certs() {
  command -v virt-fw-vars >/dev/null || fatal "virt-fw-vars non installé"
  [[ -f "$VARS_IN" ]] || fatal "Fichier VARS introuvable : $VARS_IN"

  local UUID="8be4df61-93ca-11d2-aa0d-00e098032b8c"
  local tmp=$(mktemp -d)
  pushd "$tmp" >/dev/null

  log "Téléchargement certificats Microsoft"
  base="https://raw.githubusercontent.com/microsoft/secureboot_objects/main/PreSignedObjects"
  curl -sOL "$base/PK/Certificate/WindowsOEMDevicesPK.der"
  curl -sOL "$base/KEK/Certificates/MicCorKEKCA2011_2011-06-24.der"
  curl -sOL "$base/DB/Certificates/MicCorUEFCA2011_2011-06-27.der"
  curl -sOL "https://uefi.org/sites/default/files/resources/dbxupdate_x64.bin"

  log "Injection certificats"
  virt-fw-vars --input "$VARS_IN" --output "$VARS_SECURE" --secure-boot \
      --set-pk "$UUID" WindowsOEMDevicesPK.der \
      --add-kek "$UUID" MicCorKEKCA2011_2011-06-24.der \
      --add-db  "$UUID" MicCorUEFCA2011_2011-06-27.der \
      --set-dbx dbxupdate_x64.bin

  popd >/dev/null
  rm -rf "$tmp"
  log "VARS sécurisé créé : $VARS_SECURE"
}

show_cmd() {
  local vars_path=$1
  cat <<EOF

Commande de test :

qemu-system-x86_64 \\
  -machine q35,smm=on,accel=kvm \\
  -global ICH9-LPC.disable_s3=1 \\
  -global driver=cfi.pflash01,property=secure,value=on \\
  -drive if=pflash,unit=0,format=qcow2,readonly=on,file=$FIRMWARE_DIR/OVMF_CODE.secboot.4m.qcow2 \\
  -drive if=pflash,unit=1,format=qcow2,file=$vars_path \\
  -m 1024 \\
  -vnc 0.0.0.0:0

EOF
}

main_menu() {
  echo
  echo "  [1] Construire OVMF"
  echo "  [2] Construire OVMF puis injecter certificats"
  echo "  [0] Quitter"
  read -rp "Choix : " c
  case "$c" in
    1) reset_workspace; build_ovmf; show_cmd "$VARS_IN" ;;
    2) reset_workspace; build_ovmf; inject_certs; show_cmd "$VARS_SECURE" ;;
    0) exit 0 ;;
    *) log "Choix invalide" ;;
  esac
}

while true; do main_menu; done
