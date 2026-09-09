# Go 服务

在此目录运行 `go run .`，默认读取 `../client/build/web`，默认监听 `:8060`（所有网卡），可用 `PORT` 环境变量设置端口，游戏入口为 `/web/`。先运行客户端导出工具生成资源。

`PORT` 须为 1–65535，未设置或为空时使用 8060；`-addr` 优先于 `PORT`，本机限定访问可用 `-addr 127.0.0.1:8060`。可通过 `-web-dir` 指定资源目录；相对路径以工作目录为准。构建使用 `go build -o build/server .`，测试使用 `go test ./...`。

提供 Godot 静态资源及 `/ws` 游客联机；首页和 `/api/v1/` 尚未实现，对应路径返回 404。资源使用重新验证缓存策略，缺失文件返回 404，不回退到首页。不将游戏资源嵌入 Go 二进制。

## 游客联机协议

WebSocket 首条消息须在 5 秒内发送：`{"type":"hello","id":"32位小写十六进制随机ID","campus":"lingshui","position":[0,0,0],"yaw":0}`。校区仅接受 `lingshui`、`eda`、`panjin`。服务端返回 `welcome`（id、username），之后每秒 10 次发送 `snapshot`，其 `players` 数组含同校区玩家的 id、username、campus、position、yaw，包括自己。

客户端每秒 10 次发送 `{"type":"state","position":[0,0,0],"yaw":0}`，坐标单位为米，朝向为弧度（-2π 至 2π）。服务器根据 ID 前八位十六进制数模 1000000 生成六位游客昵称，不接受客户端指定昵称。单消息上限 1024 字节，每秒最多 40 条状态，坐标绝对值不超过 10000，15 秒无状态则关闭。玩家退出或连接替换后从快照移除；同 ID 新连接替换旧连接，旧连接收到关闭码 4001 后须停止重连。

浏览器 Origin 须与请求 Host 相同，反向代理须保留 Host 并支持 WebSocket Upgrade；桌面可不发送 Origin。当前为单进程内存同步，重启清空在线状态，多实例部署尚不共享房间。此游客协议不提供账户鉴权或防作弊，不能用游客 ID 作为后续敏感接口的凭证。

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

产物作为 Actions artifacts 保留 7 天，名称包含提交 SHA。镜像可用 `docker load -i server-image.tar` 导入，push 构建通过后自动发布到 `ghcr.io/saurlax/dlut-online`；PR 只构建验证，不发布镜像。Windows/macOS 包暂不签名，macOS 不公证；下载运行时可能触发系统安全提示。

构建镜像前 CI 会先导出 Web，并在容器中使用 PORT=9090 验证首页及 PCK 资源；不会用临时占位文件替代真实游戏资源。

## Build 与 Release 发布

- 分支 push：发布 `sha-<完整提交 SHA>`；默认分支额外更新 `edge`。
- 推送 `vMAJOR.MINOR.PATCH` 标签：复用完整构建，发布同名版本镜像及 `latest`，创建 GitHub Release 并附 Windows/macOS ZIP。
- `vMAJOR.MINOR.PATCH-rc.1` 等预发布标签：发布版本镜像和预发布 Release，不覆盖 `latest`。

镜像只在容器资源检查成功后发布，使用仓库自带 GITHUB_TOKEN，不需要配置个人访问令牌。GHCR 包的可见性由 GitHub 包设置管理，不自动改为公开。重复运行会重新上传同名 Release 附件。
