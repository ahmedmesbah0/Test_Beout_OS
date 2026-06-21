# BeoutOS — Architecture Overview

Complete system architecture for the BeoutOS, a commercial-grade network security platform based on Debian 12 (bookworm) Minimal.

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Boot Flow](#2-boot-flow)
3. [Filesystem Architecture](#3-filesystem-architecture)
4. [Component Architecture](#4-component-architecture)
5. [Communication Model](#5-communication-model)
6. [Security Architecture](#6-security-architecture)
7. [Network Architecture](#7-network-architecture)
8. [Update Architecture](#8-update-architecture)
9. [First Boot Flow](#9-first-boot-flow)
10. [Service Lifecycle](#10-service-lifecycle)

---

## 1. System Overview

### 1.1 What BeoutOS Is

BeoutOS is a **locked-down network security appliance operating system** designed for enterprise deployment. It provides:

- Firewall and IDS/IPS (nftables + Suricata)
- VPN gateway (OpenVPN + WireGuard)
- DNS and DHCP services (dnsmasq)
- Secure management via HTTPS Web UI and custom CLI
- License-enforced activation gating
- Immutable, read-only operating system with signed updates

### 1.2 What BeoutOS Is NOT

| NOT This | Reason |
|---|---|
| Desktop Linux distribution | No GUI, no X11, no desktop packages |
| General-purpose Debian | No apt, no shell, no root access for users |
| Development environment | No compilers, no debug tools, no IDE |
| Container host | Dedicated appliance, not a platform for other workloads |
| Router OS | Full security stack, not just packet forwarding |

### 1.3 Design Philosophy

```
┌─────────────────────────────────────────────────────┐
│                 BeoutOS Design Principles              │
├─────────────────────────────────────────────────────┤
│                                                     │
│  1. IMMUTABILITY    — OS cannot be modified         │
│  2. MINIMALISM      — Only what is needed, nothing  │
│                       more                          │
│  3. CONTROLLABILITY — Users see only what we expose │
│  4. VERIFIABILITY   — Signed updates, dm-verity    │
│  5. ISOLATION       — Config separate from OS      │
│  6. ACTIVATION      — License gates all features    │
│                                                     │
└─────────────────────────────────────────────────────┘
```

### 1.4 Target Use Cases

- Perimeter firewall with IDS/IPS
- VPN concentrator (site-to-site and remote access)
- DNS/DHCP server for network segments
- Internal network segmentation firewall
- Virtualized security appliance in cloud environments

---

## 2. Boot Flow

### 2.1 Complete Boot Sequence

```
UEFI Firmware
     │
     ├─ Secure Boot verification (if enabled)
     │  ├─ Verify EFI signature
     │  └─ Verify GRUB signature
     │
     ▼
GRUB2 Bootloader
     │
     ├─ Load vmlinuz (kernel)
     ├─ Load initrd.img (initramfs)
     ├─ Pass kernel parameters:
     │    boot=live components quiet
     │    systemd.unit=beoutos-boot.target
     │    root=/dev/disk/by-partlabel/BEOUTOS_ROOT_A
     │    ro                          (read-only root)
     │    overlay=/mnt/horus-config/overlay-upper
     │    overlay_workdir=/mnt/horus-config/overlay-work
     │
     ▼
Linux Kernel
     │
     ├─ Hardware detection
     ├─ Mount initramfs
     │
     ▼
initramfs (custom hooks)
     │
     ├─ Mount SquashFS root filesystem
     │    (from partition BEOUTOS_ROOT_A or BEOUTOS_ROOT_B)
     ├─ Mount LUKS-encrypted config partition
     │    /mnt/horus-config (encrypted, persistent)
     ├─ Set up OverlayFS:
     │    lowerdir = SquashFS root (read-only)
     │    upperdir = /mnt/horus-config/overlay-upper
     │    workdir  = /mnt/horus-config/overlay-work
     │    merged   = / (runtime root)
     ├─ Set up tmpfs overlays for volatile data:
     │    /var/run  → tmpfs
     │    /var/log  → tmpfs (or persistent on config partition)
     │    /tmp      → tmpfs
     │
     ▼
Switch to OverlayFS merged root (/)
     │
     ▼
systemd init (PID 1)
     │
     ├─ Mount remaining filesystems
     ├─ Start horus-overlay.service     (OverlayFS verification)
     ├─ Start horus-lockdown.service    (security lockdown, BEFORE basic.target)
     │    ├─ Lock root account
     │    ├─ Disable all gettys
     │    ├─ Mask ctrl-alt-del
     │    ├─ Replace bash/apt/dpkg with "Access denied" wrappers
     │    ├─ Remount /usr, /etc, /bin, /sbin, /lib as read-only
     │    ├─ Remove SUID bits
     │    ├─ Set sysctl hardening parameters
     │    ├─ Enable AppArmor
     │    └─ Disable SSH (unless flag exists)
     │
     ▼
beoutos-boot.target (custom systemd target)
     │
     ├─ Check: /mnt/horus-config/license/activated exists?
     │
     ├─ NO ──► horus-provisioning.service
     │          │
     │          ├─ Display provisioning menu on console
     │          │    1. Configure WAN
     │          │    2. Configure LAN
     │          │    3. Configure Management
     │          │    4. Activate License
     │          │    5. Finish
     │          │
     │          └─ No shell access, no escape sequences
     │
     ├─ YES ─► horus-cli.service + horus-activation.service (completed)
     │          │
     │          ├─ horus-cli on console (BeoutOS> prompt)
     │          ├─ Start firewall (nftables)
     │          ├─ Start Suricata IDS/IPS
     │          ├─ Start dnsmasq (DNS/DHCP)
     │          ├─ Start VPN services (if configured)
     │          ├─ Start nginx (HTTPS Web UI, port 443)
     │          ├─ Start horus-update.service (update manager)
     │          ├─ Start SSH (only if /mnt/horus-config/config/ssh-enabled)
     │          │
     │          └─ Operating Mode — full appliance functionality
     │
     ▼
Runtime steady state
```

### 2.2 Boot Flow Diagram

```
  ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
  │   UEFI   │────►│  GRUB2   │────►│  KERNEL  │────►│INITRAMFS │
  │ Firmware │     │Bootloader│     │ (vmlinuz)│     │(initrd)  │
  └──────────┘     └──────────┘     └──────────┘     └──────────┘
                                                              │
       Secure Boot ──► Verify signatures                      │
       GRUB config ──► ro root, overlay params                │
                                                              │
                                                              ▼
                                                     ┌────────────────┐
                                                     │  SquashFS Root │
                                                     │  (read-only)   │
                                                     └────────────────┘
                                                              │
                                                              ▼
                                                     ┌────────────────┐
                                                     │  OverlayFS     │
                                                     │  mount setup   │
                                                     └────────────────┘
                                                              │
                                                              ▼
                                                     ┌────────────────┐
                                                     │  LUKS Config   │
                                                     │  Partition     │
                                                     │  Mount         │
                                                     └────────────────┘
                                                              │
                                                              ▼
  ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
  │ systemd  │────►│ horus-   │────►│ horus-   │────►│  Boot    │
  │   init   │     │ overlay  │     │lockdown  │     │ target   │
  └──────────┘     └──────────┘     └──────────┘     └──────────┘
                                                              │
                                              ┌───────────────┴───────────────┐
                                              │                               │
                                     activated=NO                  activated=YES
                                              │                               │
                                              ▼                               ▼
                                     ┌──────────────┐           ┌──────────────────┐
                                     │ Provisioning │           │  Operating Mode  │
                                     │   Mode       │           │  (CLI + Services)│
                                     └──────────────┘           └──────────────────┘
```

---

## 3. Filesystem Architecture

### 3.1 Partition Layout

```
┌──────────────────────────────────────────────────────────┐
│                    Target Disk (GPT)                      │
├──────────┬──────────┬──────────┬──────────┬──────────────┤
│ Part 1   │ Part 2   │ Part 3   │ Part 4   │ Part 5       │
│ EFI SP   │ Boot     │ Root A   │ Root B   │ Config       │
│ 512 MB   │ 256 MB   │ ~2 GB    │ ~2 GB    │ Remaining    │
│ FAT32    │ ext4     │ SquashFS │ SquashFS │ LUKS + ext4  │
│          │          │ payload  │ payload  │ encrypted     │
├──────────┼──────────┼──────────┼──────────┼──────────────┤
│ /boot/efi│ /boot    │ Root OS  │ Update   │ /mnt/horus-  │
│          │          │ (active) │ target   │ config       │
│ GRUB EFI │ kernel   │          │ (inactive│              │
│ BOOTX64  │ initrd   │          │  or next │ config.db    │
│ .EFI     │          │          │  update) │ license      │
│          │          │          │          │ certs        │
│          │          │          │          │ vpn keys     │
│          │          │          │          │ firewall     │
│          │          │          │          │ logs         │
│          │          │          │          │ overlay-*    │
└──────────┴──────────┴──────────┴──────────┴──────────────┘
```

### 3.2 Runtime Mount Layout

```
/ (OverlayFS merged root)
 ├─ lowerdir: SquashFS on Root A partition (READ-ONLY)
 ├─ upperdir: /mnt/horus-config/overlay-upper (persistent, on LUKS partition)
 ├─ workdir:  /mnt/horus-config/overlay-work  (persistent, on LUKS partition)
 │
 ├── /usr          → SquashFS (read-only, immutable)
 ├── /etc          → OverlayFS merged (runtime changes in overlay-upper)
 ├── /bin          → SquashFS (read-only, immutable)
 ├── /sbin         → SquashFS (read-only, immutable)
 ├── /lib          → SquashFS (read-only, immutable)
 ├── /var
 │   ├── /var/run  → tmpfs (volatile, lost on reboot)
 │   ├── /var/log  → tmpfs or /mnt/horus-config/logs (persistent option)
 │   ├── /var/cache → tmpfs (volatile)
 │   └── /var/tmp  → tmpfs (volatile)
 ├── /tmp          → tmpfs (volatile, lost on reboot)
 ├── /boot         → ext4 partition (kernel, initrd)
 ├── /boot/efi     → FAT32 EFI System Partition
 ├── /mnt/horus-config → LUKS-encrypted ext4 (persistent)
 │   ├── config/       → SQLite configuration database
 │   ├── license/      → License tokens and activation flag
 │   ├── certs/        → TLS certificates and CA certs
 │   ├── vpn/          → VPN configuration and keys
 │   ├── firewall/     → Firewall rule definitions
 │   ├── logs/         → Persistent logs
 │   ├── overlay-upper/ → OverlayFS upper directory
 │   └── overlay-work/  → OverlayFS work directory
 ├── /dev          → devtmpfs (kernel-managed)
 ├── /proc         → procfs (kernel-managed)
 ├── /sys          → sysfs (kernel-managed)
 └── /run          → tmpfs (volatile)
```

### 3.3 Immutability Enforcement

| Directory | Source | Runtime Access | Modification Path |
|---|---|---|---|
| `/usr` | SquashFS | Read-only | OverlayFS upper only; remounted ro by lockdown |
| `/bin` | SquashFS | Read-only | OverlayFS upper only; remounted ro by lockdown |
| `/sbin` | SquashFS | Read-only | OverlayFS upper only; remounted ro by lockdown |
| `/lib` | SquashFS | Read-only | OverlayFS upper only; remounted ro by lockdown |
| `/etc` | SquashFS + OverlayFS | Read-write via overlay | OverlayFS upper; changes persist across reboot |
| `/var` | tmpfs + OverlayFS | Read-write via overlay | Volatile (tmpfs) or persistent (config partition) |
| `/tmp` | tmpfs | Read-write | Volatile, lost on reboot |
| `/mnt/horus-config` | LUKS encrypted ext4 | Read-write | Persistent, encrypted |

**Factory reset** destroys the overlay-upper, overlay-work, and all config partition contents. The SquashFS root remains untouched because it is on a separate partition and is inherently read-only.

---

## 4. Component Architecture

### 4.1 Daemon Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    BeoutOS Daemon Architecture                     │
├────────────────┬────────────────────────────────────────────────┤
│ Daemon         │ Responsibility                                │
├────────────────┼────────────────────────────────────────────────┤
│ horus-overlay  │ Mount OverlayFS, verify filesystem integrity   │
│ horus-lockdown │ Security lockdown: lock root, disable shell,   │
│                │ replace tools, set sysctl, enable AppArmor     │
│ horus-provision│ First boot provisioning menu (WAN/LAN/MGMT    │
│                │ config + license activation)                   │
│ horus-activation│ License activation: validate key, contact     │
│                │ license server, store signed token              │
│ horus-cli      │ Custom appliance CLI: show, ping, traceroute, │
│                │ reboot, shutdown, factory-reset                 │
│ horus-configdb │ Configuration database: SQLite-backed store    │
│                │ for interfaces, firewall rules, VPN, DNS/DHCP  │
│ horus-update   │ A/B update manager: verify signature, write   │
│                │ to inactive partition, boot switching, rollback│
├────────────────┼────────────────────────────────────────────────┤
│ horus-common   │ Shared library: logging, types, utilities,    │
│ (library)      │ database abstraction, crypto helpers           │
└────────────────┴────────────────────────────────────────────────┘
```

### 4.2 horus-overlay (OverlayFS Manager)

```
┌─────────────────────────────────────┐
│         horus-overlay               │
├─────────────────────────────────────┤
│                                     │
│ Responsibilities:                   │
│ ┌─ Mount SquashFS root partition   │
│ ├─ Mount LUKS config partition      │
│ ├─ Set up OverlayFS (lower+upper)  │
│ ├─ Set up tmpfs for volatile dirs  │
│ ├─ Verify mount integrity           │
│ ├─ Report mount status to systemd   │
│                                     │
│ Interfaces:                         │
│ ┌─ systemd: horus-overlay.service   │
│ ├─ configdb: reads mount params     │
│ ├─ kernel: mount syscalls           │
│                                     │
│ Dependencies:                       │
│ ┌─ horus-common (logging, util)     │
│                                     │
│ Failure handling:                   │
│ ┌─ If config partition unavailable: │
│ │  → mount tmpfs as fallback       │
│ │  → log critical warning          │
│ │  → system operates in degraded   │
│ │    mode (no persistence)         │
│                                     │
└─────────────────────────────────────┘
```

### 4.3 horus-provisioning (First Boot Provisioning)

```
┌─────────────────────────────────────┐
│      horus-provisioning             │
├─────────────────────────────────────┤
│                                     │
│ Responsibilities:                   │
│ ┌─ Display provisioning menu        │
│ ├─ Configure WAN interface          │
│ ├─ Configure LAN interface          │
│ ├─ Configure Management interface   │
│ ├─ Trigger license activation       │
│ ├─ Write interface config to configdb│
│ ├─ Generate Linux network config    │
│ ├─ Create activation flag on finish │
│                                     │
│ Menu structure:                     │
│ ┌─ 1. Configure WAN                 │
│ │   → IP, gateway, DNS, VLAN       │
│ ├─ 2. Configure LAN                 │
│ │   → IP, subnet, DHCP range       │
│ ├─ 3. Configure Management          │
│ │   → IP, access restrictions      │
│ ├─ 4. Activate License              │
│ │   → key input, email, activation │
│ ├─ 5. Finish                        │
│ │   → verify config, create flag   │
│                                     │
│ Security:                           │
│ ┌─ No shell escape                  │
│ ├─ No command execution             │
│ ├─ Only menu options available      │
│ ├─ Ctrl+C trapped and ignored       │
│                                     │
└─────────────────────────────────────┘
```

### 4.4 horus-activation (License Activation)

```
┌─────────────────────────────────────┐
│      horus-activation               │
├─────────────────────────────────────┤
│                                     │
│ Responsibilities:                   │
│ ┌─ Accept license key (XXXX-XXXX-  │
│ │  XXXX-XXXX format)               │
│ ├─ Accept registered email          │
│ ├─ Generate machine ID (SHA256 of   │
│ │  hardware fingerprints)          │
│ ├─ DNS connectivity test            │
│ ├─ HTTPS connection to license server│
│ ├─ Send: Machine ID + Key + Email   │
│ ├─ Receive: Signed License Token    │
│ ├─ Verify token signature           │
│ ├─ Store token in config partition   │
│ ├─ Create /mnt/horus-config/license/│
│ │  activated flag                   │
│                                     │
│ Activation flow:                    │
│ ┌─ Input key and email              │
│ ├─ Validate format                  │
│ ├─ Test DNS resolution              │
│ ├─ Test HTTPS connectivity          │
│ ├─ POST to license server           │
│ ├─ Receive signed token             │
│ ├─ Verify token (Ed25519 signature) │
│ ├─ Store token encrypted            │
│ ├─ Create activation flag           │
│ ├─ Trigger service restart          │
│                                     │
│ Failure handling:                   │
│ ┌─ Network failure → remain in      │
│ │  provisioning mode                │
│ ├─ Invalid key → display error      │
│ ├─ Server unreachable → retry queue │
│                                     │
└─────────────────────────────────────┘
```

### 4.5 horus-cli (Appliance CLI)

```
┌─────────────────────────────────────┐
│         horus-cli                   │
├─────────────────────────────────────┤
│                                     │
│ Responsibilities:                   │
│ ┌─ Provide BeoutOS> interactive prompt│
│ ├─ Parse and execute commands       │
│ ├─ Display system information       │
│ ├─ Network diagnostics              │
│ ├─ System control operations        │
│                                     │
│ Command set:                        │
│ ┌─ show interfaces  → list all NICs │
│ ├─ show routes      → routing table │
│ ├─ show firewall    → nftables rules│
│ ├─ show version     → BeoutOS version │
│ ├─ show license     → license status│
│ ├─ ping <host>      → ICMP test     │
│ ├─ traceroute <host> → path trace  │
│ ├─ reboot           → restart system│
│ ├─ shutdown         → power off     │
│ ├─ factory-reset    → wipe config   │
│                                     │
│ Security:                           │
│ ┌─ Whitelist-only command execution │
│ ├─ No shell escape (!, |, &, etc.) │
│ ├─ No command substitution          │
│ ├─ No file access commands          │
│ ├─ No process manipulation          │
│ ├─ Input sanitized before execution │
│                                     │
│ Interface:                          │
│ ┌─ console (tty1) via systemd       │
│ ├─ SSH (if enabled)                 │
│                                     │
└─────────────────────────────────────┘
```

### 4.6 horus-configdb (Configuration Database)

```
┌─────────────────────────────────────┐
│      horus-configdb                 │
├─────────────────────────────────────┤
│                                     │
│ Responsibilities:                   │
│ ┌─ Store and retrieve all appliance │
│ │  configuration                    │
│ ├─ SQLite database backend          │
│ ├─ CRUD operations for:             │
│ │  ├─ Interface configs (WAN/LAN/  │
│ │  │  MGMT)                         │
│ │  ├─ Firewall rules                │
│ │  ├─ VPN configurations            │
│ │  ├─ DNS/DHCP settings            │
│ │  ├─ License tokens                │
│ │  ├─ Certificates                  │
│ │  ├─ System settings               │
│ ├─ Generate Linux config files from │
│ │  database:                        │
│ │  ├─ /etc/network/interfaces      │
│ │  ├─ nftables rules files          │
│ │  ├─ dnsmasq.conf                  │
│ │  ├─ OpenVPN/WireGuard configs     │
│ │  ├─ nginx.conf                    │
│ ├─ Transaction support (ACID)       │
│ ├─ Change notification to services  │
│                                     │
│ Database location:                  │
│ /mnt/horus-config/config/horus.db   │
│                                     │
│ Design principle:                   │
│ ┌─ NEVER store config in /etc       │
│ ├─ ALWAYS generate /etc from DB     │
│ ├─ /etc is overlay, generated at   │
│ │  boot from database contents     │
│                                     │
└─────────────────────────────────────┘
```

### 4.7 horus-update (Update Manager)

```
┌─────────────────────────────────────┐
│      horus-update                   │
├─────────────────────────────────────┤
│                                     │
│ Responsibilities:                   │
│ ┌─ Download signed update bundles   │
│ ├─ Verify Ed25519 signature         │
│ ├─ Write SquashFS to inactive       │
│ │  partition (A/B scheme)          │
│ ├─ Update GRUB boot selection       │
│ ├─ Reboot into new partition        │
│ ├─ Verify successful boot           │
│ ├─ Commit or rollback               │
│                                     │
│ A/B Partition Logic:                │
│ ┌─ Current boot = Root A            │
│ │  → Update writes to Root B       │
│ │  → Set GRUB to boot Root B       │
│ │  → Reboot                         │
│ │  → If Root B boots OK → commit   │
│ │  → If Root B fails 3x → rollback │
│ │    to Root A                      │
│                                     │
│ Signature verification:             │
│ ┌─ SHA256 checksum of update bundle │
│ ├─ Ed25519 signature verification   │
│ ├─ Reject unsigned updates          │
│ ├─ Reject invalid signatures        │
│                                     │
│ Rollback mechanism:                 │
│ ┌─ Boot counter in GRUB environment │
│ ├─ Increment on each boot attempt   │
│ ├─ If counter > 3 → switch back to │
│ │  previous partition               │
│ ├─ Reset counter on successful boot │
│                                     │
└─────────────────────────────────────┘
```

---

## 5. Communication Model

### 5.1 Inter-Process Communication

```
┌──────────────────────────────────────────────────────────────────┐
│              BeoutOS IPC Architecture                               │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────┐                                                 │
│  │ horus.db    │ ← SQLite database (primary communication bus)  │
│  │ (SQLite3)   │                                                 │
│  │             │   Located at: /mnt/horus-config/config/horus.db │
│  │             │   Access: file locking + WAL mode               │
│  │             │   Tables: interfaces, firewall, vpn, dns,       │
│  │             │          dhcp, system, license, certs            │
│  └─────────────┘                                                 │
│        │         │         │         │                            │
│        ▼         ▼         ▼         ▼                            │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐                │
│  │provision│ │  CLI    │ │activate │ │ configdb│                │
│  │  ing    │ │         │ │         │ │ (master)│                │
│  └─────────┘ └─────────┘ └─────────┘ └─────────┘                │
│                                                                  │
│  ┌─────────────┐                                                 │
│  │ systemd     │ ← Service dependencies (After=, Wants=,        │
│  │ deps        │   ConditionPathExists=)                         │
│  │             │   Service ordering enforced by systemd          │
│  └─────────────┘                                                 │
│                                                                  │
│  ┌─────────────┐                                                 │
│  │ D-Bus      │ ← Event notifications (future enhancement)      │
│  │ (system    │   configdb publishes change signals              │
│  │  bus)      │   services subscribe to change events            │
│  └─────────────┘                                                 │
│                                                                  │
│  ┌─────────────┐                                                 │
│  │ Condition   │ ← File-based activation flags                  │
│  │ Paths       │   /mnt/horus-config/license/activated          │
│  │             │   /mnt/horus-config/config/ssh-enabled         │
│  │             │   /mnt/horus-config/config/webui-enabled       │
│  │             │   /mnt/horus-config/config/skip-lockdown       │
│  └─────────────┘                                                 │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### 5.2 Configuration Flow

```
  User Input (CLI or Web UI)
       │
       ▼
  horus-cli / nginx
       │
       ▼
  horus-configdb (write to SQLite)
       │
       ├─ Write configuration change
       ├─ Record change in history table
       ├─ Publish change notification
       │
       ▼
  Config Generation Engine (inside configdb)
       │
       ├─ Read interface configs → generate /etc/network/interfaces
       ├─ Read firewall rules   → generate nftables rules file
       ├─ Read DNS/DHCP config  → generate dnsmasq.conf
       ├─ Read VPN config       → generate OpenVPN/WireGuard configs
       ├─ Read WebUI config     → generate nginx.conf
       │
       ▼
  Write generated files to OverlayFS upper directory
       │
       ▼
  Reload affected services (systemctl reload)
```

### 5.3 Service Dependencies

| Service | Depends On | Condition |
|---|---|---|
| `horus-overlay` | `local-fs-pre.target` | Always |
| `horus-lockdown` | `horus-overlay` | `!skip-lockdown` flag |
| `horus-provisioning` | `horus-overlay`, `network-pre.target` | `!activated` flag |
| `horus-activation` | `network-online.target` | `interfaces.conf` exists, `!activated` flag |
| `horus-cli` | `horus-overlay`, `horus-activation` | `activated` flag |
| `horus-webui` | `network-online.target`, `horus-overlay` | `activated` + `webui-enabled` |
| `horus-update` | `network-online.target`, `horus-overlay` | `activated` flag |

---

## 6. Security Architecture

### 6.1 Defense Layers

```
┌───────────────────────────────────────────────────────────┐
│                  Beout Security Layers                     │
├───────────────────────────────────────────────────────────┤
│                                                           │
│  Layer 1: Boot Security                                   │
│  ├─ UEFI Secure Boot (verify EFI + GRUB + kernel)        │
│  ├─ GRUB2 locked config (no menu editing)                 │
│  ├─ Signed kernel and initrd                              │
│  └─ GRUB password protection                             │
│                                                           │
│  Layer 2: Filesystem Integrity                            │
│  ├─ SquashFS read-only root (immutable)                   │
│  ├─ OverlayFS isolation (changes in upper dir only)       │
│  ├─ LUKS encryption for config partition                  │
│  ├─ dm-verity ready (cryptographic rootfs verification)   │
│  └─ Remounted /usr, /etc, /bin, /sbin, /lib as ro        │
│                                                           │
│  Layer 3: Access Control                                  │
│  ├─ Locked root account (passwd -l root)                  │
│  ├─ No shell access (bash wrapper → "Access denied")      │
│  ├─ No package manager (apt/dpkg wrappers → "Access       │
│  │  denied")                                              │
│  ├─ No sudo installed                                     │
│  ├─ Custom CLI only (whitelist commands)                  │
│  ├─ No Ctrl+Alt+Del reboot                                │
│  ├─ No getty on any tty (replaced by horus services)     │
│                                                           │
│  Layer 4: Network Security                                │
│  ├─ HTTPS-only Web UI (port 443)                          │
│  ├─ HTTP → HTTPS redirect                                 │
│  ├─ SSH disabled by default                               │
│  ├─ SSH key-only auth when enabled                        │
│  ├─ nftables default deny firewall                        │
│  ├─ Suricata IDS/IPS traffic inspection                   │
│  ├─ Management interface isolated                         │
│                                                           │
│  Layer 5: Runtime Hardening                               │
│  ├─ AppArmor profiles for all services                    │
│  ├─ SUID/SGID bits stripped                               │
│  ├─ Kernel sysctl hardening                               │
│  ├─ Core dumps disabled                                   │
│  ├─ No compiler, no debug tools                           │
│  ├─ Minimal package set (~120 packages)                   │
│  ├─ TPM2 support for key sealing                          │
│                                                           │
│  Layer 6: Update Security                                 │
│  ├─ Ed25519 signed update bundles                         │
│  ├─ Signature verification before apply                   │
│  ├─ A/B partition rollback                                │
│  ├─ No unsigned updates accepted                          │
│                                                           │
└───────────────────────────────────────────────────────────┘
```

---

## 7. Network Architecture

### 7.1 Interface Roles

```
┌───────────────────────────────────────────────────────────┐
│              BeoutOS Network Interface Model                 │
├───────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────────┐                                         │
│  │ WAN          │ ← External/uplink interface             │
│  │ (internet)   │                                         │
│  │              │   Config: IP (static or DHCP),          │
│  │              │   gateway, DNS servers, VLAN            │
│  │              │   Firewall: default deny inbound,       │
│  │              │   allow outbound                        │
│  │              │   Suricata: inspect all traffic         │
│  └──────────────┘                                         │
│         │                                                 │
│         ▼                                                 │
│  ┌──────────────────────────────────────┐                 │
│  │          Firewall / IDS              │                 │
│  │  ┌────────┐    ┌────────────────┐    │                 │
│  │  │nftables│    │    Suricata    │    │                 │
│  │  │(filter)│    │  (inspect/IPS) │    │                 │
│  │  └────────┘    └────────────────┘    │                 │
│  └──────────────────────────────────────┘                 │
│         │                                                 │
│         ▼                                                 │
│  ┌──────────────┐                                         │
│  │ LAN          │ ← Internal/network interface            │
│  │ (protected)  │                                         │
│  │              │   Config: IP, subnet, DHCP range        │
│  │              │   Services: DNS, DHCP, VPN access       │
│  │              │   Firewall: allow specific inbound      │
│  └──────────────┘                                         │
│                                                           │
│  ┌──────────────┐                                         │
│  │ Management   │ ← Administration interface              │
│  │ (admin)      │                                         │
│  │              │   Config: IP, access restrictions       │
│  │              │   Services: HTTPS Web UI (443),         │
│  │              │   SSH (if enabled, key-only)            │
│  │              │   Firewall: allow only admin protocols  │
│  └──────────────┘                                         │
│                                                           │
└───────────────────────────────────────────────────────────┘
```

### 7.2 Configuration Generation Flow

Configuration is NOT stored in Linux files. It is stored in the SQLite database and generated at boot or on change:

```
  Database (horus.db)
  ├── interfaces table → /etc/network/interfaces
  ├── firewall table   → /etc/nftables.conf
  ├── dns table        → /etc/dnsmasq.conf
  ├── dhcp table       → /etc/dnsmasq.d/dhcp.conf
  ├── vpn table        → /etc/openvpn/server.conf
  │                    → /etc/wireguard/wg0.conf
  ├── webui table      → /etc/horus/nginx.conf
  └── system table     → /etc/horus/system.conf
                          hostname, timezone, etc.
```

When a configuration change is made via CLI or Web UI:

1. Write change to horus.db
2. configdb regeneration engine reads from database
3. Generates appropriate Linux config files to OverlayFS upper
4. Signals affected service to reload (systemctl reload)

---

## 8. Update Architecture

### 8.1 A/B Partition Scheme

```
┌──────────────────────────────────────────────────────────────┐
│                A/B Partition Update Flow                      │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  State 1: Running on Root A                                  │
│  ┌────────────┐  ┌────────────┐                              │
│  │  Root A    │  │  Root B    │                              │
│  │ (ACTIVE)   │  │ (INACTIVE) │                              │
│  │ booting ✓  │  │ empty/old  │                              │
│  └────────────┘  └────────────┘                              │
│                                                              │
│  Step 1: Download + Verify                                   │
│  ┌─ Download signed update bundle                            │
│  ├─ Verify Ed25519 signature                                 │
│  ├─ Verify SHA256 checksum                                   │
│  ├─ Reject if signature invalid                              │
│                                                              │
│  Step 2: Write to inactive partition                         │
│  ┌─ Write new SquashFS to Root B                             │
│  ├─ Verify write integrity                                   │
│  ├─ Update GRUB environment: next_boot=B                    │
│  ├─ Set boot_attempt_counter=0                               │
│                                                              │
│  State 2: Root B ready, still running on A                   │
│  ┌────────────┐  ┌────────────┐                              │
│  │  Root A    │  │  Root B    │                              │
│  │ (ACTIVE)   │  │ (STAGED)   │                              │
│  │ running    │  │ new image  │                              │
│  └────────────┘  └────────────┘                              │
│                                                              │
│  Step 3: Reboot into new partition                           │
│  ┌─ GRUB reads next_boot=B                                  │
│  ├─ Boot from Root B                                        │
│  ├─ Increment boot_attempt_counter                          │
│                                                              │
│  Step 4: Verify successful boot                              │
│  ┌─ All critical services started?                          │
│  ├─ horus-overlay.service OK?                               │
│  ├─ horus-lockdown.service OK?                              │
│  ├─ Network interfaces up?                                  │
│  ├─ If YES:                                                 │
│  │  ├─ Set current_boot=B in GRUB env                      │
│  │  ├─ Reset boot_attempt_counter=0                         │
│  │  ├─ Commit: Root B is now ACTIVE                        │
│  │  └─ Root A becomes INACTIVE (available for next update) │
│  ├─ If NO (after 3 attempts):                               │
│  │  ├─ Set next_boot=A in GRUB env                         │
│  │  ├─ Boot back to Root A (ROLLBACK)                       │
│  │  ├─ Log rollback event                                   │
│  │  └─ Report failure to management interface              │
│                                                              │
│  State 3: Running on Root B (after successful update)        │
│  ┌────────────┐  ┌────────────┐                              │
│  │  Root A    │  │  Root B    │                              │
│  │ (INACTIVE) │  │ (ACTIVE)   │                              │
│  │ old image  │  │ running ✓  │                              │
│  └────────────┘  └────────────┘                              │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

---

## 9. First Boot Flow

### 9.1 Provisioning to Operating Mode

```
  ┌───────────────────────────────────────────────────────────┐
  │              First Boot Provisioning Flow                  │
  └───────────────────────────────────────────────────────────┘

  BOOT (no /mnt/horus-config/license/activated flag)
     │
     ▼
  ┌─────────────────────────────────────────┐
  │                                         │
  │   ╔═════════════════════════════════╗   │
  │   ║  BeoutOS Initial Configuration   ║   │
  │   ║  =============================  ║   │
  │   ║                                 ║   │
  │   ║  1 Configure WAN               ║   │
  │   ║  2 Configure LAN               ║   │
  │   ║  3 Configure Management         ║   │
  │   ║  4 Activate License             ║   │
  │   ║  5 Finish                       ║   │
  │   ║                                 ║   │
  │   ║  Enter choice: _               ║   │
  │   ╚═════════════════════════════════╝   │
  │                                         │
  │   NO SHELL ACCESS                       │
  │   NO ESCAPE SEQUENCES                   │
  │   Ctrl+C TRAPPED                        │
  │                                         │
  └─────────────────────────────────────────┘
     │
     ├─ Choice 1: Configure WAN
     │   ├─ Select interface (eth0, ens33, etc.)
     │   ├─ DHCP or static IP
     │   ├─ Gateway, DNS servers
     │   ├─ Test connectivity
     │   └─ Save to configdb → generate /etc/network/interfaces
     │
     ├─ Choice 2: Configure LAN
     │   ├─ Select interface
     │   ├─ Static IP + subnet
     │   ├─ DHCP range (optional)
     │   ├─ Save to configdb
     │
     ├─ Choice 3: Configure Management
     │   ├─ Select interface
     │   ├─ Static IP
     │   ├─ Access restrictions
     │   ├─ Save to configdb
     │
     ├─ Choice 4: Activate License
     │   ├─ Enter license key: XXXX-XXXX-XXXX-XXXX
     │   ├─ Enter registered email: admin@example.com
     │   ├─ Generate machine ID from hardware
     │   ├─ DNS connectivity test
     │   ├─ HTTPS connection to license.beout.ai
     │   ├─ POST: {machine_id, license_key, email}
     │   ├─ Receive: signed license token
     │   ├─ Verify token signature
     │   ├─ Store token in /mnt/horus-config/license/
     │   ├─ Create /mnt/horus-config/license/activated flag
     │   │
     │   ├─ If activation FAILS:
     │   │   ├─ Display error message
     │   │   ├─ Remain in provisioning mode
     │   │   ├─ Allow retry
     │
     ├─ Choice 5: Finish (only if WAN + license configured)
     │   ├─ Verify all required configs present
     │   ├─ Confirm activation flag exists
     │   ├─ Disable provisioning permanently
     │   ├─ Transition to operating mode
     │
     ▼
  ┌─────────────────────────────────────────┐
  │         Operating Mode                   │
  │                                         │
  │   BeoutOS> show interfaces                │
  │   BeoutOS> show license                   │
  │                                         │
  │   Services running:                     │
  │   ├─ Firewall (nftables)                │
  │   ├─ IDS/IPS (Suricata)                │
  │   ├─ DNS/DHCP (dnsmasq)                │
  │   ├─ VPN (OpenVPN/WireGuard)            │
  │   ├─ Web UI (nginx, HTTPS 443)          │
  │   ├─ CLI (horus-cli on console)         │
  │                                         │
  └─────────────────────────────────────────┘
```

### 9.2 Activation Lock

After successful activation:

1. `/mnt/horus-config/license/activated` flag file created
2. Provisioning service exits (ConditionPathExists fails)
3. CLI service starts (ConditionPathExists succeeds)
4. All appliance services start

On future boots:
- systemd checks `/mnt/horus-config/license/activated`
- If exists → skip provisioning, start CLI + services directly
- If not exists → start provisioning

Provisioning can only be re-entered via:
- Factory reset (scripts/factory-reset.sh — deletes activated flag and all config)
- Hardware reset button (physical GPIO input detected by horus-overlay)

---

## 10. Service Lifecycle

### 10.1 Systemd Target Architecture

```
  ┌───────────────────────────────────────────────────────────┐
  │              BeoutOS Systemd Target Tree                    │
  └───────────────────────────────────────────────────────────┘

  beoutos-boot.target (custom target, default)
     │
     ├─ horus-overlay.service (BEFORE local-fs.target)
     │   └─ Mount SquashFS + OverlayFS + LUKS config
     │
     ├─ horus-lockdown.service (BEFORE basic.target)
     │   └─ Security lockdown (oneshot, RemainAfterExit)
     │
     ├─ horus-provisioning.service
     │   │  Condition: !PathExists=/mnt/horus-config/license/activated
     │   │  After: horus-overlay, network-pre.target
     │   │  Conflicts: horus-cli.service
     │   └─ Provisioning menu on console
     │
     ├─ horus-cli.service
     │   │  Condition: PathExists=/mnt/horus-config/license/activated
     │   │  After: horus-overlay, horus-lockdown
     │   │  Conflicts: horus-provisioning.service
     │   └─ BeoutOS> prompt on console
     │
     ├─ horus-activation.service
     │   │  Condition: PathExists=.../interfaces.conf
     │   │             !PathExists=.../activated
     │   │  After: network-online.target
     │   └─ License activation handler
     │
     ├─ horus-webui.service
     │   │  Condition: PathExists=.../activated
     │   │             PathExists=.../webui-enabled
     │   │  After: network-online.target, horus-overlay
     │   └─ nginx HTTPS (port 443)
     │
     ├─ horus-update.service
     │   │  Condition: PathExists=.../activated
     │   │  After: network-online.target, horus-overlay
     │   └─ Update manager daemon
     │
     ├─ Network services (after activation):
     │   ├─ nftables.service (firewall)
     │   ├─ suricata.service (IDS/IPS)
     │   ├─ dnsmasq.service (DNS/DHCP)
     │   ├─ openvpn-server@*.service (VPN)
     │   ├─ wg-quick@wg0.service (WireGuard)
     │
     ├─ SSH (conditional):
     │   ├─ ssh.service
     │   │  Condition: PathExists=.../ssh-enabled
     │
     └───────────────────┬───────────────────────
                       │
                       ▼
              multi-user.target (standard Debian)
                       │
                       ├─ dbus.service
                       ├─ systemd-logind.service
                       ├─ systemd-resolved.service (if configured)
                       └─ Other essential system services
```

### 10.2 Service Activation Decision Tree

```
                    Boot
                     │
                     ▼
            horus-overlay.service
                     │
                     ▼
            horus-lockdown.service
                     │
                     ▼
      ┌── activated flag exists? ──┐
      │                             │
     NO                            YES
      │                             │
      ▼                             ▼
horus-provisioning             horus-cli.service
  .service                       │
      │                          ├─ horus-webui.service (if webui-enabled)
      │                          ├─ horus-update.service
      │                          ├─ Firewall + Suricata
      │                          ├─ DNS/DHCP services
      │                          ├─ VPN services (if configured)
      │                          ├─ SSH (if ssh-enabled)
      │                          │
      ▼                          ▼
  Provisioning menu            Operating Mode
  on console                   (BeoutOS> prompt + all services)
      │
      ├─ WAN configured?
      │   YES → enable network
      │   NO  → remain offline
      │
      ├─ License activated?
      │   YES → create flag → restart services
      │   NO  → stay in provisioning → retry
      │
      ▼
  (loops until activation complete)
```

---

*End of Architecture Overview — BeoutOS v1.0.0 sentinel*
