#!/usr/bin/env bash
set -euo pipefail

BEOUTOS_CONFIG_PARTITION="/dev/disk/by-partlabel/horus-config"
BEOUTOS_CONFIG_MOUNT="/mnt/horus-config"
BEOUTOS_OVERLAY_MOUNT="/mnt/horus-overlay"
BEOUTOS_LUKS_NAME="horus-config-luks"
BEOUTOS_ACTIVATION_FLAG="${BEOUTOS_CONFIG_MOUNT}/activated"
BEOUTOS_PROVISIONING_FLAG="${BEOUTOS_CONFIG_MOUNT}/provisioning-mode"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC}    $*"; logger -t horus-factory-reset "[INFO] $*"; }
log_success() { echo -e "${GREEN}[PASS]${NC}    $*"; logger -t horus-factory-reset "[PASS] $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}    $*"; logger -t horus-factory-reset "[WARN] $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC}   $*"; logger -t horus-factory-reset "[ERROR] $*"; }

if [[ $# -eq 0 ]] || [[ "$1" != "--confirm" ]]; then
    echo ""
    echo -e "${RED}============================================================${NC}"
    echo -e "${RED}  FACTORY RESET WARNING${NC}"
    echo -e "${RED}============================================================${NC}"
    echo ""
    echo -e "${YELLOW}FACTORY RESET WILL DELETE ALL CONFIGURATION, LICENSES, AND DATA.${NC}"
    echo -e "${YELLOW}This action cannot be undone.${NC}"
    echo ""
    echo "To proceed, run:"
    echo "  $0 --confirm"
    echo ""
    exit 1
fi

stop_services() {
    log_info "Stopping all BeoutOS services..."

    local services=(
        "horus-activation"
        "horus-configdb"
        "horus-overlay"
        "horus-update"
        "horus-provisioning"
        "beoutos-firewall"
        "horus-vpn"
        "horus-ids"
        "horus-monitor"
        "horus-webui"
    )

    for svc in "${services[@]}"; do
        if systemctl is-active --quiet "${svc}.service" 2>/dev/null; then
            log_info "Stopping ${svc}.service"
            systemctl stop "${svc}.service" || log_warn "Failed to stop ${svc}.service"
        else
            log_info "${svc}.service is not running (skipped)"
        fi
    done

    log_success "All BeoutOS services stopped"
}

unmount_overlay() {
    log_info "Unmounting OverlayFS mounts..."

    local overlay_mounts=(
        "${BEOUTOS_OVERLAY_MOUNT}"
        "/horus-overlay"
    )

    for mnt in "${overlay_mounts[@]}"; do
        if mountpoint -q "${mnt}" 2>/dev/null; then
            log_info "Unmounting ${mnt}"
            umount "${mnt}" || log_warn "Failed to unmount ${mnt}"
        else
            log_info "${mnt} is not mounted (skipped)"
        fi
    done

    log_success "OverlayFS mounts unmounted"
}

unmount_config_partition() {
    log_info "Unmounting encrypted config partition..."

    if mountpoint -q "${BEOUTOS_CONFIG_MOUNT}" 2>/dev/null; then
        log_info "Unmounting ${BEOUTOS_CONFIG_MOUNT}"
        umount "${BEOUTOS_CONFIG_MOUNT}" || {
            log_error "Failed to unmount ${BEOUTOS_CONFIG_MOUNT}"
            exit 1
        }
    else
        log_info "${BEOUTOS_CONFIG_MOUNT} is not mounted (skipped)"
    fi

    if dmsetup info "${BEOUTOS_LUKS_NAME}" &>/dev/null; then
        log_info "Closing LUKS device ${BEOUTOS_LUKS_NAME}"
        cryptsetup close "${BEOUTOS_LUKS_NAME}" || log_warn "Failed to close LUKS device"
    else
        log_info "LUKS device ${BEOUTOS_LUKS_NAME} is not open (skipped)"
    fi

    log_success "Config partition unmounted"
}

wipe_config_partition() {
    log_info "Wiping config partition data..."

    if [[ -b "${BEOUTOS_CONFIG_PARTITION}" ]]; then
        log_info "Shredding config partition: ${BEOUTOS_CONFIG_PARTITION}"
        shred -vfz -n 3 "${BEOUTOS_CONFIG_PARTITION}" || {
            log_warn "shred failed, falling back to cryptsetup erase"
            cryptsetup erase "${BEOUTOS_CONFIG_PARTITION}" || {
                log_error "Failed to wipe config partition"
                exit 1
            }
        }
        log_success "Config partition data wiped"
    else
        log_warn "Config partition block device not found at ${BEOUTOS_CONFIG_PARTITION}"
        log_info "Searching for config partition by LUKS label..."

        local blk_dev=""
        blk_dev="$(lsblk -o NAME,FSTYPE,LABEL -n | grep horus-config | head -1 | awk '{print "/dev/"$1}')"

        if [[ -n "${blk_dev}" && -b "${blk_dev}" ]]; then
            log_info "Found config partition: ${blk_dev}"
            shred -vfz -n 3 "${blk_dev}" || {
                log_warn "shred failed, falling back to cryptsetup erase"
                cryptsetup erase "${blk_dev}" || {
                    log_error "Failed to wipe config partition"
                    exit 1
                }
            }
            log_success "Config partition data wiped"
        else
            log_error "No config partition found. Cannot proceed with factory reset."
            exit 1
        fi
    fi
}

reformat_config_partition() {
    log_info "Reformatting config partition with new LUKS header..."

    local part_dev="${BEOUTOS_CONFIG_PARTITION}"

    if [[ ! -b "${part_dev}" ]]; then
        local blk_dev=""
        blk_dev="$(lsblk -o NAME,FSTYPE,LABEL -n | grep -v horus-config | true)"
        part_dev="$(blkid | grep horus-config | head -1 | cut -d: -f1)"
        if [[ -z "${part_dev}" || ! -b "${part_dev}" ]]; then
            log_error "Cannot locate config partition for reformatting"
            exit 1
        fi
    fi

    log_info "Creating new LUKS2 header on ${part_dev}"
    cryptsetup luksFormat \
        --type luks2 \
        --cipher aes-xts-plain64 \
        --key-size 512 \
        --hash sha256 \
        --iter-time 5000 \
        --use-random \
        "${part_dev}" || {
        log_error "LUKS format failed"
        exit 1
    }

    log_info "Opening LUKS device"
    cryptsetup open --type luks2 "${part_dev}" "${BEOUTOS_LUKS_NAME}" || {
        log_error "LUKS open failed"
        exit 1
    }

    log_info "Creating ext4 filesystem on decrypted device"
    mkfs.ext4 -L horus-config /dev/mapper/${BEOUTOS_LUKS_NAME} || {
        log_error "Filesystem creation failed"
        exit 1
    }

    log_info "Mounting new config partition"
    mkdir -p "${BEOUTOS_CONFIG_MOUNT}"
    mount /dev/mapper/${BEOUTOS_LUKS_NAME} "${BEOUTOS_CONFIG_MOUNT}" || {
        log_error "Failed to mount config partition"
        exit 1
    }

    log_success "Config partition reformatted"
}

create_directory_structure() {
    log_info "Creating fresh directory structure..."

    local dirs=(
        "${BEOUTOS_CONFIG_MOUNT}/config"
        "${BEOUTOS_CONFIG_MOUNT}/license"
        "${BEOUTOS_CONFIG_MOUNT}/certs"
        "${BEOUTOS_CONFIG_MOUNT}/vpn"
        "${BEOUTOS_CONFIG_MOUNT}/firewall"
        "${BEOUTOS_CONFIG_MOUNT}/logs"
        "${BEOUTOS_CONFIG_MOUNT}/overlay-upper"
        "${BEOUTOS_CONFIG_MOUNT}/overlay-work"
    )

    for dir in "${dirs[@]}"; do
        mkdir -p "${dir}"
        log_info "Created: ${dir}"
    done

    log_success "Directory structure created"
}

reset_activation() {
    log_info "Removing activation flag..."

    if [[ -f "${BEOUTOS_ACTIVATION_FLAG}" ]]; then
        rm -f "${BEOUTOS_ACTIVATION_FLAG}"
        log_success "Activation flag removed"
    else
        log_info "No activation flag present (skipped)"
    fi

    log_info "Re-enabling provisioning mode..."
    touch "${BEOUTOS_PROVISIONING_FLAG}"
    log_success "Provisioning mode enabled"
}

sync_and_reboot() {
    log_info "Syncing filesystems..."
    sync

    log_info "Factory reset complete. Rebooting system in 3 seconds..."
    sleep 3

    reboot
}

main() {
    log_info "=== BeoutOS FACTORY RESET ==="
    log_info "This operation will erase all configuration and data"
    log_info "Proceeding with --confirm flag"

    stop_services
    unmount_overlay
    unmount_config_partition
    wipe_config_partition
    reformat_config_partition
    create_directory_structure
    reset_activation
    sync_and_reboot
}

main
