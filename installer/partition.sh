#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

MIN_DISK_SIZE_BYTES=4294967296

horus_create_partitions() {
    local disk="$1"
    local efi_part="$2"
    local boot_part="$3"
    local roota_part="$4"
    local rootb_part="$5"
    local config_part="$6"

    echo -e "${CYAN}${BOLD}[STEP]${NC} Creating GPT partition table on ${disk}..."

    local disk_size_bytes
    disk_size_bytes=$(blockdev --getsize64 "$disk" 2>/dev/null || echo 0)

    if [[ "$disk_size_bytes" -lt "$MIN_DISK_SIZE_BYTES" ]]; then
        local disk_size_gb
        disk_size_gb=$(echo "scale=1; $disk_size_bytes / 1073741824" | bc 2>/dev/null || echo 0)
        echo -e "${RED}${BOLD}[ERROR]${NC} Disk too small: ${disk_size_gb}GB. Minimum requirement is 4GB."
        return 1
    fi

    wipefs -a "$disk" 2>/dev/null || true
    sgdisk --zap-all "$disk" 2>/dev/null || true
    dd if=/dev/zero of="$disk" bs=1M count=1 conv=notrunc 2>/dev/null || true
    sync

    parted -s "$disk" mklabel gpt

    parted -s "$disk" mkpart EFI primary 1MiB 513MiB
    parted -s "$disk" set 1 esp on
    parted -s "$disk" set 1 boot on

    parted -s "$disk" mkpart BOOT primary 513MiB 769MiB

    local roota_start="769MiB"
    local roota_end="2817MiB"
    parted -s "$disk" mkpart ROOTA primary "$roota_start" "$roota_end"

    local rootb_start="2817MiB"
    local rootb_end="4865MiB"
    parted -s "$disk" mkpart ROOTB primary "$rootb_start" "$rootb_end"

    local config_start="4865MiB"
    parted -s "$disk" mkpart CONFIG primary "$config_start" 100%

    parted -s "$disk" name 1 "BEOUTOS-EFI"
    parted -s "$disk" name 2 "BEOUTOS-BOOT"
    parted -s "$disk" name 3 "BEOUTOS-ROOTA"
    parted -s "$disk" name 4 "BEOUTOS-ROOTB"
    parted -s "$disk" name 5 "BEOUTOS-CONFIG"

    parted -s "$disk" set 1 esp on
    parted -s "$disk" set 1 boot on

    sleep 2
    partprobe "$disk" 2>/dev/null || true
    sleep 2
    udevadm settle 2>/dev/null || true

    horus_verify_partitions "$disk" || return 1

    echo -e "${GREEN}${BOLD}[OK]${NC} GPT partition table created successfully."
}

horus_verify_partitions() {
    local disk="$1"

    echo -e "${CYAN}${BOLD}[STEP]${NC} Verifying partition layout..."

    local pt_type
    pt_type=$(blkid -o value -s PTTYPE "$disk" 2>/dev/null || echo "")
    if [[ "$pt_type" != "gpt" ]]; then
        echo -e "${RED}${BOLD}[ERROR]${NC} Partition table is not GPT."
        return 1
    fi

    local num_parts
    num_parts=$(parted -s "$disk" print | grep -c "^ [0-9]" || echo 0)
    if [[ "$num_parts" -lt 5 ]]; then
        echo -e "${RED}${BOLD}[ERROR]${NC} Expected 5 partitions, found ${num_parts}."
        return 1
    fi

    local efi_flag
    efi_flag=$(parted -s "$disk" print | grep "^ 1" | grep -c "esp" || echo 0)
    if [[ "$efi_flag" -eq 0 ]]; then
        echo -e "${RED}${BOLD}[ERROR]${NC} EFI partition ESP flag not set."
        return 1
    fi

    local boot_flag
    boot_flag=$(parted -s "$disk" print | grep "^ 1" | grep -c "boot" || echo 0)
    if [[ "$boot_flag" -eq 0 ]]; then
        echo -e "${RED}${BOLD}[ERROR]${NC} EFI partition boot flag not set."
        return 1
    fi

    local p3_name
    p3_name=$(parted -s "$disk" print | grep "^ 3" | awk '{print $6}' || echo "")
    if [[ "$p3_name" != "BEOUTOS-ROOTA" ]]; then
        echo -e "${RED}${BOLD}[ERROR]${NC} Root A partition name mismatch."
        return 1
    fi

    local p4_name
    p4_name=$(parted -s "$disk" print | grep "^ 4" | awk '{print $6}' || echo "")
    if [[ "$p4_name" != "BEOUTOS-ROOTB" ]]; then
        echo -e "${RED}${BOLD}[ERROR]${NC} Root B partition name mismatch."
        return 1
    fi

    local p5_name
    p5_name=$(parted -s "$disk" print | grep "^ 5" | awk '{print $6}' || echo "")
    if [[ "$p5_name" != "BEOUTOS-CONFIG" ]]; then
        echo -e "${RED}${BOLD}[ERROR]${NC} Config partition name mismatch."
        return 1
    fi

    echo -e "${GREEN}${BOLD}[OK]${NC} Partition verification passed."
    return 0
}

