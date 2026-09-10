## Context

Go 已有公开在线人数接口和 PocketBase 账户能力。网站定位为游戏官网 Landing、账户管理与数据工具，当前仍只有首页；游戏 UI 继续只使用 Godot。

## Goals / Non-Goals

提供可维护的前端工程、统一组件主题与宣传型 landing 页，为后续账户管理和数据工具建立 UI 基础。本轮不新增账户页面、玩家隐私数据、虚构统计或 SSR。

## Decisions

Vue 3 + TypeScript + Vite + Naive UI，源码放 apps/web/src；构建结果 apps/api/static 被 Go embed 打入二进制且不提交。Naive UI 使用全局中文 locale 与 DLUT Online 主题变量，按需导入现有页面所用组件。开发时 Vite 代理 /api 至 Go 8415，生产不运行 Node。只为首页和实际存在的静态文件提供响应，不将未知 API 或旧 /web 路由回退为 HTML。

首页不请求在线接口，移除轮询、人数和服务状态展示。Go 公开在线接口保持原有行为；页面只承载产品介绍、校园实景与客户端下载。

## Risks / Trade-offs

Go 编译前必须先构建前端，CI、Docker 及应用文档统一该顺序。公开网页不请求管理员接口，不嵌入服务凭据。

Go 源码迁移至 apps/api，Vue 位于 apps/web。应用技术文档与合并构建 Dockerfile 放在 apps/api；既有 Go 模块名保持兼容。更新所有现行路径引用，Compose web 名称和 dlut-online-web 镜像不变。

包管理统一使用 pnpm，packageManager 固定版本，提交 pnpm-lock.yaml；CI 和 Docker 使用 frozen-lockfile 安装，不维护 npm 锁文件。

## 首页设计语言

本次按用户要求重做布局：全屏实景动态首屏、纸白叙事介绍、深墨色校园实景展示、蓝色下载收尾。首屏覆盖式轻导航、居中宋体大标题与单一主要下载入口，采用 MMORPG 官网的沉浸式节奏，不保留仪表盘布局。

品牌蓝 #0041B7，纸白 #F6F5F1，深墨色 #0B1727。宋体用于主标题，无衬线体用于正文与交互。Naive UI NConfigProvider 与 GlobalThemeOverrides 统一按钮风格，不新增字体或依赖。窄屏垂直编排，按钮可换行，保留清晰的键盘焦点。

背景改用大工英文官网发布的真实校园视频，静音、循环、内联播放。提供暂停/播放按钮，用户暂停后不自动恢复；系统偏好减少动态效果或页面隐藏时暂停，自动播放被拒绝时保留可点击的播放按钮，资源失败时显示静态封面。删除照片平移缩放动画，不使用游戏素材。

校园展示提供三个实景视角的手动切换，标题和图像由同一对象驱动，不自动轮播。页面标明校园实景；下载区提示项目持续建设中，避免把照片等同于已完成的游戏质量。

### 参考来源与使用边界

2026-09-10 读取以下官网页面结构：
- https://www.yysls.cn/ ：大幅主视觉与集中下载入口。
- https://freetrial.finalfantasyxiv.com/ ：背景影像、分段世界介绍和转化入口。
- https://www.guildwars2.com/en/ ：世界观宣传与清晰的游玩入口。
- https://www.naeu.playblackdesert.com/en-US/Main/Index ：游戏官网入口与品牌呈现。
- https://www.dlut.edu.cn/css/style20230317.css ：参考品牌蓝 #0041B7，不声称为学校完整 VI 标准。

图片来自 http://map.dlut.edu.cn 的已归档实景，原始读取 2026-09-09，本次复核 2026-09-10；原始 URL 和图片 ID 在 references/lingshui/photos/77386.json 与 77357.json 对应 result 数组中。网站展示副本：
- main-building.jpg ← references/lingshui/photos/77386-1.jpg，主楼，Feature 77386，用于首屏与场景展示。
- library.jpg ← references/lingshui/photos/77357-7.jpg，令希图书馆，Feature 77357，用于场景展示。
- campus-garden.jpg ← references/lingshui/photos/77386-4.jpg，主楼旁绿荫，Feature 77386，用于介绍与场景展示。

仅作为网站宣传中的校园实景，不进入 Godot 客户端，不作为游戏截图或新增建模精度证据。没有修改建筑模型、室内或碰撞。

### 背景视频与默认字距

2026-09-10 从 https://en.dlut.edu.cn/ 首页读取视频源 https://en.dlut.edu.cn/video/ssdg.mp4 （首页图片对象 78290）。截取 22.0–23.2 秒及 26.0–29.2 秒的校园航拍、校名石、主楼与图书馆实景片段，按原时间顺序拼接、以 2/3 速度播放，移除音轨，转为 H.264/yuv420p、25fps、faststart MP4。保留原始 856×480 分辨率，不声称高清视频。展示文件 apps/web/src/assets/campus-film.mp4，第一帧封面 campus-film-poster.jpg；原始完整片与临时处理产物仅留在忽略目录 .local/landing/。影片不进入游戏客户端。

遵循 AGENTS.md：所有文字使用字体默认字间距，禁止设置 letter-spacing、tracking 或等效字符间距，也不插入空格模拟字距。
