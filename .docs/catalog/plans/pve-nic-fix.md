# pve NIC fix (e1000e Hardware Unit Hang)

pve's onboard Intel I219-LM (`eno1`, `e1000e` driver) hangs under sustained network
load — symptom is the host answering ICMP but SSH stalling at banner exchange, and
the mediacenter VM (hosted on pve) losing network with it. First seen 2026-07-11
after a fleet-wide container deploy generated sustained traffic through `eno1`; same
NIC/driver combination had this issue on the previous pve build (see old anterra
repo, `ansible/playbooks/proxmox/server/pve_fix_intel_nic_issue.yaml`).

## Fix

`scripts/pve-fix-nic.sh` — not an ansible playbook, deliberately. If the NIC has
hung, GitHub Actions and ansible can't reach pve to run anything; this has to be
run directly against the host (SSH from a machine with a working path to it, or
console).

Applies, live and persisted via a `fix-e1000e-nic.service` systemd oneshot
(runs before `network.target` on every boot):

- Ring buffers: `ethtool -G eno1 rx 4096 tx 4096`
- Offloads off: `ethtool -K eno1 tso off gso off gro off`
- EEE off: `ethtool --set-eee eno1 advertise 0`

## Recovery procedure

1. Power cycle pve.
2. Once pve SSH is reachable, stop the mediacenter VM (or at minimum `systemctl
   stop docker` on mediacenter) before it generates load — the hang can recur
   within minutes under qbittorrent/VPN traffic.
3. Run `scripts/pve-fix-nic.sh` on pve.
4. Start mediacenter back up.

Verified 2026-07-11: settings persist across a pve reboot via the systemd unit.
