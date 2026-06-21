#!/usr/bin/env bash
set -euo pipefail

BEOUTOS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${BEOUTOS_ROOT}/config"
BUILD_DIR="${BEOUTOS_ROOT}/build"
SRC_DIR="${BEOUTOS_ROOT}/src"
LB_DIR="${BEOUTOS_ROOT}/live-build"
LOG_DIR="${BUILD_DIR}/logs"
BIN_DIR="${BUILD_DIR}/bin"
INSTALL_DIR="${LB_DIR}/config-includes.chroot"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log_info()    { printf "${GREEN}[INFO]${NC}  %s\n" "$1"; }
log_warn()    { printf "${YELLOW}[WARN]${NC}  %s\n" "$1"; }
log_error()   { printf "${RED}[ERROR]${NC} %s\n" "$1"; }
log_step()    { printf "${BOLD}${CYAN}[STEP]${NC} %s\n" "$1"; }
log_section() { printf "\n${BOLD}${BLUE}==== %s ====${NC}\n\n" "$1"; }

die() {
    log_error "$1"
    exit 1
}

load_config() {
    local global_conf="${CONFIG_DIR}/global.conf"
    local versions_conf="${CONFIG_DIR}/versions.conf"

    if [[ ! -f "${global_conf}" ]]; then
        die "Missing global configuration: ${global_conf}"
    fi
    if [[ ! -f "${versions_conf}" ]]; then
        die "Missing version configuration: ${versions_conf}"
    fi

    while IFS='=' read -r key value; do
        key="$(echo "$key" | xargs)"
        value="$(echo "$value" | sed 's/^["\']//;s/["\']$//' | xargs)"
        if [[ -n "$key" && ! "$key" =~ ^# ]]; then
            eval "${key}=\"${value}\""
        fi
    done < "${global_conf}"

    while IFS='=' read -r key value; do
        key="$(echo "$key" | xargs)"
        value="$(echo "$value" | sed 's/^["\']//;s/["\']$//' | xargs)"
        if [[ -n "$key" && ! "$key" =~ ^# ]]; then
            eval "${key}=\"${value}\""
        fi
    done < "${versions_conf}"

    log_info "Loaded configuration: BeoutOS ${BEOUTOS_VERSION} (${BEOUTOS_CODENAME})"
}

init_build_dirs() {
    mkdir -p "${BUILD_DIR}"
    mkdir -p "${LOG_DIR}"
    mkdir -p "${BIN_DIR}"
    mkdir -p "${INSTALL_DIR}/usr/bin"
    mkdir -p "${INSTALL_DIR}/usr/lib/horus"
    mkdir -p "${INSTALL_DIR}/etc/horus"
    mkdir -p "${INSTALL_DIR}/var/horus"
}

setup_logging() {
    local timestamp="$(date +%Y%m%d_%H%M%S)"
    local log_file="${LOG_DIR}/build_${timestamp}.log"
    exec > >(tee -a "${log_file}") 2>&1
    log_info "Build log: ${log_file}"
}

REQUIRED_DEPS=(
    lb
    mksquashfs
    debootstrap
    cmake
    make
    gcc
    g++
    dpkg
    apt
    xorriso
    sha256sum
)

check_dependencies() {
    log_section "Checking Build Dependencies"

    local missing=()
    for dep in "${REQUIRED_DEPS[@]}"; do
        if ! command -v "${dep}" &>/dev/null; then
            missing+=("${dep}")
        else
            log_info "Found: ${dep}"
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required dependencies:"
        for dep in "${missing[@]}"; do
            log_error "  - ${dep}"
        done
        die "Install missing dependencies before continuing. On Debian: apt install live-build squashfs-tools debootstrap cmake build-essential xorriso"
    fi

    log_info "All dependencies satisfied"
}

check_disk_space() {
    local required_gb=10
    local available_kb="$(df -k "${BEOUTOS_ROOT}" | tail -1 | awk '{print $4}')"
    local available_gb="$(echo "${available_kb}" | awk '{printf "%.1f", $1/1024/1024}')"

    log_info "Available disk space: ${available_gb} GB"

    if (( $(echo "${available_gb} < ${required_gb}" | bc -l) )); then
        die "Insufficient disk space. Need at least ${required_gb} GB, have ${available_gb} GB"
    fi
}

build_cpp_daemons() {
    log_section "Building C++ Daemons"

    local cmake_src="${SRC_DIR}"
    local cmake_build="${BUILD_DIR}/cmake"

    mkdir -p "${cmake_build}"

    log_step "Configuring CMake (build type: ${CMAKE_BUILD_TYPE})"
    cmake -S "${cmake_src}" -B "${cmake_build}" \
        -DCMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE}" \
        -DBEOUTOS_VERSION="${BEOUTOS_VERSION}" \
        -DBEOUTOS_CODENAME="${BEOUTOS_CODENAME}" \
        -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}/usr" \
        2>&1 || die "CMake configuration failed"

    log_step "Compiling C++ daemons"
    cmake --build "${cmake_build}" -- -j$(nproc) 2>&1 || die "C++ compilation failed"

    log_step "Installing daemons to live-build includes"
    cmake --install "${cmake_build}" 2>&1 || die "CMake install failed"

    log_info "C++ daemons built and installed successfully"

    local binaries=()
    for bin in "${INSTALL_DIR}/usr/bin/horus-*"; do
        if [[ -f "${bin}" ]]; then
            binaries+=("$(basename "${bin}")")
        fi
    done

    if [[ ${#binaries[@]} -gt 0 ]]; then
        log_info "Installed binaries:"
        for b in "${binaries[@]}"; do
            local f="${INSTALL_DIR}/usr/bin/${b}"
            local size="$(stat -c%s "${f}" 2>/dev/null || echo "unknown")"
            log_info "  ${b} (${size} bytes)"
        done
    else
        log_warn "No horus binaries found in ${INSTALL_DIR}/usr/bin/"
    fi
}

configure_live_build() {
    log_section "Configuring live-build"

    mkdir -p "${LB_DIR}"

    lb config \
        --architecture amd64 \
        --distribution bookworm \
        --mirror-bootstrap "${DEBIAN_MIRROR}" \
        --mirror-chroot "${DEBIAN_MIRROR}" \
        --mirror-chroot-security "${DEBIAN_SECURITY_MIRROR}" \
        --parent-mirror-bootstrap "${DEBIAN_MIRROR}" \
        --parent-mirror-chroot "${DEBIAN_MIRROR}" \
        --parent-mirror-chroot-security "${DEBIAN_SECURITY_MIRROR}" \
        --archive-areas "main contrib non-free-firmware" \
        --parent-archive-areas "main contrib non-free-firmware" \
        --linux-flavour "amd64" \
        --linux-packages "linux-image-${KERNEL_VERSION}" \
        --bootappend-live "boot=live components hostname=horus username=admin quiet systemd.unit=beoutos-boot.target" \
        --iso-volume-id "${ISO_VOLUME_ID}" \
        --iso-publisher "Beout Security; https://beout.ai; support@beout.ai" \
        --iso-application "BeoutOS ${BEOUTOS_VERSION}" \
        --system live \
        --username admin \
        --chroot-filesystem squashfs \
        --compression gzip \
        --zsync false \
        2>&1 || die "live-build configuration failed"

    log_info "live-build configured successfully"
}

build_iso() {
    log_section "Building ISO Image"

    pushd "${LB_DIR}" &>/dev/null

    log_step "Running live-build (this takes 20-60 minutes)")
    lb build 2>&1 || {
        popd &>/dev/null
        die "live-build ISO generation failed"
    }

    popd &>/dev/null

    local iso_file="${LB_DIR}/live-image-amd64.hybrid.iso"
    if [[ -f "${iso_file}" ]]; then
        local iso_size="$(stat -c%s "${iso_file}" | awk '{printf "%.1f", $1/1024/1024}')"
        local iso_dest="${BUILD_DIR}/horus-${BEOUTOS_VERSION}-${BEOUTOS_CODENAME}-amd64.iso"

        cp "${iso_file}" "${iso_dest}"

        local sha256="$(sha256sum "${iso_dest}" | awk '{print $1}')"
        echo "${sha256}" > "${iso_dest}.sha256"

        log_info "ISO built successfully:"
        log_info "  Path: ${iso_dest}"
        log_info "  Size: ${iso_size} MB"
        log_info "  SHA256: ${sha256}"
    else
        die "ISO file not found at ${iso_file}"
    fi
}

build_all() {
    log_section "BeoutOS - Full Build"
    log_info "Version: ${BEOUTOS_VERSION} (${BEOUTOS_CODENAME})"
    log_info "Target: amd64 / Debian ${DEBIAN_BASE_VERSION}"
    log_info "Build started: $(date)"

    check_dependencies
    check_disk_space
    build_cpp_daemons
    configure_live_build
    build_iso

    log_section "Build Complete"
    log_info "Build finished: $(date)"
    log_info "Output directory: ${BUILD_DIR}"
}

build_source_only() {
    log_section "BeoutOS - Source Build Only"

    check_dependencies
    check_disk_space
    build_cpp_daemons

    log_section "Source Build Complete"
    log_info "Binaries in: ${BIN_DIR}"
    log_info "Installed to: ${INSTALL_DIR}/usr/bin/"
}

build_iso_only() {
    log_section "BeoutOS - ISO Build Only"

    check_dependencies
    check_disk_space
    configure_live_build
    build_iso

    log_section "ISO Build Complete"
}

clean_build() {
    log_section "Cleaning Build Artifacts"

    if [[ -d "${BUILD_DIR}" ]]; then
        log_step "Removing build directory: ${BUILD_DIR}"
        rm -rf "${BUILD_DIR}"
        log_info "Build directory removed"
    fi

    if [[ -d "${LB_DIR}" ]]; then
        log_step "Cleaning live-build workspace"
        pushd "${LB_DIR}" &>/dev/null
        lb clean --all 2>&1 || log_warn "lb clean failed (may be expected if not built yet)"
        popd &>/dev/null
        log_info "live-build workspace cleaned"
    fi

    log_info "Clean complete"
}

show_help() {
    cat <<EOF
${BOLD}BeoutOS - Build System${NC}
${CYAN}Version: ${BEOUTOS_VERSION} (${BEOUTOS_CODENAME})${NC}

${BOLD}USAGE:${NC}
    build.sh <command> [options]

${BOLD}COMMANDS:${NC}
    ${GREEN}all${NC}       Full build: compile C++ daemons + generate ISO
    ${GREEN}src${NC}       Build C++ source only (skip ISO generation)
    ${GREEN}iso${NC}       Build ISO only (assumes daemons are pre-built)
    ${GREEN}clean${NC}     Remove all build artifacts
    ${GREEN}help${NC}      Show this help message

${BOLD}CONFIGURATION:${NC}
    config/global.conf    Build parameters and mirror settings
    config/versions.conf  Component version tracking

${BOLD}DIRECTORY STRUCTURE:${NC}
    src/                  C++ daemon source code
    live-build/           live-build configuration and workspace
    build/                Build output (ISO, binaries, logs)
    config/               Build configuration files
    scripts/              Utility scripts
    systemd/              systemd unit files

${BOLD}EXAMPLES:${NC}
    ./build.sh all          # Complete build from source to ISO
    ./build.sh src          # Compile daemons only
    ./build.sh iso          # Generate ISO from existing binaries
    ./build.sh clean        # Remove all build artifacts

EOF
}

main() {
    local command="${1:-help}"

    load_config
    init_build_dirs
    setup_logging

    case "${command}" in
        all)
            build_all
            ;;
        src)
            build_source_only
            ;;
        iso)
            build_iso_only
            ;;
        clean)
            clean_build
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            die "Unknown command: '${command}'. Run './build.sh help' for usage."
            ;;
    esac
}

main "$@"
