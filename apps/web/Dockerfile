FROM golang:1.26.5-alpine AS build
RUN apk add --no-cache ca-certificates
WORKDIR /src
COPY apps/web/go.mod apps/web/go.sum ./
RUN go mod download
COPY apps/web/*.go ./
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/server .

FROM scratch
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=build /out/server /server
USER 65532:65532
EXPOSE 8415
ENTRYPOINT ["/server"]
