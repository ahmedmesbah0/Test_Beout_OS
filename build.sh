#!/usr/bin/env bash
set -e

# Simple wrapper for CMake build and optional ISO creation

if [[ "$1" == "iso" ]]; then
    echo "[Placeholder] ISO generation would be invoked here (e.g., using live-build)"
    exit 0
fi

# Configure and build
cmake -B build -S .
cmake --build build

echo "Build complete. Executables are in the 'build' directory."
