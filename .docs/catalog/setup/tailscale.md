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


## Key expiry

**Disabled** for `pve`, `rpi`, and `vps` (per-node setting in the admin console, Machines list). With Tailscale SSH as the access path, an expired node key means total lockout.
