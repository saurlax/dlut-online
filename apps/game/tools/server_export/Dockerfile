FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /game
COPY apps/game/build/server/dlut-game-server.x86_64 /game/server
COPY apps/game/build/server/dlut-game-server.pck /game/server.pck
RUN chmod 755 /game/server && mkdir -p /var/lib/dlut-online && chown 65532:65532 /var/lib/dlut-online
USER 65532:65532
ENV DO_GAME_LISTEN_ADDR=*
ENV XDG_DATA_HOME=/var/lib/dlut-online
EXPOSE 8061/udp
ENTRYPOINT ["/game/server", "--headless"]
