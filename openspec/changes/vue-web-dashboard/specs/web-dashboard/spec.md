## ADDED Requirements

### Requirement: Vue 网站
网站 SHALL 使用 Vue 3、TypeScript、Vite 和 Naive UI，通过 Go 嵌入静态构建产物，运行时不依赖 Node。Naive UI SHALL 提供统一主题、导航操作、场景切换及下载按钮。

#### Scenario: 访问网站
- **WHEN** 用户打开 Go 首页
- **THEN** 显示宣传型 landing 页，包括沉浸式首屏、校园世界介绍、实景展示与客户端下载，并适配移动屏幕

#### Scenario: 未知资源
- **WHEN** 请求不存在的静态资源、API 或旧游戏 Web 路由
- **THEN** 返回 404 而非首页 HTML

### Requirement: 宣传内容范围
首页 SHALL 不展示在线人数、校区统计、服务状态或更新时间，也不轮询在线 API。宣传 SHALL 区分当前能力与愿景，不声称未建设内容已完成。

#### Scenario: 加载和停留
- **WHEN** 用户加载首页并停留
- **THEN** 页面仅介绍校园世界并提供下载入口，不产生在线人数接口请求

### Requirement: 实景动态主视觉
首页 SHALL 采用大工蓝、墨色、纸白的 Naive UI 主题，以全屏校园实景作为首屏背景。首页 SHALL 不使用现有游戏画面或其他游戏美术。首屏 SHALL 使用真实校园 MP4 视频作为背景，不使用照片平移缩放代替视频。

#### Scenario: 动效控制
- **WHEN** 系统偏好减少动态效果或页面隐藏
- **THEN** 背景视频暂停，所有介绍与下载功能仍可用

#### Scenario: 校园实景展示
- **WHEN** 用户切换场景展示
- **THEN** 图片、标题、说明与所选按钮保持一致，并标注校园实景而非游戏截图

#### Scenario: 小屏和键盘访问
- **WHEN** 用户在小屏浏览或使用键盘操作
- **THEN** 页面无横向溢出，入口有清晰焦点，内容顺序合理且交互支持键盘

#### Scenario: 视频失败或自动播放受限
- **WHEN** 视频加载失败或浏览器拒绝自动播放
- **THEN** 加载失败显示静态封面，自动播放受限保留静态画面，宣传介绍和下载始终可用

### Requirement: 默认字间距
页面 SHALL 使用字体默认字间距，不设置 letter-spacing、tracking 或等效字符间距。

#### Scenario: 文案渲染
- **WHEN** 首页在桌面或小屏显示
- **THEN** 标题、品牌、正文和按钮均保留默认字间距

### Requirement: 标题与精简导航
首页主标题 SHALL 使用本地加载的 Google Fonts Ma Shan Zheng 字体子集，保留字体默认字距。顶部 SHALL 只保留下载导航，首屏底部 SHALL 不展示向下探索、实景标签或视频控制行。

#### Scenario: 首页导航
- **WHEN** 用户点击顶部下载或首屏其他下载
- **THEN** 进入 /download 页面，主标题以毛笔手写体显示

### Requirement: 系统识别与下载页
首页主下载按钮 SHALL 识别 Windows/macOS 并使用集中配置的平台 URL；未知或不支持系统 SHALL 指向 /download，移动设备不得误识别为 macOS。当前 URL SHALL 使用 GitHub Releases，后续允许替换为 OSS。

#### Scenario: 支持的桌面系统
- **WHEN** Windows 或 macOS 用户打开首页
- **THEN** 主按钮显示对应平台并指向该平台配置的下载地址

#### Scenario: 其他系统
- **WHEN** 手机、平板、Linux 或未知系统用户打开首页
- **THEN** 主按钮引导选择桌面版本，不伪造平台支持

#### Scenario: 下载页面直达与刷新
- **WHEN** 用户直接访问或刷新 /download 或 /download/
- **THEN** Go 返回应用入口，展示 Windows x86_64 与 macOS Universal 下载选项，未知路径仍返回 404
