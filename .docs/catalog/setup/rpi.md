# rpi — Manual Setup

## Tailscale

`rpi` is the subnet router + exit node for the India LAN (`10.0.0.0/22`)

```bash
sudo tailscale up --ssh --advertise-routes=10.0.0.0/22 --advertise-exit-node --accept-routes=false
```

## Network tuning (flagged, not yet done)

`tailscale up` warned about suboptimal UDP GRO forwarding on `eth0`. 

Fix: has been run but is non-persistent

```bash
sudo ethtool -K eth0 rx-udp-gro-forwarding on rx-gro-list off
```

Permanent fix needs a boot-time hook (systemd oneshot unit or `networkd-dispatcher` script).
**Planned**: codify as an Ansible playbook (systemd unit + enable) once automation build-out starts.