horus_format_partitions() {
    local efi_part="$1"
    local boot_part="$2"
    local roota_part="$3"
    local rootb_part="$4"

    echo -e "${CYAN}${BOLD}[STEP]${NC} Formatting partitions..."

    sleep 2
    udevadm settle 2>/dev/null || true

    mkfs.vfat -F 32 -n BEOUTOS-EFI "$efi_part"
    mkfs.ext4 -L BEOUTOS-BOOT -q "$boot_part"

    mkfs.ext4 -L BEOUTOS-ROOTA -q "$roota_part"
    mkfs.ext4 -L BEOUTOS-ROOTB -q "$rootb_part"

    echo -e "${GREEN}${BOLD}[OK]${NC} All partitions formatted."
}

horus_setup_luks() {
    local config_part="$1"
    local mapper_name="$2"
    local passphrase="$3"

    echo -e "${CYAN}${BOLD}[STEP]${NC} Setting up LUKS encryption on ${config_part}..."

    sleep 2
    udevadm settle 2>/dev/null || true

    cryptsetup luksFormat \
        --type luks2 \
        --cipher aes-xts-plain64 \
        --key-size 512 \
        --hash sha256 \
        --iter-time 5000 \
        --use-random \
        "$config_part" \
        <<< "$passphrase"

    echo -e "${CYAN}${BOLD}[STEP]${NC} Opening LUKS container..."
    cryptsetup luksOpen "$config_part" "$mapper_name" <<< "$passphrase"

    echo -e "${CYAN}${BOLD}[STEP]${NC} Formatting LUKS decrypted volume..."
    mkfs.ext4 -L BEOUTOS-CONFIG-DATA -q "/dev/mapper/${mapper_name}"

    echo -e "${GREEN}${BOLD}[OK]${NC} LUKS encryption configured."
}

horus_close_luks() {
    local mapper_name="$1"

    if dmsetup info "$mapper_name" &>/dev/null; then
        dmsetup remove "$mapper_name" 2>/dev/null || true
    fi
}

horus_resize_partitions() {
    local disk="$1"
    local disk_size_bytes
    disk_size_bytes=$(blockdev --getsize64 "$disk" 2>/dev/null || echo 0)
    local disk_size_mb
    disk_size_mb=$(echo "scale=0; $disk_size_bytes / 1048576" | bc 2>/dev/null || echo 0)

    local roota_size_mb=2048
    local rootb_size_mb=2048

    if [[ "$disk_size_mb" -gt 32768 ]]; then
        roota_size_mb=4096
        rootb_size_mb=4096
    elif [[ "$disk_size_mb" -gt 16384 ]]; then
        roota_size_mb=3072
        rootb_size_mb=3072
    fi

    echo "$roota_size_mb $rootb_size_mb"
}
