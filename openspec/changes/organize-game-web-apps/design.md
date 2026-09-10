## Context

参见 proposal.md。当前 Go 与 Godot 各自具有独立构建配置，Godot res:// 以工程根定位。Python 模型工具从自身位置解析仓库根，移动 apps 下目录不会改变相对层级。

## Goals / Non-Goals

目标是目录职责清楚、路径引用可验证、导出及双服务运行不受重命名影响。不改变游戏行为，不批量格式化或调整架构，不清除用户的本地资料与缓存。

## Decisions

apps/game 是一个 Godot 项目，scripts/client 放客户端交互、UI、预测联网与桌面配置；scripts/server 放权威服务和 Go 内部接口适配；scripts/shared 放运动、碰撞、协议和校区注册表。scenes/campuses 保留完整客户端地图，scenes/server 保留生成的碰撞世界，入口场景不做额外重命名。

apps/api 保留当前 Go 源码布局，负责站点及 HTTP API；程序构建为 dlut-online-web，现有 Go 模块名保持兼容，不因目录名称增加 package 分层。

references、openspec、AGENTS.md、Compose 与 CI 保留根目录职责。本地 .local、docs/verification.md、Godot 缓存和 build 仅为工作区资料，不提交也不删除。历史变更内的路径引用同步新位置，保留历史行为描述。

源码目录移动与 LFS/忽略规则在同一次提交中完成，确认模型在新路径仍受 LFS 管理，防止大文件意外进入普通 Git。Godot UID 随源文件移动，禁止重建模型来“修复”路径。

游戏服镜像命名为 dlut-online，Go HTTP 镜像命名为 dlut-online-web；CI 本地标签、GHCR 发布与 Release 说明同步，版本标签规则保持不变。游戏服可执行文件与 PCK 的基础名称统一为 dlut-online-server，容器启动同名程序。Compose 服务名为 game 和 web，游戏服通过 http://web.internal:8415 访问 Go 服务。

## Risks / Trade-offs

- 插件、Autoload、preload 或导出清单遗漏路径 → 扫描旧目录引用，重新导入与导出并检查包内资源隔离。
- 字体子集脚本原来只扫描 scripts 根目录 → 改为递归扫描客户端脚本，验证现有字形仍覆盖；无需改字体资源。
- 外部编辑器仍打开旧工程路径 → 新入口为 apps/game/project.godot；不保留旧目录软链接掩盖过期配置。
