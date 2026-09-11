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

Godot 编辑器 SHALL 在顶部提供 API Local / Dev 下拉框。Local SHALL 使用 http://localhost:8415，Dev SHALL 使用 https://dlut.online；两者客户端环境均为 development。选择 SHALL 保存在本机已忽略的配置中，并对下一次 F5/F6 运行生效；未设置时默认 Local。

#### Scenario: 快速切换服务地址
- **WHEN** 开发者选择 Local 或 Dev 后启动游戏
- **THEN** 客户端使用对应 API 根地址；重新打开编辑器保留选择，已有进程的配置保持不变

#### Scenario: 显式覆盖
- **WHEN** 进程带有 DO_ENV 或 DO_API_SERVER_URL
- **THEN** 保持现有显式环境变量优先级，编辑器提示覆盖正在生效

#### Scenario: 发布隔离
- **WHEN** 编辑器选中任一运行配置后导出客户端或游戏服
- **THEN** 本机选择和编辑器控件不进入发布包，桌面默认 production 和 https://dlut.online，仍可使用显式环境变量覆盖构建配置
