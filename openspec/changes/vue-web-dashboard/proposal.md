## Why

用户希望网站首页成为以校园世界宣传介绍为主的 MMORPG landing 页，使用 Vue、Vite 与 Naive UI，建立有沉浸感的品牌入口。

## What Changes

- apps/web 使用 Vue 3、TypeScript、Vite 和 Naive UI，首页作为游戏官网入口展示产品愿景、校园实景与客户端下载。
- Go 嵌入前端构建结果，同域提供页面及现有 API；Docker 与 CI 先构建前端。
- 首页不展示在线人数、服务状态或统计面板，不请求在线接口。
- 首页采用大工蓝、纸白与墨色设计语言，参考《燕云十六声》的沉浸式主视觉构图与下载入口层级，使用校园实景和 Naive UI 统一主题。

## Capabilities

### New Capabilities
- `web-dashboard`: Vue 宣传网站、校园实景展示及同域部署。

### Modified Capabilities

## Impact

Go 代码移动到 apps/api，Vue 位于 apps/web；网站后续承载 Landing、账户管理与数据工具，影响网站首页与构建，不改变 Godot 客户端、游戏服或 API 协议。仍部署 game/web 两个服务。
