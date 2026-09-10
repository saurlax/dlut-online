FROM --platform=$BUILDPLATFORM node:22-slim AS frontend
WORKDIR /src/apps/web
COPY apps/web/package.json apps/web/pnpm-lock.yaml ./
RUN corepack enable && pnpm install --frozen-lockfile
COPY apps/web/ ./
RUN pnpm build

FROM golang:1.27-alpine AS build
RUN apk add --no-cache ca-certificates
WORKDIR /src
COPY apps/api/go.mod apps/api/go.sum ./
RUN go mod download
COPY apps/api/ ./
COPY --from=frontend /src/apps/api/static ./static
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/dlut-online-web . \
    && mkdir -p /out/data/pb_data

FROM scratch
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=build /out/dlut-online-web /dlut-online-web
COPY --from=build --chown=65532:65532 /out/data /data
USER 65532:65532
ENV DO_DATA_DIR=/data/pb_data
EXPOSE 8415
VOLUME ["/data"]
ENTRYPOINT ["/dlut-online-web"]
