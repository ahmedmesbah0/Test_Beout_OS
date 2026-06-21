#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_FILE="${PROJECT_DIR}/config/global.conf"

if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "ERROR: Configuration file not found: ${CONFIG_FILE}"
    exit 1
fi

source "${CONFIG_FILE}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SQUASHFS_PATH="${PROJECT_DIR}/build/horus-rootfs.squashfs"
ISO_OUTPUT="${PROJECT_DIR}/build/${BEOUTOS_PRODUCT}-${BEOUTOS_VERSION}-${BEOUTOS_CODENAME}.iso"
ISO_LABEL="${ISO_VOLUME_ID}"

log_info()    { echo -e "${BLUE}[INFO]${NC}    $*"; }
log_success() { echo -e "${GREEN}[PASS]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}    $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC}   $*"; }

usage() {
    cat <<EOF
BeoutOS ISO Creation Utility

Usage: $0 [OPTIONS]

Options:
  --squashfs FILE  SquashFS rootfs image path (default: build/horus-rootfs.squashfs)
  --output FILE    Output ISO file path (default: build/<product-version>.iso)
  --label STRING   ISO volume ID / label (default: from global.conf)
  --help           Show this help message

EOF
    exit 0
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --squashfs)
                SQUASHFS_PATH="$2"
                shift 2
                ;;
            --output)
                ISO_OUTPUT="$2"
                shift 2
                ;;
            --label)
                ISO_LABEL="$2"
                shift 2
                ;;
            --help|-h)
                usage
                ;;
            *)
                log_error "Unknown argument: $1"
                exit 1
                ;;
        esac
    done
}

ISO_WORK_DIR=""
cleanup() {
    local exit_code=$?
    if [[ -n "${ISO_WORK_DIR}" && -d "${ISO_WORK_DIR}" ]]; then
        log_info "Cleaning up ISO work directory: ${ISO_WORK_DIR}"
        rm -rf "${ISO_WORK_DIR}" || true
    fi
    if [[ ${exit_code} -ne 0 ]]; then
        log_error "ISO creation failed (exit code: ${exit_code})"
        if [[ -f "${ISO_OUTPUT}" ]]; then
            log_warn "Removing incomplete ISO: ${ISO_OUTPUT}"
            rm -f "${ISO_OUTPUT}"
        fi
    fi
    exit ${exit_code}
}
trap cleanup EXIT

