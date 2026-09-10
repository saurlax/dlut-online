## Why

所有玩家必须绑定 PocketBase 真实账号，现有游客入口不再符合要求。统一采用官网登录，通过浏览器认证后返回游戏，并为未来移动平台系统认证回调保留清晰边界。

## What Changes

- **BREAKING** 移除游客入场，Go 仅为已验证且未禁用的 PocketBase 用户签发票据。
- Godot 登录按钮打开官网，通过绑定客户端密钥的短期一次性授权码兑换账号会话，游戏服确认后进入世界。
- 网站提供登录、注册、验证邮件重发；导航右侧使用下载文字链接按钮及登录、注册按钮，登录后显示账号和退出。
- 更新现行约定及被取代的游客规范，保留三校区切换和游戏协议结构。

- 后续部署要求：production 客户端也接受 API 下发的 enet://，按协议选择 DTLS；不改变 HTTPS 登录要求与 enets:// 证书校验。

## Capabilities

### New Capabilities
- `account-only-login`: 网站账号入口、游戏内认证及强制账号入场。

### Modified Capabilities
无已归档主规范；本变更取代既有变更中的游客要求。

## Impact

apps/api、apps/web、apps/game 客户端和必要验证工具、AGENTS.md、现有技术与 OpenSpec 文档。不增加浏览器插件、前端依赖或移动端导出。
