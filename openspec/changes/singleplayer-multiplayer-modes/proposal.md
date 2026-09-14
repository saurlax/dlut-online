## Why
首页需要分别提供纯本地探索与账号多人游戏，单人玩家可以自行调整环境。

## What Changes
- 首页改为单人模式和多人模式，登录弹窗仅在选择多人且未登录时显示。
- 单人模式无需账号、API、ENet，沿用本地运动和碰撞，支持三校区异步切换。
- 大地图左上角仅单人显示时间与天气设置，跨校区保留；多人继续服务器同步。

## Capabilities
### New Capabilities
- `game-modes`: 双模式入口、离线运行及本地环境控制。
### Modified Capabilities
- `account-only-login`: 多人模式点击后恢复或登录并直接入场。
- `native-menu-theme`: 双入口首页与登录弹窗。
- `campus-weather`: 单人本地环境与多人同步环境分离。

## Impact
修改 Godot 客户端、原生菜单和当前规范。不改建筑、室内、服务器协议、数据库或网站行为。发布配置、环境变量、migration：无。
