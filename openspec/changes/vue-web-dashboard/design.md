## Context

Go 已有公开在线人数接口和 PocketBase 账户能力。网站定位为游戏官网 Landing、账户管理与数据工具，当前仍只有首页；游戏 UI 继续只使用 Godot。

## Goals / Non-Goals

提供可维护的前端工程、统一组件主题与宣传型 landing 页，为后续账户管理和数据工具建立 UI 基础。本轮不新增账户页面、玩家隐私数据、虚构统计或 SSR。

## Decisions

Vue 3 + TypeScript + Vite + Naive UI，源码放 apps/web/src；构建结果 apps/api/static 被 Go embed 打入二进制且不提交。Naive UI 使用全局中文 locale 与 DLUT Online 主题变量，按需导入现有页面所用组件。开发时 Vite 代理 /api 至 Go 8415，生产不运行 Node。只为首页、/download（含末尾斜杠）和实际存在的静态文件提供响应，不将未知 API 或旧 /web 路由回退为 HTML。

首页不请求在线接口，移除轮询、人数和服务状态展示。Go 公开在线接口保持原有行为；页面只承载产品介绍、校园实景与客户端下载。

## Risks / Trade-offs

Go 编译前必须先构建前端，CI、Docker 及应用文档统一该顺序。公开网页不请求管理员接口，不嵌入服务凭据。

Go 源码迁移至 apps/api，Vue 位于 apps/web。应用技术文档与合并构建 Dockerfile 放在 apps/api；既有 Go 模块名保持兼容。更新所有现行路径引用，Compose web 名称和 dlut-online-web 镜像不变。

包管理统一使用 pnpm，packageManager 固定版本，提交 pnpm-lock.yaml；CI 和 Docker 使用 frozen-lockfile 安装，不维护 npm 锁文件。

## 首页设计语言

本次按用户要求重做布局：全屏实景动态首屏，随后依次展示玩法特色、活动日历、版本更新、实机演示四区。首屏覆盖式轻导航、居中宋体大标题与单一主要下载入口，采用 MMORPG 官网的沉浸式节奏，不保留仪表盘布局。

品牌蓝 #0041B7，纸白 #F6F5F1，深墨色 #0B1727。首页主标题使用 Google Fonts Ma Shan Zheng 毛笔楷书，其他标题保留宋体，正文与交互使用无衬线体。Naive UI NConfigProvider 与 GlobalThemeOverrides 统一按钮风格，不新增框架依赖。窄屏垂直编排，按钮可换行，保留清晰的键盘焦点。

背景改用大工英文官网发布的真实校园视频，静音、循环、内联播放。按用户要求移除首屏底部的向下探索、校园实景标签及播放/暂停控制；系统偏好减少动态效果或页面隐藏时暂停，自动播放被拒绝时保留静态画面，资源失败时显示静态封面。删除照片平移缩放动画，不使用游戏素材。

校园展示提供三个实景视角的手动切换，标题和图像由同一对象驱动，不自动轮播。页面标明校园实景；首屏使用正式客户端下载文案，不展示建设进度；实景图片继续标注来源属性，不等同于游戏截图。

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

### 手写标题与下载入口

首页 h1 单独使用 Google Fonts 的 Ma Shan Zheng（马善政毛笔楷书），字体权重 400、font-display: swap。2026-09-10 从 https://fonts.googleapis.com/css2?family=Ma+Shan+Zheng 获取 text=大工，再相逢。 的标题子集（7 个唯一字符），本地保存 apps/web/src/assets/fonts/ma-shan-zheng-title.ttf，并保留 apps/web/public/licenses/ma-shan-zheng-OFL.txt，构建后随字体一并分发（来源 https://github.com/google/fonts/tree/main/ofl/mashanzheng ）。新增或修改标题字符时重新获取子集；不改字间距，不依赖运行时 Google Fonts 网络请求。字体通过 Vite 引用并进入 Go 静态嵌入产物，仅用于网站。

顶部只保留前往 /download 的下载导航；首屏主按钮按浏览器系统识别 Windows / macOS，分别显示对应下载文案，未知系统、Linux、Android、iPhone、iPad（包括桌面模式）进入 /download 选择页。系统检测只影响建议，不限制下载页访问。平台链接集中维护在 apps/web/src/downloads.ts；目前两个平台均使用用户接受的 GitHub Releases 页面，未发现可核实的 latest 安装包，不构造虚假直链。以后替换平台 URL 为 OSS 即可，检测与组件无需改动。

首屏“其他下载”进入 /download。下载页用 Naive UI 按钮列出 Windows x86_64、macOS Universal，当前系统标注推荐。原生链接跳转及浏览器前进/后退，不为两个页面引入路由依赖；Go 仅对 /、/download、/download/ 返回应用入口，其他未知路径继续 404。

首屏标题固定为“大工，再相逢”（无句号），移除标题上方英文校名和“第一人称校园 MMORPG”说明。既有字体子集包含全部剩余字符，仅删除句号不需重新生成字体文件。

### 正式内容文案

参考《燕云十六声》官网的玩法特色与场景展示分段，首页下半页改为“玩法特色 → 活动日历 → 版本更新 → 实机演示”。使用具体功能说明：第一人称行走与奔跑、地图查看位置和建筑分布、校区传送、同校区玩家实时可见。场景卡片说明建筑特征，不再使用回忆、故事与相逢等重复标语。保留首屏主标题“大工，再相逢”，其余文案直接介绍游戏内容。首页和下载页不出现未完成、规划、持续建设等进度表述，不增加未经实现的战斗、任务、奖励或室内功能承诺。

### Naive UI 组件优先

下载页使用 NPageHeader（含返回首页操作）、NGrid/NGi、NCard、NTag、NText/NP 与 NButton；组件主题集中在 GlobalThemeOverrides，卡片、边框与推荐标记不自行仿制。首页与页脚排列使用 NFlex，游戏介绍与场景区域使用响应式 NGrid，玩法说明采用 NList/NListItem/NThing，照片采用关闭预览的 NImage，场景选择采用 NRadioGroup/NRadioButton。屏幕断点采用 Naive UI 的 m（768px），小屏单列，场景网格启用 item-responsive。

保留语义化 main/section/figure、品牌标题与原生视频背景，定制样式仅用于品牌视觉、版面留白及图片裁切，不新增功能或修改字间距。

### 首页四区结构

保留视频首屏，正文固定为玩法特色、活动日历、版本更新、实机演示，取消独立下载收尾区。玩法特色复用现有真实功能介绍；活动日历使用 NCalendar，默认当天，可切月及选择日期，旁侧 NCard 显示选中日期与 NEmpty 日程状态。当前无活动排期，不编造活动。版本更新使用 NCard 提供 GitHub Releases 记录入口；2026-09-10 查询未发现发布记录，不编造版本号、日期或日志。实机演示暂用现有三个校园实景图切换，继续标注校园实景，不添加假的视频播放按钮。字体子集标题不变，新增正文使用系统字体。

### 前端验证约定

按用户要求移除 apps/web 的测试文件与 package.json test 脚本，CI 网站步骤仅安装依赖并执行包含 TypeScript 检查的生产构建。常规前端改动不新增自动化测试文件或框架，按需进行浏览器检查；Go 与 Godot 检查不受影响。
