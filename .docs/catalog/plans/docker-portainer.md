# Docker + Portainer

Container runtime and management for the workload hosts. Deployed by
`ansible/site.yml` (imports `playbooks/docker.yml`, `playbooks/portainer.yml`).

## Layout

| Host | Docker | Portainer |
|---|---|---|
| mediacenter | yes | server (BE) |
| rpi | yes | agent |
| vps | yes | agent |
| pve | no (hypervisor) | no |

Inventory groups (`ansible/inventory/hosts.yaml`): `docker_hosts` (all three),
`portainer_server` (mediacenter), `portainer_agents` (rpi, vps).

## Components

- Docker Engine via the `geerlingguy.docker` Galaxy role (`ansible/requirements.yml`).
- Portainer server: `portainer/portainer-ee:2.21.4`, UI on `9443`, `8000` for
  edge tunnels, `portainer_data` volume.
- Portainer agents: `portainer/agent:2.21.4`, listening on `9001`. Standard
  agents — the server connects out to them over the tailnet.

## One-time UI bootstrap

The playbook only deploys containers. After first apply, at
`https://mediacenter.tailb3a7a.ts.net:9443`:

1. Create the admin user.
2. Apply the free Business Edition license (covers 3 nodes — exactly this fleet).
3. Add environments → Agent, one per host, using the tailnet address:
   `rpi.tailb3a7a.ts.net:9001` and `vps.tailb3a7a.ts.net:9001`.

## Out of scope

- App workloads (Jellyfin, arr) on the containers.
- Automating admin/license/endpoint setup.
