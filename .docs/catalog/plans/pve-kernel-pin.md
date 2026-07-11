# Plan: pin pve to kernel 6.17.13-2-pve (e1000e 7.0.x regression)

## Background

pve full-host hangs (ICMP answers, SSH stalls, no logs) started 2026-07-03, three days
after the opt-in upgrade from kernel 6.17.13-2-pve to the 7.0 series. All five hangs
(Jul 3, 5, 7, and two on Jul 11) occurred on 7.0.x kernels. 6.17.13-2-pve ran Apr 8 to
Jun 30 with no hangs. The ethtool mitigation (`fix-e1000e-nic.service`: ring buffers
4096, TSO/GSO/GRO off, EEE off) was confirmed active at boot and did not prevent the
7.0.x hangs. Matches Proxmox forum reports of an e1000e regression on 6.17/7.0 kernels
that persists with offloads disabled (thread 182178); no upstream fix as of Jun 2026.

Decision: pin the empirically stable kernel 6.17.13-2-pve, keep the fix service as
defense in depth, soak-test under real load.

## Execution steps

Run each step in order. If a verify fails, stop and report; do not improvise.

### 1. Preflight (read-only)

```
ssh pve "uname -r"                                  # expect: 7.0.14-4-pve
ssh pve "ls /boot/vmlinuz-6.17.13-2-pve"            # expect: file exists
ssh pve "systemctl is-enabled fix-e1000e-nic.service"  # expect: enabled
```

### 2. Pin kernel

```
ssh pve "proxmox-boot-tool kernel pin 6.17.13-2-pve"
ssh pve "proxmox-boot-tool kernel list"             # expect: 6.17.13-2-pve marked pinned
```

### 3. Reboot pve

Confirm with the user before this step (takes down all guests briefly).

```
ssh pve "reboot"
```

Wait ~2 minutes, then poll `ssh pve "uname -r"` until it answers.
Expect: `6.17.13-2-pve`. If it still shows 7.0.14-4-pve, stop and report.

### 4. Verify NIC mitigation applied on new kernel

```
ssh pve "systemctl status fix-e1000e-nic.service --no-pager"   # active (exited), all ExecStart status=0
ssh pve "ethtool -g eno1"                                      # RX 4096, TX 4096 (current)
ssh pve "ethtool -k eno1 | grep -E 'tcp-segmentation-offload|generic-segmentation-offload|generic-receive-offload'"  # all: off
ssh pve "ethtool --show-eee eno1"                              # EEE status: disabled
```

### 5. Restore load

mediacenter's docker was stopped as a precaution on 2026-07-11. Check and restart:

```
ssh mediacenter "systemctl is-active docker"
```

If inactive: `ssh mediacenter "sudo systemctl start docker.socket docker.service"`, then
`ssh mediacenter "docker ps"` and confirm the arr stack + gluetun + qbittorrent
containers come up healthy. If docker is already active, do nothing.

### 6. Soak test

Success criterion: 48 hours under normal load (qbittorrent active) with no hang.
Spot-check a few times: `ssh pve "uptime"` must answer promptly and show
monotonically increasing uptime (a reset indicates a hang + power cycle happened).

## Guardrails

- Do not run `apt upgrade`/`dist-upgrade` on pve while the pin is being evaluated.
- The pin survives kernel package upgrades; do not unpin.
- Rollback of the pin itself: `proxmox-boot-tool kernel unpin` + reboot.

## If a hang recurs on 6.17.13-2-pve

Do not retry other kernels unattended. Report to the user. Fallback candidates, in
order: kernel 6.14.11-9-pve (also in /boot; reported stable on the Proxmox forum),
then a USB3/PCIe NIC to bypass the onboard I219-LM entirely.

## Exit criteria

After a clean 48h soak: note the pinned kernel and rationale in
`.docs/catalog/servers.md` (pve entry), and revisit 7.0.x only when a
proxmox-kernel changelog mentions e1000e fixes.

## Status (2026-07-11)

Steps 1-5 complete. Kernel pinned to 6.17.13-2-pve, pve rebooted, NIC
mitigation confirmed active, mediacenter docker was already running (no
action needed).

Reboot baseline: 2026-07-11 11:49:37 IST, uptime 1 min.
Soak test (step 6) in progress, target clean through ~2026-07-13 11:49 IST.
User is monitoring manually over the coming week; no automated checks set up.
