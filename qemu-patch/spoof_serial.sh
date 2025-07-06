#!/usr/bin/env bash

# === CONFIGURATION ===
QEMU_DIR="$HOME/pve-qemu/qemu" # <-- adapte si besoin
USB_DIR="${QEMU_DIR}/hw/usb"
BACKUP_DIR="${QEMU_DIR}/.spoof_backup"

PATTERNS=(
  "STRING_SERIALNUMBER"
  "STR_SERIALNUMBER"
  "STR_SERIAL_MOUSE"
  "STR_SERIAL_TABLET"
  "STR_SERIAL_KEYBOARD"
  "STR_SERIAL_COMPAT"
)

# === SÉCURITÉ ===
if [ ! -d "$USB_DIR" ]; then
  echo "❌ Erreur: Dossier $USB_DIR introuvable"
  exit 1
fi

mkdir -p "$BACKUP_DIR"

echo "🔧 Spoofing des identifiants USB..."

for file in "$USB_DIR"/*.c; do
  cp "$file" "$BACKUP_DIR/$(basename "$file")"

  for pat in "${PATTERNS[@]}"; do
    grep -n "\[\s*${pat}\s*\]\s*=\s*\"[^\"]*\"" "$file" | cut -d: -f1 | while read -r lineno; do
      new_serial=$(tr -dc 'A-Z0-9' </dev/urandom | head -c10)
      sed -r -i "${lineno}s/(\[\s*${pat}\s*\]\s*=\s*\")[^\"]*(\")/\1${new_serial}\2/" "$file"
    done
  done
done

echo "✅ Spoofing terminé. Sauvegarde des fichiers dans: $BACKUP_DIR"
