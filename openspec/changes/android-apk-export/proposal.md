## Why

用户要求提供 Android APK，并同时适配触屏移动和视角。当前仅有桌面导出，缺少 Android 服务配置打包及触屏输入。

## What Changes

- 增加本地 Android arm64 测试 APK，复用三校区、账号和 ENet 协议；桌面继续使用 Forward+，Android 使用 Mobile。
- 接入左侧摇杆、外圈奔跑、右侧滑动环视、跳跃、暂停、触屏地图拖动和双指缩放，失焦、暂停、切图清空输入。
- Android 账号仅保留内存会话，重启后重新登录；不以明文文件替代系统凭据库。
- 扩展现有导出配置插件，提供可复用 APK 构建及签名、架构、资源检查工具。

## Capabilities

### New Capabilities

- `android-client`: Android 测试包与触屏交互。

### Modified Capabilities

- `desktop-client-distribution`: 允许额外本地导出 Android 测试包，正式发布工作流维持现状。

## Non-goals

不增加 iOS、Web 游戏、应用商店发布、正式签名密钥、Android CI、建筑或室内，不调整账号/API/协议和数据库。

## Impact

影响 Godot 客户端输入、Android 预设和本地工具；使用外部 JDK 17、Android SDK 及 Godot 4.7.2 Android 模板，均不提交。数据库、服务配置、migration 与发布工作流变化：无。Android 真机性能与多人体验须单独验收。
