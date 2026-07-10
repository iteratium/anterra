services:
  gluetun:
    image: qmcgaw/gluetun:latest
    hostname: gluetun
    container_name: gluetun
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun:/dev/net/tun
    volumes:
      - ${docker_config_path}/gluetun:/gluetun
    environment:
      - VPN_SERVICE_PROVIDER=airvpn
      - VPN_TYPE=wireguard
      - WIREGUARD_PRIVATE_KEY=${wireguard_private_key}
      - WIREGUARD_PRESHARED_KEY=${wireguard_preshared_key}
      - WIREGUARD_ADDRESSES=${wireguard_addresses}
      - SERVER_COUNTRIES=${server_countries}
      - FIREWALL_VPN_INPUT_PORTS=${vpn_input_port}
      - FIREWALL_OUTBOUND_SUBNETS=${outbound_subnets}
      - DOT_BLOCK_MALICIOUS=on
      - DOT_BLOCK_ADS=on
      - DOT_BLOCK_SURVEILLANCE=on
    ports:
      - "${vpn_input_port}:${vpn_input_port}/tcp"
      - "${vpn_input_port}:${vpn_input_port}/udp"
      - "8585:8585/tcp"
      - "5055:5055/tcp"
      - "7878:7878/tcp"
      - "8989:8989/tcp"
      - "9696:9696/tcp"
      - "6868:6868/tcp"
      - "8191:8191/tcp"
    restart: always

  qbittorrent:
    image: lscr.io/linuxserver/qbittorrent:latest
    container_name: qbittorrent
    network_mode: "service:gluetun"
    depends_on: [gluetun]
    environment:
      - PUID=${docker_user_puid}
      - PGID=${docker_user_pgid}
      - TZ=${docker_timezone}
      - WEBUI_PORT=8585
    volumes:
      - ${docker_config_path}/qbittorrent:/config
      - ${docker_downloads_path}:/downloads
    restart: always

  seerr:
    image: ghcr.io/seerr-team/seerr:latest
    init: true
    container_name: seerr
    network_mode: "service:gluetun"
    depends_on: [gluetun]
    environment:
      - TZ=${docker_timezone}
    volumes:
      - ${docker_config_path}/seerr:/app/config
    healthcheck:
      test: wget --no-verbose --tries=1 --spider http://localhost:5055/api/v1/status || exit 1
      start_period: 20s
      timeout: 3s
      interval: 15s
      retries: 3
    restart: always

  prowlarr:
    image: lscr.io/linuxserver/prowlarr:latest
    container_name: prowlarr
    network_mode: "service:gluetun"
    depends_on: [gluetun]
    environment:
      - PUID=${docker_user_puid}
      - PGID=${docker_user_pgid}
      - TZ=${docker_timezone}
    volumes:
      - ${docker_config_path}/prowlarr:/config
    restart: always

  flaresolverr:
    image: ghcr.io/flaresolverr/flaresolverr:latest
    container_name: flaresolverr
    network_mode: "service:gluetun"
    depends_on: [gluetun]
    environment:
      - LOG_LEVEL=info
      - TZ=${docker_timezone}
    restart: always

  radarr:
    image: lscr.io/linuxserver/radarr:latest
    container_name: radarr
    network_mode: "service:gluetun"
    depends_on: [gluetun]
    environment:
      - PUID=${docker_user_puid}
      - PGID=${docker_user_pgid}
      - TZ=${docker_timezone}
    volumes:
      - ${docker_config_path}/radarr:/config
      - ${docker_media_path}/movies:/movies
      - ${docker_downloads_path}:/downloads
    restart: always

  sonarr:
    image: lscr.io/linuxserver/sonarr:latest
    container_name: sonarr
    network_mode: "service:gluetun"
    depends_on: [gluetun]
    environment:
      - PUID=${docker_user_puid}
      - PGID=${docker_user_pgid}
      - TZ=${docker_timezone}
    volumes:
      - ${docker_config_path}/sonarr:/config
      - ${docker_media_path}/tv:/tv
      - ${docker_downloads_path}:/downloads
    restart: always

  profilarr:
    image: santiagosayshey/profilarr:latest
    container_name: profilarr
    network_mode: "service:gluetun"
    depends_on: [gluetun]
    volumes:
      - ${docker_config_path}/profilarr:/config
    environment:
      - TZ=${docker_timezone}
      - GIT_USER_NAME=${git_user_name}
      - GIT_USER_EMAIL=${git_user_email}
      - PROFILARR_PAT=${profilarr_pat}
    restart: always
