# Tailscale — Fleet-Wide Setup

Manual, one-time steps in the Tailscale admin console. Applies across the fleet — not duplicated per host doc.

## SSH access policy

Default tailnet policy puts Tailscale SSH in `check` mode (12h browser re-auth). Replaced with an explicit `accept` rule scoped to a named group, under **Access Controls**:

```json
"groups": {
  "group:fleet-admins": ["your-login@example.com"]
},
```
```json
"ssh": [
  {
    "src":    ["group:fleet-admins"],
    "dst":    ["autogroup:self", "tag:peer-relay"],
    "users":  ["autogroup:nonroot", "root"],
    "action": "accept",
  }
]
```

- **`group:fleet-admins`**, not `autogroup:owner` — deliberately decoupled from the tailnet's administrative Owner role. Owner is about who administers billing/the tailnet itself; this group is about who gets SSH into the fleet. Adding a co-owner later shouldn't silently grant them SSH access as a side effect.
- **`dst` needs both `autogroup:self` and `tag:peer-relay`** — tag-owned devices (like `vps`, see below) fall outside `autogroup:self`, which only covers devices owned by the connecting user's own account.
- **`action: accept`**, not `check` — this tailnet has one trusted admin group; the periodic browser re-auth step is unnecessary friction, not meaningful extra security here.

## `tag:peer-relay`

`vps` is configured as a Tailscale Peer Relay and is tag-owned (`tag:peer-relay`) rather than user-owned — hence its explicit inclusion in `dst` above. Requires a corresponding `tagOwners` entry in the same policy file.

## Key expiry

**Disabled** for `pve`, `rpi`, and `vps` (per-node setting in the admin console, Machines list). With Tailscale SSH as the access path, an expired node key means total lockout — no fallback SSH key exists once the old key/access method is retired. Treated as a lockout-avoidance measure, not a security relaxation to be "cleaned up" later.

## Per-host install steps

See `setup/pve.md` for the `tailscale up` invocation and host-specific gotchas (e.g. the `--accept-routes` conflict with `rpi`'s advertised LAN subnet). `rpi`/`vps` setup docs: not yet written.
