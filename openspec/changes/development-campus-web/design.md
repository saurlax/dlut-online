## Context

Godot 4.7.2 / GDScript / Compatibility，27 个官方轮廓已生成静态模型。用户明确要求第一人称 MMORPG 方向，当前阶段仅实现校园场景浏览，不实现社团活动或联机。

## Goals / Non-Goals

**Goals:** 以约 1.7 米眼高在校园行走，真实尺度建筑碰撞，Web 与桌面共用控制器和界面。

**Non-Goals:** 地图搜索、地标列表、活动、登录、多人服务器。

## Decisions

- CharacterBody3D 胶囊角色与 Camera3D 实现第一人称。WASD 行走、Shift 奔跑、鼠标锁定后环视。
- 模型主体网格添加静态碰撞；建筑窗带不生成碰撞。底座承载角色，校区范围设置边界与坠落复位。
- 初始位置在南门内侧，朝向信息楼。初始界面只保留进入按钮以满足浏览器 Pointer Lock 用户手势要求。
- Escape 释放鼠标并显示 Godot 原生暂停提示；点击继续重新捕获。失焦或已成功捕获后浏览器退出 Pointer Lock 时停止移动。
- 使用 Control/CanvasLayer 和嵌入 Noto Sans SC 字体，呈现必要按钮、准星、圆形小地图及主动打开的校区选择面板。
- 不使用自定义 HTML 产品 UI、业务 JS 或 JavaScriptBridge；Godot 官方导出页只用于启动引擎和加载/错误提示，允许通过 html/head_include 定制加载样式和只读资源计数。

## Risks / Trade-offs

- 当前立面为程序化近似 → 将数据来源与近似范围写入文档，不承诺真实立面或室内。
- 浏览器 Pointer Lock 行为差异 → 以实际点击及 Escape 验证，捕获失败时启用 Godot 原生按住右键环视，WASD 继续可用，不依赖 JS。
- 世界尺度大 → 奔跑加速；校区内保持步行，校区间通过场景传送。

## 品牌与视觉方向

产品名称统一为 DLUT Online，学校整体和第一人称 MMORPG 定位写入 AGENTS.md，主界面不展示定位说明。校区名称仅用于场景数据与参考范围。采用低饱和度混凝土、石材、沥青及玻璃，增加窗框、窗台与基座，植被使用树干、分枝和分散叶片。纹理为程序化生成，不代表真实建筑实拍。装饰立面不参与碰撞，按材质合并网格控制 Web 绘制开销。

## 官方照片与数据边界

通过官方 /image/v1 接口取得实景照片，首批用于信息楼和图书馆的立面精修。外观生成拆分到 tools/build_photo_facades.gd，运行时仍加载导出的静态模型。照片与索引位于 references/photos，不加入 Web 成品。

没有数据的就不做，不要臆想。已查室内接口没有可用的墙、房间或门洞几何，故不制作室内，也不新增推测性入口或家具。

## 编辑器可见性

校园静态模型以 PackedScene 实例直接挂入 scenes/main.tscn，环境和太阳光也保存在主场景中。运行时控制器引用已有 CampusModel，仅初始化输入、碰撞和角色界面，避免重复模型。

## 三校区场景与小地图（最新要求）

本节替代此前不提供地图或传送的限制。固定 ID 为 lingshui、eda、panjin，默认入口实例化 lingshui。三个场景独立保存静态模型和环境，位于 scenes/campuses/。eda 使用原有 27 个官方要素；另外两处为用户授权的简单占位，不代表真实建筑。

校区通过 change_scene_to_file 切换并卸载旧场景，各自配置出生点。输入绑定去重，避免多次传送后重复触发。小地图采用 Godot Control 绘制二维轮廓，圆形裁剪，10 Hz 跟随玩家位置和朝向，不额外渲染三维世界。

点击小地图或 M 打开当前校区地图和三个校区按钮，停止角色并释放鼠标。当前校区禁用选择；M/Escape 按打开前状态恢复。传送后进入目标场景；保留鼠标锁定失败时的拖动兼容。

## 首次封面与加载（最新交互）

静态会话标记 started 保留于校区注册表。首次创建封面；玩家开始后封面保持隐藏，传送目标直接恢复游戏，鼠标锁定不成功时立即保留拖动控制。暂停与失焦停止移动但不显示进入/继续按钮，点击世界或 Escape 恢复。此要求替代前述继续按钮设计。

