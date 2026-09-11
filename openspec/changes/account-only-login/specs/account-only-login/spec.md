## Purpose

统一 DLUT Online 网站和游戏客户端的真实账号登录，所有游戏身份由 PocketBase 已验证账号提供，取消游客通道，客户端使用原生邮箱、密码认证，不开启本机回调监听。

## ADDED Requirements

### Requirement: 强制账号入场
系统 SHALL 仅向有效、邮箱已验证且未禁用的 PocketBase users 账号签发游戏票据，身份及显示名由服务器决定；无凭据、伪造凭据和游客身份不得入场。

#### Scenario: 游客被拒绝
- **WHEN** 客户端只提供游客 ID 或无效 token 申请票据
- **THEN** 返回 401，不签发票据

#### Scenario: 已验证账号入场
- **WHEN** 有效账号申请并兑换票据
- **THEN** 使用 PocketBase record ID 与 display_name，票据只能消费一次

### Requirement: 客户端原生密码登录
客户端 SHALL 使用 Godot 原生邮箱、密码表单直接调用 PocketBase 密码认证，密码隐藏且不写文件或日志，提交后清空密码输入框；token 在内存使用并按下述要求保存至系统凭据库。登录 SHALL 不打开浏览器或本机监听端口，移除授权码 API 与网页返回游戏流程。无账号时 SHALL 提示前往 dlut.online 注册，注册链接不承担认证回调。

#### Scenario: 成功登录
- **WHEN** 用户提交已验证、未禁用账号的正确邮箱与密码
- **THEN** 获得 PocketBase 会话并申请游戏票据，仅收到游戏服 welcome 后进入世界

#### Scenario: 失败及取消
- **WHEN** 密码错误、账号未验证或禁用、网络失败或用户取消
- **THEN** 不建立会话，恢复可操作表单并允许重试；取消后的迟到响应不得认证成功，重复提交不产生并行登录

#### Scenario: 切换与认证失效
- **WHEN** 玩家切换校区或重连
- **THEN** 切换复用现有连接，重连以账号凭据取票；凭据无效时清理会话并返回原生登录界面

### Requirement: 网站账号入口
网站 SHALL 提供邮箱密码登录、注册、验证邮件重发和退出。注册包含邮箱、唯一用户名、显示名、密码及确认密码，注册后提示先完成邮箱验证。导航从左到右为下载客户端文字链接按钮、登录和注册入口；登录后展示账号及退出。小屏幕表单和导航 SHALL 可用，不增加字间距。

#### Scenario: 注册与验证
- **WHEN** 用户提交有效注册数据
- **THEN** 创建 PocketBase 用户并请求验证邮件，明确提示邮件发送结果，验证前不宣称登录成功

#### Scenario: 网站登录
- **WHEN** 用户提交有效账号或退出
- **THEN** 登录后展示账号显示名，退出后恢复登录和注册入口；密码及 token 不写入 URL

### Requirement: 客户端按游戏端点选择传输
客户端 SHALL 在 development 和 production 均接受 API 下发的 enet:// 和 enets:// 端点；前者使用明文 ENet，后者启用 DTLS 并校验证书信任链与主机名，不自动降级。生产客户端账号 API 仍 SHALL 使用 HTTPS。

#### Scenario: 正式客户端连接明文测试服
- **WHEN** production 客户端通过 HTTPS API 收到有效的 enet:// 端点和账号票据
- **THEN** 客户端建立普通 ENet 连接，不因构建环境拒绝连接

#### Scenario: DTLS 证书校验失败
- **WHEN** 下发 enets:// 端点且证书无效
- **THEN** 拒绝连接，不跳过校验或自动改为明文

### Requirement: 持久登录与恢复
客户端 SHALL 按 API 根地址隔离，将 auth token 保存至 macOS 钥匙串或 Windows 凭据管理器；不得保存密码，或把 token 写入明文文件、命令行或日志。启动 SHALL 使用已保存的 token 调用 PocketBase auth-refresh，验证成功后更新保存并自动进入游戏。过期或失效 token SHALL 要求重新登录，不假定存在独立 refresh token。

#### Scenario: 重启自动登录
- **WHEN** 客户端重新启动且系统保存了有效 token
- **THEN** 验证刷新后获取账号与游戏票据，不要求重新输入密码；其他 API 地址的凭据不得复用

#### Scenario: 网络与认证失败
- **WHEN** 刷新发生网络超时、限流或服务器故障
- **THEN** 保留凭据且恢复可操作表单，不将网络失败视为账号失效

#### Scenario: 退出及失效
- **WHEN** 用户点击大地图退出登录，或账号认证明确失效
- **THEN** 清除会话及对应凭据；本地无敏感信息标记 SHALL 阻止删除失败时自动重登，之后成功保存新登录才能重新启用

#### Scenario: 凭据库不可用
- **WHEN** 系统凭据库锁定、拒绝访问或平台缺少支持
- **THEN** 仍允许本次手动登录，不回退到明文 token 文件
