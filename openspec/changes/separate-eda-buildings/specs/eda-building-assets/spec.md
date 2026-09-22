## ADDED Requirements

### Requirement: Independent development-campus buildings

系统 SHALL 将开发区每个已登记建筑保存为独立 Blender 源文件和独立 Godot 运行场景，并保留官方 Feature ID、校区世界位置和已登记来源限制。

#### Scenario: Rebuild one building

- **WHEN** 制作者在 Blender 中修改并导出一栋开发区建筑
- **THEN** 离线打包工具仅需重建该建筑的 Godot 资源即可更新整场景中的对应实例

#### Scenario: Assemble the campus

- **WHEN** 开发区校区场景被生成或加载
- **THEN** 每栋建筑以 `Feature_<id>` 独立场景实例出现在登记世界位置，地形、道路、广场、水体、植被和室外细节仍保留在校区级资源中

### Requirement: Preserve verified geometry and collision

初次迁移 SHALL 从现有已验收开发区模型提取建筑，不重新推断未确认的外观或室内，并 SHALL 在 glTF/Blender 往返后恢复通行碰撞标记和不可见碰撞辅助网格。

#### Scenario: Verify migrated assets

- **WHEN** 16 栋建筑完成 Blender 往返和 Godot 打包
- **THEN** 验证工具确认 Feature ID 集合、世界包围盒、可见节点及碰撞标记与迁移清单一致，误差不超过工具声明的浮点容差
