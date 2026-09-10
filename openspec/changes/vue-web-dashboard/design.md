## Context

Go 已有公开在线人数接口和 PocketBase 账户能力。网站定位为游戏官网 Landing、账户管理与数据工具，当前仍只有首页；游戏 UI 继续只使用 Godot。

## Goals / Non-Goals

提供可维护的前端工程、统一组件主题与真实在线状态展示，为后续账户管理和数据工具建立 UI 基础。本轮不新增账户页面、玩家隐私数据、虚构统计或 SSR。

## Decisions

Vue 3 + TypeScript + Vite + Naive UI，源码放 apps/web/src；构建结果 apps/api/static 被 Go embed 打入二进制且不提交。Naive UI 使用全局中文 locale 与 DLUT Online 主题变量，按需导入现有页面所用组件。开发时 Vite 代理 /api 至 Go 8415，生产不运行 Node。只为首页和实际存在的静态文件提供响应，不将未知 API 或旧 /web 路由回退为 HTML。

每 10 秒串行请求公开在线接口，设超时并在组件卸载时取消请求。按 received_at 判断 15 秒有效期，错误或失效展示未知状态及最后更新时间，不将 last_total 作为当前人数。页面保留客户端下载入口，适配桌面与移动屏幕。

## Risks / Trade-offs

Go 编译前必须先构建前端，CI、Docker 及应用文档统一该顺序。公开网页不请求管理员接口，不嵌入服务凭据。

Go 源码迁移至 apps/api，Vue 位于 apps/web。应用技术文档与合并构建 Dockerfile 放在 apps/api；既有 Go 模块名保持兼容。更新所有现行路径引用，Compose web 名称和 dlut-online-web 镜像不变。

包管理统一使用 pnpm，packageManager 固定版本，提交 pnpm-lock.yaml；CI 和 Docker 使用 frozen-lockfile 安装，不维护 npm 锁文件。
