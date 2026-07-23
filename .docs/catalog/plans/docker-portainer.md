# Docker + Portainer

Container runtime and management for the workload hosts. Deployed by
`ansible/site.yml` (imports `playbooks/docker.yml`, `playbooks/portainer.yml`).

## Layout

| Host | Docker | Portainer | Endpoint id |
|---|---|---|---|
| mediacenter | yes | server (BE) | 2 |
| rpi | yes | agent | 3 |
| vps | yes | agent | 4 |
| pve | no (hypervisor) | no | — |

Endpoint ids are needed for any `portainer_stack` Terraform resource
targeting a host (`mediacenter_endpoint_id`, `rpi_endpoint_id`,
`vps_endpoint_id` in `terraform/portainer/variables.tf`); see
`watchtower.md` for why Watchtower went via Ansible instead.

Inventory groups (`ansible/inventory/hosts.yaml`): `docker_hosts` (all three),
`portainer_server` (mediacenter), `portainer_agents` (rpi, vps).

## Components

- Docker Engine via the `geerlingguy.docker` Galaxy role (`ansible/requirements.yml`).
- Portainer server: `portainer/portainer-ee:2.43.0`, UI on `9443`, `8000` for
  edge tunnels, `portainer_data` volume.
- Portainer agents: `portainer/agent:2.43.0`, listening on `9001`. Standard
  agents — the server connects out to them over the tailnet. Keep the agent
  version matched to the server version.

## Trusted origins (CSRF, since 2.41)

Portainer 2.41+ enforces CSRF protection: every hostname used to reach the UI
must be listed as a full URL (scheme + optional port) or requests 403 /
the server fails to start. The server container runs with
`--trusted-origins=https://portainer.{{ domain_name }},https://{{ ansible_host }}:9443`
covering both the Caddy-proxied hostname and the direct tailnet URL. Add any
new hostname used to reach Portainer to this flag.

## One-time UI bootstrap

The playbook only deploys containers. After first apply, at
`https://mediacenter.tailb3a7a.ts.net:9443`:

1. Create the admin user.
2. Apply the free Business Edition license (covers 3 nodes — exactly this fleet).
3. Add environments → Docker Standalone → Agent, one per host, using the
   tailnet IP: `<host-100.x>:9001`. Use the IP, not the MagicDNS name —
   MagicDNS does not resolve inside the Portainer container (its resolver is the
   LAN DNS, not `100.100.100.100`). This assigns the endpoint ids in the Layout
   table above.

## Out of scope

- App workloads (Jellyfin, arr) on the containers.
- Automating admin/license/endpoint setup.
