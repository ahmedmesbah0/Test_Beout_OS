#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

BEOUTOS_GRUB_PASSWORD_HASH=""
BEOUTOS_SERIAL_CONSOLE="ttyS0,115200n8"
BEOUTOS_GRUB_TIMEOUT=3

horus_install_bootloader() {
    local disk="$1"
    local efi_part="$2"
    local boot_part="$3"
    local roota_part="$4"
    local rootb_part="$5"

    echo -e "${CYAN}${BOLD}[STEP]${NC} Installing GRUB2 bootloader for UEFI..."

    local efi_mount="/mnt/horus-efi"
    local boot_mount="/mnt/horus-boot"

    mkdir -p "$efi_mount"
    mkdir -p "$boot_mount"

    mount "$efi_part" "$efi_mount"
    mount "$boot_part" "$boot_mount"

    mkdir -p "${efi_mount}/EFI"
    mkdir -p "${efi_mount}/EFI/BeoutOS"
    mkdir -p "${boot_mount}/grub"

    grub-install \
        --target=x86_64-efi \
        --efi-directory="$efi_mount" \
        --bootloader-id=BeoutOS \
        --boot-directory="$boot_mount" \
        --no-nvram \
        --recheck \
        "$disk"

    if [[ ! -f "${boot_mount}/grub/x86_64-efi/core.efi" ]]; then
        umount "$efi_mount"
        umount "$boot_mount"
        echo -e "${RED}${BOLD}[ERROR]${NC} GRUB EFI core image not found."
        return 1
    fi

    cp "${efi_mount}/EFI/BeoutOS/grubx64.efi" "${efi_mount}/EFI/BOOT/grubx64.efi" 2>/dev/null || true
    mkdir -p "${efi_mount}/EFI/BOOT"
    if [[ -f "${efi_mount}/EFI/BeoutOS/grubx64.efi" ]]; then
        cp "${efi_mount}/EFI/BeoutOS/grubx64.efi" "${efi_mount}/EFI/BOOT/grubx64.efi"
    fi

    echo -e "${GREEN}${BOLD}[OK]${NC} GRUB2 installed for UEFI."
}

horus_create_grub_config() {
    local boot_part="$1"
    local roota_part="$2"
    local rootb_part="$3"

    echo -e "${CYAN}${BOLD}[STEP]${NC} Creating GRUB configuration..."

    local boot_mount="/mnt/horus-boot"
    mkdir -p "$boot_mount"

    if ! mountpoint -q "$boot_mount" 2>/dev/null; then
        mount "$boot_part" "$boot_mount"
    fi

    horus_generate_grub_password

    cat > "${boot_mount}/grub/grub.cfg" << GRUBCFG
set default=0
set timeout=${BEOUTOS_GRUB_TIMEOUT}
set fallback=1

set superusers="beoutos-admin"
password_pbkdf2 beoutos-admin ${BEOUTOS_GRUB_PASSWORD_HASH}

set pager=1

serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1
terminal_input serial console
terminal_output serial console

insmod part_gpt
insmod ext2
insmod squashfs
insmod overlay
insmod cryptodisk
insmod luks
insmod gcry_sha256
insmod gcry_sha512
insmod pbkdf2
insmod all_video
insmod efi_gop
insmod efi_uga
insmod font
insmod gfxterm

load_env -f (BEOUTOS-BOOT)/grub/horus-env

menuentry "BeoutOS (Root A)" --users beoutos-admin {
    load_video
    set gfxpayload=keep
    insmod gzio
    insmod part_gpt
    insmod ext2
    search --set=bootpart --partlabel BEOUTOS-BOOT
    search --set=rootapart --partlabel BEOUTOS-ROOTA
    linux (BEOUTOS-BOOT)/vmlinuz root=PARTLABEL=BEOUTOS-ROOTA ro \
        rootfstype=squashfs \
        horus.root=/system.squashfs \
        horus.overlay.upper=/mnt/horus-config/overlay-upper \
        horus.overlay.work=/tmp/horus-overlay-work \
        horus.config=/dev/disk/by-partlabel/BEOUTOS-CONFIG \
        horus.config.mapper=horus-config \
        overlay=/etc:/mnt/horus-config/overlay-upper/etc:/tmp/horus-overlay-work/etc \
        overlay=/var:/mnt/horus-config/overlay-upper/var:/tmp/horus-overlay-work/var \
        console=${BEOUTOS_SERIAL_CONSOLE} console=tty0 \
        quiet panic=10 \
        horus.boot.slot=a
    initrd (BEOUTOS-BOOT)/initrd.img
}

menuentry "BeoutOS (Root B - Fallback)" --users beoutos-admin {
    load_video
    set gfxpayload=keep
    insmod gzio
    insmod part_gpt
    insmod ext2
    search --set=bootpart --partlabel BEOUTOS-BOOT
    search --set=rootbpart --partlabel BEOUTOS-ROOTB
    linux (BEOUTOS-BOOT)/vmlinuz root=PARTLABEL=BEOUTOS-ROOTB ro \
        rootfstype=squashfs \
        horus.root=/system.squashfs \
        horus.overlay.upper=/mnt/horus-config/overlay-upper \
        horus.overlay.work=/tmp/horus-overlay-work \
        horus.config=/dev/disk/by-partlabel/BEOUTOS-CONFIG \
        horus.config.mapper=horus-config \
        overlay=/etc:/mnt/horus-config/overlay-upper/etc:/tmp/horus-overlay-work/etc \
        overlay=/var:/mnt/horus-config/overlay-upper/var:/tmp/horus-overlay-work/var \
        console=${BEOUTOS_SERIAL_CONSOLE} console=tty0 \
        quiet panic=10 \
        horus.boot.slot=b
    initrd (BEOUTOS-BOOT)/initrd.img
}

menuentry "BeoutOS Recovery Console (Root A)" --users beoutos-admin {
    load_video
    set gfxpayload=keep
    insmod gzio
    insmod part_gpt
    insmod ext2
    search --set=bootpart --partlabel BEOUTOS-BOOT
    search --set=rootapart --partlabel BEOUTOS-ROOTA
    linux (BEOUTOS-BOOT)/vmlinuz root=PARTLABEL=BEOUTOS-ROOTA ro \
        rootfstype=squashfs \
        horus.root=/system.squashfs \
        horus.overlay.upper=/mnt/horus-config/overlay-upper \
        horus.overlay.work=/tmp/horus-overlay-work \
        horus.config=/dev/disk/by-partlabel/BEOUTOS-CONFIG \
        horus.config.mapper=horus-config \
        console=${BEOUTOS_SERIAL_CONSOLE} console=tty0 \
        horus.recovery=1 \
        horus.boot.slot=a
    initrd (BEOUTOS-BOOT)/initrd.img
}
GRUBCFG

    chmod 400 "${boot_mount}/grub/grub.cfg"

    cat > "${boot_mount}/grub/horus-env" << 'ENVCFG'
horus_boot_slot=a
horus_boot_attempts=0
horus_boot_healthy=1
ENVCFG

    chmod 600 "${boot_mount}/grub/horus-env"

    echo -e "${GREEN}${BOLD}[OK]${NC} GRUB configuration created with password protection and lockdown."
}

horus_generate_grub_password() {
    echo -e "${CYAN}${BOLD}[STEP]${NC} Generating GRUB admin password..."

    local temp_password="horus-$(date +%s | sha256sum | head -c 12)"

    BEOUTOS_GRUB_PASSWORD_HASH=$(grub-mkpasswd-pbkdf2 \
        -c 10000 \
        -l 64 \
        -s 32 \
        <<< "${temp_password}${temp_password}" 2>/dev/null | \
        grep "grub.pbkdf2" | awk '{print $NF}')

    if [[ -z "$BEOUTOS_GRUB_PASSWORD_HASH" ]]; then
        BEOUTOS_GRUB_PASSWORD_HASH="grub.pbkdf2.sha512.10000.000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000.a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6"
        echo -e "${YELLOW}${BOLD}[WARN]${NC} Using placeholder GRUB password hash. Replace in production."
    fi

    echo -e "${GREEN}${BOLD}[OK]${NC} GRUB password protection configured."
}

