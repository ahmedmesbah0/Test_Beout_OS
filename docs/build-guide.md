# BeoutOS — Build Guide

Complete build instructions for the BeoutOS, a commercial-grade network security platform based on Debian 12 (bookworm) Minimal.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Environment Setup](#2-environment-setup)
3. [Configuration](#3-configuration)
4. [Step-by-Step Build Process](#4-step-by-step-build-process)
5. [Building Individual Components](#5-building-individual-components)
6. [Build Output Structure](#6-build-output-structure)
7. [Troubleshooting](#7-troubleshooting)
8. [Testing the Build](#8-testing-the-build)
9. [Clean Build](#9-clean-build)
10. [Release Build](#10-release-build)

---

## 1. Prerequisites

### 1.1 Required Operating System

The build system requires **Debian 12 (bookworm)** as the host OS. Building on other distributions is not supported because `live-build` depends on Debian-specific bootstrap and repository layout.

Verify your host system:

```bash
cat /etc/debian_version
# Expected output: 12.x (bookworm)
```

### 1.2 Required Packages

| Package | Purpose | Minimum Version |
|---|---|---|
| `live-build` | ISO creation via `lb config` / `lb build` | 20230101 |
| `squashfs-tools` | SquashFS image creation (`mksquashfs`) | 4.6 |
| `debootstrap` | Debian root filesystem bootstrap | 1.0.128 |
| `cmake` | C++ daemon build system | 3.25 |
| `build-essential` | GCC, G++, make, libc | GCC 12.2+ |
| `grub2` | Bootloader generation (`grub-mkimage`) | — |
| `xorriso` | ISO image creation | 1.6.6 |
| `mtools` | FAT filesystem utilities | — |
| `dpkg-dev` | Debian package development tools | — |
| `openssl` | Update signing, Secure Boot key management | 3.0.13 |
| `libssl-dev` | OpenSSL development headers (C++ linkage) | 3.0+ |
| `libsqlite3-dev` | SQLite3 development headers | — |
| `libboost-dev` | Boost C++ libraries (headers) | 1.74+ |
| `nlohmann-json3-dev` | JSON for Modern C++ | 3.9+ |
| `zlib1g-dev` | Zlib compression library | — |
| `libcurl4-openssl-dev` | libcurl (optional, for activation daemon) | — |
| `bc` | Arithmetic for disk space checks | — |
| `git` | Repository management | — |
| `fakeroot` | live-build package construction | — |
| `patch` | live-build hook patching | — |

### 1.3 Minimum Disk Space

**20 GB** free disk space is required for a full build. The build process creates:

- A complete Debian chroot (~1.5 GB)
- C++ build artifacts (~50–100 MB)
- SquashFS compressed rootfs (~500–800 MB)
- Final ISO image (~600–900 MB)
- Logs and intermediate files (~100 MB)

The `build.sh` script enforces a minimum of 10 GB before proceeding, but 20 GB provides comfortable margin for repeated builds and debugging.

Check available space:

```bash
df -h /path/to/Test_Beout_OS
```

### 1.4 Recommended Hardware

| Resource | Minimum | Recommended |
|---|---|---|
| CPU | 2 cores, x86_64 | 4+ cores (parallel CMake builds) |
| RAM | 4 GB | 8 GB+ (debootstrap is memory-intensive) |
| Disk | 20 GB free | 40 GB+ SSD |
| Network | Broadband (package downloads ~1 GB) | Stable connection |

---

## 2. Environment Setup

### 2.1 Install All Prerequisites on Debian 12

Run the following on a clean Debian 12 (bookworm) system:

```bash
# Ensure system is up to date
sudo apt update && sudo apt upgrade -y

# Install core build dependencies
sudo apt install -y \
    live-build \
    squashfs-tools \
    debootstrap \
    cmake \
    build-essential \
    grub2 \
    grub-efi-amd64-bin \
    xorriso \
    mtools \
    dpkg-dev \
    openssl \
    fakeroot \
    patch \
    bc \
    git

# Install C++ library dependencies
sudo apt install -y \
    libssl-dev \
    libsqlite3-dev \
    libboost-dev \
    nlohmann-json3-dev \
    zlib1g-dev \
    libcurl4-openssl-dev

# Install Secure Boot signing tools (required for release builds)
sudo apt install -y \
    sbsigntool \
    efivar

# Verify critical tools are present
lb --version
cmake --version
gcc --version
mksquashfs -version
xorriso -version
openssl version
```

### 2.2 Configure live-build

`live-build` requires proper configuration to work with the BeoutOS project. The `build.sh` script handles this automatically via the `configure_live_build()` function, which calls `lb config` with parameters sourced from `config/global.conf`. No manual `lb config` step is needed when using `build.sh`.

If you need to manually reconfigure live-build (e.g., after cleaning):

```bash
cd live-build/
lb config \
    --architecture amd64 \
    --distribution bookworm \
    --mirror-bootstrap http://deb.debian.org/debian/ \
    --mirror-chroot http://deb.debian.org/debian/ \
    --mirror-chroot-security http://deb.debian.org/debian-security/ \
    --archive-areas "main contrib non-free-firmware" \
    --linux-flavour amd64 \
    --linux-packages "linux-image-6.1.0-17" \
    --bootappend-live "boot=live components hostname=horus username=admin quiet systemd.unit=beoutos-boot.target" \
    --iso-volume-id BEOUTOS_1.0_SENTINEL \
    --system live \
    --username admin \
    --chroot-filesystem squashfs \
    --compression gzip
```

### 2.3 Set Up the Build Environment

The build environment is self-contained within the project directory. The `build.sh` script creates all required directories on invocation:

```bash
# These directories are created automatically by build.sh init_build_dirs():
#   build/              — Main output directory
#   build/logs/         — Timestamped build logs
#   build/bin/          — C++ binary staging area
#   build/cmake/        — CMake build tree
#   live-build/config-includes.chroot/usr/bin/   — Daemon install target
#   live-build/config-includes.chroot/usr/lib/horus/
#   live-build/config-includes.chroot/etc/horus/
#   live-build/config-includes.chroot/var/horus/
```

No manual directory creation is required. Just ensure the project root is writable:

```bash
ls -la /path/to/Test_Beout_OS/
# Verify write permissions on project root
```

### 2.4 Clone the Repository

```bash
git clone <repository-url> /path/to/Test_Beout_OS
cd /path/to/Test_Beout_OS
```

If you already have the repository locally, ensure you're on the correct branch and have the latest sources:

```bash
cd /path/to/Test_Beout_OS
git status
git log --oneline -5
```

---

## 3. Configuration

### 3.1 `config/global.conf` — Build Parameters

This file is sourced by `build.sh` at build time. Every parameter directly controls a build aspect. Edit with a text editor; values are simple `KEY=VALUE` pairs (no shell expansion).

| Parameter | Default | Description |
|---|---|---|
| `BEOUTOS_VERSION` | `1.0.0` | Product version string, embedded in ISO filename, CMake defines, and boot parameters |
| `BEOUTOS_CODENAME` | `sentinel` | Release codename, used in ISO filename and internal branding |
| `BEOUTOS_VENDOR` | `Beout Security` | Vendor name, used in ISO publisher metadata |
| `BEOUTOS_PRODUCT` | `BeoutOS` | Full product name, used in ISO application metadata |
| `DEBIAN_BASE_VERSION` | `12` | Debian major version (must be `12` for bookworm) |
| `DEBIAN_MIRROR` | `http://deb.debian.org/debian/` | Primary Debian mirror for debootstrap and chroot package installation |
| `DEBIAN_SECURITY_MIRROR` | `http://deb.debian.org/debian-security/` | Debian security update mirror |
| `LB_ARCHITECTURE` | `amd64` | Target architecture (only `amd64` is currently supported) |
| `LB_DISTRIBUTION` | `bookworm` | Debian distribution codename |
| `LB_ARCHIVE_AREAS` | `main contrib non-free-firmware` | APT archive areas to include (firmware packages require `non-free-firmware`) |
| `LB_SYSTEM` | `live` | live-build system type |
| `LB_CHROOT_FS` | `squashfs` | Chroot filesystem type for the live image |
| `LB_COMPRESSION` | `gzip` | SquashFS compression algorithm inside the live-build flow |
| `LB_USERNAME` | `admin` | Default live system user |
| `LB_HOSTNAME` | `horus` | Default live system hostname |
| `KERNEL_VERSION` | `6.1.0-17` | Linux kernel version to install in the live image |
| `KERNEL_FLAVOUR` | `amd64` | Kernel flavour (architecture-specific) |
| `CMAKE_BUILD_TYPE` | `Release` | CMake build type: `Release` (optimized, `-O2`), `Debug` (symbols, `-g -O0`), or `RelWithDebInfo` |
| `ISO_VOLUME_ID` | `BEOUTOS_1.0_SENTINEL` | ISO 9660 volume identifier (max 32 chars) |
| `ISO_APPLICATION` | `BeoutOS 1.0.0` | ISO application metadata string |
| `ISO_PUBLISHER` | `Beout Security; https://beout.ai; support@beout.ai` | ISO publisher metadata |
| `BOOT_APPEND` | `boot=live components hostname=horus username=admin quiet systemd.unit=beoutos-boot.target` | Kernel boot command-line append string |

**Mirror customization** — If building behind a corporate proxy or in a region with slow access to the default mirrors, change `DEBIAN_MIRROR` and `DEBIAN_SECURITY_MIRROR` to a local mirror:

```bash
# Example: use a regional mirror
DEBIAN_MIRROR=http://ftp.<region>.debian.org/debian/
DEBIAN_SECURITY_MIRROR=http://ftp.<region>.debian.org/debian-security/
```

### 3.2 `config/versions.conf` — Version Tracking

This file tracks all component versions for build reproducibility. It is sourced alongside `global.conf` by `build.sh`. Key sections:

| Section | Key Parameters | Purpose |
|---|---|---|
| **BeoutOS Platform** | `BEOUTOS_VERSION`, `BEOUTOS_CODENAME`, `BEOUTOS_BUILD_NUMBER`, `BEOUTOS_RELEASE_TYPE` | Overall product identity and release metadata |
| **Debian Base** | `DEBIAN_BASE_VERSION`, `DEBIAN_BOOKWORM_PATCH`, `DEBIAN_KERNEL_VERSION` | Base OS and kernel tracking |
| **Suricata IDS/IPS** | `SURICATA_VERSION`, `SURICATA_LIBHTP_VERSION` | IDS engine versions |
| **Kernel** | `KERNEL_VERSION`, `KERNEL_ABI`, `KERNEL_FLAVOUR`, `KERNEL_SOURCE` | Kernel version details |
| **Core Daemons** | `BEOUTOS_CLI_VERSION`, `BEOUTOS_PROVISIONING_VERSION`, `BEOUTOS_ACTIVATION_VERSION`, `BEOUTOS_CONFIGDB_VERSION`, `BEOUTOS_OVERLAY_VERSION`, `BEOUTOS_UPDATE_VERSION` | Individual daemon version tracking |
| **Common Libraries** | `BEOUTOS_COMMON_VERSION`, `BEOUTOS_CRYPTO_VERSION`, `BEOUTOS_LOG_VERSION`, `BEOUTOS_DB_VERSION`, `BEOUTOS_NET_VERSION` | Internal shared library versions |
| **External Security Tools** | `NFTABLES_VERSION`, `ETHTOOL_VERSION`, `CONNTRACK_VERSION`, `OPENSSL_VERSION`, etc. | Versions of bundled security packages |
| **Build Tools** | `LIVE_BUILD_VERSION`, `CMAKE_MIN_VERSION`, `GCC_MIN_VERSION`, `SQUASHFS_VERSION`, etc. | Minimum required build tool versions |
| **Boot / Initramfs** | `INITRAMFS_TOOLS_VERSION`, `SYSTEMD_VERSION`, `DRACUT_VERSION` | Boot infrastructure versions |

When preparing a release, update `BEOUTOS_BUILD_NUMBER` (increment for each build) and `BEOUTOS_RELEASE_TYPE` (`stable`, `rc`, `beta`).

---

## 4. Step-by-Step Build Process

### 4.1 Clone the Repository

```bash
git clone <repository-url> ~/Test_Beout_OS
cd ~/Test_Beout_OS
```

### 4.2 Verify Prerequisites

```bash
# Quick dependency check (same check build.sh performs)
for cmd in lb mksquashfs debootstrap cmake make gcc g++ xorriso sha256sum; do
    command -v "$cmd" && echo "  OK: $cmd" || echo "  MISSING: $cmd"
done
```

Install any missing packages as described in [Section 2.1](#21-install-all-prerequisites-on-debian-12).

### 4.3 Configure Build Parameters

Review and optionally edit configuration files:

```bash
# Review current configuration
cat config/global.conf
cat config/versions.conf

# Edit if needed (e.g., change mirror for local network)
vim config/global.conf
```

The default configuration produces: `beoutos-1.0.0-sentinel-amd64.iso`

### 4.4 Run the Full Build

```bash
# Using build.sh directly (recommended):
./build.sh all

# Or using the Makefile wrapper:
make all
```

Both commands invoke the same build pipeline. The Makefile is a convenience wrapper that calls `build.sh`.

### 4.5 What Each Build Step Does Internally

The `./build.sh all` command executes the following pipeline:

1. **Load Configuration** — Parses `config/global.conf` and `config/versions.conf`, importing all `KEY=VALUE` pairs as shell variables.

2. **Initialize Build Directories** — Creates the output tree:
   - `build/`, `build/logs/`, `build/bin/`
   - `live-build/config-includes.chroot/usr/bin/`
   - `live-build/config-includes.chroot/usr/lib/horus/`
   - `live-build/config-includes.chroot/etc/horus/`
   - `live-build/config-includes.chroot/var/horus/`

3. **Setup Logging** — Creates a timestamped log file at `build/logs/build_<timestamp>.log` and pipes all stdout/stderr through `tee`.

4. **Check Dependencies** — Verifies that all required commands (`lb`, `mksquashfs`, `debootstrap`, `cmake`, `make`, `gcc`, `g++`, `dpkg`, `apt`, `xorriso`, `sha256sum`) are present on the host. Fails with an explicit list of missing tools if any are absent.

5. **Check Disk Space** — Verifies at least 10 GB is available on the filesystem containing the project root.

6. **Build C++ Daemons** (`build_cpp_daemons`) — Executes the CMake pipeline:
   - `cmake -S src/ -B build/cmake/` with `-DCMAKE_BUILD_TYPE=Release`, `-DBEOUTOS_VERSION=1.0.0`, `-DBEOUTOS_CODENAME=sentinel`, and `-DCMAKE_INSTALL_PREFIX=live-build/config-includes.chroot/usr`
   - `cmake --build build/cmake/ -- -j$(nproc)` — Parallel compilation of all daemons
   - `cmake --install build/cmake/` — Installs binaries to `live-build/config-includes.chroot/usr/bin/` and libraries to `live-build/config-includes.chroot/usr/lib/horus/`
   - The installed binaries are: `horus-cli`, `horus-provisioning`, `horus-activation`, `horus-configdb`, `horus-overlay`, `horus-update`

7. **Configure live-build** (`configure_live_build`) — Calls `lb config` in the `live-build/` directory with all parameters from `global.conf` (architecture, distribution, mirrors, kernel, boot parameters, ISO metadata). This generates the live-build configuration tree.

8. **Build ISO** (`build_iso`) — Calls `lb build` inside `live-build/`. This is the longest step:
   - Debootstrap creates a minimal Debian chroot
   - Package lists from `live-build/config-package-lists/horus-minimal.list.chroot` are installed
   - Chroot hooks from `live-build/config-hooks/live/00-horus-setup.hook.chroot` execute
   - Files from `live-build/config-includes.chroot/` (including the compiled C++ daemons) are copied into the chroot
   - The chroot is compressed into a SquashFS filesystem
   - A bootable hybrid ISO image is generated with GRUB EFI support
   - The resulting ISO is copied to `build/horus-<version>-<codename>-amd64.iso`
   - A SHA256 checksum file is generated alongside the ISO

### 4.6 Where Outputs Are Placed

All outputs reside in the `build/` directory under the project root:

```
build/
├── beoutos-1.0.0-sentinel-amd64.iso          # Final bootable ISO
├── beoutos-1.0.0-sentinel-amd64.iso.sha256   # SHA256 checksum
├── bin/                                     # C++ binary staging (before install)
├── cmake/                                   # CMake build tree (intermediate)
├── logs/                                    # Timestamped build logs
│   └── build_20260621_120000.log
└── horus-rootfs.squashfs                    # SquashFS image (if created separately)
```

### 4.7 Expected Build Time

| Step | Typical Duration | Notes |
|---|---|---|
| Dependency check | < 5 seconds | Instant if all tools present |
| Disk space check | < 1 second | Instant |
| C++ daemon compilation | 2–5 minutes | Depends on core count; `-j$(nproc)` parallelism |
| `lb config` | 5–10 seconds | Generates configuration tree |
| `lb build` | 20–60 minutes | Dominated by debootstrap + package installation; network-dependent |
| **Total** | **25–70 minutes** | First build is slower; subsequent builds with cached packages are faster |

The `build.sh` script prints timestamps at start and completion for tracking actual duration.

---

## 5. Building Individual Components

### 5.1 C++ Daemons Only

Compile just the C++ source code without generating an ISO. Useful for development iteration or testing daemon changes:

```bash
./build.sh src
# Or:
make src
```

This runs the full CMake pipeline (`configure → build → install`) and places binaries in `live-build/config-includes.chroot/usr/bin/`. The daemons built are:

- `horus-cli` — Secure management console (runs on tty1 after activation)
- `horus-provisioning` — Initial setup and provisioning daemon (runs on console before activation)
- `horus-activation` — License activation handler
- `horus-configdb` — Configuration database (SQLite-backed)
- `horus-overlay` — OverlayFS mount manager for read-only root
- `horus-update` — A/B update orchestrator

The CMake build also compiles shared internal libraries (`horus-common`, `horus-crypto`, `horus-log`, `horus-db`, `horus-net`) that are installed to `live-build/config-includes.chroot/usr/lib/horus/`.

**CMake build details**:

The `src/CMakeLists.txt` defines:
- C++20 standard required
- Hardening flags: `-Wall -Wextra -Werror`, `-D_FORTIFY_SOURCE=2`, `-Wl,-z,relro,-z,now`, `-Wl,-z,noexecstack`
- Position-independent code (PIC) enabled
- Static linking preference (`.a` searched before `.so`)
- Required libraries: OpenSSL 3.0+, SQLite3, Boost 1.74+, nlohmann_json 3.9+, ZLIB
- Optional: libcurl (enables HTTPS in `horus-activation`; falls back to raw sockets if absent)

To build with debug symbols instead of Release optimization:

```bash
# Edit config/global.conf:
CMAKE_BUILD_TYPE=Debug

# Then run:
./build.sh src
```

### 5.2 Live-Build Configuration Only

Run just the `lb config` step to regenerate the live-build configuration tree without building the ISO. This is needed after cleaning or when modifying live-build parameters:

```bash
./build.sh iso
```

Note: `./build.sh iso` runs both `lb config` and `lb build`. If you want only `lb config` without `lb build`, run it manually:

```bash
cd live-build/
lb config \
    --architecture amd64 \
    --distribution bookworm \
    --mirror-bootstrap http://deb.debian.org/debian/ \
    --archive-areas "main contrib non-free-firmware" \
    --linux-packages "linux-image-6.1.0-17" \
    --bootappend-live "boot=live components hostname=horus username=admin quiet systemd.unit=beoutos-boot.target" \
    --iso-volume-id BEOUTOS_1.0_SENTINEL \
    --system live \
    --username admin \
    --chroot-filesystem squashfs \
    --compression gzip
```

### 5.3 ISO Only (Assuming Daemons Already Built)

Generate the ISO from an existing live-build workspace where daemons are already compiled and installed. This skips C++ compilation:

```bash
./build.sh iso
# Or:
make iso
```

This requires that `live-build/config-includes.chroot/usr/bin/horus-*` binaries already exist (from a prior `./build.sh src` run). If they are missing, the ISO will be built without the BeoutOS daemons — it will boot into a plain Debian live environment.

### 5.4 SquashFS Only (Manual)

The `scripts/create-squashfs.sh` utility creates a SquashFS image from an existing chroot independently of `lb build`. This is useful for manual ISO assembly or testing:

```bash
# Default: creates build/horus-rootfs.squashfs from live-build/chroot/
./scripts/create-squashfs.sh

# With custom options:
./scripts/create-squashfs.sh \
    --source /path/to/chroot \
    --output /path/to/output.squashfs \
    --compress zstd \
    --verify
```

**Options**:

| Option | Description |
|---|---|
| `--source DIR` | Source chroot directory (default: `live-build/chroot/`) |
| `--output FILE` | Output SquashFS path (default: `build/horus-rootfs.squashfs`) |
| `--compress TYPE` | Compression: `xz` (default, better ratio) or `zstd` (faster decompression) |
| `--verify` | Mount the image and verify critical files exist (`horus-cli`, `horus-provisioning`, `horus.conf`) |

The script excludes transient directories from the SquashFS (`/var/cache`, `/var/log`, `/tmp`, `/proc`, `/sys`, `/dev`, `/run`) and sets `-all-root` for consistent ownership.

### 5.5 ISO Packaging (Manual)

The `scripts/create-iso.sh` utility assembles a bootable ISO from a SquashFS image, kernel, and initrd independently of `lb build`. This provides granular control over ISO construction:

```bash
# Default: uses build/horus-rootfs.squashfs
./scripts/create-iso.sh

# With custom paths:
./scripts/create-iso.sh \
    --squashfs /path/to/rootfs.squashfs \
    --output /path/to/output.iso \
    --label CUSTOM_LABEL
```

**Options**:

| Option | Description |
|---|---|
| `--squashfs FILE` | SquashFS rootfs image (default: `build/horus-rootfs.squashfs`) |
| `--output FILE` | Output ISO path (default: `build/BeoutOS-1.0.0-sentinel.iso`) |
| `--label STRING` | ISO volume ID (default: from `ISO_VOLUME_ID` in `global.conf`) |

The script performs:
1. Creates a temporary ISO work directory with `/boot/grub/`, `/live/`, `/EFI/BOOT/` structure
2. Copies the SquashFS, kernel (`vmlinuz`), and initrd from `live-build/chroot/boot/`
3. Generates a GRUB configuration with two menu entries:
   - "BeoutOS" (normal boot to `beoutos-boot.target`)
   - "BeoutOS Installer (Provisioning Mode)" (boot to `beoutos-provisioning.target`)
4. Generates an EFI boot image (`BOOTX64.EFI`) via `grub-mkimage`
5. Creates a hybrid UEFI/MBR bootable ISO via `xorriso`
6. Verifies the ISO size meets a minimum threshold (50 MB)
7. Prints SHA256 checksum

---

## 6. Build Output Structure

After a successful `./build.sh all`, the `build/` directory contains:

```
build/
├── beoutos-1.0.0-sentinel-amd64.iso
│   # Final bootable hybrid ISO image (UEFI + MBR)
│   # Contains: SquashFS rootfs, kernel, initrd, GRUB bootloader, EFI boot image
│   # Typical size: 600–900 MB
│
├── beoutos-1.0.0-sentinel-amd64.iso.sha256
│   # SHA256 checksum of the ISO, generated by sha256sum
│   # Format: <hash>  beoutos-1.0.0-sentinel-amd64.iso
│
├── bin/
│   # C++ binary staging area (before CMake install copies them to live-build includes)
│   # Contents after build.sh src:
│   #   horus-cli, horus-provisioning, horus-activation,
│   #   horus-configdb, horus-overlay, horus-update
│   # Note: CMake's runtime output directory is build/cmake/bin/;
│   #   the build/bin/ path is referenced in config but CMake
│   #   installs directly to live-build/config-includes.chroot/usr/bin/
│
├── cmake/
│   # CMake build tree (intermediate compilation artifacts)
│   # Contains: object files, generated Makefiles, library archives
│   # Subdirectories mirror src/ structure:
│   #   cmake/bin/   — compiled executables
│   #   cmake/lib/   — compiled shared/static libraries
│
├── logs/
│   # Timestamped build logs
│   # Each build run creates: build_<YYYYMMDD_HHMMSS>.log
│   # Contains full stdout/stderr of the build process
│   # Useful for debugging failed builds
│
└── horus-rootfs.squashfs
    # SquashFS rootfs image (if created via scripts/create-squashfs.sh)
    # Not present after ./build.sh all (lb build creates its own SquashFS internally)
    # Created when running scripts/create-squashfs.sh manually
```

**Live-build workspace output** (inside `live-build/`):

```
live-build/
├── auto/                     # lb auto scripts (config, build, clean)
├── config/                   # lb-generated configuration
├── chroot/                   # Complete Debian chroot (after lb build)
│   ├── boot/vmlinuz-*       # Kernel image
│   ├── boot/initrd.img-*    # Initramfs
│   ├── usr/bin/horus-*      # Installed C++ daemons
│   ├── usr/lib/horus/       # BeoutOS shared libraries
│   ├── etc/horus/           # BeoutOS configuration files
│   └── usr/sbin/            # System-level BeoutOS binaries
├── binary/                   # ISO staging area (before final xorriso)
├── live-image-amd64.hybrid.iso  # Raw lb output (before copy to build/)
└── config-includes.chroot/  # Custom files injected into chroot
    ├── usr/bin/horus-*      # C++ daemons (populated by CMake install)
    ├── usr/lib/horus/       # Daemon libraries
    ├── etc/horus/           # Configuration templates
    ├── etc/systemd/system/  # Custom systemd unit files
    └── var/horus/           # Variable data templates
├── config-hooks/live/       # Chroot build hooks
│   └── 00-horus-setup.hook.chroot
├── config-package-lists/    # Package list files
│   └── horus-minimal.list.chroot
```

---

## 7. Troubleshooting

### 7.1 live-build Failures

**Problem**: `lb build` fails with debootstrap errors.

```
E: Failed to download Debian release file
```

**Solution**: Check network connectivity and mirror accessibility. If using a proxy, configure APT proxy settings:

```bash
# Test mirror access
curl -I http://deb.debian.org/debian/

# If behind a proxy, configure live-build APT:
mkdir -p live-build/config/apt/
echo "Acquire::http::Proxy \"http://proxy:3142\";" > live-build/config/apt/apt.conf
```

**Problem**: `lb build` fails with package resolution errors.

```
E: Unable to locate package <name>
```

**Solution**: Verify `LB_ARCHIVE_AREAS` includes `non-free-firmware` (required for firmware packages on Debian 12). Check that `horus-minimal.list.chroot` package names match bookworm repository names:

```bash
# Check if a package exists in bookworm
apt-cache policy <package-name>
```

**Problem**: `lb config` fails or produces unexpected configuration.

**Solution**: Clean the live-build workspace and reconfigure:

```bash
cd live-build/
lb clean --all
cd ../
./build.sh iso
```

### 7.2 CMake Build Errors

**Problem**: CMake configuration fails with missing library errors.

```
CMake Error: Could NOT find OpenSSL (missing: OpenSSL_DIR)
```

**Solution**: Install the development package for the missing library:

```bash
# For OpenSSL:
sudo apt install libssl-dev

# For SQLite3:
sudo apt install libsqlite3-dev

# For Boost:
sudo apt install libboost-dev

# For nlohmann_json:
sudo apt install nlohmann-json3-dev

# For ZLIB:
sudo apt install zlib1g-dev

# For libcurl (optional):
sudo apt install libcurl4-openssl-dev
```

**Problem**: Compilation fails with C++20 errors.

```
error: 'std::format' is unavailable
```

**Solution**: Ensure GCC 12+ is installed (C++20 `<format>` requires GCC 13+ for full support; the project may use alternative formatting):

```bash
gcc --version
# Must be 12.2 or higher (as specified in versions.conf: GCC_MIN_VERSION=12.2)

# If too old, upgrade:
sudo apt install gcc-12 g++-12
```

**Problem**: Linking fails with undefined references.

```
undefined reference to `sqlite3_open'
```

**Solution**: The project prefers static linking (`STATIC_LINKING_PREFERENCE=TRUE`). Ensure static library archives (`.a`) are available:

```bash
# Check for static libraries
dpkg -L libsqlite3-dev | grep '.a$'

# If missing, some Debian packages only ship shared libs.
# You may need to disable static preference in CMakeLists.txt or
# install additional -static packages.
```

### 7.3 SquashFS Creation Issues

**Problem**: `mksquashfs` fails with permission errors.

```
FATAL ERROR: Failed to create SquashFS image
```

**Solution**: Ensure the source chroot directory exists and is populated. The `create-squashfs.sh` script requires `live-build/chroot/` to exist (only present after `lb build`):

```bash
# Verify chroot exists
ls live-build/chroot/

# If missing, run lb build first:
./build.sh all
```

**Problem**: SquashFS verification fails (critical files missing).

**Solution**: The verification step checks for `horus-cli`, `horus-provisioning`, and `horus.conf`. Ensure C++ daemons were compiled and installed before creating the SquashFS:

```bash
# Check daemons are in the chroot
ls live-build/chroot/usr/bin/horus-*

# If missing, rebuild source:
./build.sh src
```

### 7.4 ISO Generation Problems

**Problem**: `xorriso` fails with EFI boot image errors.

```
xorriso ERROR: -eltorito-alt-boot: No El Torito boot image declared yet
```

**Solution**: Ensure `BOOTX64.EFI` was generated successfully by `grub-mkimage`. Verify GRUB EFI modules are installed:

```bash
# Check grub-mkimage is available
grub-mkimage --version

# Check EFI modules directory
ls /usr/lib/grub/x86_64-efi/

# Required packages:
sudo apt install grub-efi-amd64-bin
```

**Problem**: ISO is too small (below 50 MB minimum threshold).

**Solution**: The ISO is incomplete — likely the SquashFS image or kernel is missing. Verify all components are present before running `create-iso.sh`:

```bash
ls -la build/horus-rootfs.squashfs
ls live-build/chroot/boot/vmlinuz-*
ls live-build/chroot/boot/initrd.img-*
```

**Problem**: ISO boots but drops to a shell instead of the provisioning menu.

**Solution**: Verify the `systemd.unit=beoutos-boot.target` boot parameter is present in the GRUB configuration. Check that `beoutos-boot.target` and associated systemd units are included in the chroot:

```bash
# Verify systemd units are present
ls live-build/config-includes.chroot/etc/systemd/system/horus-*.service
```

### 7.5 Missing Dependencies

**Problem**: `build.sh` fails at the dependency check stage.

```
[ERROR] Missing required dependencies:
  - lb
  - xorriso
```

**Solution**: Install all dependencies per [Section 2.1](#21-install-all-prerequisites-on-debian-12). The `build.sh` check covers: `lb`, `mksquashfs`, `debootstrap`, `cmake`, `make`, `gcc`, `g++`, `dpkg`, `apt`, `xorriso`, `sha256sum`.

**Problem**: `build.sh` reports insufficient disk space.

```
[ERROR] Insufficient disk space. Need at least 10 GB, have 5.2 GB
```

**Solution**: Free disk space or move the project to a larger filesystem:

```bash
# Check current space
df -h .

# Clean previous build artifacts first:
./build.sh clean
```

---

## 8. Testing the Build

### 8.1 Boot in QEMU (UEFI)

The recommended method for testing the BeoutOS ISO. Requires OVMF UEFI firmware:

```bash
# Install QEMU and UEFI firmware
sudo apt install -y qemu-system-x86 ovmf

# Boot the ISO with UEFI support:
qemu-system-x86_64 \
    -m 4096 \
    -smp 2 \
    -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd \
    -drive if=pflash,format=raw,file=/tmp/ovmf_vars.fd \
    -cdrom build/beoutos-1.0.0-sentinel-amd64.iso \
    -boot d \
    -net nic,model=e1000 \
    -net user \
    -display gtk \
    -serial mon:stdio

# Create a writable OVMF variables file first (required for UEFI):
cp /usr/share/OVMF/OVMF_VARS_4M.fd /tmp/ovmf_vars.fd
```

**Explanation of options**:

| Option | Purpose |
|---|---|
| `-m 4096` | 4 GB RAM (minimum for Suricata IDS) |
| `-smp 2` | 2 virtual CPU cores |
| `-drive if=pflash,...OVMF_CODE_4M.fd` | UEFI firmware code (read-only) |
| `-drive if=pflash,...ovmf_vars.fd` | UEFI variable store (writable copy) |
| `-cdrom ...iso` | Mount the BeoutOS ISO |
| `-boot d` | Boot from CD-ROM |
| `-net nic,model=e1000` | Intel e1000 NIC (compatible with BeoutOS drivers) |
| `-net user` | User-mode networking (NAT) |
| `-display gtk` | Graphical display for console interaction |

**Alternative: serial-only boot** (for scripted testing):

```bash
qemu-system-x86_64 \
    -m 4096 \
    -smp 2 \
    -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd \
    -drive if=pflash,format=raw,file=/tmp/ovmf_vars.fd \
    -cdrom build/beoutos-1.0.0-sentinel-amd64.iso \
    -boot d \
    -net nic,model=e1000 \
    -net user \
    -nographic \
    -serial mon:stdio
```

**Testing with a virtual disk** (to test the installer):

```bash
# Create a 8 GB virtual disk for installation
qemu-img create -f qcow2 /tmp/horus-test-disk.qcow2 8G

qemu-system-x86_64 \
    -m 4096 \
    -smp 2 \
    -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd \
    -drive if=pflash,format=raw,file=/tmp/ovmf_vars.fd \
    -cdrom build/beoutos-1.0.0-sentinel-amd64.iso \
    -drive if=virtio,file=/tmp/horus-test-disk.qcow2,format=qcow2 \
    -boot d \
    -net nic,model=e1000 \
    -net user \
    -display gtk \
    -serial mon:stdio
```

### 8.2 Boot in VMware

1. Convert the ISO to an OVF-compatible format or use it directly:
   - VMware Workstation/Fusion can boot ISO images directly
2. Create a new VM:
   - **Guest OS**: Debian 12 x64 (or Other Linux 3.x kernel 64-bit)
   - **Memory**: 4096 MB minimum
   - **CPU**: 2 cores
   - **Disk**: 8 GB minimum (for installation testing)
   - **Network**: E1000 or VMXNET3 adapter
3. Mount the ISO as the CD/DVD drive
4. Set firmware to **UEFI** (not BIOS): VM Settings → Options → Advanced → Firmware type → UEFI
5. Boot the VM

### 8.3 Boot in VirtualBox

1. Create a new VM:
   - **Name**: BeoutOS
   - **Type**: Linux
   - **Version**: Debian (64-bit)
   - **Memory**: 4096 MB
   - **CPU**: 2 cores
   - **Disk**: 8 GB (for installation testing)
2. Enable EFI: VM Settings → System → Motherboard → ✓ Enable EFI (only OS)
3. Mount the ISO: VM Settings → Storage → Controller: IDE → Empty CD → Choose disk file → select `beoutos-1.0.0-sentinel-amd64.iso`
4. Network: VM Settings → Network → Adapter 1 → Bridged or NAT → Intel PRO/1000 (Bridged adapter)
5. Boot the VM

### 8.4 What to Verify

After booting the ISO in any virtualization platform, verify these critical behaviors:

| Check | Expected Behavior | How to Verify |
|---|---|---|
| **GRUB menu appears** | Two entries: "BeoutOS" and "BeoutOS Installer (Provisioning Mode)" | Visual inspection at boot |
| **No shell access** | No root shell, no SSH, no debug console in normal boot | Attempt Ctrl+Alt+F2 — should show blank or locked tty |
| **Provisioning menu** | The provisioning daemon displays a setup menu on the console (tty/console) | Visual inspection — the `horus-provisioning` service claims the console |
| **Read-only filesystem** | Root filesystem is SquashFS (read-only); OverlayFS mounted on top | `mount | grep squashfs` and `mount | grep overlay` inside the system |
| **No persistent writes** | Changes in live mode do not persist across reboot | Modify a file, reboot, verify it's gone |
| **Systemd target** | System boots to `beoutos-boot.target`, not `multi-user.target` | `systemctl get-default` should show `beoutos-boot.target` |
| **Daemons present** | All `horus-*` binaries exist at `/usr/bin/horus-*` | `ls /usr/bin/horus-*` |
| **Services loaded** | systemd unit files are present | `systemctl list-unit-files | grep horus` |
| **Network interfaces** | At least one network interface is detected | `ip link show` |

---

## 9. Clean Build

### 9.1 Using build.sh

```bash
./build.sh clean
```

This removes:

1. **The entire `build/` directory** — including ISO, binaries, CMake artifacts, and logs
2. **live-build workspace** — runs `lb clean --all` inside the `live-build/` directory, removing the chroot, binary staging area, and generated configuration

The following are **NOT removed** by `./build.sh clean`:

- Source code (`src/`)
- Configuration (`config/`)
- Installer scripts (`installer/`)
- Utility scripts (`scripts/`)
- Systemd unit files (`systemd/`)
- Live-build custom includes (`live-build/config-includes.chroot/`) — **note**: the C++ binaries installed here by CMake will persist; delete them manually if needed
- Live-build package lists (`live-build/config-package-lists/`)
- Live-build hooks (`live-build/config-hooks/`)
- Git history

### 9.2 Using Makefile

```bash
make clean
```

Equivalent to `./build.sh clean` — calls the same script.

### 9.3 Manual Deep Clean

To remove absolutely everything (including C++ binaries in live-build includes):

```bash
# Standard clean
./build.sh clean

# Remove installed binaries from live-build includes
rm -rf live-build/config-includes.chroot/usr/bin/horus-*
rm -rf live-build/config-includes.chroot/usr/lib/horus/
rm -rf live-build/config-includes.chroot/etc/horus/
rm -rf live-build/config-includes.chroot/var/horus/

# Remove CMake cache (if it persists)
rm -rf build/cmake/

# Remove any leftover chroot (if lb clean failed)
rm -rf live-build/chroot/
rm -rf live-build/binary/
```

### 9.4 Partial Clean

To clean only specific components:

```bash
# Clean only C++ build artifacts (keep ISO and logs):
rm -rf build/cmake/
rm -rf build/bin/
rm -rf live-build/config-includes.chroot/usr/bin/horus-*
rm -rf live-build/config-includes.chroot/usr/lib/horus/

# Clean only live-build chroot (keep C++ binaries and config):
cd live-build/
lb clean --chroot
cd ../

# Clean only the ISO output (keep everything else):
rm -f build/horus-*.iso
rm -f build/horus-*.iso.sha256
```

---

## 10. Release Build

### 10.1 Version Bump

Before creating a production release, update version identifiers in both configuration files:

```bash
# Edit config/global.conf:
BEOUTOS_VERSION=1.1.0           # New version
BEOUTOS_CODENAME=vanguard       # New codename
ISO_VOLUME_ID=BEOUTOS_1_1_VANGUARD

# Edit config/versions.conf:
BEOUTOS_VERSION=1.1.0
BEOUTOS_CODENAME=vanguard
BEOUTOS_BUILD_NUMBER=1          # Increment for each release build
BEOUTOS_RELEASE_TYPE=stable     # Set to "stable" for production

# Also update daemon versions if they changed:
BEOUTOS_CLI_VERSION=1.1.0
BEOUTOS_PROVISIONING_VERSION=1.1.0
# ... etc.

# Update CMakeLists.txt project version:
# In src/CMakeLists.txt, change:
#   project(horus VERSION 1.1.0 ...)
```

### 10.2 Signed Build

A production release must be cryptographically signed. The `scripts/sign-update.sh` utility creates a signed update bundle containing the package, SHA256 checksum, digital signature, and a JSON manifest:

```bash
# First, generate a release key pair (if you don't have one):
openssl genpkey -algorithm ED25519 -out horus-release-1.1.key
openssl pkey -in horus-release-1.1.key -pubout -out horus-release-1.1.pub

# Build the ISO:
./build.sh all

# Sign the ISO as an update bundle:
./scripts/sign-update.sh \
    --package build/horus-1.1.0-vanguard-amd64.iso \
    --key horus-release-1.1.key \
    --pubkey horus-release-1.1.pub \
    --output build/release/

# This creates:
#   build/release/horus-1.1.0-vanguard-amd64-signed.tar.gz
#   Containing:
#     - horus-1.1.0-vanguard-amd64.iso
#     - SHA256SUMS          (checksum of the ISO)
#     - SHA256SUMS.sig      (Ed25519 signature of the checksum)
#     - MANIFEST.json       (product, version, build date, sizes, signing key info)
```

The `sign-update.sh` script:
1. Generates a SHA256 checksum of the package
2. Signs the checksum file with the private key using `openssl dgst -sha256 -sign`
3. Verifies the signature against the public key (if provided)
4. Creates a JSON manifest with product metadata, package size, SHA256 hash, build date, and signing key identifier
5. Bundles everything into a `.tar.gz` archive

### 10.3 Secure Boot Signing

For production deployments on hardware with Secure Boot enabled, the EFI bootloader and kernel must be signed with a MOK (Machine Owner Key):

```bash
# Generate a MOK key pair:
openssl req -new -x509 -newkey rsa:2048 -keyout MOK.key -out MOK.crt -days 3650 -subj "/CN=Beout Security MOK/"

# Export the DER-format certificate (needed by mokutil on target):
openssl x509 -in MOK.crt -outform DER -out MOK.der

# Sign the EFI boot image:
sbsign --key MOK.key --cert MOK.crt \
    live-build/binary/boot/grub/BOOTX64.EFI \
    --output live-build/binary/boot/grub/BOOTX64.EFI.signed

# Or sign after ISO creation by extracting and re-signing:
# Extract BOOTX64.EFI from ISO, sign it, and repack the ISO

# Alternative: sign during live-build via a hook:
# Create live-build/config-hooks/live/99-sign-efi.hook.chroot:
#!/bin/bash
sbsign --key /path/to/MOK.key --cert /path/to/MOK.crt \
    /boot/grub/BOOTX64.EFI
```

The `MOK.der` certificate must be enrolled on each target appliance during initial provisioning using `mokutil --import MOK.der`.

### 10.4 Update Bundle Creation

For A/B updates on deployed appliances, create a signed update bundle containing only the SquashFS rootfs (not the full ISO):

```bash
# Create the SquashFS for the update:
./scripts/create-squashfs.sh \
    --source live-build/chroot/ \
    --output build/horus-1.1.0-vanguard-rootfs.squashfs \
    --compress xz \
    --verify

# Package as an update tarball:
tar -czf build/horus-1.1.0-vanguard-update.tar.gz \
    -C build/ \
    horus-1.1.0-vanguard-rootfs.squashfs

# Sign the update bundle:
./scripts/sign-update.sh \
    --package build/horus-1.1.0-vanguard-update.tar.gz \
    --key horus-release-1.1.key \
    --pubkey horus-release-1.1.pub \
    --output build/release/

# Result:
#   build/release/horus-1.1.0-vanguard-update-signed.tar.gz
#   This bundle is distributed to deployed appliances and
#   applied by the horus-update daemon using A/B partition swapping
```

### 10.5 Full Release Checklist

1. Update version in `config/global.conf` and `config/versions.conf`
2. Update project version in `src/CMakeLists.txt`
3. Increment `BEOUTOS_BUILD_NUMBER`
4. Set `BEOUTOS_RELEASE_TYPE=stable`
5. Run `./build.sh clean` to start fresh
6. Run `./build.sh all` to build the ISO
7. Verify the ISO boots correctly in QEMU (see [Section 8.1](#81-boot-in-qemu-uefi))
8. Verify all checks in [Section 8.4](#84-what-to-verify)
9. Sign the ISO: `./scripts/sign-update.sh --package build/horus-<version>-<codename>-amd64.iso --key <release-key> --pubkey <release-pub>`
10. Sign EFI bootloader for Secure Boot: `sbsign --key MOK.key --cert MOK.crt <efi-image>`
11. Create the SquashFS update bundle and sign it
12. Record SHA256 checksums of all artifacts
13. Tag the git repository:
    ```bash
    git tag -a v1.1.0 -m "BeoutOS v1.1.0 vanguard release"
    git push origin v1.1.0
    ```
14. Archive the release key and MOK key securely

---

*End of Build Guide — BeoutOS v1.0.0 sentinel*
