## Why
CI 临时 runner 每次生成不同的 debug keystore，导致测试 APK 无法持续覆盖更新。用户要求把现有本机密钥保存到 GitHub Secrets 并新开 PR。

## What Changes
- 固定使用当前已安装 APK 的本机 debug keystore，保存到仓库 Actions Secret。
- 常规 CI 恢复固定密钥，缺失时失败；外部 fork/Dependabot PR 使用临时测试签名并明确提示。
- 发布工作流显式传递该 Secret；密钥不进入 Git、artifact 或缓存。

## Capabilities
### New Capabilities
- `android-fixed-signing`: 固定 Android 测试签名与受限 PR 的退化行为。
### Modified Capabilities
无；同步已有 Android 导出规范中的签名约定。

## Impact
新增仓库 Secret `DO_ANDROID_KEYSTORE_BASE64`，内容为现有标准 debug keystore 的 Base64。沿用默认别名和密码，不更换签名身份。本机密钥保存在 `~/.android/debug.keystore`；Secrets 不能作为可下载备份。数据库、API、游戏协议及 migration：无。