check_prerequisites() {
    log_info "Checking prerequisites..."

    local missing_cmds=()

    for cmd in xorriso grub-mkimage mksquashfs; do
        if ! command -v "${cmd}" &>/dev/null; then
            missing_cmds+=("${cmd}")
        fi
    done

    if [[ ${#missing_cmds[@]} -gt 0 ]]; then
        log_error "Missing required commands: ${missing_cmds[*]}"
        exit 1
    fi

    if [[ ! -f "${SQUASHFS_PATH}" ]]; then
        log_error "SquashFS image not found: ${SQUASHFS_PATH}"
        log_error "Run create-squashfs.sh first"
        exit 1
    fi

    log_success "Prerequisites satisfied"
}

create_iso_structure() {
    log_info "Creating ISO directory structure..."

    ISO_WORK_DIR="$(mktemp -d /tmp/horus-iso-build.XXXXXX)"

    mkdir -p "${ISO_WORK_DIR}/boot/grub"
    mkdir -p "${ISO_WORK_DIR}/live"
    mkdir -p "${ISO_WORK_DIR}/EFI/BOOT"

    log_info "Copying SquashFS image..."
    cp "${SQUASHFS_PATH}" "${ISO_WORK_DIR}/live/horus-rootfs.squashfs"

    local kernel_src="${PROJECT_DIR}/live-build/chroot/boot/vmlinuz-*"
    local initrd_src="${PROJECT_DIR}/live-build/chroot/boot/initrd.img-*"

    local kernel_found=false
    local initrd_found=false

    for k in ${kernel_src}; do
        if [[ -f "${k}" ]]; then
            cp "${k}" "${ISO_WORK_DIR}/boot/vmlinuz"
            log_success "Kernel copied: ${k}"
            kernel_found=true
            break
        fi
    done

    for i in ${initrd_src}; do
        if [[ -f "${i}" ]]; then
            cp "${i}" "${ISO_WORK_DIR}/boot/initrd.img"
            log_success "Initrd copied: ${i}"
            initrd_found=true
            break
        fi
    done

    if [[ "${kernel_found}" != "true" ]]; then
        log_warn "No kernel found in chroot — ISO may not be bootable"
    fi

    if [[ "${initrd_found}" != "true" ]]; then
        log_warn "No initrd found in chroot — ISO may not be bootable"
    fi

    log_success "ISO directory structure created"
}

create_grub_config() {
    log_info "Creating GRUB configuration..."

    cat > "${ISO_WORK_DIR}/boot/grub/grub.cfg" <<'GRUBEOF'
set timeout=3
set default=0
set pager=1

insmod all_video
insmod gfxterm
set gfxpayload=keep

menuentry "BeoutOS" {
    linux  /boot/vmlinuz boot=live components quiet systemd.unit=beoutos-boot.target ro
    initrd /boot/initrd.img
}

menuentry "BeoutOS Installer (Provisioning Mode)" {
    linux  /boot/vmlinuz boot=live components quiet systemd.unit=beoutos-provisioning.target ro
    initrd /boot/initrd.img
}

set superusers=""
password_pbk2 ""
GRUBEOF

    log_success "GRUB configuration created"
}

generate_efi_boot_image() {
    log_info "Generating EFI boot image..."

    local efi_dir="${ISO_WORK_DIR}/EFI/BOOT"
    local grub_mods="boot linux normal search search_fs_file search_fs_uuid search_label iso9660 fat part_msdos part_gpt gzio xzio lzopio squash4 memdisk all_video gfxterm gfxmenu loadenv echo configfile test true false cat chain reboot halt sleep help read"

    grub-mkimage \
        -O x86_64-efi \
        -o "${efi_dir}/BOOTX64.EFI" \
        -p "/boot/grub" \
        ${grub_mods}

    if [[ ! -f "${efi_dir}/BOOTX64.EFI" ]]; then
        log_error "EFI boot image generation failed"
        exit 1
    fi

    log_success "EFI boot image generated: BOOTX64.EFI ($(du -h "${efi_dir}/BOOTX64.EFI" | cut -f1))"
}

create_iso() {
    log_info "Creating bootable ISO image..."

    local iso_dir="$(dirname "${ISO_OUTPUT}")"
    mkdir -p "${iso_dir}"

    xorriso \
        -as mkisofs \
        -iso_level 3 \
        -full-iso9660-filenames \
        -joliet \
        -joliet-long \
        -rational-rock \
        -volid "${ISO_LABEL}" \
        -publisher "Beout Security Systems" \
        -application "BeoutOS" \
        -graft-points \
        /boot="${ISO_WORK_DIR}/boot" \
        /live="${ISO_WORK_DIR}/live" \
        /EFI="${ISO_WORK_DIR}/EFI" \
        -- \
        -eltorito-alt-boot \
        -e /EFI/BOOT/BOOTX64.EFI \
        -no-emul-boot \
        -isohybrid-gpt-basdat \
        -isohybrid-mbr \
        -partition_offset 16 \
        -append_partition 2 0xef "${ISO_WORK_DIR}/EFI/BOOT/BOOTX64.EFI" \
        -output "${ISO_OUTPUT}"

    if [[ ! -f "${ISO_OUTPUT}" ]]; then
        log_error "ISO image was not created"
        exit 1
    fi

    log_success "ISO image created"
}

verify_iso() {
    log_info "Verifying ISO image..."

    local iso_size
    iso_size="$(du -h "${ISO_OUTPUT}" | cut -f1)"
    log_info "ISO size: ${iso_size}"

    local min_size_mb=50
    local iso_size_bytes
    iso_size_bytes="$(stat -c%s "${ISO_OUTPUT}" 2>/dev/null || stat -f%z "${ISO_OUTPUT}")"
    local iso_size_mb=$((iso_size_bytes / 1024 / 1024))

    if [[ ${iso_size_mb} -lt ${min_size_mb} ]]; then
        log_warn "ISO size (${iso_size_mb}MB) is below expected minimum (${min_size_mb}MB)"
    fi

    log_success "ISO verification passed"

    log_info "SHA256 checksum:"
    sha256sum "${ISO_OUTPUT}"
}

main() {
    parse_args "$@"
    check_prerequisites
    create_iso_structure
    create_grub_config
    generate_efi_boot_image
    create_iso
    verify_iso

    log_success "ISO creation complete: ${ISO_OUTPUT}"
}

main "$@"
