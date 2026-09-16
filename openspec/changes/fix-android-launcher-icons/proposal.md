## Why

Android 安装器中的标志偏大，Honor 500 Pro 的 MagicOS 10 桌面显示满幅白色正方形。真机对照确认 Godot 非 Gradle 导出的 Manifest 包名已更新，但资源表包名仍为 `com.godot.game`，导致该设备跳过图标主题处理。仅调整 SVG 无法解决此问题。

## What Changes

- 沿用 `apps/game/tools/build_brand_icons.py`，从同一品牌 SVG 生成 Android 图标。
- 普通图标增加透明外边距和白色圆角底板，缩小蓝色标志。
- 自适应前景缩小，背景保持满幅白色，由启动器决定外形。
- 资源表应用包名必须与 Manifest 一致。最初采用导出后修正的兼容方案，现已由 `android-gradle-build` 变更替换为官方 Gradle 资源编译与签名，不再保留 APK 二进制补丁。
- 包名改写仅保留必要的格式和边界保护，沿用最终 APK 签名、对齐检查；图标引用与显示效果按需专项验收，不新增常规构建资源校验或测试文件。

## Capabilities

### New Capabilities

- `android-launcher-layout`: 安装器和启动器图标的留白与遮罩兼容布局。

### Modified Capabilities

无。

## Impact

修改 Android 派生图标与打包工具，不修改品牌主文件、游戏场景或桌面客户端。数据库、API、协议、配置、环境变量、migration 和新增依赖：无。沿用标准 debug keystore，发布需要重新生成 APK；实际启动器形状由设备主题和遮罩决定。
