#!/usr/bin/env bash
set -euo pipefail

############################################
# Pretty logging helpers
############################################
CLR_RESET='\e[0m'
CLR_RED='\e[31m'
CLR_GRN='\e[32m'

log()   { printf "${CLR_GRN}[INFO]${CLR_RESET} %s\n"  "$*"; }
err()   { printf "${CLR_RED}[ERREUR]${CLR_RESET} %s\n" "$*" >&2; }
fatal() { err "$*"; exit 1; }

############################################
# Distro-aware package installation
############################################
detect_distro() { source /etc/os-release; echo "${ID}"; }

install_pkgs() {
  local d=$1; shift
  local -a p=("$@")
  case "$d" in
    debian|ubuntu)      apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y "${p[@]}" ;;
    fedora)             dnf  install -y "${p[@]}" ;;
    arch)               pacman -Sy --noconfirm --needed "${p[@]}" ;;
    opensuse*|suse|sles) zypper --non-interactive install "${p[@]}" ;;
    *)                  log "Distribution inconnue, installation auto ignorée" ;;
  esac
}

DISTRO="$(detect_distro)"
REQUIRED_PKGS=(git gcc g++ make nasm python3 python3-virt-firmware)
install_pkgs "$DISTRO" "${REQUIRED_PKGS[@]}"

############################################
# Globals & paths
############################################
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

############################################
# Helpers
############################################
reset_workspace() {
  rm -rf "$FIRMWARE_DIR" "$SRC_DIR"
  mkdir -p "$FIRMWARE_DIR"
}

require_source() { [[ -d "$SRC_DIR" ]] || fatal "Source manquante – exécutez d’abord l’étape « fetch source »."; }
require_build () { [[ -f "$FIRMWARE_DIR/OVMF_CODE.secboot.4m.qcow2" ]] || fatal "Firmware non compilé – lancez l’étape « compile »."; }

############################################
# STEP 1 — Fetch & patch source
############################################
fetch_source() {
  reset_workspace
  log "Clonage EDK2 ($EDK2_VERSION)…"
  git clone --depth=1 --branch "$EDK2_VERSION" https://github.com/tianocore/edk2.git "$SRC_DIR"
  pushd "$SRC_DIR" >/dev/null
  git submodule update --init

  [[ -f "$PATCH_DIR/$OVMF_PATCH" ]] || fatal "Patch manquant : $PATCH_DIR/$OVMF_PATCH"
  git apply "$PATCH_DIR/$OVMF_PATCH"
  log "Patch appliqué : $OVMF_PATCH"
  # Copie du logo personnalisé
  local logo_path="/root/nogo.bmp"
  local logo_dest="MdeModulePkg/Logo/Logo.bmp"
  if [[ -f "$logo_path" ]]; then
    cp -f "$logo_path" "$logo_dest"
    log "Logo personnalisé copié dans $logo_dest"
  else
    log "Avertissement : logo non trouvé à $logo_path. Aucun logo personnalisé appliqué."
  fi


  popd >/dev/null
  log "Source prête dans $SRC_DIR"


}

############################################
# STEP 2 — Build (compile & qcow2 convert)
############################################
compile_ovmf() {
  require_source
  pushd "$SRC_DIR" >/dev/null

  export WORKSPACE="$SRC_DIR"
  export EDK_TOOLS_PATH="$SRC_DIR/BaseTools"
  export CONF_PATH="$SRC_DIR/Conf"
  export PYTHON_COMMAND=python3

  log "Compilation BaseTools…"
  make -C BaseTools -s

  source edksetup.sh

  log "Compilation OVMF…"
  build \
    -a X64 \
    -p OvmfPkg/OvmfPkgX64.dsc \
    -b RELEASE \
    -t GCC5 \
    -n "$(nproc)" \
    -q \
    --define SECURE_BOOT_ENABLE=TRUE \
    --define TPM_CONFIG_ENABLE=TRUE \
    --define TPM_ENABLE=TRUE \
    --define TPM1_ENABLE=TRUE \
    --define TPM2_ENABLE=TRUE

  log "Conversion en qcow2…"
  qemu-img convert -f raw -O qcow2 Build/OvmfX64/RELEASE_GCC5/FV/OVMF_CODE.fd \
                   "$FIRMWARE_DIR/OVMF_CODE.secboot.4m.qcow2"
  qemu-img convert -f raw -O qcow2 Build/OvmfX64/RELEASE_GCC5/FV/OVMF_VARS.fd \
                   "$VARS_IN"

  popd >/dev/null
  log "Firmware compilé : $FIRMWARE_DIR"
}

############################################
# STEP 3 — Inject Microsoft certificates
############################################
inject_certs() {
  command -v virt-fw-vars >/dev/null || fatal "virt-fw-vars non installé"
  require_build

  local UUID="8be4df61-93ca-11d2-aa0d-00e098032b8c"   # EFI_GLOBAL_VARIABLE
  local tmp
  tmp=$(mktemp -d)

  pushd "$tmp" >/dev/null
  log "Téléchargement des certificats Microsoft…"
  base="https://raw.githubusercontent.com/microsoft/secureboot_objects/main/PreSignedObjects"

  curl -sL "$base/PK/Certificate/WindowsOEMDevicesPK.der"                        -o PK.der
  curl -sL "$base/KEK/Certificates/microsoft%20corporation%20kek%202k%20ca%202023.der"            -o KEK_2023.der
  curl -sL "$base/DB/Certificates/microsoft%20uefi%20ca%202023.der"             -o DB_UEFI_2023.der
  curl -sL "$base/DB/Certificates/windows%20uefi%20ca%202023.der"               -o DB_WIN_2023.der
  curl -sL "$base/DB/Certificates/microsoft%20option%20rom%20uefi%20ca%202023.der" -o DB_OPROM_2023.der
  curl -sL "$base/DB/Certificates/MicWinProPCA2011_2011-10-19.der"              -o DB_PCA2011.der
  curl -sL "https://uefi.org/sites/default/files/resources/dbxupdate_x64.bin"   -o dbxupdate_x64.bin

  log "Injection dans $VARS_SECURE…"
  virt-fw-vars --input  "$VARS_IN"  \
               --output "$VARS_SECURE" \
               --secure-boot \
               --set-pk  "$UUID" PK.der \
               --add-kek "$UUID" KEK_2023.der \
               --add-db  "$UUID" DB_UEFI_2023.der \
               --add-db  "$UUID" DB_WIN_2023.der \
               --add-db  "$UUID" DB_OPROM_2023.der \
               --add-db  "$UUID" DB_PCA2011.der \
               --set-dbx dbxupdate_x64.bin

  popd >/dev/null
  rm -rf "$tmp"
  log "VARS sécurisé créé : $VARS_SECURE"
}

############################################
# Helper — show example qemu command line
############################################
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

############################################
# Menu
############################################
main_menu() {
  echo
  echo "=== OVMF Secure-Boot Builder ==="
  echo "  [1] Fetch & patch source"
  echo "  [2] Compile OVMF (requires source)"
  echo "  [3] Inject Microsoft certificates (requires build)"
  echo "  [4] FULL run : fetch + compile + inject"
  echo "  [0] Quit"
  read -rp "Choix : " c
  case "$c" in
    1) fetch_source ;;
    2) compile_ovmf; show_cmd "$VARS_IN" ;;
    3) inject_certs;  show_cmd "$VARS_SECURE" ;;
    4) fetch_source; compile_ovmf; inject_certs; show_cmd "$VARS_SECURE" ;;
    0) exit 0 ;;
    *) log "Choix invalide" ;;
  esac
}

while true; do main_menu; done
