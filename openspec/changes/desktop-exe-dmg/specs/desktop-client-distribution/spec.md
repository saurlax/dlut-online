## ADDED Requirements

### Requirement: 独立桌面附件

Release SHALL 仅以 DLUT-Online-Windows.exe 和 DLUT-Online-macOS.dmg 分发 Windows x86_64 与 macOS arm64 客户端，不提供客户端 ZIP。Windows SHALL 内嵌运行资源，DMG SHALL 包含完整应用与 Applications 入口。网站 SHALL 链接最新正式 Release 的对应附件。

#### Scenario: 产物发布
- **WHEN** 所有构建和必要检查成功
- **THEN** 上传本次提交的独立 EXE、DMG 和 Android arm64 测试 APK，test.yml 为 build.yml 五个独立构建任务的统一前置，release.yml 校验版本后复用整个 build.yml 并等待全部成功

### Requirement: Select builds by application changes
普通 PR/main push SHALL 按路径选择构建，所有被选任务仍依赖 changes 与完整 Vue/Go 测试成功。PR 使用 base/head 合并基点差异，push 使用 before/after；重命名按删除和新增处理，历史读取失败 SHALL 阻止构建，不静默跳过。

#### Scenario: Website or API only
- **WHEN** 仅 apps/web/ 或 apps/api/ 的非 Markdown 文件变化
- **THEN** 仅构建 web 镜像，跳过 Windows、macOS、Android 与游戏服构建

#### Scenario: Game changes
- **WHEN** apps/game/ 的非 Markdown 文件变化
- **THEN** 构建 Windows、macOS、Android 与游戏服；同时修改网站/API 时也构建 web

#### Scenario: Shared build inputs
- **WHEN** 修改 CREDITS.md、.github/workflows/、.github/scripts/、.dockerignore、.gitattributes 或 compose.yaml
- **THEN** 执行全部五种构建；纯普通 Markdown 文档不触发工作流

#### Scenario: Release or manual run
- **WHEN** 版本标签发布、手动构建或新分支 push 无有效 before 基线
- **THEN** 执行全部测试和五种构建，只有全部成功后才允许发布对应附件

### Requirement: 有效临时签名

macOS SHALL 重新做有效 ad-hoc 签名，不保留失效 Godot 模板签名，不要求正式证书或私钥。最终挂载 DMG 内应用 SHALL 通过严格签名校验，具有项目 bundle identifier 和仅 arm64 架构。Windows SHALL 暂不签名；发布说明 SHALL 如实说明 macOS 未使用 Developer ID 和公证，ad-hoc 不保证消除 Gatekeeper 拦截。

#### Scenario: 签名或架构失败
- **WHEN** DMG 内应用严格校验失败或架构不是单独 arm64
- **THEN** 构建失败，不上传客户端附件且不执行 Release 发布
