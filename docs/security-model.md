# BeoutOS — Security Model

Complete security model documentation for the BeoutOS, a commercial-grade locked-down network security platform.

---

## Table of Contents

1. [Security Philosophy](#1-security-philosophy)
2. [Immutable Root Filesystem](#2-immutable-root-filesystem)
3. [Access Control](#3-access-control)
4. [Network Security](#4-network-security)
5. [Boot Security](#5-boot-security)
6. [Configuration Security](#6-configuration-security)
7. [Update Security](#7-update-security)
8. [Runtime Security](#8-runtime-security)
9. [Attack Surface Analysis](#9-attack-surface-analysis)
10. [TPM Integration](#10-tpm-integration)
11. [Credential Storage](#11-credential-storage)
12. [Threat Model](#12-threat-model)
13. [Comparison with General-Purpose Linux](#13-comparison-with-general-purpose-linux)

---

## 1. Security Philosophy

### 1.1 Appliance Security vs. General-Purpose OS Security

The BeoutOS security model is fundamentally different from securing a general-purpose Linux installation. A general-purpose OS must:

- Allow users to install software
- Permit shell access and command execution
- Support dynamic configuration changes in /etc
- Trust the administrator to make good security decisions
- Expose package management to the user

BeoutOS rejects all of these. The core philosophy is:

```
┌──────────────────────────────────────────────────────┐
│                                                      │
│   "The user cannot misconfigure what they cannot     │
│    modify, and they cannot compromise what they      │
│    cannot access."                                   │
│                                                      │
│   — Beout Security Design Principle                  │
│                                                      │
└──────────────────────────────────────────────────────┘
```

### 1.2 Core Principles

| Principle | Implementation | Rationale |
|---|---|---|
| **Immutability** | SquashFS read-only root, OverlayFS isolation | OS cannot be modified even by root at runtime |
| **Minimalism** | ~120 packages, no compilers, no debug tools | Less code = fewer vulnerabilities |
| **Controllability** | Custom CLI only, whitelist commands | Users see only what we expose |
| **Verifiability** | Signed updates, dm-verity ready | Cryptographic proof of integrity |
| **Isolation** | Config partition separate from OS | Config corruption cannot affect OS |
| **Activation Gating** | License required before operation | Unactivated appliance is inert |

### 1.3 Goal: Minimize Attack Surface

Every component, service, package, and access path that is NOT required for the appliance's security functions is removed or disabled. The result is a system where:

- There is no path to a Linux shell
- There is no path to package installation
- There is no path to arbitrary command execution
- There is no path to filesystem modification (except via OverlayFS to the config partition)
- There is no path to unauthorized network access

---

## 2. Immutable Root Filesystem

### 2.1 SquashFS Design

The BeoutOS root filesystem is a SquashFS image stored on a dedicated partition. SquashFS properties:

| Property | Value | Security Impact |
|---|---|---|
| **Compressed** | xz/zstd compression | Reduces image size, cannot be modified in-place |
| **Read-only** | inherently read-only filesystem | Even root cannot write to SquashFS without rebuilding |
| **All-root ownership** | all files owned by 0:0 | Consistent ownership, no per-user file manipulation |
| **Immutable** | cannot be modified at runtime | Runtime changes go only to OverlayFS upper |

**Key security properties of SquashFS:**

1. **No in-place modification**: SquashFS is a compressed, read-only filesystem. There is no write path. Even if an attacker gains root access, they cannot modify the SquashFS root.

2. **Rebuild required for changes**: To change the root filesystem, one must rebuild the entire SquashFS image using the build system and sign it with the release key. This requires access to the private signing key held by the BeoutOS development team.

3. **dm-verity ready**: The SquashFS partition can be protected by dm-verity, which provides cryptographic verification of every block read from the root filesystem. Any tampering with the SquashFS image on disk will be detected at boot and the system will refuse to mount it.

### 2.2 OverlayFS Isolation

OverlayFS provides the mechanism for runtime modifications while preserving root immutability:

```
  ┌─────────────────────────────────────────────┐
  │           OverlayFS Stack                    │
  │                                             │
  │  ┌─────────────────┐  ← upperdir            │
  │  │ /mnt/horus-     │    (persistent, on      │
  │  │ config/overlay- │    LUKS partition)      │
  │  │ upper           │                         │
  │  └─────────────────┘  Changes go HERE only   │
  │                                             │
  │  ┌─────────────────┐  ← workdir             │
  │  │ /mnt/horus-     │    (OverlayFS internal) │
  │  │ config/overlay- │                         │
  │  │ work            │                         │
  │  └─────────────────┘                         │
  │                                             │
  │  ┌─────────────────┐  ← lowerdir            │
  │  │ SquashFS root   │    (READ-ONLY,          │
  │  │ on Root A/B     │    immutable)           │
  │  │ partition        │                         │
  │  └─────────────────┘  NEVER modified         │
  │                                             │
  │  ┌─────────────────┐  ← merged result       │
  │  │ Runtime /       │    (what the system     │
  │  │                  │    sees)                │
  │  └─────────────────┘                         │
  └─────────────────────────────────────────────┘
```

**Security implications of OverlayFS:**

- **Upper directory isolation**: All runtime writes go to `/mnt/horus-config/overlay-upper/`, which is on the encrypted LUKS partition. This means:
  - Changes are persistent across reboots (for legitimate config changes)
  - Changes are encrypted (LUKS protects the entire partition)
  - Changes can be completely wiped (factory reset destroys overlay-upper and overlay-work, restoring the pristine SquashFS root)

- **No direct SquashFS modification**: There is no kernel path to write to the SquashFS lower layer. The OverlayFS driver only writes to the upper directory.

- **Factory reset restores pristine state**: By deleting `overlay-upper/` and `overlay-work/`, all runtime modifications are eliminated and the system returns to its original SquashFS state. This is critical for security incident response.

### 2.3 What Can and Cannot Be Modified

| Can Be Modified (via OverlayFS) | Cannot Be Modified (SquashFS) | Security Impact |
|---|---|---|
| `/etc` contents (via overlay) | `/usr` (programs, libraries) | Programs cannot be replaced |
| `/var` volatile data (tmpfs) | `/bin` (essential binaries) | Core commands cannot be swapped |
| `/mnt/horus-config/*` (config db) | `/sbin` (system binaries) | Admin commands cannot be modified |
| Generated config files (from db) | `/lib` (shared libraries) | Library injection impossible |

After the lockdown service runs, `/usr`, `/etc`, `/bin`, `/sbin`, and `/lib` are **remounted read-only** as an additional enforcement layer. Even if OverlayFS upper contains modifications to these directories, the remount prevents runtime writes to the merged view.

### 2.4 dm-verity Preparation

BeoutOS is prepared for dm-verity integration, which provides block-level cryptographic verification of the root filesystem:

```
  ┌─────────────────────────────────────────────────┐
  │              dm-verity Architecture              │
  │                                                 │
  │  SquashFS partition blocks                      │
  │       │                                         │
  │       ▼                                         │
  │  dm-verity driver                               │
  │  ├─ Hash tree verification on each block read   │
  │  ├─ Root hash stored in kernel cmdline or       │
  │  │  signed metadata                            │
  │  ├─ Any block tampering → verification failure  │
  │  ├─ System refuses to boot or returns I/O error │
  │                                                 │
  │  Benefits:                                      │
  │  ├─ Offline disk modification detected          │
  │  ├─ Boot-time integrity check                   │
  │  ├─ No performance impact (hash tree cached)    │
  │                                                 │
  │  Current status: READY (framework prepared,     │
  │  activation requires root hash generation       │
  │  in build pipeline and kernel cmdline update)   │
  └─────────────────────────────────────────────────┘
```

---

## 3. Access Control

### 3.1 Complete Lockdown Model

BeoutOS implements a **zero-shell, zero-admin** access model. The following table enumerates every access restriction:

| Restriction | Mechanism | Enforced By | Verification |
|---|---|---|---|
| **No shell access** | `/usr/bin/bash` replaced with wrapper that prints "Access denied by BeoutOS security policy" and exits | `horus-lockdown.service` ExecStartPre | Try typing `bash` at CLI → "Access denied" |
| **No root login** | `passwd -l root` (root account locked) | `horus-lockdown.service` ExecStartPre | `su -` → authentication failure |
| **No sudo** | sudo package not installed in minimal image | Package list exclusion | `sudo` → command not found |
| **No apt** | `/usr/bin/apt` replaced with "Access denied" wrapper | `horus-lockdown.service` ExecStartPre | `apt install` → "Access denied" |
| **No dpkg** | `/usr/bin/dpkg` replaced with "Access denied" wrapper | `horus-lockdown.service` ExecStartPre | `dpkg -i` → "Access denied" |
| **No getty** | All getty services masked (`systemctl mask getty@tty1.service` etc.) | `horus-lockdown.service` ExecStartPre | Ctrl+Alt+F2 → blank/locked tty |
| **No Ctrl+Alt+Del** | `ctrl-alt-del.target` masked | `horus-lockdown.service` ExecStartPre | Ctrl+Alt+Del → no effect |
| **No GRUB editing** | GRUB config: `grub-editenv set disable_menu_edit=1` | Installer bootloader.sh | Press 'e' at GRUB → blocked |
| **Custom CLI only** | `horus-cli` replaces getty on tty1 via systemd service | `horus-cli.service` | Console shows `BeoutOS>` prompt only |
| **Whitelist commands** | CLI parser rejects any command not in whitelist | `horus-cli` internal logic | `BeoutOS> ls` → "Unknown command" |
| **No command substitution** | Input parser strips `!`, `|`, `&`, `$`, `;`, backticks, `()` | `horus-cli` parser | `BeoutOS> ping 127.0.0.1;bash` → rejected |
| **No file access** | No `cat`, `less`, `more`, `vi`, `nano`, `edit` commands in CLI | CLI whitelist | `BeoutOS> cat /etc/passwd` → "Unknown command" |
| **No process manipulation** | No `kill`, `ps`, `top`, `htop` in CLI whitelist | CLI whitelist | `BeoutOS> kill 1` → "Unknown command" |

### 3.2 Access Wrapper Implementation

The lockdown service replaces critical binaries with simple wrapper scripts:

```bash
# /usr/bin/bash (replaced by lockdown)
#!/bin/sh
echo "Access denied by BeoutOS security policy."
echo "Shell access is not permitted on this appliance."
exit 1

# /usr/bin/apt (replaced by lockdown)
#!/bin/sh
echo "Access denied by BeoutOS security policy."
echo "Package management is not available on this appliance."
echo "Updates are managed by the signed update system."
exit 1

# /usr/bin/dpkg (replaced by lockdown)
#!/bin/sh
echo "Access denied by BeoutOS security policy."
echo "Package management is not available on this appliance."
exit 1
```

These wrappers are written to the OverlayFS upper directory during lockdown. They cannot be bypassed because:

1. The original binaries are on the SquashFS (read-only)
2. The OverlayFS upper layer replaces them at runtime
3. `/bin`, `/sbin`, `/usr/bin` are remounted read-only after lockdown
4. No shell exists to modify the wrapper scripts

### 3.3 SSH Access

SSH follows the most restrictive configuration:

| Setting | Value | Rationale |
|---|---|---|
| **Default state** | Disabled | No remote shell access until explicitly enabled |
| **Enable method** | Web UI only (requires authenticated admin) | Prevents unauthorized SSH enablement |
| **Authentication** | Key-only (Ed25519/RSA) | No password authentication possible |
| **PasswordAuthentication** | `no` | Explicitly disabled in sshd_config |
| **PermitRootLogin** | `no` | Root cannot SSH in even with a key |
| **AllowUsers** | `admin` | Only the appliance admin account can connect |
| **Port** | Non-standard (configurable, default not 22) | Reduces automated scan detection |
| **Banner** | "BeoutOS — Restricted Access" | Legal notice |

SSH is controlled by a systemd condition path:

```
ConditionPathExists=/mnt/horus-config/config/ssh-enabled
```

The `ssh-enabled` flag file is created only when an authenticated admin enables SSH through the Web UI. The flag is stored on the encrypted config partition.

---

## 4. Network Security

### 4.1 HTTPS Web UI

The Web UI is the primary management interface. It follows strict HTTPS-only policy:

| Setting | Value | Security Impact |
|---|---|---|
| **Protocol** | HTTPS only (TLS 1.2+) | No plaintext credential transmission |
| **Port** | 443 | Standard HTTPS port |
| **HTTP redirect** | Port 80 → 301 redirect to HTTPS | No unencrypted access possible |
| **Certificate** | Auto-generated on activation or admin-uploaded | TLS encryption enforced |
| **HSTS** | Enabled (max-age=31536000, includeSubDomains) | Browser enforces HTTPS, no downgrade |
| **TLS cipher suites** | ECDHE+AESGCM, no CBC, no RSA key exchange | Modern cipher suite only |
| **Authentication** | Session-based with CSRF protection | No credential reuse attacks |
| **Session timeout** | 15 minutes idle, 4 hours absolute | Limits session window |
| **Rate limiting** | 5 attempts per minute per IP on login | Brute-force protection |

### 4.2 Firewall Default Policy

BeoutOS uses nftables with a **default deny** policy:

```
table inet beoutos-firewall {
    chain input {
        type filter hook input priority 0; policy drop;
        # Allow established/related
        ct state established,related accept
        # Allow ICMP (limited)
        icmp type echo-request limit rate 5/second accept
        # Allow management interface HTTPS only
        iifname "mgmt0" tcp dport 443 accept
        # Allow SSH on management (if enabled)
        iifname "mgmt0" tcp dport { custom_ssh_port } accept
        # Drop everything else
        log prefix "BEOUTOS-DROP: " drop
    }
    
    chain forward {
        type filter hook forward priority 0; policy drop;
        # Rules generated from configdb firewall table
        # Allow specific flows defined by admin
    }
    
    chain output {
        type filter hook output priority 0; policy accept;
        # Allow outbound for DNS, license activation, updates
    }
}
```

### 4.3 Suricata IDS/IPS

Suricata inspects all traffic flowing through the appliance:

| Setting | Value | Purpose |
|---|---|---|
| **Mode** | IPS (inline) | Active blocking, not just detection |
| **Rules** | Emerging Threats + custom BeoutOS rules | Comprehensive threat coverage |
| **Logging** | EVE JSON to config partition | Persistent alert storage |
| **Updates** | Rule updates via signed bundles | No unsigned rule injection |

---

## 5. Boot Security

### 5.1 UEFI and Secure Boot

```
  ┌───────────────────────────────────────────────────┐
  │           Secure Boot Chain                        │
  │                                                   │
  │  UEFI Firmware                                    │
  │  ├─ Verify Platform Key (PK) — vendor enrolled    │
  │  ├─ Verify Key Exchange Key (KEK) — BeoutOS MOK     │
  │  ├─ Verify EFI bootloader signature               │
  │  │   (BOOTX64.EFI signed with MOK private key)   │
  │  │                                                │
  │  ▼                                                │
  │  GRUB2 EFI                                        │
  │  ├─ GRUB signature verified by UEFI               │
  │  ├─ GRUB loads vmlinuz                            │
  │  ├─ Kernel signature verified by GRUB             │
  │  │   (if shim or GRUB Secure Boot enabled)        │
  │  │                                                │
  │  ▼                                                │
  │  Linux Kernel                                     │
  │  ├─ Kernel verified                               │
  │  ├─ Load initrd                                   │
  │  ├─ Mount SquashFS root                           │
  │  │                                                │
  │  ▼                                                │
  │  systemd → BeoutOS services                         │
  │                                                   │
  │  Any signature failure → boot halted              │
  │  Unsigned EFI binary → refused by UEFI            │
  │  Unsigned kernel → refused by GRUB/shim           │
  │                                                   │
  └───────────────────────────────────────────────────┘
```

### 5.2 GRUB2 Lockdown

| Setting | Value | Purpose |
|---|---|---|
| **Menu editing disabled** | `grub-editenv set disable_menu_edit=1` | Users cannot modify boot parameters |
| **GRUB password** | Password hash set for superusers only | Only authorized personnel can change boot |
| **Read-only root parameter** | `ro` in kernel cmdline | Kernel mounts root as read-only |
| **Overlay parameters** | `overlay=... overlay_workdir=...` | Explicit OverlayFS configuration |
| **systemd.target** | `systemd.unit=beoutos-boot.target` | Boot into BeoutOS target, not default |
| **Quiet boot** | `quiet` | Reduces boot information leakage |
| **No single-user mode** | No rescue target available | No emergency shell access |

### 5.3 Initramfs Integrity

The initramfs contains custom hooks for OverlayFS setup. Security measures:

- Initramfs is signed alongside the kernel (Secure Boot verifies it)
- Initramfs hooks mount the SquashFS and OverlayFS before any user-space code runs
- No interactive shell in initramfs (no `break=` kernel parameter support)
- Emergency mode drops to a locked console, not a shell

---

## 6. Configuration Security

### 6.1 LUKS Encrypted Config Partition

The configuration partition is encrypted with LUKS (Linux Unified Key Setup):

| Setting | Value | Security Impact |
|---|---|---|
| **Encryption** | LUKS2 with AES-256-XTS | Strong encryption for all config data |
| **Key derivation** | PBKDF2 with high iteration count | Resistant to brute-force key extraction |
| **Key source** | TPM-sealed key (if TPM available) or passphrase | Hardware-bound decryption |
| **Mount point** | `/mnt/horus-config` | Isolated from root filesystem |
| **Auto-mount** | systemd service with cryptsetup | Decrypted at boot by horus-overlay |

**LUKS encryption ensures:**

- Configuration data is unreadable if the disk is removed from the appliance
- License tokens, VPN keys, and certificates cannot be extracted offline
- TPM binding means the partition only decrypts on the original hardware
- Brute-force attacks on the LUKS header are impractical with AES-256

### 6.2 Configuration NOT in /etc

A critical design principle: **configuration is NEVER stored directly in /etc**.

```
  ┌────────────────────────────────────────────────────┐
  │   Traditional Linux        │   BeoutOS Appliance     │
  │                            │                       │
  │   /etc/network/interfaces  │   horus.db            │
  │   /etc/resolv.conf         │   (interfaces table)  │
  │   /etc/nftables.conf       │   (firewall table)    │
  │   /etc/dnsmasq.conf        │   (dns table)         │
  │                            │   (vpn table)         │
  │   User edits /etc files    │   (system table)      │
  │   directly                 │                       │
  │                            │   → configdb generates │
  │                            │     Linux config files │
  │                            │     from database      │
  │                            │     at boot / on change│
  └────────────────────────────────────────────────────┘
```

**Why this matters:**

1. `/etc` is on the SquashFS (read-only). Even with OverlayFS, direct edits to `/etc` files would go to the overlay-upper, which is fragile and hard to manage.

2. The SQLite database provides ACID transactions, change history, and rollback capability — none of which flat files in `/etc` provide.

3. The configdb generation engine can regenerate all `/etc` files from the database on boot, ensuring consistency between the database and the running system.

4. Factory reset is simple: delete the database file and all config partition contents. The SquashFS root with its default `/etc` is untouched.

---

## 7. Update Security

### 7.1 Signed Update Bundles

All updates must be cryptographically signed. The update flow:

```
  ┌──────────────────────────────────────────────────────────┐
  │              Update Signature Flow                        │
  │                                                          │
  │  Build Pipeline:                                         │
  │  ├─ Create SquashFS image                                │
  │  ├─ SHA256 checksum of image                             │
  │  ├─ Sign checksum with Ed25519 private key               │
  │  │   (openssl dgst -sha256 -sign release_key.pem)       │
  │  ├─ Bundle: image + SHA256SUMS + SHA256SUMS.sig +       │
  │  │   MANIFEST.json                                       │
  │  │                                                       │
  │  Appliance (horus-update):                               │
  │  ├─ Download bundle                                      │
  │  ├─ Verify Ed25519 signature against embedded public key │
  │  │   (openssl dgst -sha256 -verify release_key.pub)     │
  │  ├─ If signature INVALID → REJECT, do not apply         │
  │  ├─ If signature VALID → proceed                        │
  │  ├─ Verify SHA256 checksum matches image                │
  │  ├─ Write to inactive partition                          │
  │  ├─ Update GRUB boot selection                           │
  │  ├─ Reboot into new partition                            │
  │  ├─ Verify successful boot (3 health checks)             │
  │  ├─ Commit or rollback                                   │
  │                                                          │
  │  The Ed25519 public key is embedded in the SquashFS      │
  │  root (read-only, immutable). It CANNOT be replaced      │
  │  by an attacker because it is on the SquashFS.           │
  │                                                          │
  └──────────────────────────────────────────────────────────┘
```

### 7.2 No Unsigned Updates Accepted

The `horus-update` daemon:

1. Contains the Ed25519 public key compiled into the binary (hardcoded, cannot be modified)
2. Verifies every update bundle's signature before proceeding
3. Rejects bundles with invalid or missing signatures
4. Rejects bundles where the checksum does not match the image
5. Logs all verification attempts (successful and failed)

There is no configuration option to disable signature verification. It is always enforced.

### 7.3 A/B Partition Rollback

If an update causes boot failure:

```
  Boot attempt 1 → fails (services don't start)
  Boot attempt 2 → fails (still broken)
  Boot attempt 3 → fails (third consecutive failure)
       │
       ▼
  GRUB environment: boot_attempt_counter > 3
       │
       ▼
  GRUB switches boot partition back to previous (A)
       │
       ▼
  System boots on known-good partition
       │
       ▼
  horus-update logs rollback event
  horus-update reports failure to management interface
```

The boot attempt counter is stored in GRUB's environment block, which is on the separate boot partition (not on the root SquashFS). The counter is reset to 0 after a successful boot verification.

---

## 8. Runtime Security

### 8.1 OverlayFS Upper/Work Directories

OverlayFS directories are stored on the LUKS-encrypted config partition:

| Directory | Location | Persistence | Encryption |
|---|---|---|---|
| `overlay-upper/` | `/mnt/horus-config/overlay-upper/` | Persistent, encrypted | LUKS AES-256 |
| `overlay-work/` | `/mnt/horus-config/overlay-work/` | Persistent, encrypted | LUKS AES-256 |
| `/var/run/` | tmpfs | Volatile, lost on reboot | N/A (memory only) |
| `/var/log/` | tmpfs or `/mnt/horus-config/logs/` | Configurable | LUKS if persistent |
| `/var/cache/` | tmpfs | Volatile | N/A |
| `/tmp/` | tmpfs | Volatile, lost on reboot | N/A |

### 8.2 AppArmor Profiles

All BeoutOS services run under AppArmor confinement:

| Service | Profile | Confined Operations |
|---|---|---|
| `horus-cli` | `horus-cli.profile` | Read configdb, execute whitelisted network commands, write to log |
| `horus-provisioning` | `horus-provisioning.profile` | Read/write configdb, write to OverlayFS /etc, read network state |
| `horus-activation` | `horus-activation.profile` | Read configdb, write license files, HTTPS outbound only |
| `horus-configdb` | `horus-configdb.profile` | Read/write SQLite database, write generated config files to overlay |
| `horus-overlay` | `horus-overlay.profile` | Mount/umount operations, read partition labels, write mount state |
| `horus-update` | `horus-update.profile` | Read SquashFS, write to Root B partition, update GRUB env, verify signatures |
| `nginx` | Custom BeoutOS profile | Read config, read TLS certs, bind port 443, write logs |
| `suricata` | Custom BeoutOS profile | Read rules, read/write logs, capture on network interfaces |
| `dnsmasq` | Custom BeoutOS profile | Read config, bind DNS/DHCP ports, write lease file |

AppArmor is enabled by the lockdown service and enforced from boot.

### 8.3 SUID/SGID Removal

The lockdown service strips SUID and SGID bits from all binaries except a carefully vetted whitelist:

**Binaries that retain SUID (required for operation):**

- `/usr/bin/sudo` — but sudo is NOT installed, so this is moot
- `/usr/bin/passwd` — but root is locked, users cannot change passwords
- `/usr/bin/newgrp` — required for group management
- `/usr/bin/ssh` — required for SSH client functionality

**All other SUID/SGID binaries are stripped:**

```bash
find / -perm /6000 -type f -exec chmod a-s {} \;
# Excludes: the whitelist above
```

This eliminates privilege escalation paths through SUID binaries like `chsh`, `chfn`, `mount`, `umount`, `ping` (old behavior), etc.

### 8.4 Kernel Hardening (sysctl)

| Parameter | Value | Purpose |
|---|---|---|
| `kernel.kptr_restrict` | `1` | Prevent unprivileged users from reading kernel addresses |
| `kernel.dmesg_restrict` | `1` | Prevent unprivileged users from reading kernel ring buffer |
| `kernel.core_pattern` | `|/dev/null` | Core dumps disabled, no disk writes on crash |
| `kernel.unprivileged_bpf_disabled` | `1` | Disable BPF for unprivileged users (prevents eBPF exploitation) |
| `fs.protected_symlinks` | `1` | Restrict symlink creation in world-writable directories |
| `fs.protected_hardlinks` | `1` | Restrict hardlink creation to files user owns |
| `net.ipv4.conf.all.accept_source_route` | `0` | Reject source-routed packets |
| `net.ipv4.conf.all.accept_redirects` | `0` | Reject ICMP redirects |
| `net.ipv4.conf.all.send_redirects` | `0` | Do not send ICMP redirects |
| `net.ipv4.conf.all.rp_filter` | `1` | Enable strict reverse path filtering |
| `net.ipv4.icmp_echo_ignore_broadcasts` | `1` | Ignore broadcast ICMP echo (Smurf attack prevention) |
| `net.ipv4.tcp_syncookies` | `1` | SYN flood protection |
| `net.ipv6.conf.all.accept_source_route` | `0` | IPv6 source route rejection |
| `net.ipv6.conf.all.accept_redirects` | `0` | IPv6 redirect rejection |

### 8.5 Core Dumps Disabled

Core dumps are disabled at multiple levels:

1. **kernel.core_pattern** = `|/dev/null` — kernel sends core dumps to null
2. **limits.conf** — `* hard core 0` — process core size limit is 0
3. **systemd** — `LimitCORE=0` in all BeoutOS service units

This prevents:
- Disk writes from crash dumps (information leakage)
- Core dump analysis by any user (no gdb installed anyway)
- Disk exhaustion from repeated crashes

### 8.6 No Compiler, No Debug Tools

The BeoutOS image does NOT contain:

| Removed Category | Examples | Security Impact |
|---|---|---|
| **Compilers** | gcc, g++, clang, make, cmake | Cannot compile exploit code locally |
| **Debuggers** | gdb, strace, ltrace, valgrind | Cannot analyze running processes |
| **Editors** | vim, nano, emacs | Cannot modify files (even if access existed) |
| **Download tools** | wget, curl (user-accessible) | Cannot download arbitrary files |
| **Scripting** | python3 (user-accessible), perl | Cannot run exploit scripts |
| **Network debug** | tcpdump (user-accessible), nmap | Cannot probe network from appliance |

Note: Some tools like `curl` and `tcpdump` may exist for internal daemon use but are NOT accessible through the CLI. They are in `/usr/bin/` on the SquashFS but the CLI whitelist does not include them.

---

## 9. Attack Surface Analysis

### 9.1 Exposed Interfaces

Before activation (provisioning mode):

| Interface | Port | Protocol | Access Level |
|---|---|---|---|
| Console | — | Physical/serial | Provisioning menu only |
| No network services | — | — | All ports closed |

After activation (operating mode):

| Interface | Port | Protocol | Access Level |
|---|---|---|---|
| Console | — | Physical/serial | BeoutOS> CLI (whitelist only) |
| HTTPS Web UI | 443 | TLS 1.2+ | Authenticated admin |
| HTTP redirect | 80 | HTTP → 301 to HTTPS | No content served |
| SSH | Custom | SSH key-only | Disabled by default; admin user only |
| DNS | 53 | UDP/TCP | dnsmasq (LAN interface only) |
| DHCP | 67 | UDP | dnsmasq (LAN interface only) |

**No other services listen on any interface before or after activation.**

### 9.2 Network Attack Surface

After activation, the appliance has these network-facing services:

- **WAN interface**: Firewall (nftables) and Suricata in IPS mode. No listening services on WAN.
- **LAN interface**: dnsmasq (DNS + DHCP) listening. Firewall rules control what flows through.
- **Management interface**: nginx (HTTPS 443) and optionally SSH. Both require authentication.

The attack surface per interface:

| Interface | Listening Services | Attackable Protocols |
|---|---|---|
| WAN | 0 (firewall + Suricata only) | None directly attackable |
| LAN | DNS (53), DHCP (67) | dnsmasq (well-audited, minimal) |
| Management | HTTPS (443), SSH (custom port) | nginx, OpenSSH (both heavily audited) |

### 9.3 Package Count Comparison

| System | Package Count | BeoutOS Difference |
|---|---|---|
| Debian 12 full desktop | ~1,500+ | BeoutOS has ~90% fewer packages |
| Debian 12 minimal server | ~300+ | BeoutOS has ~60% fewer packages |
| BeoutOS | ~120 | Minimal, purpose-specific |

Each package is a potential vulnerability. Fewer packages = fewer potential vulnerabilities.

---

## 10. TPM Integration

### 10.1 TPM2 Usage Model

```
  ┌──────────────────────────────────────────────────────┐
  │              TPM2 Integration                        │
  │                                                      │
  │  LUKS Key Sealing:                                   │
  │  ├─ LUKS passphrase derived from TPM2               │
  │  ├─ Key sealed to specific PCR values               │
  │  │   (PCR 0: UEFI firmware, PCR 4: boot loader,   │
  │  │    PCR 7: Secure Boot policy)                    │
  │  ├─ Partition only decrypts if:                      │
  │  │   ├─ Same TPM chip                               │
  │  │   ├─ Same firmware (PCR 0 unchanged)            │
  │  │   ├─ Same bootloader (PCR 4 unchanged)          │
  │  │   ├─ Same Secure Boot policy (PCR 7 unchanged)  │
  │  │                                                   │
  │  │  If any PCR changes → key unseal fails →        │
  │  │  partition stays encrypted → system halts        │
  │  │                                                   │
  │  Measured Boot:                                      │
  │  ├─ Each boot component extends PCR values          │
  │  ├─ UEFI → PCR 0, 1, 2, 3                         │
  │  ├─ GRUB → PCR 4, 5                                │
  │  ├─ Kernel → PCR 4, 5                              │
  │  ├─ Initrd → PCR 4, 5                              │
  │  ├─ Secure Boot policy → PCR 7                     │
  │  │                                                   │
  │  Future: Remote Attestation                          │
  │  ├─ TPM signed PCR log sent to central server      │
  │  ├─ Server verifies boot chain integrity            │
  │  ├─ Detects firmware/boot tampering remotely        │
  │  │                                                   │
  └──────────────────────────────────────────────────────┘
```

### 10.2 TPM Key Sealing Benefits

- **Hardware binding**: Config partition only decrypts on the original appliance hardware. Disk removal → encrypted, unreadable.
- **Boot chain binding**: Config partition only decrypts if the boot chain has not been tampered with (PCR values unchanged). Firmware replacement → key unseal fails.
- **Anti-cloning**: The appliance cannot be cloned to another machine. TPM-sealed keys are unique to each chip.

---

## 11. Credential Storage

### 11.1 Storage Architecture

```
  ┌──────────────────────────────────────────────────────┐
  │          Credential Storage Model                     │
  │                                                      │
  │  LUKS Partition Encryption (outer layer):            │
  │  ├─ AES-256-XTS encrypts entire partition           │
  │  ├─ All files below are encrypted at block level    │
  │  ├─ TPM-sealed key or passphrase unlocks at boot    │
  │  │                                                   │
  │  Inside /mnt/horus-config/:                          │
  │  │                                                   │
  │  ├─ config/horus.db (SQLite database)                │
  │  │   ├─ system table: admin password (bcrypt hash) │
  │  │   ├─ license table: license token (encrypted)   │
  │  │   ├─ vpn table: VPN keys (encrypted)            │
  │  │   ├─ certs table: certificates (PEM, some       │
  │  │   │   encrypted with AES-256)                   │
  │  │   │                                               │
  │  ├─ license/activated (flag file)                    │
  │  ├─ license/token.dat (signed license token)         │
  │  ├─ certs/ca.pem (CA certificate)                   │
  │  ├─ certs/server.pem (TLS server certificate)       │
  │  ├─ vpn/wg0-private.key (WireGuard private key)     │
  │  │   encrypted with AES-256-CBC, key derived from  │
  │  │   machine ID + master key                        │
  │  │                                                   │
  │  NO plaintext credentials on disk at any time.      │
  │  LUKS provides at-rest encryption.                  │
  │  Additional encryption within SQLite for sensitive   │
  │  fields.                                             │
  │                                                      │
  └──────────────────────────────────────────────────────┘
```

### 11.2 Password Storage

- Admin passwords are stored as bcrypt hashes (cost factor 12)
- No plaintext passwords anywhere on disk
- No MD5, no SHA1 — only bcrypt
- Password verification happens in memory only

### 11.3 VPN Key Storage

- WireGuard private keys stored encrypted with AES-256-CBC
- Encryption key derived from: PBKDF2(machine_id + master_salt, iterations=100000)
- OpenVPN keys stored in PKCS#12 format, encrypted with passphrase derived from machine ID
- Keys only decrypted in memory at service start time, never written to disk unencrypted

### 11.4 License Token Storage

- Signed license token stored in `/mnt/horus-config/license/token.dat`
- Token is Ed25519-signed by the license server
- Token contains: machine_id, license_key, email, expiration_date, features_enabled
- Token verified at every boot by `horus-activation`
- Token signature uses public key embedded in SquashFS (immutable)

---

## 12. Threat Model

### 12.1 What BeoutOS Defends Against

| Threat Category | Defense | Confidence |
|---|---|---|
| **Remote network attacks** | nftables default deny + Suricata IPS + minimal services | High |
| **Unauthorized configuration changes** | Config in encrypted database, no /etc access, CLI whitelist | High |
| **Shell access exploitation** | No shell, bash wrapper, locked root, no sudo | High |
| **Package injection** | No apt/dpkg, signed updates only, SquashFS immutable | High |
| **Offline disk tampering** | LUKS encryption, SquashFS immutable, dm-verity ready | High |
| **Boot chain modification** | Secure Boot, GRUB locked, signed kernel/initrd | High |
| **Supply chain attacks** | Signed updates, Ed25519 verification, hardcoded public key | Medium-High |
| **Credential extraction** | LUKS at-rest encryption, TPM binding, bcrypt hashes | High |
| **Brute-force login** | Rate limiting, key-only SSH, bcrypt (cost 12) | High |

### 12.2 What BeoutOS Assumes

| Assumption | Risk if Assumption Wrong |
|---|---|
| **Physical security for initial installation** | If attacker has physical access during install, they can modify EFI, GRUB, or disk layout |
| **Trusted network for license activation** | If MITM during activation, license server connection could be intercepted (mitigated by TLS certificate verification) |
| **Trusted build environment** | If build environment compromised, signed updates carry attacker's code (mitigated by key separation) |
| **TPM is not compromised** | TPM provides hardware-level key storage; hardware TPM attacks require specialized equipment |
| **Kernel is not exploited** | Kernel exploits bypass all user-space security (mitigated by minimal attack surface, sysctl hardening) |

### 12.3 What BeoutOS Does NOT Defend Against

| Threat | Reason | Mitigation Path |
|---|---|---|
| **Kernel-level exploits** | Kernel is the trust root; kernel compromise bypasses all security | Keep kernel updated via signed A/B updates, minimal kernel module loading |
| **Physical hardware attacks** | Bus snooping, JTAG, hardware modification | TPM provides some resistance; future: physical tamper detection |
| **TPM bypass via hardware** | Specialized equipment can extract TPM keys | Low probability for commercial deployments; future: FIPS 140-2 TPM |
| **Side-channel attacks** | Timing, power analysis | Not applicable for network appliance use case |
| **Social engineering of admin** | Admin can enable SSH, configure firewall rules | Web UI logging, change audit trail, mandatory confirmation for destructive actions |

### 12.4 Threat Model Summary

```
  ┌───────────────────────────────────────────────────────────┐
  │                                                           │
  │  HIGH CONFIDENCE defenses:                                │
  │  ├─ Remote network attacks                                │
  │  ├─ Shell access attempts                                 │
  │  ├─ Configuration tampering                               │
  │  ├─ Offline disk extraction                               │
  │  ├─ Credential brute-force                                │
  │                                                           │
  │  MEDIUM CONFIDENCE defenses:                              │
  │  ├─ Supply chain attacks (depends on build security)      │
  │  ├─ Boot chain modification (depends on Secure Boot       │
  │  │   enrollment)                                          │
  │                                                           │
  │  ACCEPTED RISKS:                                          │
  │  ├─ Kernel-level exploits (keep updated)                  │
  │  ├─ Physical hardware attacks (TPM resistance)            │
  │  ├─ Social engineering (audit trail)                      │
  │                                                           │
  └───────────────────────────────────────────────────────────┘
```

---

## 13. Comparison with General-Purpose Linux

| Security Dimension | General-Purpose Debian | BeoutOS |
|---|---|---|
| **Root access** | Available via su/sudo | Locked (passwd -l root), no sudo |
| **Shell access** | bash, zsh, fish available | bash replaced with "Access denied" wrapper |
| **Package manager** | apt fully available | apt/dpkg replaced with "Access denied" wrappers |
| **Filesystem mutability** | /usr, /etc, /bin all writable | SquashFS read-only, OverlayFS isolated |
| **Configuration storage** | Flat files in /etc | SQLite database, /etc generated from db |
| **Update model** | apt update (any source) | Signed bundles only, A/B partition with rollback |
| **Exposed services** | Whatever user installs | Minimal set (HTTPS, SSH, DNS, DHCP, VPN, IDS) |
| **Total packages** | 300-1500+ | ~120 (minimal) |
| **Attack surface** | Large (many paths to shell) | Minimal (only whitelist CLI + HTTPS) |
| **Boot security** | GRUB editable, no Secure Boot enforcement | GRUB locked, Secure Boot ready, signed kernel |
| **Credential storage** | Plaintext /etc/shadow (MD5/SHA256) | bcrypt hashes in encrypted SQLite |
| **Disk encryption** | Optional, user-configured | Mandatory LUKS on config partition |
| **Compiler availability** | gcc, g++, make available | None installed |
| **Debug tools** | gdb, strace, ltrace available | None installed |
| **SUID binaries** | 20+ SUID binaries | Stripped to essential minimum |
| **Network default policy** | Typically permissive | Default deny (nftables drop) |
| **Console access** | Full shell on tty1-6 | Provisioning menu or BeoutOS> CLI only |
| **Factory reset** | Manual reinstall | Scripted reset, preserves OS, wipes config |
| **Update rollback** | No automatic rollback | A/B partition automatic rollback on failure |

---

*End of Security Model — BeoutOS v1.0.0 sentinel*
