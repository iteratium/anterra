services:
  filebrowser:
    image: gtstef/filebrowser:${filebrowser_version}
    container_name: filebrowser
    user: "${docker_user_puid}:${docker_user_pgid}"
    environment:
      - TZ=${docker_timezone}
    ports:
      - "${mediacenter_tailscale_ip}:8334:80"
    volumes:
      - ${docker_config_path}/filebrowser/data:/home/filebrowser/data
      - ${docker_config_path}/filebrowser/files:/files
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
    restart: always
