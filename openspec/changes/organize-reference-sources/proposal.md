## Why

原始参考资料混合校区、主题和逐次建模说明，来源许可分散在历史变更与应用文件中。需要形成可长期维护的三校区资料结构及覆盖游戏、网站、服务端天气 API 的来源总账本。

## What Changes

- 以 lingshui、eda、panjin 分校区，按 mapping、terrain、vegetation、buildings、facilities、imagery 分类；共享资料归 shared，活动和文件按需扩展。
- README 改为目录与录入规范，保留原建模参数、照片配准和精度限制于专题 basis.md 与 JSON。
- 根目录新增正式的第三方资料、版权与许可声明 CREDITS.md，列明实际使用的 Weather API、素材、字体及软件的来源、使用范围与许可；不收录调研候选和内部维护约定。
- 同步工具、来源索引和文档中的本地路径，保留原始 URL、对象 ID、数值、图像与 LFS 管理。

## Capabilities

### New Capabilities

- `reference-sources`：参考目录组织、来源登记和许可维护。

### Modified Capabilities

无游戏功能或对外协议变化。

## Impact

影响 references、来源读取工具和文档。迁移目录及来源元数据；桌面导出与 macOS 打包统一读取根目录 CREDITS.md，该文件作为发行资源参与 CI 构建触发。不重建校园模型、不修改碰撞、渲染或天气 API 行为。数据库、API、环境变量、migration、发布拓扑和新增依赖：无。
