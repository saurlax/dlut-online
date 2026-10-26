# 仓库与构建

## 目录边界

| 路径 | 内容 |
| --- | --- |
| `apps/api/` | Go 模块、PocketBase 服务、后续权威世界和 Pion 模块 |
| `apps/web/` | Next.js App Router、TypeScript、后续 Phaser 游戏 |
| `spec/` | 当前行为与架构契约 |
| `docs/` | 操作与部署指南 |
| `.github/workflows/` | test.yml、build.yml、release.yml |
| `Dockerfile` | 唯一发行镜像构建入口 |

`main` 为浏览器像素版本主线，`3d` 保存历史 Godot 版本，不维护 `pixel` 分支。旧分支的客户端导出、三维资源和双镜像流水线不进入新主线。

## 构建与发行

Next.js 使用 `output: "export"` 和 `trailingSlash: true`，构建输出 `apps/web/out/`。Go 通过文件系统提供完整导出目录，不用 SPA 首页兜底掩盖未知 URL，也不覆盖 PocketBase `/api/` 与 `/_/`。

根 Dockerfile 分别构建前端和 Go，最终阶段只包含 Go 可执行文件、静态网页、证书及必要系统文件，无 Node 服务。镜像名统一为 `dlut-online`，仓库发行地址为 `ghcr.io/saurlax/dlut-online`；不再生成 `dlut-online-web` 或独立三维游戏服镜像。

SQLite 数据放在 `/data/pb_data` 持久卷，运行用户为非 root。当前镜像仅开放 HTTP 8415；未实现 WebRTC 时不发布虚假的 UDP 服务端口。

test.yml 提供可复用的前端类型检查与 Go test/vet。build.yml 在主线 push、PR、手动和发布复用时先调用测试，再构建统一镜像。PR 仅构建，主线发布 latest 和提交标签。release.yml 接收版本标签并调用同一构建流程，不绕过测试门禁。

## 状态

当前仅初始化工程。完整校园和多人实现完成前，镜像不能描述为正式可玩的多人版本。
