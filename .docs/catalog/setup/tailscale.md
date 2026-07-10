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

The ephemeral GitHub Actions runner (`plans/ci-cd.md`) joins as
`tag:ci-runner` to Tailscale-SSH into `pve`/`rpi`/`vps` for Terraform and
Ansible. It needs its own `ssh` rule: a tag-based `src` can't use
`autogroup:self` or a bare hostname `dst` (both require a user/group `src`),
and `pve`/`rpi` are user-owned, so they can't be named directly.

Fix: tag `pve` and `rpi` with `tag:fleet-host` so the rule reaches them via
`dst: ["tag:fleet-host", ...]`. Applied per-device in the admin console
(**Machines** → device → **…** → **Edit ACL tags**).

## Device tags and MagicDNS names

Confirmed applied state (`tailscale status --json`, `.Self.Tags` / `.DNSName`):

| Device | MagicDNS name | Tag |
|---|---|---|
| pve | pve.tailb3a7a.ts.net | `tag:fleet-host` |
| rpi | rpi.tailb3a7a.ts.net | `tag:fleet-host` |
| vps | vps.tailb3a7a.ts.net | `tag:peer-relay` |
| mediacenter | mediacenter.tailb3a7a.ts.net | `tag:mediacenter` |

All four are covered by the `tag:ci-runner` SSH `dst` (`tag:fleet-host`,
`tag:peer-relay`, `tag:mediacenter`), so CI reaches every host as `root`.

`vps`'s OS hostname is `gcvpssg`; its tailnet device name (and MagicDNS name) is
`vps` — Ansible inventory targets the MagicDNS name, not the OS hostname.

## OAuth clients

Two single-tag OAuth clients (Auth Keys: Write), not one scoped to both:

- `tag:ci-runner` — `tailscale/github-action` joins the runner to the tailnet.
  Secrets: `TS_OAUTH_CLIENT_ID` / `TS_OAUTH_CLIENT_SECRET`.
- `tag:mediacenter` — Terraform's `tailscale` provider mints the VM join key
  via `tailscale_tailnet_key`. Secrets: `TS_OAUTH_MEDIACENTER_CLIENT_ID` /
  `TS_OAUTH_MEDIACENTER_CLIENT_SECRET`.

Not one shared client: a client scoped to 2+ tags rejects a request for a
subset, and neither caller requests both
([terraform-provider-tailscale#437](https://github.com/tailscale/terraform-provider-tailscale/issues/437)).

## Key expiry

**Disabled** for `pve`, `rpi`, `vps` (per-node, Machines list). With Tailscale
SSH as the access path, an expired node key means total lockout.
