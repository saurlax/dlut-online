# Go 服务与 Godot 游戏服

Go 使用 Chi，负责首页、`/web/` 静态资源、入场票据、在线查询和 `/ws` 反向代理。Godot 独立进程负责权威移动、校园碰撞与同校区玩家同步。没有真实 SSO、数据库、持久账号或历史分析；游客 ID 不是账户凭据。

## 本地运行

从仓库根目录准备资源：

```sh
godot --headless --path apps/client --script tools/server_export/build_worlds.gd
godot --headless --path apps/client --export-release Web build/web/index.html
```

生成两个不同的随机凭据，分别设置 `DO_GAME_SERVICE_TOKEN` 和 `DO_ADMIN_API_TOKEN`，至少 32 个字符，例如使用 `openssl rand -hex 32`。仅在服务端环境中设置，不保存到源码或客户端导出。

Go 终端（继承上述两个变量）：

```sh
cd apps/server
go run .
```

Godot 终端（继承相同的 `DO_GAME_SERVICE_TOKEN`）：

```sh
godot --headless --path apps/client scenes/server.tscn
```

打开 `http://localhost:8060/` 或 `/web/`。Go `PORT` 默认 8060；`-addr` 优先，可用 `-addr 127.0.0.1:8060` 限定本机。`-web-dir` 默认 `../client/build/web`，相对路径按 Go 进程工作目录解析。不自动加载 `.env`。

| 环境变量 | 所属进程 | 默认或要求 |
|---|---|---|
| DO_GAME_SERVER_URL | Go | `http://127.0.0.1:8061`，内网 HTTP(S) 根地址 |
| DO_GAME_SERVICE_TOKEN | 两个服务 | 相同的服务凭据，至少 32 字符 |
| DO_ADMIN_API_TOKEN | Go | 独立的只读管理凭据，至少 32 字符 |
| DO_API_SERVER_URL | Godot | `http://127.0.0.1:8060`，Go 内网 HTTP(S) 根地址 |
| DO_GAME_LISTEN_ADDR | Godot | `127.0.0.1`，容器设为 `0.0.0.0` |
| DO_GAME_PORT | Godot | `8061` |
| DO_GAME_INSTANCE_ID | Godot | `main`，当前支持单游戏实例 |

客户端继续使用 `DO_SERVER_URL` 或浏览器同源根地址，不能收到服务端凭据。公开部署使用 HTTPS/WSS，游戏端口只在内网可见。反向代理须保留 Host、支持 Upgrade，并允许心跳维持长连接。

## HTTP 接口

- `GET /`：简单游戏入口。
- `/web/`：完整 Godot Web 资源目录，缺失资源返回 404，不回退到首页。
- `POST /api/v1/game/tickets`：正文 `{"id":"32位小写十六进制游客ID","version":2}`，返回 201 与 `ticket`、`expires_in:30`、`ws_path:"/ws"`。不提交校区。
- `POST /internal/v1/game/tickets/consume`：服务凭据，正文 `{"ticket":"..."}`；原子消费，返回 id、username、kind、admission_id。
- `POST /internal/v1/game/register`：服务凭据，正文 instance_id、boot_id；返回 epoch，同启动标识重试幂等，旧启动不可重新注册。
- `POST /internal/v1/game/presence`：服务凭据，正文 instance_id、epoch、递增 seq、players；每位玩家含 id、username、kind、campus、joined_at（Unix 秒）。
- `GET /api/v1/game/online`：公开聚合人数，status 为 live/stale/unavailable；失联超过 15 秒当前 total/campuses 为 null，不伪装成零人，保留最后观测时间及 last_total。
- `GET /api/v1/admin/game/players`：管理凭据，附当前玩家列表与相同的时效语义；失联时 players 为 null。

受保护接口使用 `Authorization: Bearer <对应凭据>`。游戏服务凭据与管理凭据不可互换。票据有效期 30 秒、只能兑换一次；每身份每秒最多签发一次，全局每秒最多 100 次、待兑换票据最多 512 张。票据仅放消息正文，不放 URL 或日志。Go 重启丢失未兑换票据和在线缓存，客户端可重新取票，游戏服自动重新注册上报。

未来 SSO 在 Go 建立身份，再沿用入场票据；未来持久化通过受认证数据接口处理，重要操作采用事务和幂等 ID，位置按周期保存，不逐 tick 写数据库。当前在线快照不能用于声称已提供历史在线时长、DAU 或留存。

## 游戏协议版本 2

