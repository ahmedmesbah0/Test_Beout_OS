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

SOURCE_DIR="${PROJECT_DIR}/live-build/chroot/"
OUTPUT_FILE="${PROJECT_DIR}/build/horus-rootfs.squashfs"
COMPRESS_TYPE="xz"
DO_VERIFY=false

log_info()    { echo -e "${BLUE}[INFO]${NC}    $*"; }
log_success() { echo -e "${GREEN}[PASS]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}    $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC}   $*"; }

usage() {
    cat <<EOF
BeoutOS SquashFS Creation Utility

Usage: $0 [OPTIONS]

Options:
  --source DIR     Source chroot directory (default: live-build/chroot/)
  --output FILE    Output SquashFS file (default: build/horus-rootfs.squashfs)
  --compress TYPE  Compression type: xz or zstd (default: xz)
  --verify         Verify the created SquashFS image
  --help           Show this help message

EOF
    exit 0
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --source)
                SOURCE_DIR="$2"
                shift 2
                ;;
            --output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            --compress)
                COMPRESS_TYPE="$2"
                shift 2
                ;;
            --verify)
                DO_VERIFY=true
                shift
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

    if [[ "${COMPRESS_TYPE}" != "xz" && "${COMPRESS_TYPE}" != "zstd" ]]; then
        log_error "Invalid compression type: ${COMPRESS_TYPE}. Must be xz or zstd."
        exit 1
    fi
}

MOUNT_POINT=""
cleanup() {
    local exit_code=$?
    if [[ -n "${MOUNT_POINT}" ]]; then
        log_info "Unmounting verification mount at ${MOUNT_POINT}"
        mountpoint -q "${MOUNT_POINT}" && umount "${MOUNT_POINT}" || true
        rm -rf "${MOUNT_POINT}" || true
    fi
    if [[ ${exit_code} -ne 0 ]]; then
        log_error "SquashFS creation failed (exit code: ${exit_code})"
        if [[ -f "${OUTPUT_FILE}" ]]; then
            log_warn "Removing incomplete image: ${OUTPUT_FILE}"
            rm -f "${OUTPUT_FILE}"
        fi
    fi
    exit ${exit_code}
}
trap cleanup EXIT

check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v mksquashfs &>/dev/null; then
        log_error "mksquashfs not found. Install squashfs-tools."
        exit 1
    fi

    if [[ ! -d "${SOURCE_DIR}" ]]; then
        log_error "Source directory not found: ${SOURCE_DIR}"
        exit 1
    fi

    if [[ ! -f "${SOURCE_DIR}/usr/bin/horus-cli" ]]; then
        log_warn "horus-cli not found in chroot — image may be incomplete"
    fi

    local output_dir
    output_dir="$(dirname "${OUTPUT_FILE}")"
    mkdir -p "${output_dir}"

    log_success "Prerequisites satisfied"
}

create_squashfs() {
    log_info "Creating SquashFS image..."
    log_info "  Source:      ${SOURCE_DIR}"
    log_info "  Output:      ${OUTPUT_FILE}"
    log_info "  Compression: ${COMPRESS_TYPE}"

    local compress_opts=""
    if [[ "${COMPRESS_TYPE}" == "xz" ]]; then
        compress_opts="-comp xz -Xbcj x86"
    elif [[ "${COMPRESS_TYPE}" == "zstd" ]]; then
        compress_opts="-comp zstd -Xcompression-level 19"
    fi

    local exclude_dirs="/var/cache,/var/log,/tmp,/proc,/sys,/dev,/run"

    if [[ -f "${OUTPUT_FILE}" ]]; then
        log_warn "Removing existing image: ${OUTPUT_FILE}"
        rm -f "${OUTPUT_FILE}"
    fi

    mksquashfs "${SOURCE_DIR}" "${OUTPUT_FILE}" \
        ${compress_opts} \
        -b 1M \
        -no-progress \
        -no-xattrs \
        -all-root \
        -e ${exclude_dirs}

    if [[ ! -f "${OUTPUT_FILE}" ]]; then
        log_error "SquashFS image was not created"
        exit 1
    fi

    local image_size
    image_size="$(du -h "${OUTPUT_FILE}" | cut -f1)"
    log_success "SquashFS image created (${image_size})"
}

verify_image() {
    if [[ "${DO_VERIFY}" != "true" ]]; then
        log_info "Verification skipped (use --verify to enable)"
        return 0
    fi

    log_info "Verifying SquashFS image..."

    MOUNT_POINT="$(mktemp -d /tmp/horus-squashfs-verify.XXXXXX)"

    log_info "Mounting image to ${MOUNT_POINT}"
    mount -t squashfs -o ro "${OUTPUT_FILE}" "${MOUNT_POINT}"

    local verify_pass=true

    log_info "Checking /usr/bin/horus-cli..."
    if [[ -f "${MOUNT_POINT}/usr/bin/horus-cli" ]]; then
        log_success "  /usr/bin/horus-cli found"
    else
        log_error "  /usr/bin/horus-cli NOT found"
        verify_pass=false
    fi

    log_info "Checking /usr/bin/horus-provisioning..."
    if [[ -f "${MOUNT_POINT}/usr/bin/horus-provisioning" ]]; then
        log_success "  /usr/bin/horus-provisioning found"
    else
        log_error "  /usr/bin/horus-provisioning NOT found"
        verify_pass=false
    fi

    log_info "Checking /etc/horus/horus.conf..."
    if [[ -f "${MOUNT_POINT}/etc/horus/horus.conf" ]]; then
        log_success "  /etc/horus/horus.conf found"
    else
        log_error "  /etc/horus/horus.conf NOT found"
        verify_pass=false
    fi

    log_info "Unmounting verification mount"
    umount "${MOUNT_POINT}"
    rm -rf "${MOUNT_POINT}"
    MOUNT_POINT=""

    if [[ "${verify_pass}" != "true" ]]; then
        log_error "SquashFS verification FAILED — required files missing"
        exit 1
    fi

    log_success "SquashFS verification passed"

    log_info "SHA256 checksum:"
    sha256sum "${OUTPUT_FILE}"
}

main() {
    parse_args "$@"
    check_prerequisites
    create_squashfs
    verify_image

    log_success "SquashFS creation complete: ${OUTPUT_FILE}"
}

main "$@"
