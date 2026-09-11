## Why

玩家进入校园后无法直接确认当前账号，也无法判断游戏连接延迟。需要在右下角提供简洁的用户名和实时延迟，让玩家在探索时了解自身连接状态。

## What Changes

- 游戏右下角显示当前 PocketBase 账号的 `username`，明确区别于昵称 `display_name`。
- 显示到当前 Godot 游戏服的往返延迟（RTT），单位 ms，每秒刷新。
- 延迟低于 100 ms 显示绿色，100–199 ms 显示黄色，200 ms 及以上显示红色；测量中、数据过期和断线使用明确状态文字，不伪造 0 ms。
- 使用 Godot 原生只读控件，保持默认字间距；兼容暂停、失焦、地图面板和跨校区切换，不增加额外操作。

## Capabilities

### New Capabilities

- `player-connection-hud`: 当前玩家用户名、实时游戏连接延迟、颜色分级以及显示生命周期。

### Modified Capabilities

无。当前主规范目录没有已归档能力；本变更作为新增能力补充已有账号登录、桌面客户端和权威游戏服务变更。

## Impact

- `apps/game/scripts/client/account_session.gd`：单独保留认证记录中的账号用户名，避免改变现有昵称用途。
- `apps/game/scripts/client/player_network.gd`：提供当前 ENet 连接的 RTT、有效性和连接状态。
- `apps/game/scripts/client/campus_hud.gd`：右下角状态显示及与现有覆盖层的协调。
- 涉及客户端字体子集检查、相关本地验证和桌面导出；不改变服务端协议、API、校园模型或新增依赖。本轮仅编写规划文件。