首条消息 5 秒内发送 `{"type":"hello","version":2,"ticket":"...","campus":"lingshui"}`。三个校区均开放；游戏服只检查地图 ID，出生位置由服务端决定。欢迎消息包含身份、admission_id、map_epoch、权威位置/速度、朝向和名册。

客户端每秒至多 20 次发送 input：seq、axis（二维）、yaw、run、jump（按键递增序号）、map_epoch。服务端不接受 position、speed、delta，不信任客户端物理结果。服务端以 60 Hz 模拟，10 Hz 同校区快照，包含本机权威状态；昵称通过名册同步。碰撞仅玩家对校园，不新增玩家间碰撞。

单消息最多 2 KiB，每秒最多 40 条；500 ms 无有效输入停止水平移动。heartbeat 每 5 秒发送，15 秒无有效消息断开。应用层只保留最新待发快照，传输缓存持续拥堵会断开慢连接。关闭码：4001 身份被替换并停止重试；4002 协议/输入错误；4003 超时或暂时不可用；4004 满员。不同玩家上限 50，身份替换不额外占名额。

客户端 Autoload 跨场景保留 WebSocket。切图通过 change_map(request_id,campus) → map_prepare(transfer_id) → 场景异步加载 → map_ready → map_entered 完成，不重新取票、登录或统计退出。加载期间角色冻结且心跳继续，目标就绪后原子迁移。map_cancel/map_status/map_resume 处理取消、结果查询和原场景恢复；准备超时 180 秒。map_epoch 隔离旧输入及快照，重复请求不重复迁移。真实断线才重新取票，连接代次与入场时间重建。

Go 内部数据接口不可用时，不阻塞现有世界模拟；新入场不能绕过验证。Go 网关进程重启仍会断开代理连接，随后客户端自动重连。客户端使用共享规则预测和权威纠正，弱网仍可能发生回拉，不承诺完全确定性物理或通用反外挂。

## 导出、Docker 与 CI

服务端碰撞场景位于 `apps/client/scenes/server/`，由现有校园数据生成并保留为可打开的运行资源；修改碰撞来源后重新生成，不手工维护第二套模型。

```sh
mkdir -p apps/client/build/server
godot --headless --path apps/client --script tools/server_export/build_worlds.gd
godot --headless --path apps/client --export-release Server build/server/dlut-game-server.x86_64
docker compose build
docker compose up -d
```

先完成 Web 导出，再构建。Compose 将两个服务放在内部网络，仅映射 Go 端口；默认宿主机绑定 127.0.0.1:8060，可通过 DO_HTTP_BIND、DO_HTTP_PORT 调整。生产通过已有 HTTPS 网关接入。镜像以非 root 用户运行；正式 Godot 镜像仅包含服务端 PCK 和程序，PCK 排除视觉资源与客户端 UI。

CI 每次 push/PR 构建内置 Web 的 Go 镜像和独立 Linux amd64 Godot 镜像，同时导出 Windows x86_64、macOS universal ZIP。测试真实双服务入场、切图与资源请求。非 PR 构建发布 `ghcr.io/saurlax/dlut-online` 和 `ghcr.io/saurlax/dlut-online-game`：提交使用 sha 标签，默认分支更新 edge，正式版本更新版本标签及 latest，预发布不更新 latest。桌面没有签名/公证。所有构建产物不提交。

回滚须同时回滚客户端、Go 和 Godot 镜像；版本 2 输入客户端不能与旧位置转发服务混用。当前没有数据库迁移，重启不保存玩家位置。

## 验证

Go 目录运行 `go test -race ./...`、`go vet ./...`。联机测试需先启动两服务：

```sh
DO_TEST_SERVER_URL=http://127.0.0.1:8060 go test -run TestGameProtocol -v
DO_TEST_GODOT_PROJECT=../client DO_TEST_SERVER_URL=http://127.0.0.1:8060 go test -run 'TestGodot' -timeout 3m -v
DO_TEST_SERVER_URL=http://127.0.0.1:8060 DO_TEST_LOAD_SECONDS=600 go test -run TestGameLoad -timeout 12m -v
```

50 人压测需要空闲测试游戏实例。Godot 目录运行 `godot --headless --script tests/server_physics.gd`，以及带 DO_SERVER_URL 的 `tests/campus_travel.gd`。真实 Web 检查登录、移动、M 地图、三校区切换和失焦停止。客户端仍使用已有建筑与碰撞精度，不因新增服务器提高校园建模精度。
