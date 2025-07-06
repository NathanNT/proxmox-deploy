cd ~
rm -rf pve-qemu Hypervisor-Phantom

# Clone Proxmox QEMU source with submodules
git clone --recurse-submodules https://git.proxmox.com/git/pve-qemu.git
cd pve-qemu
git submodule update --init --recursive

# Force fresh clone of QEMU submodule
rm -rf submodules/qemu
git clone https://git.proxmox.com/git/qemu.git submodules/qemu

# Install dependencies
apt update
apt install -y git build-essential devscripts fakeroot equivs gnupg flex bison \
               ninja-build libglib2.0-dev iasl meson quilt curl

apt build-dep -y .

# Prepare QEMU source tree
make submodule

# Download Meson subprojects required by QEMU
cd pve-qemu-kvm-10.0.2
meson subprojects download
cd ..

# Remove --disable-download to allow Meson to use downloaded subprojects
sed -i 's/--disable-download //' debian/rules

# Clone Hypervisor-Phantom patch project
git clone https://github.com/Scrut1ny/Hypervisor-Phantom.git
cd Hypervisor-Phantom
git submodule update --init --recursive
cd ..

# Apply AMD-specific QEMU patches from Hypervisor Phantom
cp Hypervisor-Phantom/patches/QEMU/amd-qemu-10.0.2.patch \
   debian/patches/extra/9000-hypervisor-phantom-amd.patch

cp Hypervisor-Phantom/patches/QEMU/libnfs6-qemu-10.0.2.patch \
   debian/patches/extra/9010-hypervisor-phantom-libnfs.patch

echo "extra/9000-hypervisor-phantom-amd.patch" >> debian/patches/series
echo "extra/9010-hypervisor-phantom-libnfs.patch" >> debian/patches/series

# Build QEMU .deb packages
make deb -j"$(nproc)"

# Install patched QEMU
dpkg -i pve-qemu-kvm_10.0.2-3_amd64.deb pve-qemu-kvm-dbgsym_10.0.2-3_amd64.deb

# Restart Proxmox services
systemctl restart pvedaemon qmeventd pveproxy

# (Optional) Compile spoofed ACPI tables
iasl -tc Hypervisor-Phantom/patches/QEMU/fake_battery.dsl
iasl -tc Hypervisor-Phantom/patches/QEMU/spoofed_devices.dsl

mkdir -p /root/acpi
mv fake_battery.aml spoofed_devices.aml /root/acpi/

# (Optional) Enable spoofed ACPI tables for VM ID 105 (adjust if needed)
echo 'args: -acpitable file=/root/acpi/fake_battery.aml -acpitable file=/root/acpi/spoofed_devices.aml' \
     >> /etc/pve/qemu-server/105.conf
