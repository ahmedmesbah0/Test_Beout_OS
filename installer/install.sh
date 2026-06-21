#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

BEOUTOS_VERSION="1.0.0"
INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/horus-install.log"
TARGET_DISK=""
ROOTA_PART=""
ROOTB_PART=""
EFI_PART=""
BOOT_PART=""
CONFIG_PART=""
CONFIG_MAPPER="horus-config"
LUKS_PASSPHRASE=""
ABOVE_THRESHOLD=""

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$LOG_FILE"
}

print_banner() {
    echo ""
    echo "${CYAN}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
    echo "${CYAN}${BOLD}║                                                  ║${NC}"
    echo "${CYAN}${BOLD}║          BeoutOS Installer      ║${NC}"
    echo "${CYAN}${BOLD}║                  Version ${BEOUTOS_VERSION}                    ║${NC}"
    echo "${CYAN}${BOLD}║                                                  ║${NC}"
    echo "${CYAN}${BOLD}║    Commercial-Grade Network Security Platform    ║${NC}"
    echo "${CYAN}${BOLD}║                                                  ║${NC}"
    echo "${CYAN}${BOLD}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_error() {
    echo "${RED}${BOLD}[ERROR]${NC} $*"
    log "ERROR: $*"
}

print_success() {
    echo "${GREEN}${BOLD}[OK]${NC} $*"
    log "OK: $*"
}

print_info() {
    echo "${BLUE}${BOLD}[INFO]${NC} $*"
    log "INFO: $*"
}

print_warning() {
    echo "${YELLOW}${BOLD}[WARN]${NC} $*"
    log "WARN: $*"
}

print_step() {
    echo "${CYAN}${BOLD}[STEP]${NC} $*"
    log "STEP: $*"
}

