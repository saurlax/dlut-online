# 资源目录

- `fonts/`：三校区共享的中文字体和许可，运行时 UI 使用。
- `campuses/eda/data/campus.json`：开发区 27 个官方轮廓、来源和高度估计；模型生成、运行时碰撞关联和地图使用，不代表全校数据。
- `campuses/eda/data/roads.json`：开发区道路描摹数据，模型生成和地图使用。
- `campuses/eda/data/building_assets.json`：16 栋 Blender 建筑的局部坐标原点及来源元数据，供校区离线组装使用。
- `campuses/eda/models/development_campus.tscn`：开发区地形、道路、广场、水域、绿地等非建筑静态内容，并实例引用拆分后的建筑资源。
- `campuses/eda/models/buildings/<feature_id>.glb`：开发区建筑运行时模型。可编辑源文件位于仓库根目录 `references/eda/buildings/blender/`，建筑几何以 Blender 文件为准，不再由 GDScript 生成。
- `.import`：Godot 资源导入配置，由编辑器管理；移动资产时同步更新。

`lingshui` 的官方轮廓数据位于 `campuses/lingshui/data/campus.json`，静态模型位于 `campuses/lingshui/models/lingshui_campus.tscn`，由凌水场景直接挂载。包含 313 段轮廓及七栋建筑的局部照片立面，来源与精度见根目录 `references/lingshui/buildings/basis.md`。`panjin` 仍为直接保存在场景内的占位模型，不复制其他校区资源。

开发区建筑在 Blender 中编辑。从仓库根运行 `python apps/game/tools/buildings/export_eda_buildings.py --blender <Blender 可执行文件>`，由 Blender 批量把 16 个 `.blend` 源文件导出为 Godot 使用的 GLB。`tools/build_model.gd` 不再作为开发区建筑生成入口。原始参考资料位于 `references/`，不打入客户端。

本文客户端路径均相对 apps/game/；references/ 指仓库根目录的原始参考资料。

## Git LFS

模型目录中的 TSCN、GLB/Blender 文件、图片和字体由 Git LFS 管理，规则见根目录 .gitattributes。普通场景、脚本及 JSON 保持 Git 文本文件。克隆前安装 Git LFS 并执行 `git lfs install`；已有克隆执行 `git lfs pull`，确保资源不是指针文本后再打开 Godot 或构建。CI checkout 必须启用 `lfs: true`。忽略的生成产物仍不提交。

Web 导出由 tools/campus_packs 自动把三校区转换为基础轮廓/碰撞启动层与 100 米网格细节包。完整建筑细节只保存一次并由覆盖格引用；其他非碰撞表面按格裁切，共享材质随启动层提供。源 TSCN 与官方 Feature ID 不变，编辑器和桌面仍使用完整模型。生成 PCK 位于 build/web/campuses/，临时场景位于 .godot/campus_grid/，均不提交。首包保留共享字体和凌水启动层。

## 三校区植被

共享形态及材质位于 `assets/vegetation/`，校区实例数据和静态场景位于 `assets/campuses/<id>/data/vegetation.json` 与 `models/vegetation.tscn`。配置依据见仓库 `references/<id>/vegetation/planting.json` 和 `basis.md`。

从仓库根运行 `godot --headless --path apps/game --script tools/generate_vegetation.gd` 重新生成三校区植被；开发区整场景构建仍通过 build_vegetation.gd 更新对应资源。生成期间关闭正打开这些资源的游戏进程。网格使用压缩二进制 `.res`，三种姿态共享材质；每 32 米单元按形态和姿态组成 MultiMesh，近远级别分别使用 48 米（乔木）与 32 米（低植被）切换。乔木保留到 650 米，低植被保留到 120 米，细草只在 32 米内绘制。低植被和远距模型不投射实时阴影；近景乔木保留阴影。近远包围盒统一并预留微风摆动余量。

草坪随地形细分，并在边缘裁切过渡；装饰植被没有碰撞。运行时只加载当前校区静态资源，服务端不包含视觉植物。实际分布和数量是照片限定区域内的确定性估计，不能作为逐树调查。

回归检查使用真实渲染器运行 `godot --path apps/game --script tests/vegetation.gd`，核对来源、逐实例变换、地形、官方排除轮廓、资源共享、近远包围盒与三角形缩减。无头 dummy renderer 不保留 MultiMesh 变换，不能用于此检查。Android 的 Mobile 渲染路径可在桌面检查，但不替代 Android 真机性能验收。
