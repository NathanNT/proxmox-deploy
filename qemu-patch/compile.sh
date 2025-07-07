#!/bin/bash
set -e

# === CONFIGURATION ===
VERSION_SUFFIX="+custom1"
CHLOG_MSG="Build personnalisé QEMU Proxmox"
PACKAGE="pve-qemu-kvm"
PVE_QEMU_DIR="pve-qemu"

cd "$PVE_QEMU_DIR"

# === Lire la version amont depuis debian/changelog ===
BASE_VERSION=$(dpkg-parsechangelog -l debian/changelog -S Version | sed 's/-.*//')
ORIG_REV=$(dpkg-parsechangelog -l debian/changelog -S Version | sed 's/.*-//')
PATCHED_VERSION="${BASE_VERSION}-${ORIG_REV}${VERSION_SUFFIX}"
BUILDDIR="${PACKAGE}-${BASE_VERSION}"

echo "🔧 Version d'origine : $BASE_VERSION-$ORIG_REV"
echo "🎯 Version modifiée  : $PATCHED_VERSION"
echo "📁 Dossier de build  : $BUILDDIR"

# === Supprimer --disable-download s'il est présent ===
echo "🧽 Suppression de --disable-download..."
sed -i 's/--disable-download//g' debian/rules

# === Générer le dossier source patché ===
echo "📦 Préparation du dossier de compilation..."
make "$BUILDDIR"

# === Modifier le changelog dans le dossier généré ===
cd "$BUILDDIR"
echo "✏️ Mise à jour de debian/changelog avec la version $PATCHED_VERSION"
dch -b --force-distribution --newversion "$PATCHED_VERSION" "$CHLOG_MSG"
cd ..

# === Compilation finale ===
echo "⚙️ Compilation du paquet..."
cd "$BUILDDIR"
dpkg-buildpackage -b -us -uc
cd ..

# === Installation automatique ===
echo "📥 Installation du paquet compilé..."
DEBS=$(ls ${PACKAGE}_${PATCHED_VERSION}_*.deb 2>/dev/null || true)

if [ -z "$DEBS" ]; then
    echo "❌ Aucun paquet .deb trouvé"
else
    echo "✅ Installation des paquets : $DEBS"
    dpkg -i $DEBS || true
fi

echo "✅ Compilation terminée avec succès — version : $PATCHED_VERSION"
