## Why

用户需要从 Codex 环境操作便捷启动各 worktree 的客户端，避免手动输入绝对路径。

## What Changes

添加项目级本地环境配置和“启动客户端”操作，运行 `godot --path apps/game`，使用当前任务的工作目录。环境初始化不执行额外步骤。

## Capabilities

### New Capabilities

- `local-client-action`: 从当前工作目录启动 Godot 客户端。

### Modified Capabilities

无。

## Impact

只新增 Codex 配置，无游戏运行内容、数据库、API、依赖、环境变量及 migration 变化。要求本机 PATH 中已有 Godot；配置随仓库分支传播。
