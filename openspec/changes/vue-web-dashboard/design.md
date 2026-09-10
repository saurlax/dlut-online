## Context

Go 已有公开在线人数接口，未接入 SSO、数据库或历史分析。用户已授权网站使用 Vue，游戏 UI 继续只使用 Godot。

## Goals / Non-Goals

提供可维护的前端工程与真实在线状态展示。不添加账号、玩家隐私数据、虚构统计或 SSR。

## Decisions

Vue 3 + TypeScript + Vite，源码放 apps/web/src；构建结果 apps/api/static 被 Go embed 打入二进制且不提交。开发时 Vite 代理 /api 至 Go 8415，生产不运行 Node。只为首页和实际存在的静态文件提供响应，不将未知 API 或旧 /web 路由回退为 HTML。

每 10 秒串行请求公开在线接口，设超时并在组件卸载时取消请求。按 received_at 判断 15 秒有效期，错误或失效展示未知状态及最后更新时间，不将 last_total 作为当前人数。页面保留客户端下载入口，适配桌面与移动屏幕。

## Risks / Trade-offs

Go 编译前必须先构建前端，CI、Docker 及应用文档统一该顺序。公开网页不请求管理员接口，不嵌入服务凭据。

Go 源码迁移至 apps/api，Vue 位于 apps/web。应用技术文档与合并构建 Dockerfile 放在 apps/api；既有 Go 模块名保持兼容。更新所有现行路径引用，Compose web 名称和 dlut-online-web 镜像不变。

包管理统一使用 pnpm，packageManager 固定版本，提交 pnpm-lock.yaml；CI 和 Docker 使用 frozen-lockfile 安装，不维护 npm 锁文件。
