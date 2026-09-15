## ADDED Requirements

### Requirement: Android test APK

系统 SHALL 提供 Android arm64 横屏测试 APK，使用 Godot Mobile 渲染器，共用完整三校区资源、Godot 原生界面与 ENet 协议。正式桌面发布仍使用 Windows x86_64、macOS arm64 和 Forward+。Android 不进入现有四任务 CI 发布链路。

#### Scenario: Local export

- **WHEN** 安装 Godot 4.7.2、Android debug/release 模板、JDK 17 和 Android SDK Build-Tools 35.0.0、platform-tools
- **THEN** 关闭正在运行的 Godot 编辑器后，执行 `python3 apps/game/tools/export_android.py --sdk /absolute/android-sdk --java /absolute/jdk-home`，生成 `apps/game/build/android/DLUT-Online-Android.apk`
- **AND** 工具将 SDK、Java 和调试密钥路径写入本机 Godot 编辑器设置，按现有环境规则打入生产 API 地址，校验签名、16 KB ZIP 对齐、arm64 库和三校区数据
- **AND** Android 模板可用 `python3 apps/game/tools/install_export_templates.py --android` 安装；APK 与本机生成的调试密钥不提交，不作为应用商店正式发行包

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
