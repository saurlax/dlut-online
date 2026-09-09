FROM golang:1.26.5-alpine AS build
WORKDIR /src
COPY apps/server/go.mod apps/server/go.sum ./
RUN go mod download
COPY apps/server/*.go ./
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/server .

FROM scratch
COPY --from=build /out/server /server
COPY apps/client/build/web/ /web/
USER 65532:65532
EXPOSE 8060
ENTRYPOINT ["/server"]
CMD ["-web-dir", "/web"]