detect_disks() {
    print_step "Detecting available disks..."
    local disks=()
    local disk_info=()

    for dev in /dev/sd* /dev/vd* /dev/nvme*n1; do
        if [[ -b "$dev" ]] && [[ ! "$dev" =~ [0-9]$ ]]; then
            local size_bytes
            size_bytes=$(blockdev --getsize64 "$dev" 2>/dev/null || echo 0)
            local size_gb
            size_gb=$(echo "scale=1; $size_bytes / 1073741824" | bc 2>/dev/null || echo "0")
            local model
            model=$(lsblk -dn -o MODEL "$dev" 2>/dev/null || echo "Unknown")
            local transport
            transport=$(lsblk -dn -o TRAN "$dev" 2>/dev/null || echo "unknown")
            disks+=("$dev")
            disk_info+=("${dev} - ${size_gb}GB - ${model} (${transport})")
        fi
    done

    if [[ ${#disks[@]} -eq 0 ]]; then
        print_error "No disks found. Cannot continue installation."
        exit 1
    fi

    echo ""
    echo "${BOLD}Available disks:${NC}"
    echo ""
    local i=1
    for info in "${disk_info[@]}"; do
        echo "  ${BOLD}${i}.${NC} ${info}"
        i=$((i + 1))
    done
    echo ""

    MIN_DISK_SIZE_GB=4

    for d in "${disks[@]}"; do
        local size_bytes
        size_bytes=$(blockdev --getsize64 "$d" 2>/dev/null || echo 0)
        local size_gb_int
        size_gb_int=$(echo "scale=0; $size_bytes / 1073741824" | bc 2>/dev/null || echo 0)
        if [[ $size_gb_int -ge $MIN_DISK_SIZE_GB ]]; then
            ABOVE_THRESHOLD="$d"
        fi
    done

    if [[ ${#disks[@]} -eq 1 ]] && [[ -n "$ABOVE_THRESHOLD" ]]; then
        TARGET_DISK="${disks[0]}"
        print_info "Auto-detected single disk: ${TARGET_DISK}"
        return 0
    fi

    echo "${BOLD}Select target disk (1-${#disks[@]}):${NC} "
    local choice
    read -r choice

    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt ${#disks[@]} ]]; then
        print_error "Invalid selection."
        exit 1
    fi

    TARGET_DISK="${disks[$((choice - 1))]}"
    print_info "Selected disk: ${TARGET_DISK}"
}

confirm_install() {
    local disk_size
    disk_size=$(lsblk -dn -o SIZE "$TARGET_DISK" 2>/dev/null || echo "unknown")
    local disk_model
    disk_model=$(lsblk -dn -o MODEL "$TARGET_DISK" 2>/dev/null || echo "Unknown")

    echo ""
    echo "${RED}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
    echo "${RED}${BOLD}║               !! WARNING !!                      ║${NC}"
    echo "${RED}${BOLD}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "${RED}${BOLD}This will DESTROY ALL DATA on:${NC}"
    echo "${RED}${BOLD}  Disk: ${TARGET_DISK}${NC}"
    echo "${RED}${BOLD}  Size: ${disk_size}${NC}"
    echo "${RED}${BOLD}  Model: ${disk_model}${NC}"
    echo ""
    echo "${YELLOW}The following partition layout will be created:${NC}"
    echo "  Partition 1: EFI System Partition  (512MB, FAT32)"
    echo "  Partition 2: Boot Partition         (256MB, ext4)"
    echo "  Partition 3: Root A (SquashFS)      (~2GB)"
    echo "  Partition 4: Root B (SquashFS)      (~2GB)  [A/B updates]"
    echo "  Partition 5: Config (LUKS encrypted)(remaining space)"
    echo ""
    echo "${RED}${BOLD}This operation is IRREVERSIBLE. All existing data will be lost.${NC}"
    echo ""
    echo "${BOLD}Type 'INSTALL' to confirm, or anything else to cancel:${NC} "
    local confirm
    read -r confirm

    if [[ "$confirm" != "INSTALL" ]]; then
        print_info "Installation cancelled by user."
        exit 0
    fi
}

set_luks_passphrase() {
    echo ""
    echo "${BOLD}Set encryption passphrase for config partition:${NC}"
    echo "${YELLOW}This passphrase protects all configuration, licenses, and certificates.${NC}"
    echo "${YELLOW}You will need this passphrase if the TPM is unavailable.${NC}"
    echo ""

    while true; do
        echo "${BOLD}Enter passphrase:${NC} "
        read -rs LUKS_PASSPHRASE
        echo ""
        if [[ -z "$LUKS_PASSPHRASE" ]]; then
            print_error "Passphrase cannot be empty."
            continue
        fi
        if [[ ${#LUKS_PASSPHRASE} -lt 8 ]]; then
            print_error "Passphrase must be at least 8 characters."
            continue
        fi
        echo "${BOLD}Confirm passphrase:${NC} "
        local confirm_pass
        read -rs confirm_pass
        echo ""
        if [[ "$LUKS_PASSPHRASE" != "$confirm_pass" ]]; then
            print_error "Passphrases do not match. Try again."
            continue
        fi
        print_success "Passphrase accepted."
        break
    done
}

source_components() {
    print_step "Loading installer components..."
    source "${INSTALLER_DIR}/partition.sh"
    source "${INSTALLER_DIR}/squashfs.sh"
    source "${INSTALLER_DIR}/overlay.sh"
    source "${INSTALLER_DIR}/bootloader.sh"
    source "${INSTALLER_DIR}/config_partition.sh"
    print_success "All components loaded."
}

check_prerequisites() {
    print_step "Checking prerequisites..."

    local required_cmds=(
        parted mkfs.vfat mkfs.ext4 cryptsetup grub-install
        mksquashfs unsquashfs mount umount mkdir cp
        bc lsblk blockdev sgdisk dmsetup modprobe
    )

    for cmd in "${required_cmds[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            print_error "Required command '${cmd}' not found."
            exit 1
        fi
    done

    modprobe overlay 2>/dev/null || true
    if ! grep -q overlay /proc/filesystems; then
        print_error "OverlayFS kernel support not available."
        exit 1
    fi

    modprobe squashfs 2>/dev/null || true
    if ! grep -q squashfs /proc/filesystems; then
        print_error "SquashFS kernel support not available."
        exit 1
    fi

    if [[ ! -f /live/system.squashfs ]]; then
        print_error "SquashFS image not found at /live/system.squashfs"
        exit 1
    fi

    local sq_size
    sq_size=$(stat -c%s /live/system.squashfs 2>/dev/null || echo 0)
    local sq_gb
    sq_gb=$(echo "scale=2; $sq_size / 1073741824" | bc 2>/dev/null || echo 0)
    print_info "SquashFS image size: ${sq_gb}GB"

    print_success "All prerequisites met."
}

find_partitions() {
    local disk_base
    disk_base="${TARGET_DISK}"
    if [[ "$TARGET_DISK" =~ nvme ]]; then
        EFI_PART="${disk_base}p1"
        BOOT_PART="${disk_base}p2"
        ROOTA_PART="${disk_base}p3"
        ROOTB_PART="${disk_base}p4"
        CONFIG_PART="${disk_base}p5"
    else
        EFI_PART="${disk_base}1"
        BOOT_PART="${disk_base}2"
        ROOTA_PART="${disk_base}3"
        ROOTB_PART="${disk_base}4"
        CONFIG_PART="${disk_base}5"
    fi
}

install_system() {
    print_step "Starting BeoutOS installation..."
    echo ""

    check_prerequisites

    detect_disks
    confirm_install
    set_luks_passphrase

    find_partitions

    print_step "Partitioning disk ${TARGET_DISK}..."
    horus_create_partitions "$TARGET_DISK" "$EFI_PART" "$BOOT_PART" "$ROOTA_PART" "$ROOTB_PART" "$CONFIG_PART"
    print_success "Partitioning complete."

    print_step "Formatting partitions..."
    horus_format_partitions "$EFI_PART" "$BOOT_PART" "$ROOTA_PART" "$ROOTB_PART"
    print_success "Partition formatting complete."

    print_step "Setting up LUKS encryption on config partition..."
    horus_setup_luks "$CONFIG_PART" "$CONFIG_MAPPER" "$LUKS_PASSPHRASE"
    print_success "LUKS encryption configured."

    print_step "Writing SquashFS image to Root A partition..."
    horus_write_squashfs_to_partition /live/system.squashfs "$ROOTA_PART"
    print_success "SquashFS image written to Root A."

    print_step "Configuring config partition directory structure..."
    horus_setup_config_dirs "/dev/mapper/${CONFIG_MAPPER}"
    print_success "Config directory structure created."

    print_step "Installing bootloader (GRUB2 UEFI)..."
    horus_install_bootloader "$TARGET_DISK" "$EFI_PART" "$BOOT_PART" "$ROOTA_PART" "$ROOTB_PART"
    print_success "Bootloader installed."

    print_step "Generating initramfs with OverlayFS support..."
    horus_generate_initrd "$BOOT_PART" "$ROOTA_PART" "$CONFIG_MAPPER"
    print_success "Initramfs generated."

    print_step "Configuring OverlayFS mounts..."
    horus_configure_overlay "$BOOT_PART" "$CONFIG_MAPPER"
    print_success "OverlayFS configured."

    print_step "Verifying installation integrity..."
    horus_verify_installation "$TARGET_DISK" "$EFI_PART" "$BOOT_PART" "$ROOTA_PART" "$CONFIG_MAPPER"
    print_success "Installation integrity verified."

    print_step "Creating activation flag structure..."
    horus_create_activation_structure "/dev/mapper/${CONFIG_MAPPER}"
    print_success "Activation flag structure created."
}

cleanup() {
    print_step "Cleaning up mount points..."
    for mp in /mnt/horus-boot /mnt/horus-roota /mnt/horus-rootb /mnt/horus-config /mnt/horus-efi; do
        if mountpoint -q "$mp" 2>/dev/null; then
            umount "$mp" 2>/dev/null || true
        fi
    done
    if dmsetup info "$CONFIG_MAPPER" &>/dev/null; then
        dmsetup remove "$CONFIG_MAPPER" 2>/dev/null || true
    fi
    print_success "Cleanup complete."
}

main() {
    trap cleanup EXIT
    trap 'print_error "Installation interrupted. Cleaning up..."; exit 130' INT TERM

    print_banner

    log "BeoutOS Installer v${BEOUTOS_VERSION} started"

    install_system

    echo ""
    echo "${GREEN}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
    echo "${GREEN}${BOLD}║                                                  ║${NC}"
    echo "${GREEN}${BOLD}║        BeoutOS Installation Complete!              ║${NC}"
    echo "${GREEN}${BOLD}║                                                  ║${NC}"
    echo "${GREEN}${BOLD}║  The appliance will boot into provisioning mode  ║${NC}"
    echo "${GREEN}${BOLD}║  on first startup.                               ║${NC}"
    echo "${GREEN}${BOLD}║                                                  ║${NC}"
    echo "${GREEN}${BOLD}║  Press ENTER to reboot, or power off manually.   ║${NC}"
    echo "${GREEN}${BOLD}║                                                  ║${NC}"
    echo "${GREEN}${BOLD}╚══════════════════════════════════════════════════╝${NC}"
    echo ""

    read -r
    sync
    reboot
}

main "$@"
