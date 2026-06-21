#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

BEOUTOS_OVERLAY_CONFIG_MOUNT="/mnt/horus-config"
BEOUTOS_OVERLAY_UPPER_DIR="${BEOUTOS_OVERLAY_CONFIG_MOUNT}/overlay-upper"
BEOUTOS_OVERLAY_WORK_DIR="/tmp/horus-overlay-work"
BEOUTOS_SQUASHFS_ROOT="/mnt/horus-squashfs"

horus_create_overlay_dirs() {
    local config_mount="$1"

    echo -e "${CYAN}${BOLD}[STEP]${NC} Creating OverlayFS directories..."

    mkdir -p "${config_mount}/overlay-upper/etc"
    mkdir -p "${config_mount}/overlay-upper/var"
    mkdir -p "${config_mount}/overlay-upper/opt"
    mkdir -p "${config_mount}/overlay-upper/root"
    mkdir -p "${config_mount}/overlay-upper/home"

    mkdir -p "${BEOUTOS_OVERLAY_WORK_DIR}/etc"
    mkdir -p "${BEOUTOS_OVERLAY_WORK_DIR}/var"
    mkdir -p "${BEOUTOS_OVERLAY_WORK_DIR}/opt"
    mkdir -p "${BEOUTOS_OVERLAY_WORK_DIR}/root"
    mkdir -p "${BEOUTOS_OVERLAY_WORK_DIR}/home"

    echo -e "${GREEN}${BOLD}[OK]${NC} OverlayFS directories created."
}

horus_mount_overlay() {
    local lower_dir="$1"
    local upper_dir="$2"
    local work_dir="$3"
    local merge_dir="$4"

    echo -e "${CYAN}${BOLD}[STEP]${NC} Mounting OverlayFS: ${merge_dir}..."

    if mountpoint -q "$merge_dir" 2>/dev/null; then
        echo -e "${YELLOW}${BOLD}[WARN]${NC} ${merge_dir} is already mounted, skipping."
        return 0
    fi

    mkdir -p "$merge_dir"
    mkdir -p "$upper_dir"
    mkdir -p "$work_dir"

    mount -t overlay overlay \
        -o "lowerdir=${lower_dir},upperdir=${upper_dir},workdir=${work_dir}" \
        "$merge_dir"

    if ! mountpoint -q "$merge_dir" 2>/dev/null; then
        echo -e "${RED}${BOLD}[ERROR]${NC} OverlayFS mount failed for ${merge_dir}."
        return 1
    fi

    echo -e "${GREEN}${BOLD}[OK]${NC} OverlayFS mounted: ${merge_dir}"
}

horus_mount_squashfs_root() {
    local root_partition="$1"
    local mount_point="$2"

    echo -e "${CYAN}${BOLD}[STEP]${NC} Mounting SquashFS root from ${root_partition}..."

    mkdir -p "$mount_point"
    mkdir -p "/mnt/horus-roota-temp"

    mount "$root_partition" "/mnt/horus-roota-temp"

    if [[ ! -f "/mnt/horus-roota-temp/system.squashfs" ]]; then
        umount "/mnt/horus-roota-temp"
        echo -e "${RED}${BOLD}[ERROR]${NC} system.squashfs not found on Root A partition."
        return 1
    fi

    mount -t squashfs "/mnt/horus-roota-temp/system.squashfs" "$mount_point"

    if ! mountpoint -q "$mount_point" 2>/dev/null; then
        umount "/mnt/horus-roota-temp"
        echo -e "${RED}${BOLD}[ERROR]${NC} SquashFS mount failed."
        return 1
    fi

    echo -e "${GREEN}${BOLD}[OK]${NC} SquashFS root mounted at ${mount_point}."
}

horus_setup_all_overlays() {
    local config_mapper="$1"
    local squashfs_root="$2"

    echo -e "${CYAN}${BOLD}[STEP]${NC} Setting up all OverlayFS mounts..."

    local config_mount="${BEOUTOS_OVERLAY_CONFIG_MOUNT}"

    if ! mountpoint -q "$config_mount" 2>/dev/null; then
        mkdir -p "$config_mount"
        mount "/dev/mapper/${config_mapper}" "$config_mount"
    fi

    horus_create_overlay_dirs "$config_mount"

    horus_mount_overlay \
        "${squashfs_root}/etc" \
        "${config_mount}/overlay-upper/etc" \
        "${BEOUTOS_OVERLAY_WORK_DIR}/etc" \
        "/mnt/horus-overlay-etc"

    horus_mount_overlay \
        "${squashfs_root}/var" \
        "${config_mount}/overlay-upper/var" \
        "${BEOUTOS_OVERLAY_WORK_DIR}/var" \
        "/mnt/horus-overlay-var"

    echo -e "${GREEN}${BOLD}[OK]${NC} All OverlayFS mounts configured."
}

horus_configure_overlay() {
    local boot_partition="$1"
    local config_mapper="$2"

    echo -e "${CYAN}${BOLD}[STEP]${NC} Configuring OverlayFS for target system..."

    local boot_mount="/mnt/horus-boot"
    mkdir -p "$boot_mount"
    mount "$boot_partition" "$boot_mount"

    local initrd_overlay_hook="${boot_mount}/initramfs-overlay-hook"
    mkdir -p "$initrd_overlay_hook"

    cat > "${initrd_overlay_hook}/horus-overlay" << 'OVERLAYSCRIPT'
#!/bin/sh
set -e

PREREQ=""
prereqs() { echo "$PREREQ"; }
case "$1" in
    prereqs) prereqs; exit 0;;
esac

