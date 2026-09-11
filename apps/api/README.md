# Go 服务与 Godot 游戏服

Go 位于 apps/api，自定义业务接口和 Vue 站点直接注册到 PocketBase Router，负责用户认证、SQLite 持久化、网站托管、入场票据和在线查询。Vue 3 + TypeScript + Vite + Naive UI 网站位于 apps/web。Godot 独立进程负责权威移动、校园碰撞与同校区玩家同步。

## 本地运行

从仓库根目录准备服务端碰撞：

```sh
godot --headless --path apps/game --script tools/server_export/build_worlds.gd
```

生成一个随机 `DO_API_KEY`，至少 32 个字符，例如使用 `openssl rand -hex 32`。Go、Godot 游戏服及其他可信服务调用方使用各自部署环境中的同一值，不保存到源码或客户端导出。

Go 终端（继承上述变量）：

```sh
pnpm --dir apps/web install --frozen-lockfile
pnpm --dir apps/web build
cd apps/api
go run .
```

Godot 终端（继承相同的 `DO_API_KEY`）：

```sh
godot --headless --path apps/game scenes/server.tscn
```

Go `DO_API_SERVER_PORT` 默认 8415，也兼容部署平台提供的 `PORT`。PocketBase 数据默认写入 `apps/api/pb_data`；编译前需要构建 Vue 网站，运行时静态资源已嵌入 Go。首次启动后从 `/_/` 创建 PocketBase superuser，配置 SMTP、邮件模板、OAuth2/OIDC 提供方和 `servers` 游戏服端点。

| 环境变量 | 所属进程 | 默认或要求 |
|---|---|---|
| DO_ENV | Go、Godot、桌面客户端构建/运行 | `development` 或 `production`；Compose 默认 development，桌面包默认 production |
| DO_API_SERVER_URL | 桌面客户端、Godot 游戏服 | Go HTTP API 根地址；客户端开发默认 `http://localhost:8415`，生产默认 `https://dlut.online` |
| DO_API_KEY | Go、Godot 及可信服务调用方 | API Bearer Key，各进程配置相同值，至少 32 字符 |
| DO_API_SERVER_PORT | Go | HTTP 监听端口，默认 `8415` |
| DO_GAME_SERVER_PORT | Godot 游戏服 | UDP 监听端口，默认 `1949` |
| DO_GAME_TLS_CERT | Godot | 生产环境 DTLS PEM 证书链路径 |
| DO_GAME_TLS_KEY | Godot | 生产环境 DTLS PEM 私钥路径 |
| DO_GAME_TLS_CA | 桌面客户端构建/运行 | 可选，自有 DTLS CA 证书路径 |
| PB_DATA_DIR | Go | PocketBase SQLite 数据目录，本地默认 `pb_data`，容器为 `/data/pb_data` |
| PB_ENCRYPTION_KEY | Go | 生产使用的 32 字符 PocketBase 设置加密密钥 |
| PORT | Go | 部署平台兼容端口，仅在未设置 `DO_API_SERVER_PORT` 时读取 |

游戏服固定监听 `*`，单实例标识固定为 `main`。Compose 默认仅发布到宿主机回环地址；公网部署按实际网络配置修改绑定地址。

客户端用 DO_API_SERVER_URL 访问 Go HTTP API，游戏端点由票据响应返回。DO_API_KEY 不进入客户端。游戏端点不是环境变量：在 PocketBase `servers` Collection 中创建记录，填写 `name`、客户端可达的 `endpoint` 并启用；同一时刻只允许一条启用记录。没有有效启用记录时，票据接口返回 503 `game_server_unavailable`。

## HTTP 接口

- `GET /`：客户端发布页链接。
- `POST /api/collections/users/records`：PocketBase 用户注册，必填 email、password、passwordConfirm、username 和 display_name。
- `/api/collections/users/request-verification`、`confirm-verification`、`auth-with-password`、`request-password-reset`、`confirm-password-reset`、`request-email-change`、`confirm-email-change` 与 `auth-refresh`：PocketBase 标准认证流程。
- `POST /api/v1/game/tickets`：正文 `{"version":5}`，必须提交 `Authorization: Bearer <PocketBase auth token>`；服务端使用已验证且未禁用账号的 record ID 与 display_name，忽略旧客户端 id；无账号或游客请求返回 401。
- `POST /api/v1/game/tickets/consume`：API Key 鉴权，正文 `{"ticket":"..."}`；原子消费，返回 id、username、kind、admission_id。
- `POST /api/v1/game/register`：API Key 鉴权，正文 instance_id、boot_id；返回 epoch，同启动标识重试幂等，旧启动不可重新注册。
- `POST /api/v1/game/presence`：API Key 鉴权，正文 instance_id、epoch、递增 seq、players；每位玩家含 id、username、kind、campus、joined_at（Unix 秒）。
- `GET /api/v1/game/online`：公开聚合人数，status 为 live/stale/unavailable；失联超过 15 秒当前 total/campuses 为 null，不伪装成零人，保留最后观测时间及 last_total。
- `GET /api/v1/admin/game/players`：API Key 鉴权，附当前玩家列表与相同的时效语义；失联时 players 为 null。

受保护的服务接口统一使用 `Authorization: Bearer <DO_API_KEY>`。后续可信平台沿用相同路径版本和 Bearer Auth 流程。玩家登录接口中的 Bearer 值仍为 PocketBase 用户 auth token。票据有效期 30 秒、只能兑换一次；每身份每秒最多签发一次，全局每秒最多 100 次、待兑换票据最多 512 张。票据仅放消息正文，不放 URL 或日志。Go 重启丢失未兑换票据和在线缓存，客户端可重新取票，游戏服自动重新注册上报。

所有持久化通过 Go/PocketBase 处理，Godot 游戏服不直接打开 SQLite。重要操作采用事务和幂等 ID，位置按周期保存，不逐 tick 写数据库。

## 游戏协议版本 5

客户端先向 Go 获取票据与 `game_server_url`，然后直连 Godot ENet/UDP。Go 不代理游戏流量；游戏服使用 API Key 保护的 HTTP API 兑换票据、上报在线状态。首次连接和真实断线重连时取票，切图不重新认证。

控制通道 0 可靠有序传输 JSON：hello、welcome、heartbeat、roster、世界聊天和切图消息。首条 hello 在 5 秒内发送，包含 version:5、ticket 和 campus。通道 1 不可靠有序传输输入与二进制位置快照；输入仍为 JSON，每秒最多 20 次，服务器不接受客户端位置、速度或帧时长。服务端 60 Hz 物理、10 Hz 同地图快照，客户端预测并纠正。

快照每包最多 12 人、820 字节，含 tick、地图、分包编号和每个玩家的 15 字节 ID、位置、速度、朝向、输入确认和 map_epoch。每个 tick 最多 5 包；客户端只保留最新 tick 的完整快照，丢包跳过这一帧，迟到或旧地图数据丢弃。名册通过可靠通道更新。

输入累计跳跃序号抗丢包，500 ms 无有效输入停止水平移动；心跳每 5 秒，15 秒无有效消息断开。切图继续使用 change_map/prepare/ready/entered 和 cancel/status/resume，准备超时 180 秒；本地场景加载时保留连接、停止控制，确认后原子迁移。

世界聊天使用可靠控制通道：客户端发送 `chat_send`（`request_id`、`text`），服务端广播 `chat_event`（`event_id`、`kind`、`id`、`username`、`text`、`request_id`）；`kind` 为 `message`、`joined` 或 `left`。拒绝返回 `chat_result`（`request_id`、`error`、`retry_ms`），成功以广播确认。同实例三个校区共享频道，显示名来自已验证票据，切图和同账号连接替换不触发进出提示。账号两次接受消息至少间隔 1000 ms，重连保留剩余冷却；正文去首尾空白后最多 200 个 Unicode 码点、800 字节 UTF-8，拒绝控制字符和空消息，不持久化聊天。

桌面聊天位于左下角，左侧 16 px、底部 24 px 逻辑留白。回车打开输入，再按回车发送；间隔不足 1 秒时回车无效，保留草稿且不补发。编辑时暂停移动和环视，M 作为文本输入；Escape 取消编辑并保留草稿，恢复编辑前的控制状态。中文候选确认不提交聊天；失焦停止控制。地图与传送覆盖层隐藏聊天但继续接收，同连接保留最近 100 条事件，会话结束清空。世界消息白色，加入/离开提示黄色；右下角玩家状态的底部留白保持原规则。

协议 5 与协议 4 不兼容：Go 票据接口、Godot 游戏服及 Windows/macOS 客户端必须一起升级或回滚；旧客户端申请票据时返回版本错误。

关闭原因数据：4001 同身份替换并停止重试，4002 协议错误，4003 暂时不可用或超时，4004 满员。当前最多 50 人、100 个待认证/关闭中的连接。Go API 故障不阻塞现有玩家，Go 进程重启也不再断开 ENet 连接，但期间无法新入场且在线数据需要重新注册。

## 导出与部署

```sh
mkdir -p apps/game/build/server apps/game/build/windows apps/game/build/macos
godot --headless --path apps/game --script tools/server_export/build_worlds.gd
godot --headless --path apps/game --export-release Server build/server/dlut-online-server.x86_64
godot --headless --path apps/game --export-release Windows 'build/windows/DLUT-Online-Windows.exe'
godot --headless --path apps/game --export-release macOS 'build/macos/DLUT Online.app'
python3 apps/game/tools/verify_windows_export.py
python3 apps/game/tools/package_macos.py
docker compose build
docker compose up -d
```

Compose 服务名为 `web` 和 `game`，游戏服通过 `http://web.internal:8415` 访问 Go。游戏服导出 `dlut-online-server.x86_64` 与同名 `.pck`，容器运行 `/game/dlut-online-server`；Go 容器运行 `/dlut-online-web`。PocketBase 数据保存在 Compose 命名卷 `web-data`，备份覆盖完整 `/data/pb_data`。

Compose 默认将 Go TCP 8415 和游戏 UDP 1949 绑定宿主机 127.0.0.1，用于本地开发；DO_API_SERVER_PORT 和 DO_GAME_SERVER_PORT 同时调整进程监听端口与宿主机映射，绑定地址直接修改 Compose 的 ports。Go 镜像不需要客户端文件。正式发布桌面包默认 production；DO_API_SERVER_URL 显式覆盖 Go API 根地址，DO_ENV 显式指定环境，否则使用包内配置，不读取 .env。

Godot 编辑器打开 `apps/game/project.godot` 后，顶部 `Env: Local / Dev` 下拉框控制下一次 F5/F6 运行的客户端 API 地址。Local 默认连接 `http://localhost:8415`，Dev 按当前约定连接 `https://dlut.online`，两者客户端配置均为 development；Dev 与生产使用同一服务地址，不代表独立的后端环境。停止游戏、切换选项，再按 F5 运行项目或 F6 运行当前场景。选择保存在本机 `apps/game/.godot/do_run_environment.cfg`，重启编辑器保留，运行中的客户端不会随下拉框改变地址。清理 `.godot` 后恢复 Local。顶部显示 `Env*:` 时表示启动编辑器时继承的 `DO_ENV` / `DO_API_SERVER_URL` 正在覆盖选择，悬停可查看有效地址；仅显式设置 `DO_ENV=development` 会按既有规则将地址重置为 localhost。该选择也适用于本机使用编辑器二进制直接运行项目；正式桌面包和导出默认值不受影响，仍用原有环境变量控制。环境下拉框由 `Run environment` 插件（`apps/game/addons/run_environment/`）提供，如被禁用可在项目设置的插件页重新启用。`Desktop server configuration` 插件（`apps/game/addons/desktop_export/`）仅负责导出配置及 Windows 凭据脚本；两个插件共用 `desktop_config.gd` 解析配置，互不依赖。

生产部署两个独立服务：Go 通过 HTTPS 对外，游戏服暴露 UDP。在 PocketBase `servers.endpoint` 填写客户端可达地址，例如 enets://game.example.com:1949；不能填容器内部地址。两个服务设 DO_ENV=production；游戏服通过只读挂载提供 DO_GAME_TLS_CERT（PEM 证书链）与 DO_GAME_TLS_KEY（PEM 私钥）路径，由 Godot 直接终止 DTLS，普通 HTTP 反向代理不能替代。客户端按地址验证证书主机名和信任链，可用 DO_GAME_TLS_CA 指定自有 CA 文件；不提供跳过校验的开关。客户端在 development 和 production 均接受 enet://（明文）与 enets://（DTLS），按下发协议连接，不在 DTLS 失败后自动降级。临时无 DTLS 测试时，Go 与游戏服需设置 DO_ENV=development，游戏服清空 DO_GAME_TLS_CERT/DO_GAME_TLS_KEY，servers.endpoint 使用 enet://公网地址:公网UDP端口；正式客户端无需切换 development。Compose 固定将 ./.local/game-tls 挂载到 /run/game-tls，可将上述证书与私钥变量设置为该目录内的文件路径。证书及私钥不提交、不打入客户端或镜像，需要部署平台管理和续期。

`build-web.yml` 与 `build-game.yml` 各自按路径接收分支 push、PR 和手动运行；Web 内置前置 `test`，成功后才执行 `build`，不抽取共享测试工作流。轻量测试使用 Linux runner，只执行 Vue `vue-tsc --noEmit`、Go `go test -timeout 60s ./...` 与 `go vet ./...`，不拉取 LFS 资产或安装 Godot。Game 当前没有接入轻量单元测试，仅做必要生成与导出，不重复执行 Vue/Go 检查。版本标签发布先校验版本，再复用 Web（test → build）和 Game 构建工作流，全部成功后下载本次构建的 Windows EXE 和 macOS DMG 并上传 GitHub Release，不直接复用历史构建运行的产物。

CI 不执行集成、E2E、Windows 凭据、Godot 物理世界、账号联调、导出包运行或 Web 容器 smoke 检查，避免资源开销与等待卡死。数据库、PocketBase 认证和前端产物测试均带 `integration` 构建标签，默认 go test 只运行无真实外部依赖的单元测试；测试阶段静态嵌入仅用临时占位文件满足编译，正式构建使用独立检出和真实 Vue 产物。Godot 可选轻量框架为 [GUT 9.7.1](https://github.com/bitwes/Gut/releases/tag/v9.7.1)（对应 Godot 4.7），适合纯函数测试；本次未引入引擎或框架依赖到 CI。

CI 导出 Windows/macOS 与 Linux 游戏服，构建并发布游戏服 ghcr.io/saurlax/dlut-online 与 Go HTTP ghcr.io/saurlax/dlut-online-web 配套镜像；桌面未签名、macOS 未公证。

## 网站开发

在仓库根运行 `pnpm --dir apps/web dev`，Vite 将 `/api` 代理至本机 Go 8415。网站构建输出 `apps/api/static/`，该目录不提交。正式 Go 编译和前端产物集成测试需要先完成前端构建，Docker 会自动完成；纯单元测试仅要求 go:embed 有可编译的静态目录。仅公开总人数、校区人数与时效，不请求管理员接口。生产仍只运行 `game`、`web` 两个容器，不额外运行 Node。

## 验证

Go 目录运行 `go test -race ./...` 和 `go vet ./...`。需要检查基础联通时，在完成网站构建后从仓库根运行：

```sh
(cd apps/api && go test -tags=integration -run '^TestENetSmoke$' -timeout 1m -v)
```

该 smoke 检查自动启动临时 API 和 Godot 游戏服，只连接两个客户端，验证取票入场、切图、两秒输入及快照确认；客户端限时 30 秒，进程限时 45 秒。不做满员或持续压测，不加入 CI 构建前置步骤。需要本机安装 Godot，游戏资源须已完成导入。

已有空闲测试双服务时，先通过测试账号认证取得两个已验证用户的 ID/token，分别设置 `DO_TEST_ACCOUNT_ID_1`、`DO_TEST_ACCOUNT_TOKEN_1`、`DO_TEST_ACCOUNT_ID_2`、`DO_TEST_ACCOUNT_TOKEN_2`，再运行同一 smoke 脚本（不要把 token 写进版本库或日志）：

```sh
DO_API_SERVER_URL=http://127.0.0.1:8415 python3 apps/game/tools/run_godot.py --headless --path apps/game --script tests/enet_protocol.gd
```

单客户端脚本使用 `DO_TEST_ACCOUNT_ID` 和 `DO_TEST_ACCOUNT_TOKEN`。`campus_travel.gd`、`campus_transfer.gd`、`player_network.gd` 和 Go 的弱网、HTTP 故障恢复、DTLS 集成测试仅用于对应改动的专项检查，不作为每轮任务的必跑清单。碰撞改动仍运行 `server_physics.gd` 等相关物理检查。50 人容量是服务端上限，不要求每次验证都进行 50 人压测；容量压测仅在明确需要性能验收时另行安排。

### 网站与桌面登录

官网 `/login`、`/register` 提供账号登录、注册及验证邮件重发。网站 token 仅保存在当前标签页 sessionStorage，恢复时调用 auth-refresh，退出清除。SMTP、应用地址和验证邮件模板须在 PocketBase 配置；默认使用 PocketBase 自带邮箱确认页面。注册成功不代表邮箱验证完成。

客户端使用 Godot 原生邮箱和密码表单调用 `POST /api/collections/users/auth-with-password`，请求包含 identity（邮箱）和 password。PocketBase AuthRule 要求邮箱已验证且账号未禁用，客户端收到 token 和 record 后申请游戏票据。密码隐藏，提交时清空输入框，不持久保存或输出日志；Token 按 API 根地址隔离保存在 macOS 钥匙串或 Windows 凭据管理器，密码不保存。启动时读取 Token 并调用 `POST /api/collections/users/auth-refresh`，验证通过才建立会话并进入游戏。PocketBase 0.40.3 使用同一个有效 auth token 刷新并签发新 token，没有独立 refresh token；过期 token 无法续期，需重新输入密码。取消终止请求并忽略迟到响应，错误后可以重新输入并登录。

客户端不启动本机回调端口，不使用授权码接口；旧 `/api/v1/auth/requests`、`approve`、`exchange` 已移除。注册链接指向 https://dlut.online/register，用户先注册并验证邮箱，再回到游戏登录。网站原有登录、注册与验证邮件重发保持可用。

只有收到游戏服 welcome 才进入世界；票据接口返回 401/403 或账号被另一客户端替换时清理会话并回到登录。production 客户端账号 API 仍要求 HTTPS。未来 OIDC 和移动系统认证另行设计，当前未交付移动插件或导出。

大地图右下角提供“退出登录”。退出或明确认证失效时清除系统凭据，并写入不含 Token 的本地禁用标记，避免凭据库暂时不可用时下次又自动登录；新登录成功保存后移除标记。网络超时、429 或服务端故障保留凭据，回到可操作表单。macOS 使用系统 security 工具，Windows 使用随客户端导出的 PowerShell 凭据管理器桥接；Token 仅经匿名管道传递，不放入命令行、日志或明文文件。若凭据库不可用仍允许本次密码登录，无法保证下次自动登录。

桌面附件固定为 `DLUT-Online-Windows.exe`（x86_64，内嵌资源包）与 `DLUT-Online-macOS.dmg`（完整 Apple 芯片应用及 Applications 快捷入口）。macOS 导出和 DMG 打包在 macOS 上运行；官方模板仅提供 universal 二进制，因此中间应用仍按 universal 导出，打包时用 lipo 移除 Intel 架构后重新签名，最终仅发布 arm64；打包工具重新做 ad-hoc 签名，并挂载最终 DMG 检查严格签名、应用标识和仅 arm64 架构。检查失败阻止产物上传及 Release。网站直接链接最新正式 Release 的这两个文件，新链接需在首个包含 EXE/DMG 的版本发布后才可用，旧版本附件不会自动转换。

当前 Windows 未签名，macOS 使用有效 ad-hoc 签名，未使用 Apple Developer ID 或公证，不需要私钥、付费证书或 GitHub Secrets。ad-hoc 修复失效模板签名，但不提供发布者身份认证，浏览器下载仍可能被 Gatekeeper 拦截；不通过关闭 Gatekeeper 或批量清除隔离标记绕过。未来正式签名须另行配置 Developer ID 证书及私钥、公证凭据。
