# 高程数据结构与使用依据

## 数据选择

[Copernicus GLO-30](https://registry.opendata.aws/copernicus-dem/) 提供可公开取得的全球地表高程，使用的 AWS COG 来自 2021 版。主采集期为 2011–2015，补洞可能采用更早来源，不能代表当前校园建设状态。水平坐标为 WGS84，垂直基准为 EGM2008，单位为米。源文件地址、瓦片编号、读取日期、SHA-256、许可与覆盖范围固定在 [copernicus.json](copernicus.json)，各校区裁剪结果见对应 `terrain/source.json`。

这是包含建筑与植被的 **DSM（数字表面模型）**，不是已去除地物的 DTM（裸地地形模型）。约 1 角秒的采样间距，在大连约为东西 24 米、南北 31 米；不支持路沿、台阶、入口、挡墙或小平台的精确建模。重采样到 1 米也不会增加测量精度。未取得校内高程控制点和逐像元质量掩膜，不能保证每个像元代表可信地面；有限数值与无 NoData 不等于无误差。覆盖矩形包含校园周边，统计最大值、最小值不能称为校内高差。

OSM 提供同名建筑轮廓用于预览配准，未作为高程源。两校区 `terrain/alignment.json` 保存匹配对象 ID、OSM 版本及原始轮廓、面积质心、平移和残差。凌水采用 4 组控制对象，开发区采用 6 组；残差分别约 2–7 米、3–17 米。该经验平移不证明官方坐标基准或满足测绘精度。

Mapzen Terrain Tiles 等其他高程来源未混入网格；混合前须核实底层数据、采集期及垂直基准。更细致的可步行地面仍需可靠 DTM、带基准的测量点或等高线。

## 文件与网格

每校区 `terrain/` 保存：

- `surface-dem.tif`：保持源像元值和间距的地理配准 Float32 GeoTIFF，裁剪窗口向外对齐原始像元边界。
- `heightfield.json`：同一窗口的高度网格，供离线模型工具读取；保留 Float32 样本值，无平滑、插值或归一化。
- `source.json`：来源、裁剪窗口、像元边缘变换、数值范围、输出哈希与使用边界。

`heightfield.json` 的 `width` 为列数，`height` 为行数，`rows_north_to_south[row][column]` 为 EGM2008 绝对高程。行从北往南、列从西往东。采样中心坐标为：

```text
lon = sample_origin_lon_lat[0] + column * sample_step_lon_lat[0]
lat = sample_origin_lon_lat[1] + row * sample_step_lon_lat[1]
```

`source.json` 中的 `pixel_edge_geotransform` 采用 GDAL 六参数格式，描述像元边缘，不能当作首个采样点中心；两者相差半个像元。

为方便独立网格预览，`local_frame` 给出以西北采样点为原点、X 向东、Z 向南的近似米制步长；`x = column * x_east_step_m`，`z = row * z_south_step_m`，`y = elevation - y_offset_m`。转换采用 `111320 * cos(origin_lat)` 米/经度及 `111320` 米/纬度，只适用于小区域展示，不是测量投影。Y 偏移固定为零，未扣除建筑基础高程。

## 场景预览处理

凌水和开发区已挂载独立 `models/terrain.tscn`，静态三角网格和碰撞均在编辑器可见。原平板基底和开发区示意山体已移除，官方 Feature 分组及平面轮廓保留；建筑保持刚性形体，地面覆盖物贴合地形，树木实例按位置更新高度。客户端和游戏服由同一场景生成碰撞。盘锦维持原模型。

`prepare_terrain_preview.py` 从原始网格生成 `apps/game/assets/campuses/<id>/data/terrain.json`：

1. 根据 `alignment.json` 平移，将现有模型坐标对应至 WGS84 高程网格；不写回原始官方轮廓。
2. 对源 DSM 做 3×3 最小值滤波，再做 3×3 均值滤波，压低孤立的树冠/屋顶峰值。此方法也会压低自然山顶，属于地面估计，不能称为去除了全部地物的实测 DTM。
3. 以初始出生位置处过滤后的高程为 Y 零点，用 10 米网格插值。10 米是渲染网格间距，原始测量精度没有增加。
4. 建筑、场地和水面以同一 Feature 的轮廓采样中位数估计水平基面；周边 7.5 米范围贴近基面，至 20 米平滑过渡。相邻对象按最近轮廓分配网格点，避免远处过渡覆盖近处基面。相邻地坪冲突、粗网格边缘和楼门接口仍可能出现局部高差或穿插，不生成无实测依据的楼梯、挡墙或室内。
5. OSM 道路先合并路口路面，再沿地形网格单元和对角线裁切，确保三角形内部及相邻路段使用同一地形平面；凌水路面高于地形 0.12 米，开发区路面 0.22 米、路缘 0.16 米，均为渲染/通行间隙，不代表实测结构厚度。其他地面覆盖物仍细分至最长水平边不超过 5 米后投影。建筑组仅整体升降，不改变其楼高或立面比例。道路来源及限制见 [道路数据依据](../mapping/roads.md)。

这是用户授权查看整体起伏的近似版本，不作为全校入口可通行或精确基础标高的保证。后续取得测绘资料时替换过滤、配准与地坪参数，保留地形/建筑/植被分离的结构。

## 生成方式

需要 Python 3 标准库及 GDAL 命令行 `gdalinfo`、`gdal_translate`。不增加游戏运行依赖，不在客户端导出时联网下载。完整瓦片缓存于已忽略的 `.local/terrain-research/`，仓库只保存小范围裁剪数据。

```sh
python3 apps/game/tools/prepare_terrain.py
python3 apps/game/tools/prepare_terrain.py --campus lingshui
python3 apps/game/tools/prepare_terrain.py --output-root .local/terrain-check
```

工具从自身路径定位仓库；默认路径不依赖调用目录。缓存缺失时按固定 URL 下载并核对 SHA-256，缓存不符时拒绝继续。生成过程校验覆盖、样本数量、有限高程、NoData 和行列方向；工具不将质量未知像元推定为裸地。更新来源须先更新配置及其读取日期、哈希和许可依据，再生成两校区数据。

预览资源生成顺序：

```sh
python3 apps/game/tools/prepare_terrain_preview.py
godot --headless --path apps/game --script res://tools/build_lingshui.gd
godot --headless --path apps/game --script res://tools/build_model.gd
godot --headless --path apps/game --script res://tools/server_export/build_worlds.gd
```

两校区模型生成器会同时更新独立地形；开发区生成器同步更新植被。服务端碰撞场景随对应校园更新，并可从源场景重建。桌面导出通过校园场景引用携带地形，首页背景同样引用凌水地形，并按对应建筑基面调整镜头高度。