BEOUTOS_CONFIG_MAPPER="horus-config"
BEOUTOS_SQUASHFS_ROOT="/mnt/horus-squashfs"
BEOUTOS_CONFIG_MOUNT="/mnt/horus-config"
BEOUTOS_OVERLAY_UPPER="${BEOUTOS_CONFIG_MOUNT}/overlay-upper"
BEOUTOS_OVERLAY_WORK="/tmp/horus-overlay-work"

mount_squashfs_root() {
    local root_part=""
    for dev in /dev/disk/by-partlabel/BEOUTOS-ROOTA /dev/disk/by-partlabel/BEOUTOS-ROOTB; do
        if [ -e "$dev" ]; then
            local boot_flag="${dev}.boot-active"
            if [ -e "$boot_flag" ] || [ "$dev" = "/dev/disk/by-partlabel/BEOUTOS-ROOTA" ]; then
                root_part="$dev"
                break
            fi
        fi
    done

    if [ -z "$root_part" ]; then
        root_part="/dev/disk/by-partlabel/BEOUTOS-ROOTA"
    fi

    mkdir -p /mnt/horus-roota-temp
    mount "$root_part" /mnt/horus-roota-temp

    if [ ! -f /mnt/horus-roota-temp/system.squashfs ]; then
        panic "BeoutOS: system.squashfs not found on root partition"
    fi

    mkdir -p "$BEOUTOS_SQUASHFS_ROOT"
    mount -t squashfs /mnt/horus-roota-temp/system.squashfs "$BEOUTOS_SQUASHFS_ROOT"
}

open_luks() {
    if [ -e /dev/disk/by-partlabel/BEOUTOS-CONFIG ]; then
        modprobe dm_crypt 2>/dev/null
        modprobe aes_x86_64 2>/dev/null

        if cryptsetup isLuks /dev/disk/by-partlabel/BEOUTOS-CONFIG 2>/dev/null; then
            mkdir -p "$BEOUTOS_CONFIG_MOUNT"

            if [ -e /dev/tpm0 ] || [ -e /dev/tpmrm0 ]; then
                cryptsetup luksOpen --tpm2-device=auto /dev/disk/by-partlabel/BEOUTOS-CONFIG "$BEOUTOS_CONFIG_MAPPER" 2>/dev/null || \
                cryptsetup luksOpen /dev/disk/by-partlabel/BEOUTOS-CONFIG "$BEOUTOS_CONFIG_MAPPER" || \
                panic "BeoutOS: Cannot open encrypted config partition"
            else
                cryptsetup luksOpen /dev/disk/by-partlabel/BEOUTOS-CONFIG "$BEOUTOS_CONFIG_MAPPER" || \
                panic "BeoutOS: Cannot open encrypted config partition"
            fi

            mount /dev/mapper/"$BEOUTOS_CONFIG_MAPPER" "$BEOUTOS_CONFIG_MOUNT" || \
            panic "BeoutOS: Cannot mount config partition"
        else
            panic "BeoutOS: Config partition is not a LUKS device"
        fi
    else
        panic "BeoutOS: Config partition not found"
    fi
}

setup_overlays() {
    mkdir -p "$BEOUTOS_OVERLAY_WORK/etc"
    mkdir -p "$BEOUTOS_OVERLAY_WORK/var"
    mkdir -p "$BEOUTOS_OVERLAY_WORK/opt"
    mkdir -p "$BEOUTOS_OVERLAY_WORK/root"
    mkdir -p "$BEOUTOS_OVERLAY_WORK/home"

    mount -t overlay overlay-etc \
        -o "lowerdir=${BEOUTOS_SQUASHFS_ROOT}/etc,upperdir=${BEOUTOS_OVERLAY_UPPER}/etc,workdir=${BEOUTOS_OVERLAY_WORK}/etc" \
        /etc 2>/dev/null || panic "BeoutOS: Cannot mount /etc overlay"

    mount -t overlay overlay-var \
        -o "lowerdir=${BEOUTOS_SQUASHFS_ROOT}/var,upperdir=${BEOUTOS_OVERLAY_UPPER}/var,workdir=${BEOUTOS_OVERLAY_WORK}/var" \
        /var 2>/dev/null || panic "BeoutOS: Cannot mount /var overlay"
}

mount_squashfs_root
open_luks
setup_overlays
OVERLAYSCRIPT

    chmod 755 "${initrd_overlay_hook}/horus-overlay"

    cat > "${initrd_overlay_hook}/horus-overlay.conf" << 'OVERLAYCONF'
horus_overlay
OVERLAYCONF

    echo -e "${GREEN}${BOLD}[OK]${NC} OverlayFS configuration written to boot partition."

    sync
    umount "$boot_mount"

    echo -e "${GREEN}${BOLD}[OK]${NC} OverlayFS configuration complete."
}

horus_overlay_cleanup() {
    echo -e "${CYAN}${BOLD}[STEP]${NC} Cleaning up OverlayFS mounts..."

    for overlay in overlay-etc overlay-var overlay-opt overlay-root overlay-home; do
        if mountpoint -q "/${overlay}" 2>/dev/null; then
            umount "/${overlay}" 2>/dev/null || true
        fi
    done

    if mountpoint -q "$BEOUTOS_SQUASHFS_ROOT" 2>/dev/null; then
        umount "$BEOUTOS_SQUASHFS_ROOT" 2>/dev/null || true
    fi

    if mountpoint -q "$BEOUTOS_OVERLAY_CONFIG_MOUNT" 2>/dev/null; then
        umount "$BEOUTOS_OVERLAY_CONFIG_MOUNT" 2>/dev/null || true
    fi

    echo -e "${GREEN}${BOLD}[OK]${NC} OverlayFS cleanup complete."
}
