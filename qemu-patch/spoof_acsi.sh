#!/usr/bin/env bash

# === CONFIGURATION ===
QEMU_DIR="$HOME/pve-qemu/qemu" # <-- adapte si besoin
H_FILE="${QEMU_DIR}/include/hw/acpi/aml-build.h"
C_FILE="${QEMU_DIR}/hw/acpi/aml-build.c"
FAKE_BATTERY_DSL="$HOME/fake_battery.dsl"
FAKE_BATTERY_AML="$HOME/fake_battery.aml"

[[ ! -f "$H_FILE" || ! -f "$C_FILE" ]] && { echo "❌ Fichiers ACPI introuvables"; exit 1; }

# === SPOOF OEM ID / OEM TABLE ID ===
echo "🔧 Spoof ACPI OEM ID & OEM Table ID"

OEM_PAIRS=(
  "DELL  " "Dell Inc" " ASUS " "Notebook"
  "MSI NB" "MEGABOOK" "LENOVO" "TC-O5Z  "
  "LENOVO" "CB-01   " "SECCSD" "LH43STAR"
  "LGE   " "ICL     " "ALASKA" "A M I "
  "INTEL " "U Rvp   "
)

TOTAL=$(( ${#OEM_PAIRS[@]} / 2 ))
IDX=$(( RANDOM % TOTAL * 2 ))
APPNAME6="${OEM_PAIRS[$IDX]}"
APPNAME8="${OEM_PAIRS[$((IDX + 1))]}"

cp "$H_FILE" "${H_FILE}.bak"
sed -i -E "s/^#define ACPI_BUILD_APPNAME6 \".*\"/#define ACPI_BUILD_APPNAME6 \"${APPNAME6}\"/" "$H_FILE"
sed -i -E "s/^#define ACPI_BUILD_APPNAME8 \".*\"/#define ACPI_BUILD_APPNAME8 \"${APPNAME8}\"/" "$H_FILE"

echo "✅ ACPI OEM spoof: $APPNAME6 / $APPNAME8"

# === SPOOF PM TYPE ===
echo "🔧 Spoof ACPI PM Type"
CHASSIS=$(dmidecode -s chassis-type 2>/dev/null || echo "Desktop")
PM_TYPE=1 # default Desktop

[[ "$CHASSIS" == "Notebook" ]] && PM_TYPE=2

cp "$C_FILE" "${C_FILE}.bak"
sed -i -E "s/build_append_int_noprefix\(tbl, 0 \/\\* Unspecified \\\*\//build_append_int_noprefix(tbl, ${PM_TYPE} \/\* ${CHASSIS} \*\//" "$C_FILE"

echo "✅ PM Type spoofé en ${PM_TYPE} (${CHASSIS})"

# === FAKE BATTERY TABLE (optionnel) ===
if [[ "$CHASSIS" == "Notebook" ]]; then
  echo "🔋 Génération de la table ACPI Fake Battery"
  if [[ ! -f "${QEMU_DIR}/../../Hypervisor-Phantom/Hypervisor-Phantom/patches/QEMU/fake_battery.dsl" ]]; then
    echo "⚠️  Table fake_battery.dsl introuvable, génération annulée"
    exit 0
  fi

  cat "${QEMU_DIR}/../../Hypervisor-Phantom/Hypervisor-Phantom/patches/QEMU/fake_battery.dsl" \
    | sed "s/BOCHS/$APPNAME6/" \
    | sed "s/BXPCSSDT/$APPNAME8/" > "$FAKE_BATTERY_DSL"

  iasl -tc "$FAKE_BATTERY_DSL" && echo "✅ Table ACPI générée: $FAKE_BATTERY_AML"
fi
