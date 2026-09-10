FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /game
COPY apps/game/build/server/dlut-online-server.x86_64 /game/dlut-online-server
COPY apps/game/build/server/dlut-online-server.pck /game/dlut-online-server.pck
RUN chmod 755 /game/dlut-online-server && mkdir -p /var/lib/dlut-online && chown 65532:65532 /var/lib/dlut-online
USER 65532:65532
ENV DO_GAME_LISTEN_ADDR=*
ENV XDG_DATA_HOME=/var/lib/dlut-online
EXPOSE 1949/udp
ENTRYPOINT ["/game/dlut-online-server", "--headless"]