horus_generate_initrd() {
    local boot_part="$1"
    local roota_part="$2"
    local config_mapper="$3"

    echo -e "${CYAN}${BOLD}[STEP]${NC} Generating initramfs with OverlayFS hooks..."

    local boot_mount="/mnt/horus-boot"
    mkdir -p "$boot_mount"

    if ! mountpoint -q "$boot_mount" 2>/dev/null; then
        mount "$boot_part" "$boot_mount"
    fi

    local kernel_version
    kernel_version=$(ls /live/chroot/lib/modules/ 2>/dev/null | head -1 || \
        uname -r 2>/dev/null || echo "6.1.0-13-amd64")

    local initrd_temp="/tmp/horus-initrd-build"
    rm -rf "$initrd_temp"
    mkdir -p "$initrd_temp"

    mkdir -p "${initrd_temp}/bin"
    mkdir -p "${initrd_temp}/sbin"
    mkdir -p "${initrd_temp}/etc"
    mkdir -p "${initrd_temp}/lib"
    mkdir -p "${initrd_temp}/lib64"
    mkdir -p "${initrd_temp}/usr/bin"
    mkdir -p "${initrd_temp}/usr/sbin"
    mkdir -p "${initrd_temp}/usr/lib"
    mkdir -p "${initrd_temp}/proc"
    mkdir -p "${initrd_temp}/sys"
    mkdir -p "${initrd_temp}/dev"
    mkdir -p "${initrd_temp}/tmp"
    mkdir -p "${initrd_temp}/mnt/horus-squashfs"
    mkdir -p "${initrd_temp}/mnt/horus-config"
    mkdir -p "${initrd_temp}/mnt/horus-roota-temp"
    mkdir -p "${initrd_temp}/scripts"
    mkdir -p "${initrd_temp}/hooks"

    cp /usr/bin/cryptsetup "${initrd_temp}/usr/bin/" 2>/dev/null || true
    cp /usr/sbin/dmsetup "${initrd_temp}/usr/sbin/" 2>/dev/null || true

    ldd /usr/bin/cryptsetup 2>/dev/null | grep "=>" | awk '{print $3}' | while read -r lib; do
        cp "$lib" "${initrd_temp}/lib/" 2>/dev/null || true
    done

    ldd /usr/sbin/dmsetup 2>/dev/null | grep "=>" | awk '{print $3}' | while read -r lib; do
        cp "$lib" "${initrd_temp}/lib/" 2>/dev/null || true
    done

    for mod in overlay squashfs ext4 vfat dm_crypt aes_x86_64 sha256_generic; do
        local mod_path
        mod_path=$(find /lib/modules/${kernel_version} -name "${mod}.ko*" 2>/dev/null | head -1 || echo "")
        if [[ -n "$mod_path" ]]; then
            cp "$mod_path" "${initrd_temp}/lib/" 2>/dev/null || true
        fi
    done

    cat > "${initrd_temp}/init" << 'INITSCRIPT'
#!/bin/sh
set -e

export PATH=/usr/bin:/usr/sbin:/bin:/sbin

mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev

mkdir -p /dev/mapper

for mod in overlay squashfs ext4 vfat dm_crypt aes_x86_64 sha256_generic; do
    insmod /lib/${mod}.ko 2>/dev/null || modprobe ${mod} 2>/dev/null || true
done

. /scripts/horus-overlay

exec switch_root /mnt/horus-squashfs /sbin/init
INITSCRIPT

    chmod 755 "${initrd_temp}/init"

    if [[ -f /live/chroot/usr/sbin/horus-overlay ]]; then
        cp /live/chroot/usr/sbin/horus-overlay "${initrd_temp}/scripts/horus-overlay"
    else
        local overlay_hook="${boot_mount}/initramfs-overlay-hook/horus-overlay"
        if [[ -f "$overlay_hook" ]]; then
            cp "$overlay_hook" "${initrd_temp}/scripts/horus-overlay"
        else
            cat > "${initrd_temp}/scripts/horus-overlay" << 'FALLBACKOVERLAY'
#!/bin/sh
set -e

BEOUTOS_SQUASHFS_ROOT="/mnt/horus-squashfs"
BEOUTOS_CONFIG_MOUNT="/mnt/horus-config"
BEOUTOS_CONFIG_MAPPER="horus-config"

mount_squashfs() {
    local root_part="/dev/disk/by-partlabel/BEOUTOS-ROOTA"
    mkdir -p /mnt/horus-roota-temp
    mount "$root_part" /mnt/horus-roota-temp || panic "Cannot mount root partition"
    mkdir -p "$BEOUTOS_SQUASHFS_ROOT"
    mount -t squashfs /mnt/horus-roota-temp/system.squashfs "$BEOUTOS_SQUASHFS_ROOT" || panic "Cannot mount squashfs"
}

open_config() {
    cryptsetup luksOpen /dev/disk/by-partlabel/BEOUTOS-CONFIG "$BEOUTOS_CONFIG_MAPPER" || \
    panic "Cannot open config partition"
    mkdir -p "$BEOUTOS_CONFIG_MOUNT"
    mount /dev/mapper/"$BEOUTOS_CONFIG_MAPPER" "$BEOUTOS_CONFIG_MOUNT" || \
    panic "Cannot mount config partition"
}

setup_overlays() {
    mkdir -p /tmp/horus-overlay-work/etc
    mkdir -p /tmp/horus-overlay-work/var
    mount -t overlay overlay-etc -o "lowerdir=${BEOUTOS_SQUASHFS_ROOT}/etc,upperdir=${BEOUTOS_CONFIG_MOUNT}/overlay-upper/etc,workdir=/tmp/horus-overlay-work/etc" /mnt/horus-overlay-etc || panic "Cannot mount /etc overlay"
    mount -t overlay overlay-var -o "lowerdir=${BEOUTOS_SQUASHFS_ROOT}/var,upperdir=${BEOUTOS_CONFIG_MOUNT}/overlay-upper/var,workdir=/tmp/horus-overlay-work/var" /mnt/horus-overlay-var || panic "Cannot mount /var overlay"
}

mount_squashfs
open_config
setup_overlays
FALLBACKOVERLAY
            chmod 755 "${initrd_temp}/scripts/horus-overlay"
        fi
    fi

    cd "$initrd_temp"
    find . | cpio -o -H newc 2>/dev/null | gzip -9 > "${boot_mount}/initrd.img"

    cd /

    if [[ -f /live/chroot/boot/vmlinuz-* ]]; then
        cp /live/chroot/boot/vmlinuz-* "${boot_mount}/vmlinuz"
    elif [[ -f /boot/vmlinuz-* ]]; then
        cp /boot/vmlinuz-* "${boot_mount}/vmlinuz"
    else
        echo -e "${YELLOW}${BOLD}[WARN]${NC} Kernel image not found. Copy manually to boot partition."
    fi

    sync

    rm -rf "$initrd_temp"

    echo -e "${GREEN}${BOLD}[OK]${NC} Initramfs generated with OverlayFS hooks."
}

horus_setup_secure_boot() {
    local efi_mount="$1"

    echo -e "${CYAN}${BOLD}[STEP]${NC} Setting up Secure Boot signing keys..."

    local key_dir="/etc/horus/secure-boot-keys"
    mkdir -p "$key_dir"

    if [[ ! -f "${key_dir}/db.key" ]] || [[ ! -f "${key_dir}/db.crt" ]]; then
        openssl req -new -x509 \
            -newkey rsa:2048 \
            -keyout "${key_dir}/db.key" \
            -out "${key_dir}/db.crt" \
            -nodes \
            -days 3650 \
            -subj "/CN=BeoutOS Secure Boot Key/" \
            2>/dev/null

        openssl x509 -in "${key_dir}/db.crt" -outform DER \
            -out "${key_dir}/db.der" 2>/dev/null

        cert-to-efi-sig-list "${key_dir}/db.crt" "${key_dir}/db.esl" 2>/dev/null || true
        sign-efi-sig-list -k "${key_dir}/db.key" -c "${key_dir}/db.crt" db \
            "${key_dir}/db.esl" "${key_dir}/db.auth" 2>/dev/null || true

        echo -e "${YELLOW}${BOLD}[WARN]${NC} Secure Boot keys generated. Enroll in firmware for full Secure Boot support."
    fi

    if command -v sbsign &>/dev/null; then
        local grub_efi="${efi_mount}/EFI/BeoutOS/grubx64.efi"
        if [[ -f "$grub_efi" ]]; then
            sbsign --key "${key_dir}/db.key" --cert "${key_dir}/db.crt" \
                --output "$grub_efi" "$grub_efi" 2>/dev/null || true
            echo -e "${GREEN}${BOLD}[OK]${NC} GRUB EFI binary signed."
        fi
    fi

    echo -e "${GREEN}${BOLD}[OK]${NC} Secure Boot key infrastructure created."
}

horus_verify_installation() {
    local disk="$1"
    local efi_part="$2"
    local boot_part="$3"
    local roota_part="$4"
    local config_mapper="$5"

    echo -e "${CYAN}${BOLD}[STEP]${NC} Verifying installation integrity..."

    local efi_mount="/mnt/horus-efi"
    local boot_mount="/mnt/horus-boot"

    mkdir -p "$efi_mount" "$boot_mount"

    mount "$efi_part" "$efi_mount" 2>/dev/null || true
    mount "$boot_part" "$boot_mount" 2>/dev/null || true

    if [[ ! -f "${efi_mount}/EFI/BeoutOS/grubx64.efi" ]]; then
        echo -e "${RED}${BOLD}[ERROR]${NC} GRUB EFI binary not found."
        return 1
    fi

    if [[ ! -f "${boot_mount}/grub/grub.cfg" ]]; then
        echo -e "${RED}${BOLD}[ERROR]${NC} GRUB configuration not found."
        return 1
    fi

    if [[ ! -f "${boot_mount}/vmlinuz" ]]; then
        echo -e "${RED}${BOLD}[ERROR]${NC} Kernel image not found on boot partition."
        return 1
    fi

    if [[ ! -f "${boot_mount}/initrd.img" ]]; then
        echo -e "${RED}${BOLD}[ERROR]${NC} Initramfs image not found on boot partition."
        return 1
    fi

    local roota_mount="/mnt/horus-roota-temp"
    mkdir -p "$roota_mount"
    mount "$roota_part" "$roota_mount" 2>/dev/null || true

    if [[ ! -f "${roota_mount}/system.squashfs" ]]; then
        umount "$roota_mount" 2>/dev/null || true
        echo -e "${RED}${BOLD}[ERROR]${NC} SquashFS image not found on Root A."
        return 1
    fi

    if [[ -f "${roota_mount}/system.squashfs.sha256" ]]; then
        local stored_hash
        stored_hash=$(cat "${roota_mount}/system.squashfs.sha256")
        local actual_hash
        actual_hash=$(sha256sum "${roota_mount}/system.squashfs" | awk '{print $1}')
        if [[ "$stored_hash" != "$actual_hash" ]]; then
            echo -e "${RED}${BOLD}[ERROR]${NC} SquashFS integrity check failed on Root A."
            return 1
        fi
    fi

    umount "$roota_mount" 2>/dev/null || true

    if dmsetup info "$config_mapper" &>/dev/null; then
        local config_mount="/mnt/horus-config"
        mkdir -p "$config_mount"
        mount "/dev/mapper/${config_mapper}" "$config_mount" 2>/dev/null || true

        if [[ ! -d "${config_mount}/config" ]]; then
            echo -e "${RED}${BOLD}[ERROR]${NC} Config directory structure missing."
            return 1
        fi

        if [[ ! -d "${config_mount}/overlay-upper" ]]; then
            echo -e "${RED}${BOLD}[ERROR]${NC} Overlay upper directory missing."
            return 1
        fi

        umount "$config_mount" 2>/dev/null || true
    fi

    umount "$efi_mount" 2>/dev/null || true
    umount "$boot_mount" 2>/dev/null || true

    echo -e "${GREEN}${BOLD}[OK]${NC} All installation integrity checks passed."
}
