## ADDED Requirements

### Requirement: Android test APK

系统 SHALL 提供 Android arm64 横屏测试 APK，使用 Godot Mobile 渲染器，共用完整三校区资源、Godot 原生界面与 ENet 协议。正式桌面发布仍使用 Windows x86_64、macOS arm64 和 Forward+。Android 作为 build.yml 中第五个构建任务提供测试 APK artifact，GitHub Release 附件仍仅包含桌面 EXE/DMG。

#### Scenario: Local export

- **WHEN** 安装 Godot 4.7.2、Android debug/release 模板、JDK 17 和 Android SDK Build-Tools 35.0.0、platform-tools
- **THEN** 关闭正在运行的 Godot 编辑器后，执行 `python3 apps/game/tools/export_android.py --sdk /absolute/android-sdk --java /absolute/jdk-home`，生成 `apps/game/build/android/DLUT-Online-Android.apk`
- **AND** 工具将 SDK 和 Java 路径写入本机 Godot 编辑器设置，按现有环境规则打入生产 API 地址，校验签名、16 KB ZIP 对齐、arm64 库和三校区数据
- **AND** Android 模板可用 `python3 apps/game/tools/install_export_templates.py --android` 安装；APK 与本机生成的默认 debug keystore 不提交，不作为应用商店正式发行包

### Requirement: Touch exploration

客户端 SHALL 在 Android 显示原生绘制的触屏控件，保持已有碰撞和多人预测逻辑；桌面不显示触屏控件。

#### Scenario: Walk and look simultaneously

- **WHEN** 左手拖动左下摇杆，右手同时在右侧空白区域滑动
- **THEN** 摇杆半径为 84 个逻辑像素，15% 死区外按力度移动，超过 90% 时奔跑；右侧每逻辑像素转动 0.003 弧度，俯仰限制为 ±1.45 弧度
- **AND** 左手释放仅停止移动，右手仍可环视；右下箭头触发已有跳跃，右上暂停图标暂停探索

#### Scenario: Pause or lose focus

- **WHEN** 打开地图、开始传送、暂停、失焦或应用进入后台
- **THEN** 立即清空摇杆、奔跑、跳跃和手指跟踪，恢复后必须重新按下触点才能移动；点击世界可恢复探索

#### Scenario: Touch map

- **WHEN** 点击圆形小地图
- **THEN** 打开全屏地图并停止移动，支持单指拖动和双指缩放，沿用现有比例限制与边界；系统返回键收起地图或取消传送，无额外关闭按钮

### Requirement: Account and quality boundary

Android SHALL 保持单人离线无账号，多人使用真实账号；账号 token 仅保存于内存，密码提交后清空。测试包不得宣称已通过真机运行、联网或性能验收，除非执行并记录了对应检查。

#### Scenario: Restart Android app

- **WHEN** 结束应用进程后重新进入多人模式
- **THEN** 用户重新输入邮箱和密码，客户端不读取或写入明文账号 token 文件

#### Scenario: Shared campus scope

- **WHEN** 导出 Android APK
- **THEN** 只包含已有三校区模型及其现有室内范围，不增加建筑或室内；模型精度沿用 references 中各校区来源记录

### Requirement: PR test artifacts and temporary signing

系统 SHALL 在统一 build.yml 中增加 android 任务，必须 needs: test，沿用现有 PR、main push、手动和发布复用入口。Android 任务 SHALL 安装 JDK 17、Android SDK 和 Godot 4.7.2 Android 模板，使用现有导出脚本生成 arm64 Release APK 并验证签名、对齐、架构与资源；不运行集成或真机测试。

#### Scenario: Download from a pull request

- **WHEN** PR 的前置测试及 Android 构建成功
- **THEN** 上传 `client-android-release-<github.sha>` artifact，仅含 APK，保留 7 天，并在 Actions 摘要提供下载链接和解压安装说明
- **AND** 用户可从 PR Checks 打开构建下载，无需等待其他平台产物；其他构建仍必须通过才算整体 CI 成功

#### Scenario: No managed release certificate

- **WHEN** 干净的 CI runner 打包测试 APK
- **THEN** 复用 `~/.android/debug.keystore` 并签名；缺失时按 Android 标准 debug 参数初始化，不为每次构建另设密钥路径，不需用户上传证书或配置 Secrets，不缓存、提交或上传密钥
- **AND** 摘要说明不同 runner 的默认测试签名可能不同，覆盖安装失败时需卸载旧版，卸载会清除本地数据；不宣称存在通用的默认正式签名
- **AND** APK 不作为 GitHub Release 附件或应用商店正式发行包

### Requirement: Release mode with test signing

Android SHALL 与其他客户端一致使用 `--export-release` 构建；构建模式与签名身份独立，Release 测试 APK 仍使用Android 默认 debug keystore 签名，不要求维护正式发行证书。

#### Scenario: Verify release artifact

- **WHEN** 本地或 CI 调用 Android 导出脚本
- **THEN** 通过 Godot 标准 RELEASE keystore 子进程环境变量传入测试签名配置，不写入仓库预设
- **AND** 通过 Android Build-Tools 检查 APK 未声明 application-debuggable，再验证签名、对齐、架构和资源
