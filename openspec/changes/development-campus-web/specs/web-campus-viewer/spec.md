## Purpose

提供全 Godot 的 DLUT Online 第一人称校园世界，支持三校区场景切换。

## ADDED Requirements

### Requirement: 全 Godot 与浏览器运行
系统 SHALL 使用 Godot 原生场景和控件，Web 使用官方导出外壳，项目名称为 DLUT Online，不引入外部界面框架或业务 JS 桥接。

#### Scenario: 启动游戏
- **WHEN** 玩家通过支持 WebGL 2 的桌面浏览器访问游戏
- **THEN** 默认进入 lingshui 的第一人称场景，首次显示封面与进入校园按钮，进入后显示圆形小地图

### Requirement: 第一人称控制
系统 SHALL 支持 WASD、Shift 奔跑、鼠标环视、地面和建筑碰撞，眼高约 1.7 米。无法锁定鼠标时 SHALL 支持原生拖动环视。

#### Scenario: 行走
- **WHEN** 玩家进入后按 W 或 Shift 与 W
- **THEN** 按朝向行走或奔跑，不能穿过墙体或地面

### Requirement: 暂停与焦点
系统 SHALL 在失焦或普通探索时按 Escape 后停止移动，不显示封面或继续按钮。

#### Scenario: 暂停
- **WHEN** 玩家失焦或在探索中按 Escape
- **THEN** 停止移动并释放鼠标，点击世界或按 Escape 后恢复

### Requirement: 最小必要界面
系统 SHALL 仅在首次封面提供进入校园按钮，游戏中提供准星、左上圆形小地图及用户主动打开的地图面板，不显示定位宣传、操作教程、技术说明、参考链接或地标搜索。

#### Scenario: 探索画面
- **WHEN** 玩家正常行走
- **THEN** 仅显示准星和圆形小地图，不显示说明性文本

### Requirement: 三校区场景传送
系统 SHALL 提供 lingshui（凌水主校区）、eda（开发区校区）、panjin（盘锦校区）三个独立场景，界面使用上述完整中文名称，默认 lingshui；eda 保留现有模型，其他两处使用明确的简单占位。

#### Scenario: 选择目标校区
- **WHEN** 玩家在地图面板选择其他校区
- **THEN** 卸载旧场景，在目标出生点落地，仅保留一套玩家、相机和输入绑定

### Requirement: 地图交互
系统 SHALL 提供跟随玩家位置与朝向的圆形小地图，点击或 M 打开地图面板和三个校区选择按钮。

#### Scenario: 打开关闭地图
- **WHEN** 玩家点击小地图或按 M
- **THEN** 地图打开且行走暂停、鼠标释放；M 或 Escape按先前状态返回；当前校区按钮不可重复传送

### Requirement: 编辑器可见
每个校园 SHALL 在 tscn 中保存静态模型、环境和灯光，编辑器无需运行游戏即可查看。

#### Scenario: 打开场景
- **WHEN** 开发者打开 scenes/campuses 下任一校区场景
- **THEN** 模型和灯光存在于场景树中，运行时不重复加载

### Requirement: 当前范围
系统 SHALL 不实现活动、战斗、奖励、账号或多人服务器。

#### Scenario: 单人探索
- **WHEN** 玩家进入和切换校区
- **THEN** 无需登录或连接游戏服务器

### Requirement: 首次封面与加载样式
系统 SHALL 仅在首次启动显示 Godot 封面与进入校园按钮，进入后暂停、关闭地图和场景传送均不得再次显示封面或进入/继续按钮。Web SHALL 通过官方导出配置显示 DLUT Online 标识和定制进度条，保留真实加载进度和错误反馈。

#### Scenario: 校区到达
- **WHEN** 玩家传送到另一校区
- **THEN** 直接恢复游戏画面与控制，无需再次确认进入

### Requirement: 全屏大地图
大地图 SHALL 占满屏幕，采用固定默认比例尺，不自动适配全图，右上角竖直排列三个校区按钮，不显示关闭按钮。

#### Scenario: 展开地图
- **WHEN** 玩家按 M 或点击小地图
- **THEN** 看到全屏地图及右上竖排校区列表，M 或 Escape 收起地图

### Requirement: 地图缩放和边界
大地图 SHALL 使用固定默认比例尺，支持滚轮以指针位置缩放和左键拖动。缩放 SHALL 有上下限，拖动 SHALL 根据视口尺寸约束在地图范围内；地图小于视口的轴固定居中。

#### Scenario: 缩放拖动
- **WHEN** 玩家滚轮缩放或拖到地图边缘
- **THEN** 比例尺在限定范围内变化，视口不能继续向地图边界外拖动；调整窗口不自动改变比例尺

### Requirement: 客户端应用目录
Godot 项目 SHALL 位于 apps/client/，内部资源引用保持以 project.godot 为根；原始参考与 OpenSpec SHALL 保留仓库根目录。

#### Scenario: 迁移后构建
- **WHEN** 开发者打开 apps/client/project.godot 或调用客户端导出工具
- **THEN** 三校区可加载，工具可定位根目录参考，Web 导出写入 apps/client/build/web/

### Requirement: Go Web 资源托管
系统 SHALL 使用 apps/server 中的 Go 服务托管 /web/ 下的 Godot 导出资源，替换 Python 静态服务；资源目录 SHALL 可配置。

#### Scenario: 请求游戏资源
- **WHEN** 浏览器访问 /web 或请求不存在的资源
- **THEN** /web 重定向至 /web/，缺失资源返回 404，WASM 使用 application/wasm，目录不展示文件列表

### Requirement: 服务容器与持续集成
Go 服务 SHALL 支持 PORT 环境变量，默认 8060，显式 -addr 优先；CI SHALL 在每次 push 构建 Docker 镜像并提供下载产物。

#### Scenario: 容器指定端口
- **WHEN** 容器设置 PORT=9090 且镜像内置 Web 导出资源
- **THEN** 服务在 9090 提供 /web/ 资源；未设置 PORT 使用 8060，无效端口启动失败

### Requirement: 多平台构建产物
CI SHALL 在每次 push 导出 Godot Web、Windows x86_64 和 macOS universal 客户端；Web SHALL 包含在 Go 镜像中，桌面客户端 SHALL 以 ZIP 上传为 Actions artifacts。

#### Scenario: 下载构建产物
- **WHEN** 一次构建成功
- **THEN** 对应提交提供 Go+Web 镜像 tar、Windows ZIP、macOS ZIP；镜像无需额外挂载即可访问 /web/
