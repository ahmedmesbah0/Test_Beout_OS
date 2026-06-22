#!/bin/sh

echo "Configuring Beout_OS branded boot menu..."

# Rewrite ISOLINUX (Legacy BIOS Boot)
if [ -d binary/isolinux ]; then
    cat <<'EOF' > binary/isolinux/isolinux.cfg
default beout_install
prompt 0
timeout 10
EOF

    cat <<'EOF' > binary/isolinux/live.cfg
label beout_install
    menu label Beout_OS Installer
    linux /live/vmlinuz
    initrd /live/initrd.img
    append boot=live components quiet splash username=root
EOF

    cat <<'EOF' > binary/isolinux/menu.cfg
menu hshift 0
menu width 82
menu title Beout_OS Enterprise Security Appliance
include stdmenu.cfg
include live.cfg
EOF
fi

# Rewrite GRUB (UEFI Boot)
if [ -d binary/boot/grub ]; then
    cat <<'EOF' > binary/boot/grub/grub.cfg
set default=0
set timeout=1

menuentry "Beout_OS Installer" {
    linux /live/vmlinuz boot=live components quiet splash username=root
    initrd /live/initrd.img
}
EOF
fi
