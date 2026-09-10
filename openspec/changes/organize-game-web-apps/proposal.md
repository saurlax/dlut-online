## Why

Godot 工程已同时包含桌面客户端与权威游戏服，apps/client 名称不再准确。用户要求梳理仓库并将两个应用命名为 game 与 web，使目录职责与当前部署拓扑一致。

## What Changes

- 将 Godot 工程迁移至 apps/game，Go HTTP 应用迁移至 apps/web。
- Godot 脚本按 client/server/shared 分区，共享校区注册表归入 shared；保持 res:// 根和资源 UID 稳定。
- 同步构建、Docker、Compose、LFS、忽略规则、测试与技术文档路径，修复来源记录中失效的导出脚本引用。
- 根 README 不修改，不重建模型、不改变协议、平台或游戏行为；保留用户已有项目配置调整。

## Capabilities

无外部行为变化，本次为目录和路径重构，跳过 delta specs。

## Impact

两个应用路径、Godot 资源引用、构建和部署入口，以及现有路径文档。Git 历史通过重命名保留，构建产物和本地缓存不提交。不新增框架、应用或依赖。
