## ADDED Requirements

### Requirement: Free reproducible character assets
人物原型 MUST 使用明确允许分发的免费资产，记录来源、版本、校验值与许可，人体、服装与游戏骨架由同一数据基础生成。

#### Scenario: Build offline character samples
- **WHEN** 使用已核对的离线输入生成男女样本
- **THEN** 输出保留蒙皮、骨架及面部形变，运行时不连接素材站点或安装 Blender

### Requirement: Native character preview
系统 SHALL 提供独立 Godot 原生预览场景，支持男女样本、有限捏脸、实际服装网格替换、视角查看和骨骼动作预览。

#### Scenario: Change outfit and face
- **WHEN** 用户调整脸部参数并切换服装
- **THEN** 人物保留当前脸部设置，显示选定服装，并由相同骨架驱动

#### Scenario: Play animation in exported preview
- **WHEN** 用户在独立发布包中切换行走或奔跑
- **THEN** 身体与衣服随骨架持续变形，骨架绑定不依赖主工程的旧版默认路径兼容设置

#### Scenario: Reset preview
- **WHEN** 用户重置人物
- **THEN** 恢复明确的默认外观参数和服装，不保存到账号或改变校园人物

### Requirement: Prototype isolation
原型 MUST 不连接 API 或游戏服务器，不改变校园主场景和既有玩家碰撞，不将测试动作称为动作捕捉资产。

#### Scenario: Open preview directly
- **WHEN** 用户直接运行人物预览场景
- **THEN** 本地呈现人物，无需登录，现有校园入口和网络协议保持兼容
