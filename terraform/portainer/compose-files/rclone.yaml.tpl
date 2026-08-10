services:
  rclone:
    image: rclone/rclone:${rclone_version}
    container_name: rclone
    user: "${docker_user_puid}:${docker_user_pgid}"
    environment:
      - TZ=${docker_timezone}
    entrypoint: /bin/sh
    command:
      - -c
      - |
        while :; do
          for remote in gdrive onedrive; do
            timeout 900 rclone sync /data "$$remote:files" \
              --backup-dir "$$remote:.trash/$(date +%F)" \
              --track-renames \
              --max-delete 20 \
              --log-level INFO
          done
          sleep 3600
        done
    volumes:
      - ${docker_config_path}/rclone:/config/rclone
      - ${docker_config_path}/filebrowser/files:/data:ro
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
    restart: always
