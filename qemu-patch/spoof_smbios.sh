#!/usr/bin/env bash

# === CONFIGURATION ===
QEMU_DIR="./pve-qemu/qemu"  # ← adapte si besoin
QEMU_VERSION="10.0.2"
CHIPSET_FILE=""
SMBIOS_FILE="${QEMU_DIR}/hw/smbios/smbios.c"

# === DÉTERMINER LE BON FICHIER CHIPSET ===
case "$QEMU_VERSION" in
  "8.2.6") CHIPSET_FILE="${QEMU_DIR}/hw/i386/pc_q35.c" ;;
  "9.2.4"|"10.0.2") CHIPSET_FILE="${QEMU_DIR}/hw/i386/fw_cfg.c" ;;
  *) echo "❌ QEMU version non supportée: $QEMU_VERSION" && exit 1 ;;
esac

[[ ! -f "$CHIPSET_FILE" ]] && echo "❌ Fichier chipset introuvable: $CHIPSET_FILE" && exit 1
[[ ! -f "$SMBIOS_FILE" ]] && echo "❌ Fichier SMBIOS introuvable: $SMBIOS_FILE" && exit 1

# === Spoof CPU manufacturer ===
echo "🔧 Patch fabricant CPU → Intel(R) Corporation"
sed -i "$CHIPSET_FILE" -e 's/smbios_set_defaults(".*",/smbios_set_defaults("Intel(R) Corporation",/'

# === Patch SMBIOS fields ===
echo "🛠️  Spoof SMBIOS constants..."

# Valeurs fixes inspirées de ta machine
PROC_FAMILY="0xB3"           # Core i5
VOLTAGE="0x08"               # 0.8V
EXT_CLOCK="0x0064"           # 100 MHz
MAX_SPEED="0x1130"           # 4400 MHz
CUR_SPEED="0x0A0E"           # 2574 MHz
UPGRADE="0x01"               # Other
L1="0x004E"
L2="0x004F"
L3="0x0050"
CHARACTERISTICS="0x00A0"
FAMILY2="0x0000"

sed -i -E "s/(t->processor_family[[:space:]]*=[[:space:]]*)0x[0-9A-Fa-f]+;/\1${PROC_FAMILY};/" "$SMBIOS_FILE"
sed -i -E "s/(t->voltage[[:space:]]*=[[:space:]]*)0;/\1${VOLTAGE};/" "$SMBIOS_FILE"
sed -i -E "s/(t->external_clock[[:space:]]*=[[:space:]]*cpu_to_le16\()0x[0-9A-Fa-f]+(\);)/\1${EXT_CLOCK}\2/" "$SMBIOS_FILE"
sed -i -E "s/(t->l1_cache_handle[[:space:]]*=[[:space:]]*cpu_to_le16\()0x[0-9A-Fa-f]+(\);)/\1${L1}\2/" "$SMBIOS_FILE"
sed -i -E "s/(t->l2_cache_handle[[:space:]]*=[[:space:]]*cpu_to_le16\()0x[0-9A-Fa-f]+(\);)/\1${L2}\2/" "$SMBIOS_FILE"
sed -i -E "s/(t->l3_cache_handle[[:space:]]*=[[:space:]]*cpu_to_le16\()0x[0-9A-Fa-f]+(\);)/\1${L3}\2/" "$SMBIOS_FILE"
sed -i -E "s/(t->processor_upgrade[[:space:]]*=[[:space:]]*)0x[0-9A-Fa-f]+;/\1${UPGRADE};/" "$SMBIOS_FILE"
sed -i -E "s/(t->processor_characteristics[[:space:]]*=[[:space:]]*cpu_to_le16\()0x[0-9A-Fa-f]+(\);)/\1${CHARACTERISTICS}\2/" "$SMBIOS_FILE"
sed -i -E "s/(t->processor_family2[[:space:]]*=[[:space:]]*cpu_to_le16\()0x[0-9A-Fa-f]+(\);)/\1${FAMILY2}\2/" "$SMBIOS_FILE"

echo "✅ SMBIOS spoof terminé avec succès."
