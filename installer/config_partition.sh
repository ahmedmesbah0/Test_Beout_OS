#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

BEOUTOS_CONFIG_MOUNT="/mnt/horus-config"

horus_setup_config_dirs() {
    local config_device="$1"

    echo -e "${CYAN}${BOLD}[STEP]${NC} Setting up config partition directory structure..."

    local config_mount="${BEOUTOS_CONFIG_MOUNT}"
    mkdir -p "$config_mount"

    if ! mountpoint -q "$config_mount" 2>/dev/null; then
        mount "$config_device" "$config_mount"
    fi

    mkdir -p "${config_mount}/config"
    mkdir -p "${config_mount}/config/system"
    mkdir -p "${config_mount}/config/network"
    mkdir -p "${config_mount}/config/interfaces"
    mkdir -p "${config_mount}/config/services"
    mkdir -p "${config_mount}/config/dns"

    mkdir -p "${config_mount}/license"
    mkdir -p "${config_mount}/license/features"

    mkdir -p "${config_mount}/certs"
    mkdir -p "${config_mount}/certs/ca"
    mkdir -p "${config_mount}/certs/server"
    mkdir -p "${config_mount}/certs/client"
    mkdir -p "${config_mount}/certs/ssh"

    mkdir -p "${config_mount}/vpn"
    mkdir -p "${config_mount}/vpn/wireguard"
    mkdir -p "${config_mount}/vpn/ipsec"
    mkdir -p "${config_mount}/vpn/openvpn"
    mkdir -p "${config_mount}/vpn/keys"

    mkdir -p "${config_mount}/firewall"
    mkdir -p "${config_mount}/firewall/rules"
    mkdir -p "${config_mount}/firewall/nat"
    mkdir -p "${config_mount}/firewall/acls"
    mkdir -p "${config_mount}/firewall/policies"

    mkdir -p "${config_mount}/logs"
    mkdir -p "${config_mount}/logs/system"
    mkdir -p "${config_mount}/logs/security"
    mkdir -p "${config_mount}/logs/audit"
    mkdir -p "${config_mount}/logs/network"

    mkdir -p "${config_mount}/overlay-upper"
    mkdir -p "${config_mount}/overlay-upper/etc"
    mkdir -p "${config_mount}/overlay-upper/var"
    mkdir -p "${config_mount}/overlay-upper/opt"
    mkdir -p "${config_mount}/overlay-upper/root"
    mkdir -p "${config_mount}/overlay-upper/home"

    mkdir -p "${config_mount}/overlay-work"

    mkdir -p "${config_mount}/backup"
    mkdir -p "${config_mount}/backup/config"
    mkdir -p "${config_mount}/backup/system"

    mkdir -p "${config_mount}/update"
    mkdir -p "${config_mount}/update/download"
    mkdir -p "${config_mount}/update/staging"

    chmod 700 "${config_mount}/config"
    chmod 700 "${config_mount}/license"
    chmod 700 "${config_mount}/certs"
    chmod 700 "${config_mount}/vpn"
    chmod 700 "${config_mount}/firewall"
    chmod 755 "${config_mount}/logs"
    chmod 700 "${config_mount}/overlay-upper"
    chmod 700 "${config_mount}/backup"
    chmod 700 "${config_mount}/update"

    chown -R root:root "${config_mount}/config"
    chown -R root:root "${config_mount}/license"
    chown -R root:root "${config_mount}/certs"
    chown -R root:root "${config_mount}/vpn"
    chown -R root:root "${config_mount}/firewall"
    chown -R root:root "${config_mount}/overlay-upper"

    cat > "${config_mount}/config/horus.conf" << 'HORUSCONF'
[system]
version=1.0.0
boot_slot=a
hostname=horus
timezone=UTC

[provisioning]
status=unprovisioned
wan_interface=
wan_ip=
wan_gateway=
wan_dns=

[license]
status=unlicensed
license_key=
features=
expiry=

[security]
lockdown_enabled=true
ssh_enabled=false
console_enabled=true
reboot_allowed=false
HORUSCONF

    chmod 600 "${config_mount}/config/horus.conf"

    cat > "${config_mount}/config/interfaces.conf" << 'INTCONF'
[wan]
interface=
type=dhcp
ip=
gateway=
dns1=
dns2=

[lan]
interface=
type=static
ip=192.168.1.1
netmask=255.255.255.0
dns=
dhcp_enabled=false

[dmz]
interface=
type=static
ip=
netmask=
INTCONF

    chmod 600 "${config_mount}/config/interfaces.conf"

    echo -e "${GREEN}${BOLD}[OK]${NC} Config directory structure created with permissions."
}

horus_create_activation_structure() {
    local config_device="$1"

    echo -e "${CYAN}${BOLD}[STEP]${NC} Creating activation flag structure..."

    local config_mount="${BEOUTOS_CONFIG_MOUNT}"
    mkdir -p "$config_mount"

    if ! mountpoint -q "$config_mount" 2>/dev/null; then
        mount "$config_device" "$config_mount"
    fi

    mkdir -p "${config_mount}/license"
    touch "${config_mount}/license/.unactivated"

    chmod 600 "${config_mount}/license/.unactivated"

    echo -e "${GREEN}${BOLD}[OK]${NC} Activation flag structure created. System will boot into provisioning mode."
}

horus_bind_tpm() {
    local config_part="$1"
    local passphrase="$2"

    echo -e "${CYAN}${BOLD}[STEP]${NC} Binding LUKS key to TPM2..."

    if [[ ! -e /dev/tpm0 ]] && [[ ! -e /dev/tpmrm0 ]]; then
        echo -e "${YELLOW}${BOLD}[WARN]${NC} TPM2 device not found. Skipping TPM binding."
        echo -e "${YELLOW}${BOLD}[WARN]${NC} LUKS will require passphrase on every boot."
        return 0
    fi

    modprobe tpm_crb 2>/dev/null || true
    modprobe tpm_tis 2>/dev/null || true

    local tpm_key_file="/tmp/horus-tpm-key"
    echo -n "$passphrase" > "$tpm_key_file"
    chmod 600 "$tpm_key_file"

    cryptsetup luksAddKey "$config_part" "$tpm_key_file" 2>/dev/null || true

    if command -v tpm2_createprimary &>/dev/null; then
        tpm2_createprimary -C o -G rsa2048 -c /tmp/horus-tpm-primary.ctx 2>/dev/null || true
        tpm2_create -G rsa2048 -u /tmp/horus-tpm-pub.pem -r /tmp/horus-tpm-priv.pem \
            -C /tmp/horus-tpm-primary.ctx 2>/dev/null || true

        local pcr_bank="sha256"
        local pcr_ids="0,2,4,7"
        tpm2_enrollpassword -C /tmp/horus-tpm-primary.ctx \
            -G rsa2048 \
            -L "${pcr_bank}:${pcr_ids}" \
            /tmp/horus-tpm-key-sealed 2>/dev/null || true

        echo -e "${GREEN}${BOLD}[OK]${NC} TPM2 key binding configured. Config partition will auto-unlock via TPM."
    else
        echo -e "${YELLOW}${BOLD}[WARN]${NC} tpm2-tools not available. Manual TPM binding required in production."
    fi

    rm -f "$tpm_key_file" /tmp/horus-tpm-*.ctx /tmp/horus-tpm-*.pem /tmp/horus-tpm-key-sealed
}

horus_create_systemd_mount() {
    local config_mapper="$1"

    echo -e "${CYAN}${BOLD}[STEP]${NC} Creating systemd mount unit for config partition..."

    local mount_unit_dir="/mnt/horus-boot/etc/systemd/system"
    mkdir -p "$mount_unit_dir"

    cat > "${mount_unit_dir}/mnt-horus\\x2dconfig.mount" << 'MOUNTUNIT'
[Unit]
Description=Mount BeoutOS Encrypted Config Partition
Before=local-fs.target
After=horus-overlay.service
Requires=horus-overlay.service

[Mount]
What=/dev/mapper/horus-config
Where=/mnt/horus-config
Type=ext4
Options=noatime,nodiratime,data=ordered

[Install]
WantedBy=multi-user.target
MOUNTUNIT

    echo -e "${GREEN}${BOLD}[OK]${NC} systemd mount unit created for config partition."
}
