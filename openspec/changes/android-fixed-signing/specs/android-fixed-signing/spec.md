## ADDED Requirements

### Requirement: 固定测试签名
常规 Android CI SHALL 从仓库 Actions Secret `DO_ANDROID_KEYSTORE_BASE64` 恢复同一份测试 keystore；发布工作流 SHALL 显式传递该 Secret。密钥 SHALL NOT 提交到 Git、上传到 artifact 或保存到缓存。

#### Scenario: 可覆盖更新
- **WHEN** 仓库内 PR、main、手动或标签调用执行构建且 Secret 已配置
- **THEN** APK 使用固定签名，允许覆盖安装同包名、同密钥且版本兼容的已有 APK

#### Scenario: 配置缺失
- **WHEN** 常规构建没有签名 Secret
- **THEN** 构建失败，不悄悄生成新密钥

### Requirement: 受限 PR 构建
外部 fork 或 Dependabot PR 无法读取 Secret 时 SHALL 继续以临时 debug keystore 构建，并在产物摘要明确注明签名差异；不得改用 pull_request_target 执行外部 PR 代码以获取密钥。

#### Scenario: 外部 PR
- **WHEN** fork 或 Dependabot PR 的 Secret 不可用
- **THEN** 生成临时测试签名 APK，摘要提示覆盖安装可能失败并需要卸载
