# Beout_OS Security Appliance Demo

This repository contains the full enterprise demonstration architecture for **Beout_OS**, a premium, hardware-locked, API-driven network security appliance operating system (comparable to FortiGate or Palo Alto PAN-OS). 

Built from scratch using modern C++20 daemons and a React-based frontend on a highly locked-down Debian Linux core.

## Project Architecture

1. **`api/` (Phase 5)**: Native C++20 HTTPS REST API server using `cpp-httplib` and `OpenSSL` to expose configuration endpoints securely.
2. **`dashboard/` (Phase 6)**: A fully responsive, modern React/TypeScript single-page application (SPA) featuring glassmorphism and a dark mode aesthetic. Bundled dynamically with Vite and served natively by the C++ backend.
3. **`provisioning/` (Phase 3)**: A secure, strictly non-interactive CLI application designed to take over `tty1` and prevent Linux bash access, acting as the primary initial network configuration tool.
4. **`database/` (Phase 3)**: The persistent SQLite3 configuration engine orchestrating safe parameter storage across all C++ modules.
5. **`crypto/` & `activation/` (Phase 4)**: C++ cryptographic modules wrapping OpenSSL EVP interfaces. Implements an Ed25519 signature-based hardware licensing lock that verifies a unique appliance Machine ID.
6. **`licensing/` (Phase 4)**: A native Python 3 mock HTTPS licensing server that generates cryptographically signed activation tokens.
7. **`hardening/` & `packaging/` (Phase 7-8)**: Deep system-level Debian locking mechanisms. Disables root shells, masks TTY interfaces, enforces custom AppArmor GRUB configurations, and dynamically bundles all binaries and UI artifacts into a unified `.deb` package (`beout_os-core`).
8. **`installer/` (Phases 1-2)**: Harnesses `live-build` to generate an automated, self-installing hybrid ISO that wipes the target hard drive and natively installs the Beout_OS ecosystem.

## Building the Ecosystem

The entire ecosystem is orchestrated via the central `build.sh` pipeline which inherently triggers CMake, NPM, and Debian packaging utilities.

**To execute the full build and unit-test pipeline locally (Requires CMake, OpenSSL, NPM):**
```bash
./build.sh all
```

**To generate the final bootable ISO (Requires Debian `live-build` and `sudo`):**
```bash
./build.sh iso
```

## Security & Design Philosophy
This project strictly adheres to C++20 best practices (RAII, zero-cost abstractions), prevents standard Linux administration access post-install, natively handles state without requiring heavy stacks (no Apache/Nginx), and relies exclusively on memory-safe database polling for configuration. 
