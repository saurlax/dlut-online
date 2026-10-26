# 仓库与构建

## 目录边界

| 路径 | 内容 |
| --- | --- |
| `apps/api/` | Go 模块、PocketBase 服务、后续权威世界和 Pion 模块 |
| `apps/web/` | Next.js App Router、TypeScript、Phaser 校园场景及原生像素资源 |
| `spec/` | 当前行为与架构契约 |
| `docs/` | 操作与部署指南 |
| `.github/workflows/` | test.yml、build.yml、release.yml |
| `Dockerfile` | 唯一发行镜像构建入口 |

`main` 为产品主线，独立任务在对应类型的工作分支上开发。

源码、字体、像素图片与参考数据直接使用普通 Git 跟踪，不依赖 Git LFS。`.gitattributes` 只维护普通 Git 属性，不添加 LFS 过滤规则；检出和 CI 不需要安装、拉取或推送 LFS 对象。此约定适用于当前主线及后续提交，不重写已有历史。

## 构建与发行

Next.js 使用 `output: "export"` 和 `trailingSlash: true`，构建输出 `apps/web/out/`。Go 通过文件系统提供完整导出目录，不用 SPA 首页兜底掩盖未知 URL，也不覆盖 PocketBase `/api/` 与 `/_/`。

根 Dockerfile 分别构建前端和 Go，最终阶段只包含 Go 可执行文件、静态网页、证书及必要系统文件，无 Node 服务。镜像名统一为 `dlut-online`，仓库发行地址为 `ghcr.io/saurlax/dlut-online`。

SQLite 数据放在 `/data/pb_data` 持久卷，运行用户为非 root。当前镜像仅开放 HTTP 8415；未实现 WebRTC 时不发布虚假的 UDP 服务端口。

test.yml 提供可复用的前端类型检查与 Go test/vet。build.yml 在主线 push、PR、手动和发布复用时先调用测试，再构建统一镜像。PR 仅构建，主线发布 latest 和提交标签。release.yml 接收版本标签并调用同一构建流程，不绕过测试门禁。

## 状态

镜像提供产品入口与开发区校区地图浏览，不包含可玩的角色、碰撞或多人同步。生成资源随静态导出复制进镜像；生成工具和原始照片不进入运行进程。
