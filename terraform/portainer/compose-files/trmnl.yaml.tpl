services:
  init-certificates:
    image: ghcr.io/usetrmnl/terminus:latest
    container_name: trmnl-init-certificates
    user: root
    volumes:
      - certificates:/etc/ssl/certs
    entrypoint: ["/bin/bash", "-c"]
    command: scripts/docker/install-certificates
    restart: on-failure:3

  web:
    image: ghcr.io/usetrmnl/terminus:latest
    container_name: trmnl
    init: true
    environment:
      - HANAMI_PORT=${trmnl_port}
      - API_URI=http://mediacenter:${trmnl_port}
      - APP_SECRET=${trmnl_app_secret}
      - APP_SETUP=true
      - DATABASE_URL=postgres://terminus:${trmnl_database_password}@database:5432/terminus
      - KEYVALUE_URL=redis://:${trmnl_keyvalue_password}@keyvalue:6379/0
    ports:
      - "${mediacenter_tailscale_ip}:${trmnl_port}:${trmnl_port}"
    volumes:
      - certificates:/etc/ssl/certs
      - web-fonts:/app/public/fonts
      - web-fonts:/usr/share/fonts/terminus
      - web-uploads:/app/public/uploads
    depends_on:
      init-certificates:
        condition: service_completed_successfully
      database:
        condition: service_healthy
      keyvalue:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "curl --fail --silent http://localhost:${trmnl_port}/up"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 45s
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
    restart: always

  worker:
    image: ghcr.io/usetrmnl/terminus:latest
    container_name: trmnl-worker
    init: true
    environment:
      - HANAMI_PORT=${trmnl_port}
      - API_URI=http://mediacenter:${trmnl_port}
      - APP_SECRET=${trmnl_app_secret}
      - DATABASE_URL=postgres://terminus:${trmnl_database_password}@database:5432/terminus
      - KEYVALUE_URL=redis://:${trmnl_keyvalue_password}@keyvalue:6379/0
    command: bundle exec sidekiq -r ./config/sidekiq.rb
    volumes:
      - certificates:/etc/ssl/certs
      - web-fonts:/app/public/fonts
      - web-fonts:/usr/share/fonts/terminus
      - web-uploads:/app/public/uploads
    depends_on:
      web:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "pgrep", "-f", "sidekiq"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 45s
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
    restart: always

  database:
    image: postgres:18.4-alpine
    container_name: trmnl-database
    environment:
      - POSTGRES_USER=terminus
      - POSTGRES_DB=terminus
      - POSTGRES_PASSWORD=${trmnl_database_password}
    volumes:
      - database-data:/var/lib/postgresql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready --username terminus --dbname terminus"]
      interval: 10s
      timeout: 5s
      retries: 3
    restart: always

  keyvalue:
    image: valkey/valkey:9.1-alpine
    container_name: trmnl-keyvalue
    command: >
      valkey-server
      --requirepass ${trmnl_keyvalue_password}
      --maxmemory 512mb
      --maxmemory-policy noeviction
    volumes:
      - keyvalue-data:/data
    healthcheck:
      test: ["CMD-SHELL", "redis-cli -a ${trmnl_keyvalue_password} ping | grep -q PONG"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 2s
    restart: always

volumes:
  database-data:
  keyvalue-data:
  web-fonts:
  web-uploads:
  certificates:
