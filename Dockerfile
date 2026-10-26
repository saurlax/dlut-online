FROM node:24-bookworm-slim AS frontend
ENV NEXT_TELEMETRY_DISABLED=1
WORKDIR /src/apps/web
RUN npm install --global pnpm@11.6.0
COPY apps/web/package.json apps/web/pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile
COPY apps/web/ ./
RUN pnpm build

FROM golang:1.27-bookworm AS backend
WORKDIR /src/apps/api
COPY apps/api/go.mod apps/api/go.sum ./
RUN go mod download
COPY apps/api/ ./
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/dlut-online .

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 10001 dlut \
    && useradd --uid 10001 --gid dlut --no-create-home dlut \
    && mkdir -p /data/pb_data && chown -R dlut:dlut /data
WORKDIR /app
COPY --from=backend /out/dlut-online /app/dlut-online
COPY --from=frontend /src/apps/web/out/ /app/public/
ENV DO_WEB_ROOT=/app/public
USER 10001:10001
EXPOSE 8415
VOLUME ["/data/pb_data"]
ENTRYPOINT ["/app/dlut-online"]
CMD ["serve", "--http=0.0.0.0:8415", "--dir=/data/pb_data"]
