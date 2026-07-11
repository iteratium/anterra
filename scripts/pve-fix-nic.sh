#!/bin/bash
# Break-glass fix for pve's Intel I219-LM (e1000e) "Hardware Unit Hang" under
# sustained load. Run this directly on pve over SSH/console when the NIC has
# wedged and GitHub Actions/ansible can't reach the host to fix it remotely.
#
# Usage: ssh pve 'bash -s' < scripts/pve-fix-nic.sh
# Or copy it to pve and run it there directly as root.

set -euo pipefail

NIC_INTERFACE=eno1
RING_BUFFER_SIZE=4096

if [ "$(id -u)" -ne 0 ]; then
  echo "must run as root" >&2
  exit 1
fi

driver=$(ethtool -i "$NIC_INTERFACE" | awk '/^driver:/ {print $2}')
if [ "$driver" != "e1000e" ]; then
  echo "expected e1000e driver on $NIC_INTERFACE, got '$driver'" >&2
  exit 1
fi

ethtool -G "$NIC_INTERFACE" rx "$RING_BUFFER_SIZE" tx "$RING_BUFFER_SIZE"
ethtool -K "$NIC_INTERFACE" tso off gso off gro off
ethtool --set-eee "$NIC_INTERFACE" advertise 0

cat > /etc/systemd/system/fix-e1000e-nic.service << EOF
[Unit]
Description=Apply e1000e NIC fixes for Hardware Unit Hang
After=network-pre.target
Before=network.target

[Service]
Type=oneshot
ExecStart=/sbin/ethtool -G $NIC_INTERFACE rx $RING_BUFFER_SIZE tx $RING_BUFFER_SIZE
ExecStart=/sbin/ethtool -K $NIC_INTERFACE tso off gso off gro off
ExecStart=/sbin/ethtool --set-eee $NIC_INTERFACE advertise 0
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable fix-e1000e-nic

echo "=== Ring Buffers ==="
ethtool -g "$NIC_INTERFACE" | grep -A4 "Current hardware"
echo "=== Offload ==="
ethtool -k "$NIC_INTERFACE" | grep -E "tcp-segmentation-offload|generic-segmentation-offload|generic-receive-offload"
echo "=== EEE ==="
ethtool --show-eee "$NIC_INTERFACE"
