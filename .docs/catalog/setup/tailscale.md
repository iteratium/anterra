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

## `tag:mediacenter`

For the new Jellyfin/arr-stack VM being created on `pve` via Terraform — tag-owned
(`group:fleet-admins`) rather than user-owned, same reasoning as `tag:peer-relay`:
a headless, Terraform-created VM has no user account to tie the device to.

Added in both places `tag:peer-relay` appears:

- `tagOwners`: `"tag:mediacenter": ["group:fleet-admins"]`
- SSH `dst`: `["autogroup:self", "tag:peer-relay", "tag:mediacenter"]` — needed
  so `group:fleet-admins` can Tailscale-SSH into it for ops/Ansible, same as
  the other fleet hosts.

Join mechanism differs from the other three hosts: no interactive
`tailscale up --ssh` at a console, since the VM is created headlessly by
Terraform. See `terraform.md` for why this uses a Tailscale OAuth client
(scoped to this tag) minting a fresh auth key per `apply`, instead of a
manually-generated static auth key.

Still pending once the VM actually exists: disabling key expiry on the
device itself (below) — a per-device admin-console toggle, not something
the OAuth client or auth key can set.

## Key expiry

**Disabled** for `pve`, `rpi`, and `vps` (per-node setting in the admin console, Machines list). With Tailscale SSH as the access path, an expired node key means total lockout — no fallback SSH key exists once the old key/access method is retired. Treated as a lockout-avoidance measure, not a security relaxation to be "cleaned up" later.

## Per-host install steps

See `setup/pve.md` for the `tailscale up` invocation and host-specific gotchas (e.g. the `--accept-routes` conflict with `rpi`'s advertised LAN subnet). `rpi`/`vps` setup docs: not yet written.
