## Decisions

Windows 保留 embed_pck，禁止控制台伴随 EXE，上传前验证 x86_64 PE、PCK 尾部与起始标记以及无伴随文件。macOS 预设启用 Godot 内置 ad-hoc 签名，官方模板仅提供 universal 二进制，中间应用保留 universal 导出，打包时 lipo 提取 arm64，原生 codesign 在完整应用副本上再次覆盖签名，避免模板签名残留。通过 hdiutil 生成压缩 DMG，含应用和 Applications 链接，挂载最终产物检查 codesign --verify --deep --strict、bundle identifier 及仅 arm64。构建不运行游戏联调或 E2E，本地独立副本执行实际启动验证。

Linux job 继续导出 Windows/服务器及构建服务器镜像；独立 macOS job 构建 DMG。Release 必须等待两个 Game job 与 Web test → build 全部成功，明确指定两个附件，不上传 ZIP。Actions 自身的 artifact 下载封装不属于发布附件格式。

当前只使用无需证书或密钥的 ad-hoc，不接入 Apple 或 GitHub Secrets。无法保证浏览器隔离下载获得 Gatekeeper 信任，发布说明必须说明 Windows 未签名及 macOS 无 Developer ID、无公证，不宣称免提示安装。
