> 现行登录要求由 [account-only-login](../../../account-only-login/specs/account-only-login/spec.md) 取代：所有玩家必须绑定 PocketBase 已验证账号，通过官网认证后返回游戏。本文中的游客入口、游客 ID 与游客入场描述仅记录历史，不再作为当前实现要求。

## Purpose

定义 DLUT Online 从浏览器与桌面共同发布收敛为仅发布桌面游戏客户端后的分发与运行行为，确保客户端具备完整本地地图、保持原有权威会话与地图交互，并使网站和接口服务摆脱浏览器资源依赖。

## ADDED Requirements

### Requirement: 仅桌面游戏分发

系统 SHALL 仅发布 Windows x86_64、macOS universal 游戏客户端及 Linux 专用游戏服务器，不再导出、打包或托管浏览器游戏。既有 Web 分块与浏览器适配要求 SHALL 由本要求取代。

#### Scenario: 构建与服务启动
- **WHEN** 运行当前构建与部署流程
- **THEN** 无需 Web 构建目录，Go 与 Godot 服务正常启动，客户端发布包不含 Web 下载运行路径，`/web/` 返回 404

### Requirement: 本地地图与连续会话

桌面客户端 SHALL 携带三个校区现有完整资源，从本地异步切换场景并卸载旧场景，切图保持同一已认证连接，继续执行暂停、失焦、失败取消与加载期间心跳。

#### Scenario: 连续切换校区
- **WHEN** 玩家在三个校区之间传送
- **THEN** 无资源 HTTP 下载、不重新取票，目标场景准备好后由权威服务器迁移角色，旧视觉场景卸载

#### Scenario: 加载失败与取消
- **WHEN** 本地加载失败或玩家取消传送
- **THEN** 会话持续，按服务器确认结果恢复有效场景和角色控制，不残留下载 UI

### Requirement: 桌面身份与 API 配置

客户端 SHALL 使用进程内游客身份与原生 HTTP/ENet 网络，通过桌面配置获取 Go 根地址，不依赖浏览器存储或地址桥接。游戏协议 SHALL 使用版本 3，Go SHALL 返回游戏公网端点与一次性票据，客户端 SHALL 直接连接游戏服；Go 不再提供 `/ws` 代理。

#### Scenario: 客户端启动
- **WHEN** 桌面客户端启动并以游客身份入场
- **THEN** 本进程复用游客身份，经配置的 API 取得一次性票据，保留原有权威移动、同地图同步及重连行为

### Requirement: 实时传输与生产加密

系统 SHALL 将可靠控制与可丢弃的实时状态分通道传输，忽略旧输入、过期快照和旧地图代次；实时状态丢包 SHALL 不导致可靠控制等待其补齐。公网游戏连接 SHALL 按 API 下发的端点协议连接；客户端不按构建环境强制 DTLS（由 account-only-login 后续要求取代原生产客户端限制）。使用 enets:// 时 SHALL 校验端点证书与主机名，不以跳过校验或明文回退处理失败。

#### Scenario: 丢包和乱序
- **WHEN** 输入或快照发生丢包、迟到或重排
- **THEN** 客户端保持预测并接受后续有效权威状态，旧地图输入不可影响新地图，切图控制通过可靠通道完成

#### Scenario: 证书不可信
- **WHEN** 游戏服证书不在客户端信任链内或主机名不匹配
- **THEN** 客户端不得完成入场，不发送明文回退连接

#### Scenario: Go 重启
- **WHEN** Go 暂时不可用或在线注册状态重置
- **THEN** 已认证 ENet 玩家继续移动和切图，Go 恢复后游戏服重新注册并上报在线状态

### Requirement: 默认 Forward+ 渲染

项目 SHALL 默认使用 Forward+，编辑器与桌面客户端使用同一渲染配置，当前不声明移动端渲染覆盖。

#### Scenario: 默认启动与导出
- **WHEN** 从编辑器启动或导出 Windows/macOS 客户端
- **THEN** 默认选择 Forward+，移动端专属配置在后续适配时再添加

### Requirement: 编辑器运行环境选择

Godot 编辑器 SHALL 在顶部提供 Env Local / Dev 下拉框，Run environment 插件 SHALL 位于 addons/run_environment/ 并负责本机运行环境；Desktop server configuration 插件 SHALL 位于 addons/desktop_export/ 且仅负责桌面导出。两者 SHALL 共用配置解析而互不依赖。Local SHALL 使用 http://localhost:8415，Dev SHALL 使用 https://dlut.online；两者客户端环境均为 development。选择 SHALL 保存在本机已忽略的配置中，并对下一次 F5/F6 运行生效；未设置时默认 Local。

#### Scenario: 快速切换服务地址
- **WHEN** 开发者选择 Local 或 Dev 后启动游戏
- **THEN** 客户端使用对应 API 根地址；重新打开编辑器保留选择，已有进程的配置保持不变

#### Scenario: 显式覆盖
- **WHEN** 进程带有 DO_ENV 或 DO_API_SERVER_URL
- **THEN** 保持现有显式环境变量优先级，编辑器提示覆盖正在生效

#### Scenario: 发布隔离
- **WHEN** 编辑器选中任一运行配置后导出客户端或游戏服
- **THEN** 本机选择和编辑器控件不进入发布包，桌面默认 production 和 https://dlut.online，仍可使用显式环境变量覆盖构建配置

#### Scenario: 插件职责独立
- **WHEN** 仅启用 Run environment 或仅启用 Desktop server configuration
- **THEN** 前者可独立切换本机运行环境且不注册导出处理，后者可独立导出配置且不创建环境工具栏

### Requirement: 轻量测试与构建发布门禁

测试 SHALL 归属对应构建工作流，不提取共享 test.yml。Web SHALL 内置前置 test，仅在单个 Linux runner 执行 Vue 类型检查、Go 默认单元测试和 vet，Go 测试 SHALL 设置超时；默认不启用 race，不得运行集成、E2E、系统凭据、物理世界、容器 smoke 或导出包运行检查。需要真实数据库或前端构建产物的 Go 测试 SHALL 使用 integration 标签，默认 go test 不执行。Game 当前不重复运行 Vue/Go 检查，不设空测试任务；Godot 后续仅允许无校园、网络或系统依赖的纯函数单元测试，直接放入 Game 工作流并作为其构建前置。

#### Scenario: main 及 PR 检查
- **WHEN** main 分支 push 或 PR 中的应用源码或工作流变更触发 CI
- **THEN** Web/Game 工作流按路径触发；Web 先执行轻量 test，成功后才执行内部 build；Game 当前仅做必要生成和导出

#### Scenario: 功能分支推送去重
- **WHEN** 向 main 以外的分支推送提交
- **THEN** Web/Game SHALL 不由 push 触发；如存在 PR，则仅由 pull_request 按路径触发对应工作流，手动运行及 workflow_call 入口保持可用

#### Scenario: 版本发布
- **WHEN** 推送版本标签触发 release
- **THEN** 校验版本后复用 Web（test → build）和 Game 构建工作流，全部成功后上传本次构建的客户端产物；任一步失败不得发布

#### Scenario: 不可绕过的测试门禁
- **WHEN** 从仓库提供的任一 CI、手动或 release 入口运行
- **THEN** Web 的 build 始终依赖其 test 成功；Game 将来加入单元测试时也必须作为其构建前置，不提供跳过测试开关，也不增加 ci.yml 调度层
