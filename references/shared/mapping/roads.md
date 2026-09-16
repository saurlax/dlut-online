# 道路数据与接缝依据

## 来源与许可

© OpenStreetMap contributors，数据库及本项目转换后的道路数据适用 [ODbL 1.0](https://www.openstreetmap.org/copyright)。2026-09-16 通过 `https://overpass-api.de/api/interpreter` 获取 way 几何；各校区 `mapping/osm-roads.json` 保存实际查询、原始响应、way/node ID、版本及时间。校园边界 way 分别为凌水 443031231、开发区 215560705、盘锦 463862869。来源和分发声明统一见根目录 CREDITS.md。

原始查询包含周边对象，归档仅保留校园边界、范围内道路及明确排除的道路对象，保留对象字段不改写，并在 selection 标记筛选范围；转换时只保留校园边界与当前场景范围内的道路。场景边界向内留 15 米，防止估计宽度越出碰撞世界。输出为各校区 `assets/campuses/<id>/data/osm_roads.json`，官方 `campus.json` 的 Feature ID 和轮廓保留作对照，不再叠加旧的碎片道路；开发区旧手绘 `roads.json` 保留为历史参考，不用于运行路网。

## 坐标与宽度

先以校区 `campus.json` 的 origin 转换成近似米制 X/Z，再减去配准记录的 offset_xz_m。凌水和开发区复用 `terrain/alignment.json`，与现有地形一致。盘锦 `mapping/road-alignment.json` 使用 46 栋同名建筑面积质心差的分量中位数：偏移约 (-446.313, 214.896) 米，控制点残差中位数 4.820 米、最大 16.415 米。这是预览配准，不确认官方地图坐标基准，也不把 OSM 当成测绘真值。

优先使用合法米制 `width` 标签；缺失时按道路类型使用可追溯的视觉估计：primary 10 米、secondary 9 米、tertiary 7 米、residential/unclassified 6 米、service/living_street/pedestrian 5 米、track 3 米、cycleway 2.5 米、footway/path 2 米。每条道路写入 width_basis，不以默认值声称实测。未自动调整建筑位置，局部配准误差和出入口对齐仍有限制。

## 几何与范围

线段带状面在共享节点处合并横截面凸包，填上折角和路口；不吸附相近而未连接的端点。离线扫描线并集保留围合空地，消除同层重复面。相同边界的相邻条带合并，避免每个远处节点都切碎整张路网。凌水及开发区进一步沿地形格线和对角线裁切，路面任意内部点均位于相同地形平面上方；视觉与碰撞使用同一网格。盘锦仍采用平地，不新增高程。

导入凌水 87、开发区 64、盘锦 22 个道路片段。分别排除 9、6、1 条桥梁、隧道、台阶或非地面层道路，详见输出 excluded；包括大工桥、学苑桥等，未凭二维数据补造其垂直结构。OSM 本身未收录的连接、建筑入口、室内及地下通道不生成，不能据此声称道路完整测绘或全校无障碍可达。

## 重建

从仓库根目录运行（Godot 工程仍为 apps/game）：

```sh
python apps/game/tools/prepare_osm_roads.py
godot --headless --path apps/game --script res://tools/rebuild_roads.gd
godot --headless --path apps/game --script res://tools/server_export/build_worlds.gd
```

仅在主动更新来源时给 Python 工具加 `--fetch`，可用 `--campus lingshui` 限定校区。默认完全离线。完整校园生成器也调用同一道路构建器。道路专项检查为 `res://tests/road_geometry.gd`；客户端/服务端应一起重新导出。
