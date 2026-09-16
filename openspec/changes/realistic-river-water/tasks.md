## 1. 实现
- [x] 1.1 查询 Godot 官方文档并核对既有水体与渲染器限制。
- [x] 1.2 制作共享动态水面材质，替换既有材质并更新生成器。
- [x] 1.3 记录实现边界及来源。

## 2. 验证
- [x] 2.1 在 Windows Vulkan 下检查凌水和开发区 Forward+ 昼夜渲染、动画，检查凌水 Mobile 渲染；Android 与 macOS 真机未验收。
- [x] 2.2 与原 LFS 模型逐项比较，确认仅水体材质引用变化；Windows EXE 和 Windows/macOS/Android/Server 资源包导出通过，客户端包包含水材质、服务器包不包含。未做 macOS 原生打包、Android APK 和 Linux 服务端二进制导出，本次不改变其平台配置与服务端行为。
- [x] 2.3 OpenSpec 严格校验与差异检查通过，按独立任务提交。
