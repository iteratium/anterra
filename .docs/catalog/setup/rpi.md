# rpi — Manual Setup

## Tailscale

`rpi` is already the fleet's subnet router + exit node for the India LAN (`10.0.0.0/22`) — adding SSH must preserve both, not just enable `--ssh`. Tailscale doesn't silently retain a previously-set flag if you omit it on a later `tailscale up`, so the full desired state has to be restated in one command:

```bash
sudo tailscale up --ssh --advertise-routes=10.0.0.0/22 --advertise-exit-node --accept-routes=false
```

- **`sudo` required on `rpi`** — unlike `pve`, which doesn't need it.
- **`--advertise-routes=10.0.0.0/22` and `--advertise-exit-node` are non-negotiable to include.** Omitting either would silently drop subnet-routing or exit-node duty — the only path remote clients (Japan, etc.) have into the India LAN. Confirmed live values before making this change: `PrimaryRoutes: ['10.0.0.0/22']`, `ExitNodeOption: true`.
- **`--accept-routes=false`** — explicit, matching the fleet-wide pattern from `pve` (see `setup/pve.md`). Less critical here since `rpi` advertises this subnet rather than receiving it, so the self-conflict that broke `pve`'s LAN reachability doesn't directly apply — kept explicit anyway for consistency.
- If run from a session already connected over Tailscale, expect a warning that enabling `--ssh` will disconnect the current session (traffic reroutes to Tailscale SSH) — safe to continue, reconnect after.

See `setup/tailscale.md` for the fleet-wide SSH ACL (`accept` mode, `group:fleet-admins`) and key-expiry setting — both apply here, not repeated per-host.

**Verify after**: `tailscale status --self` still shows `offers exit node`; `ip route` still shows `10.0.0.0/22 dev eth0` with no conflicting route via `tailscale0`.

## Network tuning (flagged, not yet done)

`tailscale up` warned about suboptimal UDP GRO forwarding on `eth0` — matters here specifically because `rpi` relays other devices' traffic through Tailscale (subnet router + exit node), unlike `pve`/`vps`. Fix:

```bash
sudo ethtool -K eth0 rx-udp-gro-forwarding on rx-gro-list off
```

Not persistent across reboots — needs a boot-time hook (systemd oneshot unit or `networkd-dispatcher` script). Related, already-open item: `inventory/action-items.md` #16 (`ethtool -G eth0 rx 1024`, ring-buffer size, same interface) has the same unresolved persistence gap — worth solving both in one mechanism rather than two.

**Planned**: codify as an Ansible playbook (systemd unit + enable) once automation build-out starts — not written yet, still in the manual-setup documentation phase.
