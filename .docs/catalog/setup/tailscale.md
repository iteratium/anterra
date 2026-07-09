# Tailscale — Fleet-Wide Setup

Manual, one-time steps in the Tailscale admin console. Applies across the fleet.

## SSH access policy

Default tailnet policy puts Tailscale SSH in `check` mode (12h browser re-auth). Replaced with an explicit `accept` rule scoped to a named group, under **Access Controls**:

```json
{
	"ssh": [
		{
			"src":    ["group:fleet-admins"],
			"dst":    ["autogroup:self", "tag:peer-relay", "tag:mediacenter"],
			"users":  ["autogroup:nonroot", "root"],
			"action": "accept",
		},
		{
			"src":    ["tag:ci-runner"],
			"dst":    ["tag:fleet-host", "tag:mediacenter", "tag:peer-relay"],
			"users":  ["autogroup:nonroot", "root"],
			"action": "accept",
		},
	],

	"nodeAttrs": [
		{
			"target": ["autogroup:members"],
			"attr":   ["funnel"],
		},
	],

	"tagOwners": {
		"tag:peer-relay":  ["group:fleet-admins"],
		"tag:mediacenter": ["group:fleet-admins"],
		"tag:ci-runner":   ["group:fleet-admins"],
		"tag:fleet-host":  ["group:fleet-admins"],
	},

	"grants": [
		{
			"src": ["*"],
			"dst": ["*"],
			"ip":  ["*"],
		},
		{
			"src": ["*"],
			"dst": ["tag:peer-relay"],
			"app": {"tailscale.com/cap/relay": []},
		},
	],

	"groups": {"group:fleet-admins": ["<user-email-id>"]},
}
```

## `tag:peer-relay`

`vps` is configured as a Tailscale Peer Relay and is tag-owned (`tag:peer-relay`) rather than user-owned — hence its explicit inclusion in `dst` above. Requires a corresponding `tagOwners` entry in the same policy file.

## `tag:mediacenter`

For the new VM being created on `pve` via Terraform — tag-owned (`group:fleet-admins`) rather than user-owned, same reasoning as `tag:peer-relay`: a headless, Terraform-created VM has no user account to tie the device to.

Added in both places `tag:peer-relay` appears:

- `tagOwners`: `"tag:mediacenter": ["group:fleet-admins"]`
- SSH `dst`: `["autogroup:self", "tag:peer-relay", "tag:mediacenter"]` — needed so `group:fleet-admins` can Tailscale-SSH into it for ops/Ansible, same as the other fleet hosts.


## `tag:ci-runner` and `tag:fleet-host`

The ephemeral GitHub Actions runner (see `plans/ci-cd.md`) needs to
Tailscale-SSH into `pve`/`rpi`/`vps` to run Terraform (snippet upload) and
Ansible. It joins the tailnet as `tag:ci-runner`, tag-owned like
`tag:peer-relay`/`tag:mediacenter`.

This needs its own `ssh` rule, separate from the `group:fleet-admins` one:
Tailscale only allows `autogroup:self` in `dst` when `src` is exclusively
users/groups, and only allows a bare hostname/named-user `dst` when `src` is
that same user — a tag-based `src` can't use either. `pve` and `rpi` are
user-owned (not tag-owned), so there was no way to name them as `dst` in a
tag-sourced rule.

Fix: tag `pve` and `rpi` themselves with a new tag, `tag:fleet-host`, so the
`tag:ci-runner` rule can reach them via `dst: ["tag:fleet-host", ...]`
instead of `autogroup:self`. Applied per-device in the admin console
(**Machines** → device → **…** → **Edit ACL tags**), not via `tailscale up`
on the device itself.

## Key expiry

**Disabled** for `pve`, `rpi`, and `vps` (per-node setting in the admin console, Machines list). With Tailscale SSH as the access path, an expired node key means total lockout.
