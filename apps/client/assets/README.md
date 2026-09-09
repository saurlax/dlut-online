# 资源目录

- `fonts/`：三校区共享的中文字体和许可，运行时 UI 使用。
- `campuses/eda/data/campus.json`：开发区 27 个官方轮廓、来源和高度估计；模型生成、运行时碰撞关联和地图使用，不代表全校数据。
- `campuses/eda/data/roads.json`：开发区道路描摹数据，模型生成和地图使用。
- `campuses/eda/models/development_campus.tscn`：开发区静态模型，由 `scenes/campuses/eda.tscn` 实例引用，属于游戏运行资源。
- `campuses/eda/models/development_campus.glb` 与同目录 albedo PNG：生成器输出的离线模型交换文件及纹理，不列入 Web 导出和版本控制；需要时运行模型生成工具重建，供外部建模工具使用。
- `.import`：Godot 资源导入配置，由编辑器管理；移动资产时同步更新。

`lingshui`、`panjin` 当前只有用户授权的占位模型，直接保存在 `scenes/campuses/` 各自场景内，因此暂不创建空数据或复制 eda 资产。取得真实资料后，按 `assets/campuses/<campus_id>/{data,models}/` 添加资源，并在 `scripts/campus_catalog.gd` 声明数据路径。

`tools/prepare_campus.py`、`tools/add_roads.py`、`tools/build_model.gd` 目前仅生成 eda；不生成其他校区。原始参考资料位于 `references/`，不打入 Web。

本文客户端路径均相对 apps/client/；references/ 指仓库根目录的原始参考资料。
