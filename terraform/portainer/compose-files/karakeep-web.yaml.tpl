services:
  karakeep:
    image: ghcr.io/karakeep-app/karakeep:release
    container_name: karakeep
    ports:
      - "${vps_tailscale_ip}:9721:3000"
    volumes:
      - data:/data
    environment:
      - DATA_DIR=/data
      - NEXTAUTH_URL=https://keep.${domain_name}
      - NEXTAUTH_SECRET=${nextauth_secret}
      - DISABLE_SIGNUPS=false
      - MEILI_ADDR=http://${mediacenter_tailscale_ip}:7700
      - MEILI_MASTER_KEY=${meili_master_key}
      - BROWSER_WEB_URL=http://${mediacenter_tailscale_ip}:9222
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
    restart: always

volumes:
  data:
