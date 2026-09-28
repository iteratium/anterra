# Tube Archivist

YouTube archiver on `mediacenter`, deployed as the `tubearchivist` Portainer stack
from `terraform/portainer/stacks.tf`. Played back through Jellyfin (and Infuse via
Jellyfin).

## Layout

| Container | Image | Bind |
|---|---|---|
| tubearchivist | `bbilly1/tubearchivist` (pinned) | `<mediacenter-100.x>:8335` -> 8000 |
| archivist-es | `bbilly1/tubearchivist-es` (pinned) | stack network only |
| archivist-redis | `redis:8-alpine` | stack network only |

Host port 8335 because 8000 is Portainer's. Bound to the tailnet IP only, like
filebrowser.

`youtube` is an internal record: A -> rpi tailnet IP, served by rpi Caddy from
`http://mediacenter.tailb3a7a.ts.net:8335`. `TA_HOST` must match that URL or
logins fail CSRF.

Downloads go out the home IP, not gluetun: YouTube bot-checks VPN exit IPs.

## Storage

- videos -> `/mnt/bulk-store/media/youtube` (HDD), laid out as `<channel_id>/<video_id>.mp4`
- cache (thumbnails, artwork) -> `/mnt/fast-store/app-data/tubearchivist` (SSD)
- Elasticsearch, Redis -> docker named volumes `es`, `redis`. ES runs as uid 1000,
  so a named volume avoids clashing with the 1500:1500 bind mounts.

Both bind paths are created and owned `docker:media` by `arr-storage.yml`. Jellyfin
reads them through the `media` group.

`vm.max_map_count` must be >= 262144 for ES; mediacenter's default (1048576) is enough.

## Versions

- tubearchivist, archivist-es: pinned, no Watchtower label. Releases can require an ES
  bump or index migration; bump both together per the release notes.
- redis: major-floating, Watchtower label set.

## Secrets

`TUBEARCHIVIST_PASSWORD` (initial admin, username `admin`) and `ELASTIC_PASSWORD`.
Use alphanumeric values: they are rendered unquoted into the compose file.

## Jellyfin integration

Manual, in the Jellyfin UI:

1. Install [tubearchivist-jf-plugin](https://github.com/tubearchivist/tubearchivist-jf-plugin)
   from its repository manifest; restart Jellyfin.
2. Plugin settings: Tube Archivist URL `http://<mediacenter-100.x>:8335` (Jellyfin is
   native on the host; the container is not on localhost), API token from Tube
   Archivist -> Settings.
3. Add a **Shows** library on `/mnt/bulk-store/media/youtube`, metadata and image
   fetcher TubeArchivist only. Channels become series, years become seasons.
4. Optional: enable watched-state sync in the plugin.

Infuse uses its own (TMDB) metadata by default, which will not match YouTube videos.
Switch the Jellyfin share to server-provided metadata in Infuse; verify with one
channel.
