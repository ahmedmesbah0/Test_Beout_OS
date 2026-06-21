#!/usr/bin/env bash
set -euo pipefail

# Build script for Beout_OS Security Appliance

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build"
CMAKE_BUILD_TYPE="Release"

function usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  clean      Clean build directory"
    echo "  configure  Run CMake configure"
    echo "  build      Build all targets"
    echo "  test       Run unit tests"
    echo "  iso        Build the Debian live ISO"
    echo "  all        Clean, configure, build, and test"
}

function clean() {
    echo "Cleaning build directory..."
    rm -rf "${BUILD_DIR}"
}

function configure() {
    echo "Configuring CMake (${CMAKE_BUILD_TYPE})..."
    mkdir -p "${BUILD_DIR}"
    cd "${BUILD_DIR}"
    cmake -DCMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE}" ..
}

function build() {
    echo "Building project..."
    cmake --build "${BUILD_DIR}" -j"$(nproc)"
}

function run_tests() {
    echo "Running tests..."
    cd "${BUILD_DIR}"
    ctest --output-on-failure
}

function build_iso() {
    echo "Configuring live-build..."
    cd "${PROJECT_ROOT}/installer"
    lb config
    echo "Building ISO (requires sudo)..."
    sudo lb build
}

if [[ $# -eq 0 ]]; then
    usage
    exit 1
fi

case "$1" in
    clean) clean ;;
    configure) configure ;;
    build) build ;;
    test) run_tests ;;
    iso) build_iso ;;
    all) clean; configure; build; run_tests ;;
    *) usage; exit 1 ;;
esac
