## ADDED Requirements
### Requirement: Improved character appearance
角色 SHALL 支持扩展脸部控制及肤色调整，并保证不同实例之间参数独立。
#### Scenario: Change and reset appearance
- **WHEN** 用户改变脸部或肤色并切换人物和衣服
- **THEN** 当前参数继续生效，重置恢复默认且不修改其他角色
### Requirement: Authored locomotion
预览 SHALL 使用许可明确的现成动作驱动身体及衣物。
#### Scenario: Preview exported animation
- **WHEN** 在发布包选择行走或奔跑
- **THEN** 连续帧呈现实际网格变形，来源和限制有据可查
