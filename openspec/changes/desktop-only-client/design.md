## Context

目前 Web 与桌面共用工程，Web 分块下载器在桌面也会实例化但不启用。Go 启动要求 Web 文件存在，CI 和镜像与 Web 导出耦合。用户明确取消 Web 并要求评估 socket 协议。

## Goals / Non-Goals

目标为移除浏览器产品与构建依赖、保留完整本地地图和现有服务器权威行为。此次不改变渲染器、模型精度、物理规则、SSO 或数据库，不修改根 README。

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
