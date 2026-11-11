# 区域像素地图来源

范围为东经 120.7–124.2、北纬 38.4–41.15，包含大连全域概览和盘锦校区。地理记录使用 WGS84；区域原片按 Web Mercator 的 z9 像素网格绘制，1275×1304 像素，在北纬 40 度附近约 234 米/像素。像素尺寸不是原数据的定位精度。

| 文件 | 内容 |
| --- | --- |
| `sources.json` | 原始 URL、下载日期、SHA-256 与来源许可 |
| `geography.json` | 裁切后的 Natural Earth 陆地、城市、道路、河流及地名 |
| `terrain.png` | Mapzen Terrarium 原生高程拼图，不是游戏贴图 |
| `terrain-attribution.md` | 上游高程来源署名 |
| `landmarks.json` | 240 个建筑及设施造型参考对应的现有模型、哈希、原生尺寸与投影 |
| `building-art.json` | 逐栋 imagegen 提示词、原片摘要、正式素材摘要与标准化流程 |
| `campus-art.json` | 三校区整图插画的官方底图、风格参考、完整提示词、原片与像素化预览 |
| `campus-registration.json` | 三校区整图的人工选点、近似配准、图层四角和控制点拟合残差 |

Natural Earth 为 1:10m 区域概览数据，不用于推断精确街道、建筑或新校园海岸线；已配准的 OSM 校区边界优先于概化岸线。地形颜色表达高程，不声称这些区域均为林地。当前校园层使用三张按学校官方地图参考生成的完整 imagegen 插画，按主楼广场样片重绘，使用 Retro Diffusion Standard 保留原片分辨率并量化到每校区最多 48 色，按图面校区轮廓裁切，再以单一缩放、旋转和平移近似配准。控制点最大拟合残差约 37、12、11 米；这是预览误差指标，不代表地理精度。整图所有要素同步缩放，地标命中和传送继续使用已有 WGS84 数据。旧的 2 米/像素地面原片和 240 张逐栋美术留在本地美术档案，运行时不再叠加逐栋建筑图标。

街道、区域、湖泊、广场与小地点标签读取三校区现有 `references/<campus>/osm.osm.gz` 归档的具名节点和道路，限于校区地图外扩 800 米的周边；不推断无名称道路，不从概览底图猜测街名。道路使用校园插画轮廓内最长连续段的长度中点；同名相邻路段合并标注。建筑标签读取已配准建筑清单，省略目录前缀与长括号说明，完整名称保留在点选信息里。输出清单保存 OSM 要素类型和 ID，便于回查。

更新来源使用 `python tools/import_city_references.py`，完整下载临时缓存保存在 `.local/city-map/downloads/`。常规重生成运行 `python tools/build_city_atlas.py`，只读取仓库来源和已安装 MapLibre 许可；需要重绘模型参考时加 `--render-landmarks`，并安装 Blender 或用 `--blender` 指定路径，参考只输出到 `.local/city-map/model-sprites/`。正式 imagegen 原片及提示词保存在 `.local/city-map/imagegen/`；用 `python tools/prepare_atlas_art.py` 标准化全部，`--asset <id>` 处理单栋，`--source-dir` 指定原片目录。正式原片、图层、清单与许可输出到 `apps/web/public/world/atlas/`，正常前端构建不联网生成。

整图重新配准运行 `python tools/register_campus_atlas.py`，需要 `campus-art.json` 记录的本地生成原片，以及 `campus-registration.json` 登记版本的 [Pixel Art Fixer Standard](https://github.com/Retro-Diffusion/pixel-art-fixer) Python 包。按上游 Python 目录的依赖文件安装，令 `pixelfixer.api` 可从当前 Python 环境导入；常规 `build_city_atlas.py` 仅需已发布插画和 `campus-registration.json`。
