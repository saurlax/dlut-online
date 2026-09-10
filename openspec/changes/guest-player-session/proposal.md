> 现行登录要求由 [account-only-login](../account-only-login/specs/account-only-login/spec.md) 取代：所有玩家必须绑定 PocketBase 已验证账号，通过官网认证后返回游戏。本文中的游客入口、游客 ID 与游客入场描述仅记录历史，不再作为当前实现要求。

## Why

第一人称玩家尚无身份。增加无需注册的游客登录，为当前浏览器会话提供稳定的玩家 ID 和昵称。

## What Changes

- Godot 封面提供游客登录，进入前显示游客昵称。
- 随机生成游客 ID，Web 使用 sessionStorage，同会话刷新、暂停和传送不更换身份。
- 现有第一人称角色绑定身份，维持移动和碰撞行为。
- 同校区联机同步，显示其他玩家的人形代理和昵称，支持重连。

## Capabilities

### New Capabilities
- `guest-player`: 游客会话身份与角色登录。

### Modified Capabilities

无。

## Impact

客户端身份模块、玩家、封面及字体，Go `/ws` 同步服务，README 和项目约束。无持久服务端账户；依据本次要求，仅允许浏览器会话存储和同源地址读取的最小 JavaScript 适配。
