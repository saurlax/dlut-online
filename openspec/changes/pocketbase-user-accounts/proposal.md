> 现行登录要求由 [account-only-login](../account-only-login/specs/account-only-login/spec.md) 取代：所有玩家必须绑定 PocketBase 已验证账号，通过官网认证后返回游戏。本文中的游客入口、游客 ID 与游客入场描述仅记录历史，不再作为当前实现要求。

## Why

项目需要完整的用户管理。用 PocketBase embed 统一认证、管理界面和 SQLite 持久化，为当前规模提供简单、可备份的单数据库架构。

## What Changes

- Go HTTP 服务嵌入 PocketBase，使用其 Auth Collection、邮件流程、OAuth2/OIDC 外部身份和管理界面。
- PocketBase record ID 作为唯一内部用户 ID；邮箱唯一且必须验证，username 必填并大小写不敏感唯一，display_name 必填且允许重复。
- 用户、外部身份、验证凭据和后续业务数据保存在 PocketBase SQLite；30 秒一次性游戏票据仅保存在 Go 进程内存。
- 账号认证可签发一次性游戏票据，游戏服使用 PocketBase ID 和服务端 display_name；现有游客入口仍可用。

## Capabilities

### New Capabilities
- `user-accounts`: PocketBase 用户身份及账户生命周期。
- `game-server-configuration`: PocketBase 管理的游戏服发现配置。

### Modified Capabilities

## Impact

apps/api、PocketBase Collection 定义、SQLite 持久卷、游戏身份协议、部署与 CI。本次不增加网页或 Godot 账号登录界面，保留游客入口。
