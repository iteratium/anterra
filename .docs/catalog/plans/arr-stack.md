# Arr stack

Download/automation stack on `mediacenter`, deployed as a Portainer-managed stack
via Terraform (`terraform/portainer/`). All apps share one gluetun (AirVPN /
WireGuard) network namespace; if the VPN drops, every app loses network.

## Apps and ports

| App | Port | Subdomain | Exposure |
|---|---|---|---|
| qbittorrent | 8585 | `qbittorrent` | internal (rpi Caddy) |
| radarr | 7878 | `radarr` | internal |
| sonarr | 8989 | `sonarr` | internal |
| prowlarr | 9696 | `prowlarr` | internal |
| profilarr | 6868 | `profilarr` | internal |
| profilarr-parser | 5000 (internal only) | — | not exposed |
| flaresolverr | 8191 | `flaresolverr` | internal |
| seerr | 5055 | `seerr` | external (vps Caddy) |

Ports are published on the gluetun container (mediacenter host). Caddy reaches them
over the tailnet at `mediacenter.<tailnet>:<port>`; gluetun's
`FIREWALL_OUTBOUND_SUBNETS` must include the tailnet (`100.64.0.0/10`) and docker
bridge (`172.16.0.0/12`) or the WebUIs are unreachable through the killswitch.
qbittorrent's listen port must be set to the AirVPN forwarded port.

## Storage and ownership

- config -> `/mnt/fast-store/app-data/<app>` (SSD)
- downloads/seeding -> `/mnt/fast-store/downloads` (SSD)
- media -> `/mnt/bulk-store/media/{movies,tv}` (USB HDD)

No hardlinks and no mergerfs: downloads stay on the SSD, so seeding never touches the
HDD. Import copies SSD->HDD once per file; the HDD is written once and never seeds.

Ownership (Ansible `ansible/playbooks/arr-storage.yml`): user `docker` (uid 1500),
group `media` (gid 1500) own all three trees, mode `2775` (setgid). Containers run as
`PUID/PGID=1500`. `jellyfin` is added to the `media` group for read access —
deliberately not the host `docker` group, which is root-equivalent via the docker
socket.

## One-time bootstrap

1. Portainer UI: generate an API token (`PORTAINER_API_KEY`); note the mediacenter
   (local) endpoint id (`mediacenter_endpoint_id` tfvar, default 2).
2. AirVPN client area: generate a WireGuard config (private key, preshared key,
   addresses) and a forwarded port.
3. After first deploy, configure each app once: qbittorrent (creds, save path
   `/downloads/complete`, listen port = forwarded port); prowlarr -> radarr/sonarr +
   flaresolverr proxy; seerr linked to Jellyfin + radarr/sonarr; profilarr linked to a
   custom-format database (e.g. Dictionarry) and synced to radarr/sonarr. The
   `profilarr-parser` sidecar is only needed for testing custom formats/quality
   profiles before applying them.

## Verify VPN killswitch

`docker exec gluetun wget -qO- ifconfig.io` must return the AirVPN exit IP.

## Operating notes

- Apps behind gluetun share one network namespace, so they reach each other over
  `localhost`, not container names or IPs: seerr/prowlarr -> radarr at `localhost:7878`,
  sonarr `localhost:8989`, flaresolverr `http://localhost:8191`, download client
  qbittorrent `localhost:8585`. Set qbittorrent's listen port to the AirVPN forwarded
  port.
- seerr -> Jellyfin: Jellyfin runs natively on the host, outside the namespace. Point
  seerr at mediacenter's own Tailscale IP (`tailscale ip -4`) on port 8096. The MagicDNS
  name does not resolve inside the gluetun namespace, and the public hostname hairpins
  out through the VPN.
- qbittorrent: bind to VPN-only in its own settings too (Advanced -> Network
  Interface -> `tun0`, the interface gluetun's WireGuard tunnel creates) as
  defense-in-depth on top of gluetun's kill-switch.

## Auto-updates (Watchtower)

Every service in this stack, including gluetun, carries
`com.centurylinklabs.watchtower.enable=true`. Watchtower (see
[watchtower.md](watchtower.md)) runs in label-scoped mode, so only labelled
containers are touched, checking weekly. Watchtower detects `network_mode:
service:gluetun` as an implicit dependency link: when gluetun has an update, it
stops the dependents, updates and restarts gluetun, then recreates the
dependents on the new network namespace — no manual restart ordering needed.
