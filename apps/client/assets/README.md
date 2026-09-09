# 资源目录

- `fonts/`：三校区共享的中文字体和许可，运行时 UI 使用。
- `campuses/eda/data/campus.json`：开发区 27 个官方轮廓、来源和高度估计；模型生成、运行时碰撞关联和地图使用，不代表全校数据。
- `campuses/eda/data/roads.json`：开发区道路描摹数据，模型生成和地图使用。
- `campuses/eda/models/development_campus.tscn`：开发区静态模型，由 `scenes/campuses/eda.tscn` 实例引用，属于游戏运行资源。
- `campuses/eda/models/development_campus.glb` 与同目录 albedo PNG：生成器输出的离线模型交换文件及纹理，不列入 Web 导出和版本控制；需要时运行模型生成工具重建，供外部建模工具使用。
- `.import`：Godot 资源导入配置，由编辑器管理；移动资产时同步更新。

`lingshui` 的官方轮廓数据位于 `campuses/lingshui/data/campus.json`，静态模型位于 `campuses/lingshui/models/lingshui_campus.tscn`，由凌水场景直接挂载。包含 313 段轮廓及七栋建筑的局部照片立面，来源与精度见根目录 `references/lingshui/README.md`。`panjin` 仍为直接保存在场景内的占位模型，不复制其他校区资源。

`tools/prepare_campus.py`、`tools/add_roads.py`、`tools/build_model.gd` 目前仅生成 eda；不生成其他校区。原始参考资料位于 `references/`，不打入 Web。

本文客户端路径均相对 apps/client/；references/ 指仓库根目录的原始参考资料。

## Git LFS

模型目录中的 TSCN、GLB/Blender 文件、图片和字体由 Git LFS 管理，规则见根目录 .gitattributes。普通场景、脚本及 JSON 保持 Git 文本文件。克隆前安装 Git LFS 并执行 `git lfs install`；已有克隆执行 `git lfs pull`，确保资源不是指针文本后再打开 Godot 或构建。CI checkout 必须启用 `lfs: true`。忽略的生成产物仍不提交。
