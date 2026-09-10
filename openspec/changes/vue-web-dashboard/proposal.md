## Why

用户希望使用 Vue 与 Vite 持续开发网站数据展示，避免手工维护 DOM。

## What Changes

- apps/web 使用 Vue 3、TypeScript、Vite 和 Naive UI，首页作为游戏官网入口展示产品、客户端下载与在线情况。
- Go 嵌入前端构建结果，同域提供页面及现有 API；Docker 与 CI 先构建前端。
- 展示数据时效，轮询失败或过期时不报告零人。

## Capabilities

### New Capabilities
- `web-dashboard`: Vue 网站、在线状态展示及同域部署。

### Modified Capabilities

## Impact

Go 代码移动到 apps/api，Vue 位于 apps/web；网站后续承载 Landing、账户管理与数据工具，影响网站首页与构建，不改变 Godot 客户端、游戏服或 API 协议。仍部署 game/web 两个服务。
