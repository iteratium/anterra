# vps — Manual Setup

## Tailscale

```bash
tailscale up --ssh --accept-routes=true
```

(try without `sudo` first, add it only if it errors on permissions)

- **`--accept-routes=true`** — the opposite of `pve`/`rpi`, and deliberately so. `pve`/`rpi` sit directly on the India LAN, so accepting `rpi`'s advertised `10.0.0.0/22` route conflicts with their own direct connection (see `setup/pve.md`). `vps` is in Singapore, not on that LAN — it needs to accept that route to reverse-proxy external traffic through to India-LAN backends (`Internet → vps (Caddy) → Tailscale → rpi (subnet router) → LAN host`). Setting this `false` here would break every externally-published service.
- **`tag:peer-relay`** — already applied at the control-plane/registration level (auth key or admin console), not via a live `tailscale up` flag (`AdvertiseTags` is `null` in `tailscale debug prefs` even though `Tags: ["tag:peer-relay"]` shows applied) — omitting it from the command doesn't affect it. See `setup/tailscale.md`.
- **`RelayServerPort: 40000`** (Tailscale Peer Relay) — set via `tailscale set --relay-server-port=40000`, a separate command from `tailscale up`, which has no equivalent flag at all. Confirmed unaffected by this `up` invocation.
- **`ExitNodeOption`/`PrimaryRoutes`** — both unset before and after; `vps` has no subnet-router or exit-node role.

See `setup/tailscale.md` for the fleet-wide SSH ACL (`accept` mode, `group:fleet-admins`) and key-expiry setting — both apply here, not repeated per-host.

**Verify after**: `tailscale debug prefs` shows `RunSSH: true`, `RouteAll: true`, `RelayServerPort: 40000` unchanged; `ip route` on the public-facing side (`ens3`) unchanged — default route and `96.9.211.0/25` still direct, no Tailscale-related surprises.
