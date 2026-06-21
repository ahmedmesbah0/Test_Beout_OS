#!/bin/sh

echo "Forcing ISO to boot into Automated Installer directly..."

# Rewrite ISOLINUX (Legacy Boot)
if [ -d binary/isolinux ]; then
    cat <<EOF > binary/isolinux/isolinux.cfg
include menu.cfg
default install
prompt 0
timeout 1
EOF

    cat <<EOF > binary/isolinux/install.cfg
label install
    menu label ^Automated Install
    linux /install/vmlinuz
    initrd /install/initrd.gz
    append vga=normal auto=true priority=critical preseed/file=/cdrom/install/preseed.cfg quiet
EOF

    cat <<EOF > binary/isolinux/menu.cfg
menu hshift 0
menu width 82
menu title Boot menu
include stdmenu.cfg
include install.cfg
EOF
fi

# Rewrite GRUB (UEFI Boot)
if [ -d binary/boot/grub ]; then
    cat <<EOF > binary/boot/grub/grub.cfg
set default=0
set timeout=1

menuentry "Automated Install" {
    linux /install/vmlinuz vga=normal auto=true priority=critical preseed/file=/cdrom/install/preseed.cfg quiet
    initrd /install/initrd.gz
}
EOF
fi
