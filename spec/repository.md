# 仓库与构建

## 目录边界

| 路径 | 内容 |
| --- | --- |
| `apps/api/` | Go 模块、PocketBase 服务、后续权威世界和 Pion 模块 |
| `apps/web/` | Vite、React、TypeScript、Three.js 校园场景及原生像素资源 |
| `spec/` | 当前行为与架构契约 |
| `docs/` | 操作与部署指南 |
| `.github/workflows/` | test.yml、build.yml |
| `Dockerfile` | 唯一发行镜像构建入口 |

`main` 为产品主线，默认直接在 `main` 开发。

源码、字体、像素图片与参考数据直接使用普通 Git 跟踪，不依赖 Git LFS。`.gitattributes` 只维护普通 Git 属性，不添加 LFS 过滤规则；检出和 CI 不需要安装、拉取或推送 LFS 对象。此约定适用于当前主线及后续提交，不重写已有历史。

## 构建与发行

Vite 使用多页面模式，首页 `index.html`、游戏 `game/index.html` 和 `404.html` 分别挂载 React；构建输出 `apps/web/out/`，游戏场景通过 React.lazy 按需加载。Go 通过文件系统提供完整构建目录，未知页面返回静态 404 页及 HTTP 404，不用 SPA 首页兜底，也不覆盖 PocketBase `/api/` 与 `/_/`。

根 Dockerfile 分别构建前端和 Go，最终阶段只包含 Go 可执行文件、静态网页、证书及必要系统文件，无 Node 服务。镜像名统一为 `dlut-online`，手动构建；k3s 示例使用导入节点 containerd 的本地镜像，不依赖镜像注册表。

SQLite 数据放在 `/data/pb_data` 持久卷，运行用户为非 root。当前镜像仅开放 HTTP 8415；未实现 WebRTC 时不发布虚假的 UDP 服务端口。

test.yml 提供可复用的前端类型检查、Vite 生产构建与 Go test/vet/build。build.yml 为检查入口，在主线代码 push、PR、`v*` 标签 push 和手动触发时调用检查。Actions 只有仓库读取权限，不创建 Release，不登录 GHCR，不构建或推送容器镜像。根 Dockerfile 保留，镜像按需手动构建与发布。

## 状态

镜像提供产品入口、开发区、凌水和盘锦三个校区的 HD-2D 场景、账号与角色、背包，以及 WebSocket 玩家移动、外观、聊天与天气；Go 校验移动与碰撞，WebRTC 尚未实现。生成资源随静态构建复制进镜像；生成工具和原始照片不进入运行进程。Vite 将 `apps/web/public/` 原样复制到发行目录。原始采集资料、凭据和临时配置放在仓库根目录的 `.local/`，PocketBase 数据放在独立数据目录。
