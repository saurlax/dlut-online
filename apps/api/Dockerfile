FROM --platform=$BUILDPLATFORM node:22-slim AS frontend
WORKDIR /src/apps/web
COPY apps/web/package.json apps/web/pnpm-lock.yaml ./
RUN corepack enable && pnpm install --frozen-lockfile
COPY apps/web/ ./
RUN pnpm build

FROM golang:1.26.5-alpine AS build
RUN apk add --no-cache ca-certificates
WORKDIR /src
COPY apps/api/go.mod apps/api/go.sum ./
RUN go mod download
COPY apps/api/*.go ./
COPY --from=frontend /src/apps/api/static ./static
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/dlut-online-web .

FROM scratch
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=build /out/dlut-online-web /dlut-online-web
USER 65532:65532
EXPOSE 8415
ENTRYPOINT ["/dlut-online-web"]
