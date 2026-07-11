# Watchtower

Automatic image updates across the fleet. Deployed by
`ansible/playbooks/watchtower.yml`, imported from `ansible/site.yml`, targeting the
`docker_hosts` group (`mediacenter`, `rpi`, `vps`) — one Watchtower container per host.

## Image

`containrrr/watchtower` was archived 2025-12-17 (no further releases or security
patches). Using the actively maintained, API/label-compatible fork:
`ghcr.io/nicholas-fedor/watchtower:latest`.

## Scope

Label-scoped (`WATCHTOWER_LABEL_ENABLE=true`): only containers carrying
`com.centurylinklabs.watchtower.enable=true` are managed. Currently that's every
container in the arr stack (`terraform/portainer/compose-files/arr.yaml.tpl`),
including gluetun. Portainer server/agent are intentionally unlabelled — version
bumps there can carry breaking changes (see `docker-portainer.md`) and are done
manually.

rpi and vps run Watchtower with nothing labelled yet — placeholder for whatever gets
deployed there next; label any future container to bring it under management.

## Schedule

Weekly, Monday 4am IST: `WATCHTOWER_SCHEDULE=0 0 4 * * 1` (6-field cron, seconds
first), `TZ=Asia/Kolkata`.

## Dependency ordering

Watchtower treats `network_mode: service:X` as an implicit dependency link: it stops
dependents first, updates and restarts the base container, then recreates (not just
restarts — required, since dependents don't survive the base container's network
namespace being rebuilt) the dependents. This handles the gluetun -> arr-stack-apps
ordering automatically, no explicit `depends-on` label needed.
