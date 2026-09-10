> 现行登录要求由 [account-only-login](../../../account-only-login/specs/account-only-login/spec.md) 取代：所有玩家必须绑定 PocketBase 已验证账号，通过官网认证后返回游戏。本文中的游客入口、游客 ID 与游客入场描述仅记录历史，不再作为当前实现要求。

## Purpose

提供全 Godot 的 DLUT Online 第一人称校园世界，支持三校区场景切换。

## ADDED Requirements

### Requirement: 全 Godot 与浏览器运行
系统 SHALL 使用 Godot 原生场景和控件，Web 使用官方导出外壳，项目名称为 DLUT Online，不引入外部界面框架或业务 JS 桥接。

#### Scenario: 启动游戏
- **WHEN** 玩家通过支持 WebGL 2 的桌面浏览器访问游戏
- **THEN** 默认进入 lingshui 的第一人称场景，首次显示封面与游客登录按钮，进入后显示圆形小地图

### Requirement: 第一人称控制
系统 SHALL 支持 WASD、Shift 奔跑、空格跳跃、鼠标环视、地面和建筑碰撞，眼高约 1.7 米。无法锁定鼠标时 SHALL 支持原生拖动环视。

#### Scenario: 行走
- **WHEN** 玩家进入后按 W 或 Shift 与 W
- **THEN** 按朝向行走或奔跑，不能穿过墙体或地面

### Requirement: 暂停与焦点
系统 SHALL 在失焦或普通探索时按 Escape 后停止移动，不显示封面或继续按钮。

#### Scenario: 暂停
- **WHEN** 玩家失焦或在探索中按 Escape
- **THEN** 停止移动并释放鼠标，点击世界或按 Escape 后恢复

### Requirement: 最小必要界面
系统 SHALL 仅在首次封面提供游客登录按钮，游戏中提供准星、左上圆形小地图及用户主动打开的地图面板，不显示定位宣传、操作教程、技术说明、参考链接或地标搜索。

#### Scenario: 探索画面
- **WHEN** 玩家正常行走
- **THEN** 仅显示准星和圆形小地图，不显示说明性文本

### Requirement: 三校区场景传送
系统 SHALL 提供 lingshui（凌水主校区）、eda（开发区校区）、panjin（盘锦校区）三个独立场景，界面使用上述完整中文名称，默认 lingshui；eda 保留现有模型，lingshui 使用官方主校区轮廓及已核对的局部照片立面，panjin 使用明确的简单占位。

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
系统 SHALL 不实现活动、战斗、奖励或持久账号。游客身份与 WebSocket 玩家同步遵循 guest-player-session 变更。

#### Scenario: 单人探索
- **WHEN** 玩家进入和切换校区
- **THEN** 无需登录或连接游戏服务器

### Requirement: 首次封面与加载样式
系统 SHALL 仅在首次启动显示 Godot 封面、游客昵称与游客登录按钮，进入后暂停、关闭地图和场景传送均不得再次显示封面或登录/继续按钮。Web SHALL 通过官方导出配置显示 DLUT Online 标识和定制进度条，保留真实加载进度和错误反馈。

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
Godot 项目 SHALL 位于 apps/game/，内部资源引用保持以 project.godot 为根；原始参考与 OpenSpec SHALL 保留仓库根目录。

#### Scenario: 迁移后构建
- **WHEN** 开发者打开 apps/game/project.godot 或调用客户端导出工具
- **THEN** 三校区可加载，工具可定位根目录参考，Web 导出写入 apps/game/build/web/

### Requirement: Go Web 资源托管
系统 SHALL 使用 apps/web 中的 Go 服务托管 /web/ 下的 Godot 导出资源，替换 Python 静态服务；资源目录 SHALL 可配置。

#### Scenario: 请求游戏资源
- **WHEN** 浏览器访问 /web 或请求不存在的资源
- **THEN** /web 重定向至 /web/，缺失资源返回 404，WASM 使用 application/wasm，目录不展示文件列表

### Requirement: 服务容器与持续集成
Go 服务 SHALL 支持 DO_API_SERVER_PORT 环境变量，默认 8415，并在未设置时兼容平台 PORT；显式 -addr 优先。CI SHALL 在每次 push 构建 Docker 镜像并提供下载产物。

#### Scenario: 容器指定端口
- **WHEN** 容器设置 DO_API_SERVER_PORT=9090
- **THEN** 服务在 9090 提供站点；未设置项目端口和平台 PORT 时使用 8415，无效端口启动失败

### Requirement: 多平台构建产物
CI SHALL 在每次 push 导出 Godot Web、Windows x86_64 和 macOS universal 客户端；Web SHALL 包含在 Go 镜像中，桌面客户端 SHALL 以 ZIP 上传为 Actions artifacts。

#### Scenario: 下载构建产物
- **WHEN** 一次构建成功
- **THEN** 对应提交提供 Go+Web 镜像 tar、Windows ZIP、macOS ZIP；镜像无需额外挂载即可访问 /web/

### Requirement: 镜像与版本发布
分支 build 和标签 release SHALL 在验证成功后发布 GHCR 镜像；PR SHALL 不发布。release SHALL 提供 Windows/macOS 附件，正式版本更新 latest，预发布不覆盖 latest。

#### Scenario: 版本标签
- **WHEN** 推送合法 vMAJOR.MINOR.PATCH 或其预发布标签
- **THEN** 复用完整构建与容器检查，发布版本镜像及对应 GitHub Release

### Requirement: 落地跳跃
角色 SHALL 仅在探索控制激活且落地时响应空格新按键起跳，受重力和碰撞约束；空中、暂停、封面或地图期间 SHALL 不允许起跳，按住空格不连续起跳。

#### Scenario: 起跳与落地
- **WHEN** 玩家在地面按空格并在空中再次按空格
- **THEN** 仅首次起跳生效，随后落回地面，落地后重新按空格可再跳

### Requirement: 加载资源计数
Web 官方加载页 SHALL 展示已加载和总资源量（十进制 MB）及百分比，沿用官方真实字节进度与错误反馈；已知导出资源总量在下载开始时即可显示，未知总量显示占位。

#### Scenario: 下载与启动
- **WHEN** 浏览器下载游戏资源
- **THEN** 计数随官方进度更新，错误时隐藏计数并保留错误提示，引擎启动后移除加载层

### Requirement: 桌面服务器配置
桌面客户端 SHALL 使用 DO_ENV 和 DO_API_SERVER_URL，项目运行默认 development/http://localhost:8415，桌面导出默认 production/https://dlut.online。构建进程变量 SHALL 写入包内配置，运行时非空变量 SHALL 覆盖包内配置；显式环境选择其默认地址，显式服务器地址优先。Web SHALL 不注入桌面地址，本次 SHALL 不发起网络请求。

#### Scenario: 本地与发布
- **WHEN** 开发者运行项目或导出桌面客户端，且未提供覆盖变量
- **THEN** 分别读取本地开发地址或包内生产地址，无需修改源码，导出不产生工作区配置残留

#### Scenario: 自定义服务器
- **WHEN** 构建或启动桌面客户端时指定 DO_API_SERVER_URL
- **THEN** 配置入口返回指定的 HTTP(S) 根地址，运行时覆盖优先于构建值
