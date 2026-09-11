## Why

所有玩家必须绑定 PocketBase 真实账号，现有游客入口不再符合要求。客户端使用 Godot 原生邮箱、密码登录，网站提供注册与邮箱验证，不启动浏览器认证回调。

## What Changes

- **BREAKING** 移除游客入场，Go 仅为已验证且未禁用的 PocketBase 用户签发票据。
- Godot 原生邮箱、密码表单直接调用 PocketBase 密码认证，游戏服确认后进入世界；移除本机监听、授权码 API 与网页返回游戏流程。
- 网站提供登录、注册、验证邮件重发；导航右侧使用下载文字链接按钮及登录、注册按钮，登录后显示账号和退出。
- 更新现行约定及被取代的游客规范，保留三校区切换和游戏协议结构。

- 后续部署要求：production 客户端也接受 API 下发的 enet://，按协议选择 DTLS；不改变 HTTPS 登录要求与 enets:// 证书校验。

- 登录 Token 保存到系统凭据库，启动时验证刷新；退出与失效清理，密码不保存。

## Capabilities

### New Capabilities
- `account-only-login`: 网站账号入口、游戏内认证及强制账号入场。

### Modified Capabilities
无已归档主规范；本变更取代既有变更中的游客要求。

## Impact

apps/api、apps/web、apps/game 客户端和必要验证工具、AGENTS.md、现有技术与 OpenSpec 文档。不增加浏览器插件、前端依赖或移动端导出。
