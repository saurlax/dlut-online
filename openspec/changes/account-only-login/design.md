## Context

所有玩家使用 PocketBase 真实账号。客户端登录方案改为 Godot 原生邮箱、密码表单，直接调用 PocketBase；网站保留账号登录、注册与邮箱验证。

## Goals / Non-Goals

**Goals:** 原生账号登录、已验证账号入场、取消与错误重试，不开启本机监听端口。
**Non-Goals:** 不实现 OIDC、移动端插件或导出、客户端注册表单，不保存密码，不改变校园模型。

## Decisions

- Godot 使用 LineEdit 输入邮箱和密码，密码隐藏，支持回车提交、重复提交保护、取消。提交立即清空密码框；密码不保存到文件或日志，token 仅保留于进程。
- HTTPRequest 直接调用 /api/collections/users/auth-with-password。PocketBase AuthRule 要求 verified=true 且 disabled=false；客户端检查返回账号，票据和游戏服再次验证身份，不存在游客降级。
- 删除桌面 TCPServer 回调、state/verifier/授权码及 Go /api/v1/auth/requests、approve、exchange；网站移除请求参数传递与返回游戏按钮。网站登录注册、验证邮件重发继续使用原生 PocketBase API。
- 客户端注册链接打开 https://dlut.online/register，只用于注册，不承担登录回调。新账号先在网站完成邮箱验证，再回到游戏输入邮箱密码。
- 只有收到游戏服 welcome 才进入世界。短暂网络故障退避重连，认证失效清理会话并返回登录，切校区复用连接；取消后的迟到认证结果不得建立会话。
- DO_ENV 保留原有构建及运行时覆盖。production 客户端账号 API 使用 HTTPS；游戏传输按 enet:// 或 enets:// 选择，DTLS 校验失败不自动降级。Go 和游戏服 production 限制保留。
- 将来 OIDC 作为独立登录方式另行设计，移动平台按系统认证能力接入；当前不保留未使用的回调实现。

## Risks / Trade-offs

- 无效凭据、未验证或禁用账号不暴露额外账号信息，统一提示检查邮箱、密码及账号状态。
- 网络失败与超时恢复可操作表单，取消终止请求并丢弃迟到结果。
- SMTP 仍由部署配置，网站注册与验证邮件结果分开提示。

## Migration Plan

网站/API 与新版客户端共同发布。现有账号、游戏票据与协议 v4 不变，旧浏览器授权客户端需升级。移除未使用的回调接口及对应专用测试，保留真实 PocketBase 密码认证和账号安全检查。
