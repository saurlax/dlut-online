## ADDED Requirements

### Requirement: Separate vegetation distribution and geometry
系统 SHALL 将植被分布数据、可复用树网格与校园建筑/地形分离，保留开发区既有 304 棵树的位置和高度。无依据的其他校区 SHALL NOT 复制该示意分布。

#### Scenario: Rebuild existing planting
- **WHEN** 运行开发区模型生成器
- **THEN** 从独立 JSON 读取原有实例，建筑与地面模型不含树冠或树干网格，生成独立植被场景

### Requirement: Shared spatial instances
植被 SHALL 使用共享树网格和材质，按 64 米空间块与树型生成 MultiMeshInstance3D，批次包围盒覆盖所有变换后的完整树冠，使用原生网格 LOD。

#### Scenario: Trees cross cell boundaries
- **WHEN** 树位于负坐标或树冠越过块边界
- **THEN** 按位置向下取整分组且包围盒不裁掉跨界树冠，各批次引用同一树型资源

### Requirement: Static desktop scene integration
植被 SHALL 在编辑器与桌面客户端通过静态场景挂载，导出包含所有依赖，不在运行时重复生成。已有碰撞 SHALL 保持不变，叶片 SHALL NOT 生成 trimesh 碰撞。

#### Scenario: Export campus and server
- **WHEN** 导出桌面客户端和游戏服务端
- **THEN** 客户端包含独立植被场景和共享树网格，服务端只使用现有碰撞世界
