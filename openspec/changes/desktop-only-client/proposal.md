> 现行登录要求由 [account-only-login](../account-only-login/specs/account-only-login/spec.md) 取代：所有玩家必须绑定 PocketBase 已验证账号，通过官网认证后返回游戏。本文中的游客入口、游客 ID 与游客入场描述仅记录历史，不再作为当前实现要求。

## Why

用户取消 Web 游戏支持，产品只发布 Windows/macOS 客户端。移除浏览器专用构建与运行路径，减少快速迭代中的维护成本，并评估更适合实时游戏的传输协议。

## What Changes

- 默认渲染器改为 Forward+，编辑器与桌面导出共用配置，移动端覆盖留待后续适配。

- **BREAKING**：移除 Web 导出、浏览器身份适配、校区下载和分块工具及 `/web/` 托管；Go 启动和镜像不再依赖 Web 资源。
- 保留 Windows/macOS 完整地图导出和 Linux Godot 专用服务器，保留地图切换与当前权威联网能力。
- 更新 CI、应用技术文档和 AGENTS.md；根 README 不修改。
- **BREAKING**：改用 ENet/UDP；当前协议版本为 4。Go 返回公网游戏地址和票据，客户端直连游戏服，移除 Go WebSocket 代理。生产使用 DTLS 证书校验。

- 编辑器顶部增加 Env Local / Dev 下拉框，插件按惯例放在 addons/desktop_export，本机选择仅影响下一次编辑器运行；Dev 使用 https://dlut.online，桌面导出默认仍为 production。

## Capabilities

### New Capabilities

- `desktop-client-distribution`: 桌面客户端分发、完整本地资源与无浏览器依赖的服务运行。

### Modified Capabilities

无。既有变更中的 Web 平台与下载要求作为历史记录，由本次桌面分发要求取代。

## Impact

Godot 导出配置、客户端加载与游客模块、Web 专用工具和测试、Go 静态服务、Docker/CI、AGENTS.md 与应用技术文档。无新依赖，不修改建筑和碰撞源数据。
