## Implementation

- [x] 1. 导出独立 Windows EXE 与 ad-hoc macOS 应用，加入最终产物检查。
- [x] 2. 在 macOS runner 打包 DMG，更新 Release 附件及下载链接，保留前置门禁。
- [x] 3. 同步维护文档与 OpenSpec，不修改根 README。
- [x] 4. 验证导出、DMG 签名与启动、网站类型检查和构建及 OpenSpec。
- [x] 5. 按最新要求统一 test/build/release 三个工作流，拆分四个构建任务并验证依赖门禁。
- [x] 6. 将原单任务测试显示名设为 Vue and Go，避免可复用工作流层级重复显示 test；测试仍只执行一次（后续由第 7 项拆分）。
- [x] 7. 将 test.yml 拆为 Vue、Go 两个并行任务，各自独立安装依赖，构建等待全部通过。
- [x] 8. 将项目与桌面/Android 发行版本统一提升至 0.2.0，Windows 文件版本设为 0.2.0.0，Android 构建号提升至 2；对应协议 6，API、游戏服与客户端共同升级，无新增配置或数据库迁移。

- [x] 9. 按应用路径选择普通构建，保留完整测试前置和发布/手动全量构建；校验前端/API、游戏、跨应用重命名、删除、PR 合并基点与共享配置路径。
