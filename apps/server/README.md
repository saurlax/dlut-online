# Go 服务

在此目录运行 `go run .`，默认读取 `../client/build/web`，默认监听 `:8060`（所有网卡），可用 `PORT` 环境变量设置端口，游戏入口为 `/web/`。先运行客户端导出工具生成资源。

`PORT` 须为 1–65535，未设置或为空时使用 8060；`-addr` 优先于 `PORT`，本机限定访问可用 `-addr 127.0.0.1:8060`。可通过 `-web-dir` 指定资源目录；相对路径以工作目录为准。构建使用 `go build -o build/server .`，测试使用 `go test ./...`。

目前只提供 Godot 静态资源，首页、API 和 WebSocket 尚未实现，对应路径返回 404。资源使用重新验证缓存策略，缺失文件返回 404，不回退到首页。不将游戏资源嵌入 Go 二进制。

## Docker 与 CI

先从客户端目录用 Godot 导出 Web 到 build/web/，再从仓库根目录构建镜像：

```sh
docker build -f apps/server/Dockerfile -t dlut-online-server .
docker run --rm -p 8060:8060 -e PORT=8060 dlut-online-server
```

镜像同时包含 Go 服务与 Web 客户端，以非 root 用户运行，不需要额外挂载资源。客户端资源作为镜像文件保存，不嵌入 Go 二进制。

GitHub Actions 在每次 push、PR 或手动触发时测试 Go，并使用 Godot 4.7.2 导出三个平台：

- Linux amd64 Go 镜像，内置 Web 客户端，提供镜像 tar。
- Windows x86_64 客户端 ZIP。
- macOS 通用客户端 ZIP（Intel 与 Apple Silicon）。

产物作为 Actions artifacts 保留 7 天，名称包含提交 SHA。镜像可用 `docker load -i server-image.tar` 导入，不自动发布到镜像仓库。Windows/macOS 包暂不签名，macOS 不公证；下载运行时可能触发系统安全提示。

构建镜像前 CI 会先导出 Web，并在容器中使用 PORT=9090 验证首页及 PCK 资源；不会用临时占位文件替代真实游戏资源。
