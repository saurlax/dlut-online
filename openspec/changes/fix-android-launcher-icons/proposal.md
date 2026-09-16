## Why

Android 安装器中的标志偏大，部分桌面显示普通图标时出现满幅白色正方形。现有自动生成工具需要区分普通图标自身的外形与自适应图标的系统遮罩。

## What Changes

- 沿用 `apps/game/tools/build_brand_icons.py`，从同一品牌 SVG 生成 Android 图标。
- 普通图标增加透明外边距和白色圆角底板，缩小蓝色标志。
- 自适应前景缩小，背景保持满幅白色，由启动器决定外形。

## Capabilities

### New Capabilities

- `android-launcher-layout`: 安装器和启动器图标的留白与遮罩兼容布局。

### Modified Capabilities

无。

## Impact

仅修改 Android 派生图标与生成工具，不修改品牌主文件、游戏场景或桌面客户端。数据库、API、协议、配置、环境变量、migration 和新增依赖：无。发布需要重新生成 APK；实际启动器形状由设备主题和遮罩决定。
