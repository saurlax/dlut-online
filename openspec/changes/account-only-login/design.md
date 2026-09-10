## Context

Go 已嵌入 PocketBase，Godot 目前只有游客登录。最新决定为全部在网站登录，未来 OIDC 也复用网站；本轮只交付现有 Windows/macOS 客户端，移动平台仅明确可迁移边界。

## Goals / Non-Goals

**Goals:** 官网登录注册、已验证账号入场、浏览器认证后返回游戏；不依赖后台持续联网。
**Non-Goals:** 不接尚未配置的 OIDC、不内嵌 WebView、不导出移动客户端、不持久保存游戏凭据、不改变校园模型。

## Decisions

- 网站使用 PocketBase 原生密码认证、注册与验证邮件接口，保留邮箱已验证且未禁用的要求；验证邮件使用 PocketBase 原有验证页。Naive UI 实现 /login、/register 和导航，下载入口为 NButton text tag=a。
- 浏览器会话 token 保存到 sessionStorage，恢复通过 auth-refresh 校验，退出清除。授权页展示当前账号并要求点击进入游戏，避免复用浏览器账号时无感选择错误身份。
- 桌面游戏创建绑定随机 verifier 的短期授权请求，只把 SHA256 challenge 发给 Go；在 127.0.0.1 随机端口监听一次性 HTTP 回调，使用 OS.shell_open 打开官网。服务端仅允许严格的 loopback 回调，浏览器不能传入任意重定向。
- 用户在官网确认后，Go 返回带 state 和一次性 code 的回调 URL。客户端校验 state 并以 verifier 兑换新的 PocketBase 登录 token。请求有效期五分钟、批准后的 code 三十秒，兑换原子单次；账号在批准及兑换时均重新检查。不在 URL 中传递长期 token，不输出密钥日志。
- 游戏只在进程内保存账号会话，取票携带 Bearer token；收到游戏服 welcome 后进入。401/403 清理会话回封面；短暂连接故障保留退避重连；切校区仍复用 ENet 连接。
- 未来 iOS 用 ASWebAuthenticationSession，Android 用 Custom Tabs 与验证过的 App Links，通过平台注册的固定回调适配同一授权请求与兑换机制；不把桌面 loopback 用作移动端验收方案。未来增加移动端时才扩展允许的回调白名单，并处理进程重建与安全保存待完成授权。不依赖 PocketBase all-in-one OAuth2 的后台实时连接。
- 将来 OIDC 的 provider secret 与身份校验留在服务器；网站完成 OIDC 后仍使用相同的用户确认与客户端一次性兑换流程。新身份必填字段和可信邮箱映射在实际接入提供方时处理。

- 客户端不按 DO_ENV 强制游戏 DTLS，按票据中的 enet:// 或 enets:// 选择传输；enets:// 始终校验信任链与主机名且不自动降级。Go 与游戏服的 production 限制保留，明文测试部署使用 development。

## Risks / Trade-offs

- SMTP 未配置 → 注册成功与发信失败分开提示，允许重发；本地检查不能证明外网邮件投递。
- 本机端口不可用或用户关闭页面 → 明确错误、取消与重试，清理监听器；不降级为游客。
- 浏览器可能不允许自动聚焦游戏 → 回调页面显示已完成可返回游戏，客户端尽力请求前台；不声称保证操作系统焦点切换。
- 浏览器会话 token 可被同源脚本读取 → 不写 URL，不长期存储，退出清理。

## Migration Plan

网站/API 与新版客户端共同发布；拒绝旧游客客户端，协议数据结构保持 v4。现有账号数据不改。旧游客规范标明由本变更取代，更新 AGENTS 与 API 技术文档。回滚不恢复游客政策。
