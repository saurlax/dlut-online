## Why

macOS 旧包残留 Godot 模板签名，严格校验失败，不能作为普通未公证提示处理。用户要求改用独立 EXE 和 DMG，不再分发客户端 ZIP。

## What Changes

- Windows x86_64 发布内嵌完整资源的独立 EXE。
- macOS arm64 在 macOS runner 导出应用并重新做 ad-hoc 签名，生成 DMG，验证最终挂载内容。
- 更新工作流、网站链接及维护约定；保留 Web 测试前置和 Release 全部构建成功门禁。
- 本变更取代 development-campus-web 中旧的桌面 ZIP 和 macOS 不签名要求；不申请证书、不配置正式签名 Secrets、不发布版本。

## Impact

影响 Godot 导出、Game/Release 工作流及网站下载入口。无校园模型、室内、账号或游戏协议改动。旧版本不会补传新格式附件；网站链接待新版本发布后生效。
