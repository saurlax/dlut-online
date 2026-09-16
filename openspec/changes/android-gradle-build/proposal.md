## Why

Android 非 Gradle 导出需要在 APK 完成后修正资源包名才能兼容 MagicOS 图标处理。改用 Godot 官方 Gradle 构建，在正常资源编译阶段生成一致的应用包名，移除项目自行维护的二进制补丁。

## What Changes

- Android 导出启用官方 Gradle 模板，构建工具通过 Godot CLI 安装同版本的 `android_source.zip`。
- 本机 Windows 与 CI Linux 共用导出脚本；复用 JDK 17、Android SDK 和标准 debug keystore。
- CI 安装 Gradle 源模板；生成的 Android 工程不提交，使用模板自带的 Gradle Wrapper。
- 删除资源表改写脚本和导出后的重新封装/签名步骤，保留已有产物、签名和对齐检查，不新增常规资源测试。

## Capabilities

### New Capabilities

- `android-gradle-build`: 官方 Android Gradle 构建与可重建的模板管理。

### Modified Capabilities

无；同步已有 Android 图标规范，资源包名一致性改由构建阶段保障。

## Impact

影响 Android 导出预设、导出工具、CI 模板安装和忽略规则。首轮 Gradle 构建需要下载 Gradle/Android 构建依赖，后续可复用本机缓存。数据库、业务 API、游戏协议、环境变量和 migration：无。游戏、建筑、室内和桌面/服务器导出行为不变。
