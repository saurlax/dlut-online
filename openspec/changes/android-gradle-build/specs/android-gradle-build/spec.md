## ADDED Requirements

### Requirement: 官方 Gradle 导出
Android APK SHALL 由 Godot 官方 Gradle 构建流程生成，使用与编辑器同版本的 `android_source.zip` 和其自带 Gradle Wrapper，不改写成品 APK 的二进制资源表或另行签名。

#### Scenario: 干净环境构建
- **WHEN** 安装 JDK 17、Android SDK、Godot 编辑器与匹配的 Gradle 导出模板后执行 Android 导出工具
- **THEN** 工具通过 Godot CLI 安装官方 Android 构建工程并导出 arm64 Release APK，由 Gradle 完成资源编译和签名

### Requirement: 可重建的 Android 工程
生成的 Android 构建工程 SHALL 被 Git 忽略，不维护模板源码副本、本机 SDK 路径或 Gradle 缓存；CI SHALL 获取同版本官方 Gradle 模板，继续遵守先测试后构建的工作流依赖。

#### Scenario: 重复构建
- **WHEN** 从仓库检出后重新导出 Android APK
- **THEN** 使用官方模板重建应用工程，不依赖已提交的生成目录或本机安装路径

### Requirement: 测试 APK 交付保持兼容
Android 导出 SHALL 保持标准 debug keystore、arm64、Release 模式、现有图标素材、客户端配置和三校区资源，保留签名和 16 KiB 对齐验证；资源引用与设备图标外形按相关变更专项验收，不新增整套常规资源测试。

#### Scenario: Gradle APK 图标
- **WHEN** 安装未经二进制后处理的 Gradle APK
- **THEN** Manifest 与应用资源包名均为 `com.saurlax.dlutonline`，系统按设备主题处理启动器图标