加载页使用 export_presets.cfg 的 html/head_include 添加 CSS，替换加载标识和进度条样式；不替换官方引擎启动代码，不创建自定义网页产品界面。引擎启动闪屏隐藏默认图标，使用同一背景色。

大地图改为全屏 Control，使用固定默认比例尺，不再全图适配。校区按钮以 VBoxContainer 锚定右上角，删除关闭按钮。

地图默认每米 2 个 Godot UI 像素，缩放范围 0.5–8，滚轮每档 1.2 倍。鼠标下的世界位置在未触边时保持不变；边界按当前视口半宽高与比例尺计算，小于视口的轴居中。拖动只接受当前按住左键的运动事件，避免松开后持续拖动。

开发区资产统一归入 assets/campuses/eda/{data,models}，校区注册表声明数据路径，更新生成及导出流程；共享字体保留 assets/fonts。另两校区占位直接存于各自场景，不创建无依据的数据。GLB 与配套纹理保留为离线模型交换产物，游戏使用 TSCN。

## Apps 目录组织

Godot 项目整体迁移至 apps/game/，其内部 res:// 引用保持不变。本文客户端目录均相对 apps/game/；references/ 与 openspec/ 保留仓库根目录。离线生成器从脚本路径定位参考资料，Web 构建产物保留在客户端 build/web/。未来服务端与首页分别使用 apps/web/ 和 apps/site/，本次不创建空目录或实现后端。

## Go 静态托管

apps/web 使用独立 Go 模块与 Chi，读取客户端 Web 导出目录。/web 重定向至 /web/；文件缺失返回 404，不回退到首页，不开放目录列表，稳定文件名采用 no-cache 重新验证。首页、API、WebSocket 暂不实现。Go 验证通过后替换 Python 预览服务并删除旧脚本。

## 服务镜像与 CI

Go 使用 PORT 环境变量（空值默认 8060），监听所有网卡；显式 -addr 优先。无效端口启动失败。多阶段 Dockerfile 生成非 root 的 Go 镜像，将 Godot Web 导出一并复制到 /web，无需资源挂载。GitHub push/PR/手动触发测试、Web/Windows x86_64/macOS universal 导出、镜像构建及容器自定义端口验证。上传镜像 tar 和两种桌面 ZIP，保留 7 天，并在非 PR 构建检查成功后发布 GHCR。构建上下文为仓库根目录，由 .dockerignore 仅允许服务器源码及 Web 导出资源。桌面产物不签名、不公证。


## Build 与 Release

分支 push 的 build 发布 ghcr.io/<owner>/<repo>:sha-<SHA>，默认分支额外更新 edge。vMAJOR.MINOR.PATCH（可带预发布后缀）标签触发独立 release 工作流，复用 build，再创建 GitHub Release 并上传 Windows/macOS ZIP；正式版本更新 latest，预发布不更新。PR 不登录或推送 GHCR；发布使用 GITHUB_TOKEN 和最小对应权限。首次包可见性不主动修改。

## 跳跃与资源计数

空格绑定 jump，角色仅在控制激活且落地时响应新按键，初速度 7 m/s，沿用 20 m/s² 重力，不支持空中连跳或按住自动连跳。暂停、封面和地图期间不能起跳。

官方 html/head_include 增加只读进度展示脚本，观察官方 progress 的 value/max 与显示状态，不替换引擎启动或错误处理。初始总量读取官方导出 fileSizes，后续以官方进度为准；MB 按 1,000,000 字节换算，展示已加载/总量及百分比。总量未知时使用占位，不伪造进度；错误时隐藏计数，启动后随官方加载层移除。计数反映 WASM/PCK 加载字节，不代表压缩网络流量或内存占用。

## 桌面服务器配置

运行时 DesktopConfig 提供配置读取入口。未导出项目默认 development/http://localhost:8060；桌面导出默认 production/https://dlut.online（含调试导出），由 EditorExportPlugin 将配置 JSON 直接加入包，不写入工作区。构建进程的 DO_ENV / DO_SERVER_URL 可覆盖默认值，CI 显式指定生产配置。运行时进程变量优先于包内配置：显式 DO_ENV 重新选择该环境默认地址，DO_SERVER_URL 优先级最高；空变量按未设置处理。只接受 development/production 和 HTTP(S) 根地址，末尾斜杠归一化。Web 不注入桌面配置，桌面读取入口在 Web 返回空字典，本轮不实现 Web 同源解析或网络连接。不使用 .env 自动加载。
