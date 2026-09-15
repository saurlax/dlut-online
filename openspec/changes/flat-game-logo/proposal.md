## Why

为 DLUT Online 确定参考大工校徽的扁平化 SVG 标志，并统一 README 与 Android 测试 APK 的品牌形象。用户选定尖角导航箭头版；Android 打包 PR #19 已先行合并。

## What Changes

- 提供蓝色透明图标和完整产品名横版 SVG；主标志使用同心圆、尖角导航箭头和右上在线点，主要净距统一为 32 单位。
- README 展示横版标志，产品介绍文字保持原样。
- Android 普通图标采用白底蓝标，自适应图标使用透明前景和白色背景，前景保留安全区域。
- 可复用工具从主标志生成 Android SVG，APK 导出前检查图标是否与源文件一致。
- 不交付未选中的圆角箭头及 DO 候选。

## Capabilities

### New Capabilities

- `game-branding`: 可缩放品牌标志、README 展示与 Android 启动图标。

### Modified Capabilities

无。

## Impact

修改品牌资源、README、Android 图标及导出配置和相关构建工具。游戏菜单、校园、建筑、室内与联网行为不变。数据库、API、协议、部署配置、环境变量和 migration 变化：无。新增依赖：无。
