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
NC='\033[0m'

PACKAGE_FILE=""
PRIVATE_KEY=""
OUTPUT_DIR=""
VERIFY_PUBLIC_KEY=""

log_info()    { echo -e "${BLUE}[INFO]${NC}    $*"; }
log_success() { echo -e "${GREEN}[PASS]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}    $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC}   $*"; }

usage() {
    cat <<EOF
BeoutOS Update Signing Utility

Usage: $0 [OPTIONS]

Options:
  --package FILE    Update package file to sign (required)
  --key FILE        Private key path for signing (required)
  --output DIR      Output directory for signed bundle (default: same as package)
  --pubkey FILE     Public key path for verification (optional, derived from key if omitted)
  --help            Show this help message

This tool is for the build pipeline only. It is NOT for end-user use.

EOF
    exit 0
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --package)
                PACKAGE_FILE="$2"
                shift 2
                ;;
            --key)
                PRIVATE_KEY="$2"
                shift 2
                ;;
            --output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            --pubkey)
                VERIFY_PUBLIC_KEY="$2"
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

    if [[ -z "${PACKAGE_FILE}" ]]; then
        log_error "--package is required"
        exit 1
    fi

    if [[ -z "${PRIVATE_KEY}" ]]; then
        log_error "--key is required"
        exit 1
    fi

    if [[ ! -f "${PACKAGE_FILE}" ]]; then
        log_error "Package file not found: ${PACKAGE_FILE}"
        exit 1
    fi

    if [[ ! -f "${PRIVATE_KEY}" ]]; then
        log_error "Private key not found: ${PRIVATE_KEY}"
        exit 1
    fi

    if [[ -z "${OUTPUT_DIR}" ]]; then
        OUTPUT_DIR="$(dirname "${PACKAGE_FILE}")"
    fi

    if [[ -z "${VERIFY_PUBLIC_KEY}" ]]; then
        VERIFY_PUBLIC_KEY="${PRIVATE_KEY%.key}.pub"
        if [[ ! -f "${VERIFY_PUBLIC_KEY}" ]]; then
            VERIFY_PUBLIC_KEY="${PRIVATE_KEY%.pem}.pub"
        fi
    fi
}

WORK_DIR=""
cleanup() {
    local exit_code=$?
    if [[ -n "${WORK_DIR}" && -d "${WORK_DIR}" ]]; then
        log_info "Cleaning up work directory: ${WORK_DIR}"
        rm -rf "${WORK_DIR}" || true
    fi
    if [[ ${exit_code} -ne 0 ]]; then
        log_error "Update signing failed (exit code: ${exit_code})"
    fi
    exit ${exit_code}
}
trap cleanup EXIT

check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v openssl &>/dev/null; then
        log_error "openssl not found. Install openssl package."
        exit 1
    fi

    if ! command -v sha256sum &>/dev/null; then
        log_error "sha256sum not found."
        exit 1
    fi

    mkdir -p "${OUTPUT_DIR}"

    log_success "Prerequisites satisfied"
}

generate_checksum() {
    log_info "Generating SHA256 checksum..."

    local checksum_file="${WORK_DIR}/SHA256SUMS"
    sha256sum "${PACKAGE_FILE}" > "${checksum_file}"

    log_info "Checksum:"
    cat "${checksum_file}"

    log_success "Checksum generated"
}

sign_checksum() {
    log_info "Signing checksum with private key..."

    local checksum_file="${WORK_DIR}/SHA256SUMS"
    local signature_file="${WORK_DIR}/SHA256SUMS.sig"

    openssl dgst -sha256 -sign "${PRIVATE_KEY}" -out "${signature_file}" "${checksum_file}"

    if [[ ! -f "${signature_file}" ]]; then
        log_error "Signature generation failed"
        exit 1
    fi

    log_success "Checksum signed"
}

verify_signature() {
    log_info "Verifying signature..."

    local checksum_file="${WORK_DIR}/SHA256SUMS"
    local signature_file="${WORK_DIR}/SHA256SUMS.sig"

    if [[ ! -f "${VERIFY_PUBLIC_KEY}" ]]; then
        log_warn "Public key not found at ${VERIFY_PUBLIC_KEY} — skipping verification"
        log_warn "Manual verification required before distribution"
        return 0
    fi

    if openssl dgst -sha256 -verify "${VERIFY_PUBLIC_KEY}" -signature "${signature_file}" "${checksum_file}"; then
        log_success "Signature verification PASSED"
    else
        log_error "Signature verification FAILED"
        exit 1
    fi
}

create_manifest() {
    log_info "Creating manifest..."

    local package_name="$(basename "${PACKAGE_FILE}")"
    local package_size="$(stat -c%s "${PACKAGE_FILE}" 2>/dev/null || stat -f%z "${PACKAGE_FILE}")"
    local package_sha256="$(sha256sum "${PACKAGE_FILE}" | cut -d' ' -f1)"
    local build_date="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    cat > "${WORK_DIR}/MANIFEST.json" <<EOF
{
    "product": "${BEOUTOS_PRODUCT}",
    "version": "${BEOUTOS_VERSION}",
    "codename": "${BEOUTOS_CODENAME}",
    "build_date": "${build_date}",
    "package": "${package_name}",
    "package_size": ${package_size},
    "package_sha256": "${package_sha256}",
    "signing_key": "$(basename "${PRIVATE_KEY}")"
}
EOF

    log_success "Manifest created"
}

create_bundle() {
    log_info "Creating signed update bundle..."

    local package_name="$(basename "${PACKAGE_FILE}")"
    local bundle_name="${package_name%.tar.gz}-signed.tar.gz"
    if [[ "${bundle_name}" == "${package_name}" ]]; then
        bundle_name="${package_name}.signed.tar.gz"
    fi
    local bundle_path="${OUTPUT_DIR}/${bundle_name}"

    cp "${PACKAGE_FILE}" "${WORK_DIR}/${package_name}"

    tar -czf "${bundle_path}" \
        -C "${WORK_DIR}" \
        "${package_name}" \
        SHA256SUMS \
        SHA256SUMS.sig \
        MANIFEST.json

    if [[ ! -f "${bundle_path}" ]]; then
        log_error "Signed bundle was not created"
        exit 1
    fi

    local bundle_size
    bundle_size="$(du -h "${bundle_path}" | cut -f1)"

    log_success "Signed bundle created: ${bundle_path} (${bundle_size})"
    log_info "SHA256 checksum:"
    sha256sum "${bundle_path}"
}

main() {
    parse_args "$@"
    check_prerequisites

    WORK_DIR="$(mktemp -d /tmp/horus-sign-update.XXXXXX)"

    generate_checksum
    sign_checksum
    verify_signature
    create_manifest
    create_bundle

    log_success "Update signing complete"
}

main "$@"
