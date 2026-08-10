services:
  ntfy:
    image: binwiederhier/ntfy:${ntfy_version}
    container_name: ntfy
    command: serve
    environment:
      - TZ=${docker_timezone}
      - NTFY_BASE_URL=https://ntfy.${domain_name}
      - NTFY_LISTEN_HTTP=:80
      - NTFY_BEHIND_PROXY=true
      - NTFY_PROXY_TRUSTED_HOSTS=${cloudflare_edge_ranges}
      - NTFY_AUTH_FILE=/var/lib/ntfy/user.db
      - NTFY_AUTH_DEFAULT_ACCESS=deny-all
      - NTFY_ENABLE_SIGNUP=false
      - NTFY_ENABLE_LOGIN=true
      - NTFY_CACHE_FILE=/var/cache/ntfy/cache.db
      - NTFY_CACHE_DURATION=12h
      - NTFY_UPSTREAM_BASE_URL=https://ntfy.sh
    ports:
      - "${vps_tailscale_ip}:9722:80"
    volumes:
      - lib:/var/lib/ntfy
      - cache:/var/cache/ntfy
    restart: always

volumes:
  lib:
  cache:
