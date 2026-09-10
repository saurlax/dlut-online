## Purpose

统一 DLUT Online 网站和游戏客户端的真实账号登录，所有游戏身份由 PocketBase 已验证账号提供，取消游客通道，并为未来移动平台提供可复用的授权兑换机制。

## ADDED Requirements

### Requirement: 强制账号入场
系统 SHALL 仅向有效、邮箱已验证且未禁用的 PocketBase users 账号签发游戏票据，身份及显示名由服务器决定；无凭据、伪造凭据和游客身份不得入场。

#### Scenario: 游客被拒绝
- **WHEN** 客户端只提供游客 ID 或无效 token 申请票据
- **THEN** 返回 401，不签发票据

#### Scenario: 已验证账号入场
- **WHEN** 有效账号申请并兑换票据
- **THEN** 使用 PocketBase record ID 与 display_name，票据只能消费一次

### Requirement: 浏览器登录并返回游戏
客户端 SHALL 打开官网完成登录或注册，通过绑定客户端随机密钥的短期一次性授权码兑换账号会话；网站确认当前账号后才返回游戏。桌面回调仅允许本机 loopback 并校验 state，不在 URL 中传递登录 token。账号 token 仅保留于进程内，登录失败不得进入世界。只有游戏服确认身份后首次收起封面；恢复、校区传送复用会话。认证失效 SHALL 停止重试并回到登录界面。

#### Scenario: 回调防冒领
- **WHEN** 授权请求超时、state 不匹配、兑换密钥错误或授权码已使用
- **THEN** 不返回账号凭据，不进入游戏；取消或超时后可以重新发起登录

#### Scenario: 登录失败与重试
- **WHEN** 密码错误、未验证邮箱或服务不可达
- **THEN** 显示可理解的错误，保留登录界面并允许重试，无游客降级

#### Scenario: 切换与认证失效
- **WHEN** 玩家切换校区或重连
- **THEN** 切换复用现有连接，重连以账号凭据取票；凭据无效时要求重新登录

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
