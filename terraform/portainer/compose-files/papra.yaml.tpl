services:
  papra:
    image: ghcr.io/papra-hq/papra:${papra_version}
    container_name: papra
    user: "${docker_user_puid}:${docker_user_pgid}"
    environment:
      - APP_BASE_URL=https://papra.${domain_name}
      - AUTH_SECRET=${papra_auth_secret}
      - TZ=${docker_timezone}
      - DOCUMENT_STORAGE_FILESYSTEM_ROOT=/app/app-data/documents
      - DOCUMENT_STORAGE_USE_LEGACY_STORAGE_KEY_DEFINITION_SYSTEM=false
      - DOCUMENT_STORAGE_KEY_PATTERN={{document.name}}
      - AUTH_PROVIDERS_EMAIL_IS_ENABLED=false
      - AUTH_IS_REGISTRATION_ENABLED=${papra_registration_enabled}
      - AUTH_PROVIDERS_CUSTOMS=${papra_oidc_providers_json}
    ports:
      - "${mediacenter_tailscale_ip}:1221:1221"
    volumes:
      - ${docker_config_path}/papra:/app/app-data
    restart: always
