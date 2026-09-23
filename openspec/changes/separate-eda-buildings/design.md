## Context

开发区登记了 16 个 `kind=building` 的 Feature。当前生成器将这些建筑与非建筑内容保存到同一 `development_campus.tscn`，使单栋修改和独立加载都缺少稳定资产边界。

## Goals / Non-Goals

**Goals:** 每栋建筑具有独立 Blender 源文件和 Godot 场景；保持现有外观、坐标、节点身份及碰撞语义；大地图继续直接包含非建筑内容。

**Non-Goals:** 本次不切分地形、道路、植被或室外设施，不补充没有来源的建筑细节或室内。

## Decisions

- Blender 文件位于 `references/eda/buildings/blender/`，作为每栋建筑后续精修的源文件；运行时不直接依赖 Blender。
- Blender 批量导出 LOD0、LOD1、远景代理和独立碰撞 GLB。LOD0 保持在 `models/buildings/<feature_id>.glb`，其余分别位于 `lod1/`、`proxy/` 和 `collision/`；Godot 不通过 GDScript 生成、合并或改写建筑网格。
- 建筑采用局部坐标保存，校区场景中的实例记录其世界原点。根节点继续命名为 `Feature_<id>`，现有碰撞和专项检查可以沿用。
- 初次迁移从现有已验收场景提取，不重新推断照片、轮廓或尺寸。迁移完成后建筑几何唯一源文件为 Blender；程序化建筑也必须通过 Blender Python 创建，原 GDScript 建筑生成路径不再参与重建。
- 地形、道路、广场、水体、植被和其他室外细节仍由现有 Godot 工具生成并保留在校区级资源中。
- 编辑器 TSCN 保留全部 Blender LOD0 建筑实例；运行时二进制场景只保留 `Feature_<id>` 占位节点。客户端先异步加载全部远景代理，在 400 米内预取 LOD1、190 米内预取 LOD0，并在主线程挂入场景树前由单个工作线程实例化。建筑碰撞在 240 米内独立加载，远离后分别卸载细节和碰撞。
- 碰撞代理在 Blender 的 `Collision` 集合中离线生成，以 `-colonly` 节点导出，由 Godot 导入器生成 `StaticBody3D` 和 `CollisionShape3D`。进入游戏和接近建筑时不再调用 `create_trimesh_collision()`。
- GLB 导入关闭自动 LOD 与阴影副网格，避免迁移后的高精度网格在导入缓存和运行内存中重复展开。

## Risks / Trade-offs

- Godot、glTF 与 Blender 往返可能改变节点名、材质参数或不可见碰撞网格，因此打包时按迁移清单恢复元数据，并比较三角形、包围盒和碰撞标记。
- 独立文件会增加资源数量，但允许逐栋审查、替换和后续按需加载。
- 自动生成的 LOD1 保留主要立面但不能代替人工拓扑优化；远景代理只表达建筑总体量。后续精修仍需在 Blender 中检查各层轮廓、门洞和材质切换距离。
