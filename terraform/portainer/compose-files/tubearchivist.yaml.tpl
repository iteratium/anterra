services:
  tubearchivist:
    image: bbilly1/tubearchivist:${tubearchivist_version}
    container_name: tubearchivist
    ports:
      - "${mediacenter_tailscale_ip}:8335:8000"
    volumes:
      - ${docker_media_path}/youtube:/youtube
      - ${docker_config_path}/tubearchivist:/cache
    environment:
      - ES_URL=http://archivist-es:9200
      - REDIS_CON=redis://archivist-redis:6379
      - HOST_UID=${docker_user_puid}
      - HOST_GID=${docker_user_pgid}
      - TA_HOST=https://youtube.${domain_name}
      - TA_USERNAME=${tubearchivist_username}
      - TA_PASSWORD=${tubearchivist_password}
      - ELASTIC_PASSWORD=${elastic_password}
      - TZ=${docker_timezone}
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/api/health/"]
      interval: 2m
      timeout: 10s
      retries: 3
      start_period: 30s
    depends_on:
      - archivist-es
      - archivist-redis
    restart: always

  archivist-redis:
    image: redis:${redis_version}
    container_name: archivist-redis
    volumes:
      - redis:/data
    depends_on:
      - archivist-es
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
    restart: always

  archivist-es:
    image: bbilly1/tubearchivist-es:${tubearchivist_es_version}
    container_name: archivist-es
    environment:
      - ELASTIC_PASSWORD=${elastic_password}
      - ES_JAVA_OPTS=-Xms1g -Xmx1g
      - xpack.security.enabled=true
      - discovery.type=single-node
      - path.repo=/usr/share/elasticsearch/data/snapshot
    ulimits:
      memlock:
        soft: -1
        hard: -1
    volumes:
      - es:/usr/share/elasticsearch/data
    restart: always

volumes:
  redis:
  es:
