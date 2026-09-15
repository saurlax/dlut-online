## Why
首页模型异步加载时只显示背景色和按钮，用户无法判断准备状态。

## What Changes
- 启动显示简洁加载页，底部显示进度条。
- 校园背景资源加载、实例化并完成渲染后显示首页和镜头动画。
- 加载失败保留加载页并提供重试，不展示空白首页。

## Capabilities
### New Capabilities
- `startup-loading`: 首页背景加载进度及就绪门槛。
### Modified Capabilities
- `native-menu-theme`: 先加载背景再展示模式首页。

## Impact
仅修改 Godot 菜单展示与对应规范，不改变账号、联网、校园模型和室内。配置、环境变量及 migration：无。
