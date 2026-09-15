## 1. APK 与输入

- [x] 1.1 增加 Android arm64 预设、Mobile 覆盖与 API 配置打包。
- [x] 1.2 接入多指摇杆、环视、跳跃、暂停、后台输入释放和触屏地图操作。
- [x] 1.3 提供 Android 模板安装与 APK 导出验证工具，保留仅内存账号会话。
- [x] 1.4 同步现行规范和平台范围，不修改根 README 或发布工作流。

## 2. 验证

- [x] 2.1 通过触屏输入回归、地图与暂停检查，以及 Mobile 实际渲染检查。
- [x] 2.2 导出 APK，校验签名、arm64、完整资源及导出隔离，执行相关桌面回归。
- [x] 2.3 OpenSpec 校验与差异检查后创建提交。

## Deferred Validation

Android 真机安装、触屏手感、GPU 性能、软键盘登录与 ENet/DTLS 联网验收待连接设备后执行，不作为已完成结果。

## 3. PR Android CI

- [x] 3.1 在 build.yml 增加依赖 test 的 Android 构建、临时调试签名和 APK artifact 下载摘要。
- [x] 3.2 同步平台、CI 与签名规范，保留原有 Release 附件。
- [ ] 3.3 校验工作流与构建门禁，提交并创建 PR，确认 Android CI artifact 可下载。
