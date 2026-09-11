# 资源目录

- `fonts/`：三校区共享的中文字体和许可，运行时 UI 使用。
- `campuses/eda/data/campus.json`：开发区 27 个官方轮廓、来源和高度估计；模型生成、运行时碰撞关联和地图使用，不代表全校数据。
- `campuses/eda/data/roads.json`：开发区道路描摹数据，模型生成和地图使用。
- `campuses/eda/models/development_campus.tscn`：开发区静态模型，由 `scenes/campuses/eda.tscn` 实例引用，属于游戏运行资源。
- `campuses/eda/models/development_campus.glb` 与同目录 albedo PNG：生成器输出的离线模型交换文件及纹理，不列入 Web 导出和版本控制；需要时运行模型生成工具重建，供外部建模工具使用。
- `.import`：Godot 资源导入配置，由编辑器管理；移动资产时同步更新。

`lingshui` 的官方轮廓数据位于 `campuses/lingshui/data/campus.json`，静态模型位于 `campuses/lingshui/models/lingshui_campus.tscn`，由凌水场景直接挂载。包含 313 段轮廓及七栋建筑的局部照片立面，来源与精度见根目录 `references/lingshui/README.md`。`panjin` 仍为直接保存在场景内的占位模型，不复制其他校区资源。

`tools/prepare_campus.py`、`tools/add_roads.py`、`tools/build_model.gd` 目前仅生成 eda；不生成其他校区。原始参考资料位于 `references/`，不打入 Web。

本文客户端路径均相对 apps/game/；references/ 指仓库根目录的原始参考资料。

## 植被资源与分布

开发区的建筑、道路与地面保留在 `development_campus.tscn`，植被独立存放于同目录 `vegetation.tscn`，两者由 `scenes/campuses/eda.tscn` 静态挂载。`tools/build_model.gd` 调用独立的 `tools/build_vegetation.gd` 生成植被，不在运行时重复创建。无头模式的 dummy renderer 不保留 MultiMesh 缓冲，生成器显式写入标准 TSCN 的实例 buffer；修改生成逻辑后须使用真实渲染器运行 `tests/vegetation.gd` 检查保存后的变换。

`campuses/eda/data/vegetation.json` 保留旧生成器种子 20260909 对应的 304 棵示意树的位置和高度，新增树型与绕 Y 轴旋转（弧度）。坐标以米为单位，X 向东、Y 向上、Z 向南；这些位置沿用初版近似分布，不是照片核定或测绘结果。修改分布应编辑此文件，不通过建筑/地形生成器重新随机撒树。

`tree_0.tres` 至 `tree_3.tres` 是四份共享 ArrayMesh，每份包含树干枝条与叶片两个材质表面，保留现有程序化枝叶风格，不代表核实的树种。实例以 10 米基准高度统一缩放并旋转，单棵枝叶细节不再完全对应旧随机网格。生成器使用 Godot 原生网格 LOD；离散叶片能简化的程度有限，实例化本身不保证降低可见三角形数量或提高帧率。

实例按 64 米网格与树型组织为 MultiMeshInstance3D，负坐标向下取整，分块包围盒包含旋转缩放后的完整树冠。各批次共享外部树模型，保存局部变换；Godot 按批次裁剪，不逐树裁剪。块大小是初始工程参数，应依据桌面实测调整。植被不进入现有碰撞生成，树叶没有 trimesh 碰撞。桌面导出通过校园场景依赖包含植被与共享网格，服务端继续只导出既有碰撞世界。

离线 `development_campus.glb` 仅导出建筑与地面，不再烘焙植被；桌面客户端使用挂载两份场景的完整校园。

其他校区沿用建筑/地形、植被模型、植被分布分离的约定；没有有效植被分布依据时不复制开发区实例或新增随机分布。

## Git LFS

模型目录中的 TSCN、GLB/Blender 文件、图片和字体由 Git LFS 管理，规则见根目录 .gitattributes。普通场景、脚本及 JSON 保持 Git 文本文件。克隆前安装 Git LFS 并执行 `git lfs install`；已有克隆执行 `git lfs pull`，确保资源不是指针文本后再打开 Godot 或构建。CI checkout 必须启用 `lfs: true`。忽略的生成产物仍不提交。

Web 导出由 tools/campus_packs 自动把三校区转换为基础轮廓/碰撞启动层与 100 米网格细节包。完整建筑细节只保存一次并由覆盖格引用；其他非碰撞表面按格裁切，共享材质随启动层提供。源 TSCN 与官方 Feature ID 不变，编辑器和桌面仍使用完整模型。生成 PCK 位于 build/web/campuses/，临时场景位于 .godot/campus_grid/，均不提交。首包保留共享字体和凌水启动层。
