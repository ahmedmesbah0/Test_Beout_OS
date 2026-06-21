#!/bin/sh
set -e

echo "Running Beout_OS Appliance Hardening..."

# 1. Disable root login & set impossible password
usermod -p '!' root
usermod -s /usr/sbin/nologin root

# 2. Disable SSH (if installed)
if systemctl is-enabled ssh 2>/dev/null; then
    systemctl disable ssh
    systemctl stop ssh
fi

# 3. Secure GRUB Bootloader
if [ -f /etc/default/grub ]; then
    sed -i 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/' /etc/default/grub
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet"/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash net.ifnames=0 biosdevname=0 audit=1 apparmor=1 security=apparmor"/' /etc/default/grub
    update-grub
fi

# 4. Restrict permissions on sensitive files
chmod 600 /etc/shadow
chmod 644 /etc/passwd
chmod 600 /etc/crontab
chmod 600 /etc/ssh/sshd_config 2>/dev/null || true

# 5. Disable unused network protocols (IPv6 optionally, SCTP, RDS, TIPC)
cat <<EOF > /etc/modprobe.d/beout_os-blacklist.conf
install dccp /bin/true
install sctp /bin/true
install rds /bin/true
install tipc /bin/true
EOF

# 6. Ensure console is locked down to our provisioning script
# (Handled by systemd service conflict with getty@tty1, but we enforce no other gettys)
systemctl mask getty@tty2.service getty@tty3.service getty@tty4.service getty@tty5.service getty@tty6.service

echo "Hardening complete."
