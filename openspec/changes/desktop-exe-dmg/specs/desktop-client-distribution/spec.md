## ADDED Requirements

### Requirement: 独立桌面附件

Release SHALL 仅以 DLUT-Online-Windows.exe 和 DLUT-Online-macOS.dmg 分发 Windows x86_64 与 macOS arm64 客户端，不提供客户端 ZIP。Windows SHALL 内嵌运行资源，DMG SHALL 包含完整应用与 Applications 入口。网站 SHALL 链接最新正式 Release 的对应附件。

#### Scenario: 产物发布
- **WHEN** 所有构建和必要检查成功
- **THEN** 上传本次提交的独立 EXE 和 DMG，test.yml 为 build.yml 四个独立构建任务的统一前置，release.yml 校验版本后复用整个 build.yml 并等待全部成功

### Requirement: 有效临时签名

macOS SHALL 重新做有效 ad-hoc 签名，不保留失效 Godot 模板签名，不要求正式证书或私钥。最终挂载 DMG 内应用 SHALL 通过严格签名校验，具有项目 bundle identifier 和仅 arm64 架构。Windows SHALL 暂不签名；发布说明 SHALL 如实说明 macOS 未使用 Developer ID 和公证，ad-hoc 不保证消除 Gatekeeper 拦截。

#### Scenario: 签名或架构失败
- **WHEN** DMG 内应用严格校验失败或架构不是单独 arm64
- **THEN** 构建失败，不上传客户端附件且不执行 Release 发布
