services:
  chrome:
    image: gcr.io/zenika-hub/alpine-chrome:124
    container_name: chrome
    command:
      - --no-sandbox
      - --disable-gpu
      - --disable-dev-shm-usage
      - --remote-debugging-address=0.0.0.0
      - --remote-debugging-port=9222
      - --hide-scrollbars
      - --disable-blink-features=AutomationControlled
      - --window-size=1440,900
    ports:
      - "${mediacenter_tailscale_ip}:9222:9222"
    restart: always

  meilisearch:
    image: getmeili/meilisearch:${meili_version}
    container_name: meilisearch
    environment:
      - MEILI_NO_ANALYTICS=true
      - MEILI_MASTER_KEY=${meili_master_key}
    ports:
      - "${mediacenter_tailscale_ip}:7700:7700"
    volumes:
      - meilisearch:/meili_data
    restart: always

volumes:
  meilisearch:
