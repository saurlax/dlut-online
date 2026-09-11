## Context

目前 Web 与桌面共用工程，Web 分块下载器在桌面也会实例化但不启用。Go 启动要求 Web 文件存在，CI 和镜像与 Web 导出耦合。用户明确取消 Web 并要求评估 socket 协议。

## Goals / Non-Goals

目标为移除浏览器产品与构建依赖、保留完整本地地图和现有服务器权威行为。默认渲染器按后续要求改为 Forward+，不设置移动端覆盖；不改变模型精度、物理规则、SSO 或数据库，不修改根 README。

## Decisions

移除 Web 预设、模板安装项、分块导出插件、下载器、浏览器桥接及其专用测试。桌面从本地完整场景异步切图，继续使用已有 prepare/ready/entered 状态机与取消/心跳。Go 保留站点和 API，首页改为客户端发布页链接，移除 `/web/` 与 web-dir。CI 只导出 Windows、macOS 和 Linux 游戏服务器，测试无需 Web 文件的双服务运行。

用户确认部署平台支持 UDP，并要求 Go 返回游戏服地址与票据后客户端直连。当前使用 ENet 协议版本 4，Go 不再代理游戏流量。采用 Godot 原生 ENetConnection/ENetPacketPeer，沿用业务消息和服务器权威模拟。控制通道 0 可靠有序承载 JSON 认证、名册与切图，通道 1 不可靠有序承载 JSON 输入和二进制快照。输入沿用累计跳跃序号和输入超时，客户端使用 server_tick/map_epoch 拒绝跨通道迟到数据。

快照显式二进制编码，每个玩家 68 字节，16 字节包头，每包最多 12 人，共 832 字节；不依赖对象反序列化。每 tick 按地图复用分包，客户端只保留最新 tick 的最多 5 包，齐全后应用；丢包跳过该帧，后续帧继续。可靠名册与快照独立，未获得昵称前不生成对应远端角色。服务器不保留待重发的历史快照，连接、输入工作量和握手超时有界。

客户端可达的 enet:// 或 enets:// 主机:端口存入 PocketBase `servers` Collection；票据响应同时返回 game_server_url 与 version:4。DO_API_SERVER_URL 专指 Go HTTP 根地址。生产 Go 拒绝明文 enet://；客户端按 account-only-login 后续要求在两种环境均接受 enet:// 和 enets://，游戏服 DO_ENV=production 要求 DO_GAME_TLS_CERT/DO_GAME_TLS_KEY，使用 ENet 原生 DTLS。客户端默认验证系统信任链和端点主机名，可通过 DO_GAME_TLS_CA 配置自有 CA，不提供禁用验证模式。证书通过部署平台只读挂载，源码与镜像不包含私钥。

选择 ENet 避免自行实现 UDP 连接与可靠重传；原始 TCP 仍有队头阻塞，QUIC 集成需要额外依赖。已有的 50 人 WebSocket 性能数字不作为 ENet 验收，重新测试真实 ENet 连接、二进制快照、丢包乱序和 API 重启隔离。

## Risks / Trade-offs

- 完整客户端体积较大 → 沿用已有桌面完整资源分发，不新增更新器或资源服务器。
- 删除 Web 专属测试后可能漏掉共享加载回归 → 保留本地三校区切图、取消/加载失败、物理与导出资源检查。
- 停止 Web 后旧链接失效 → `/web/` 返回 404，首页提供正式客户端发布入口。

## Migration Plan

同步发布桌面与双服务构建。Go 不再携带或需要 Web 文件，游戏协议升级为 v3 并暴露 UDP 端口，配置公网端点与生产 DTLS 证书；恢复 WebSocket/Web 必须协调回滚客户端、Go 和游戏服。既有 Web 变更保留历史完成记录，本次是平台支持现行依据。

## Editor Run Profiles

Run environment 插件位于 apps/game/addons/run_environment/，通过 EditorPlugin 在 CONTAINER_TOOLBAR 放置 Env 标签与 Local / Dev OptionButton，负责本机选择保存及启动校验。Desktop server configuration 插件位于 apps/game/addons/desktop_export/，仅注册 EditorExportPlugin 处理桌面配置和 Windows 凭据脚本导出。两者共用 desktop_config.gd，互不依赖。Local 使用 http://localhost:8415，Dev 按用户指定使用 https://dlut.online；二者都是客户端 development 配置，不改变远端服务的部署环境。使用 ConfigFile 将 profile 存入 apps/game/.godot/do_run_environment.cfg，该目录已忽略，不提交或导出。

desktop_config 仅在 editor feature 的运行进程读取本机选择，首次读取后固定本进程默认值，避免运行中切换导致账号认证与票据申请跨 API。显式 DO_ENV / DO_API_SERVER_URL 仍按现有规则覆盖。插件展示实际默认地址及环境变量覆盖提示。导出插件继续从 production 默认值和显式环境变量生成包内配置，不读取本机 profile。

## Unified CI Tests

build-web.yml 与 build-game.yml 各自通过原生 paths 过滤 main 分支 push 和 PR；其他分支 push 不触发，避免同一 PR 更新重复构建，也支持手动运行及 workflow_call。Web 内置 test 任务，build 通过 needs: test 等待测试成功；Game 当前未接入轻量单元测试，只执行必要生成和导出，不重复跑 Vue/Go，不增加空 test。未来 Godot 单元测试直接放入 Game 工作流作为其构建前置。不保留 test.yml、ci.yml 或脚本路径判断。release.yml 校验标签后并行调用两个 build 工作流，Web 执行 test → build，Game 执行构建，全部成功后下载本次构建 ZIP 发布。各构建工作流使用独立 concurrency 组，仅非标签运行取消旧任务。

测试阶段只做 Vue vue-tsc、Go go test（60 秒超时）和 vet，不跑 race、不下载 LFS、Godot 或导出模板。Go 的 PocketBase/数据库/前端真实产物测试添加 integration 标签，进程联调沿用既有标签。默认保留纯计算和使用替身依赖、无真实网络/数据库的内存内 handler 单元测试。为满足 go:embed，在测试任务临时 static/ 放置占位文件；构建任务独立检出并由 Docker 生成真实 Vue 产物，不复用占位文件。

构建只执行必要碰撞生成、编译、导出、打包和上传，移除 Web 容器 smoke 和 Godot 导出包运行检查。集成/E2E 仅在相关变更时本地专项运行。测试失败通过 needs 依赖阻止对应 build，任一构建工作流失败均阻止 release。

Godot 框架评估选择 GUT 9.7.1 作为后续纯函数单元测试候选，支持 Godot 4.7、GDScript 断言和 CLI；当前按最小 CI 范围不安装引擎或引入框架，禁止将加载校园、物理、网络和系统凭据操作作为单元测试加入 CI。
