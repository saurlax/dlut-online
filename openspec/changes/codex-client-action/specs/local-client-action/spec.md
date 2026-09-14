## ADDED Requirements

### Requirement: 当前 worktree 客户端操作
项目 SHALL 提供名为“启动客户端”的 Codex 本地环境操作，使用相对路径启动当前任务工作目录中的 apps/game，不写死本机路径，不启动其他 worktree 的客户端。

#### Scenario: 点击启动客户端
- **WHEN** 用户在包含环境配置的仓库根目录任务中执行该操作，且 PATH 中可找到 Godot
- **THEN** 执行 `godot --path apps/game`，显示该 worktree 的客户端登录封面。
