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

## 首页设计语言

视觉主题为「蓝墨校园」：以大工蓝建立识别，用纸白留白与宋体标题表现校园的人文气质。参考《燕云十六声》官网的大幅主视觉、低密度导航、集中的下载入口；不复制其游戏素材、标志或武侠文案。

- 品牌蓝 `#0041B7`，悬停 `#245CCE`，按下 `#00338F`；纸白 `#F6F5F1`，墨色 `#192B40`，次级文字 `#5C6877`，边线 `#D6DADE`。品牌蓝来自大工官网 CSS，属于本产品参考取色，不声称为学校完整 VI 标准。
- 标题使用系统宋体（Songti SC / STSong / SimSun），正文使用系统无衬线字体；不新增字体依赖。桌面主标题 88px 上限，移动端 48px 上限，正文 14–16px。
- 使用 8px 间距节奏，近直角按钮和细边线；主视觉为左右错位的标题与校园照片，在线状态为下方四列紧凑信息带。小屏依次显示标题、照片、在线数据，不横向溢出。
- Naive UI 的 NConfigProvider / GlobalThemeOverrides 集中配置主题，NButton、NTag、NCard、NStatistic 承载交互与状态，不用 `!important` 覆盖组件内部主题变量。
- 下载和 GitHub 保留真实链接，在线状态继续沿用 10 秒轮询、15 秒有效期与未知状态语义。保留键盘焦点样式，动效遵循 prefers-reduced-motion。

### 参考来源与使用边界

2026-09-10 读取 https://www.yysls.cn/ 及 https://www.dlut.edu.cn/ 、https://www.dlut.edu.cn/css/style20230317.css ，参考构图和配色，不下载其品牌或游戏美术到产品。

首页图片使用仓库已有 `references/lingshui/photos/77386-1.jpg`（主楼，Feature ID 77386，官方地图 http://map.dlut.edu.cn ，原始读取 2026-09-09，本次复核 2026-09-10）。网站单独保留展示副本 `apps/web/src/assets/main-building.jpg`，页面标注「主楼 / 校园实景」，仅用于网站背景视觉；原始参考仍不进入 Godot 桌面客户端，不作为游戏渲染或新增建模精度证据。
