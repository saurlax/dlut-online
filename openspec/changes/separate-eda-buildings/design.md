## Context

开发区登记了 16 个 `kind=building` 的 Feature。当前生成器将这些建筑与非建筑内容保存到同一 `development_campus.tscn`，使单栋修改和独立加载都缺少稳定资产边界。

## Goals / Non-Goals

**Goals:** 每栋建筑具有独立 Blender 源文件和 Godot 场景；保持现有外观、坐标、节点身份及碰撞语义；大地图继续直接包含非建筑内容。

**Non-Goals:** 本次不切分地形、道路、植被或室外设施，不实现运行时距离流送，不补充没有来源的建筑细节或室内。

## Decisions

- Blender 文件位于 `references/eda/buildings/blender/`，作为每栋建筑后续精修的源文件；运行时不直接依赖 Blender。
- Blender 批量导出运行时 GLB 至 `assets/campuses/eda/models/buildings/<feature_id>.glb`，Godot 仅使用原生导入器读取，不通过 GDScript 生成、合并或改写建筑网格。
- 建筑采用局部坐标保存，校区场景中的实例记录其世界原点。根节点继续命名为 `Feature_<id>`，现有碰撞和专项检查可以沿用。
- 初次迁移从现有已验收场景提取，不重新推断照片、轮廓或尺寸。迁移完成后建筑几何唯一源文件为 Blender；程序化建筑也必须通过 Blender Python 创建，原 GDScript 建筑生成路径不再参与重建。
- 地形、道路、广场、水体、植被和其他室外细节仍由现有 Godot 工具生成并保留在校区级资源中。

## Risks / Trade-offs

- Godot、glTF 与 Blender 往返可能改变节点名、材质参数或不可见碰撞网格，因此打包时按迁移清单恢复元数据，并比较三角形、包围盒和碰撞标记。
- 独立文件会增加资源数量，但允许逐栋审查、替换和后续按需加载。
- 本次只改变资产边界；校区仍引用全部建筑，所以不把进入速度改善作为本次完成条件。
