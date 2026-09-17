# 高程数据结构与使用依据

## 数据选择

[Copernicus GLO-30](https://registry.opendata.aws/copernicus-dem/) 提供可公开取得的全球地表高程，使用的 AWS COG 来自 2021 版。主采集期为 2011–2015，补洞可能采用更早来源，不能代表当前校园建设状态。水平坐标为 WGS84，垂直基准为 EGM2008，单位为米。源文件地址、瓦片编号、读取日期、SHA-256、许可与覆盖范围固定在 [copernicus.json](copernicus.json)，各校区裁剪结果见对应 `terrain/source.json`。

这是包含建筑与植被的 **DSM（数字表面模型）**，不是已去除地物的 DTM（裸地地形模型）。约 1 角秒的采样间距，在大连约为东西 24 米、南北 31 米；不支持路沿、台阶、入口、挡墙或小平台的精确建模。重采样到 1 米也不会增加测量精度。未取得校内高程控制点和逐像元质量掩膜，不能保证每个像元代表可信地面；有限数值与无 NoData 不等于无误差。覆盖矩形包含校园周边，统计最大值、最小值不能称为校内高差。

OSM 是三校区平面要素的基础数据，不提供这里使用的连续高程。当前模型与 DSM 通过[统一 WGS84 坐标基准](../mapping/osm-world-frame.json)直接对应。凌水、开发区的 `terrain/alignment.json` 仅为迁移前的历史配准档案，保存当时匹配对象、版本、质心及经验平移；其中4组/6组控制对象和约2–7米/3–17米残差既不是当前转换参数，也不是绝对测绘精度，禁止再叠加到当前模型或 DSM 上。

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

原始网格中的 `local_frame` 仅供独立预览：以西北采样点为原点，`x = column * x_east_step_m`、`z = row * z_south_step_m`、`y = elevation - y_offset_m`，其中原始Y偏移为零。这不是校园场景原点。场景采用各校区共享原点，经度尺度为 `111320 * cos(origin_lat)`、纬度尺度为 `111320`，X向东、Z向南；它是小区域近似米制坐标，不是测量投影。

## 场景预览处理

凌水和开发区已挂载独立 `models/terrain.tscn`，静态三角网格和碰撞均在编辑器可见。原平板基底和开发区示意山体已移除；保留官方 Feature 身份，平面轮廓采用已登记的 OSM 对应及有证据的局部修正，未迁移轮廓仍明确标记待处理。建筑保持刚性形体，地面覆盖物贴合地形，树木实例按位置更新高度。客户端和游戏服由同一场景生成碰撞。盘锦平面同样已迁移至共享 WGS84 原点，但没有归档高程，保留平地近似，不能称为已恢复真实起伏。

`prepare_terrain_preview.py` 从原始网格生成 `apps/game/assets/campuses/<id>/data/terrain.json`：

1. 校验当前 `campus.json` 的 `geographic_crs=EPSG:4326`、`coordinate_frame` 和校区原点与共享基准一致；不符合时拒绝生成，不回退旧平移。以 `lon=origin_lon+x/(111320*cos(origin_lat))`、`lat=origin_lat-z/111320` 对应原始 WGS84 高程网格，禁止再应用 `alignment.json`。
2. 对源 DSM 做 3×3 最小值滤波，再做 3×3 均值滤波，压低孤立的树冠/屋顶峰值。此方法也会压低自然山顶，属于地面估计，不能称为去除了全部地物的实测 DTM。
3. 以当前清单 `spawn_xz` 处过滤后的高程为 Y 零点，输出 `absolute_y_offset_egm2008_m`，用10米网格插值。源网格范围不足时拒绝越界采样。10米是渲染网格间距，原始测量精度没有增加。
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

工具从自身路径定位仓库；默认路径不依赖调用目录。缓存缺失时按固定 URL 下载并核对 SHA-256，缓存不符时拒绝继续。生成过程校验覆盖、样本数量、有限高程、NoData 和行列方向；工具不将质量未知像元推定为裸地。更新来源须先更新配置及其读取日期、哈希和许可依据，再生成凌水、开发区数据；不能为无来源的盘锦高程复制其他校区网格。

平面清单更新后，再生成地形及场景；在仓库根目录执行以下现有工具：

```sh
python3 apps/game/tools/prepare_lingshui.py
python3 apps/game/tools/prepare_campus.py
python3 apps/game/tools/prepare_panjin.py
python3 apps/game/tools/prepare_terrain_preview.py
godot --headless --path apps/game --script res://tools/build_lingshui.gd
godot --headless --path apps/game --script res://tools/build_model.gd
godot --headless --path apps/game --script res://tools/build_panjin.gd
godot --headless --path apps/game --script res://tools/server_export/build_worlds.gd
```

凌水、开发区模型生成器同步更新独立地形，三个校区的模型生成器均重建各自植被。服务端碰撞必须在对应源场景更新后重新生成，不能只移动可见模型。桌面导出通过校园场景引用携带地形，首页背景同样引用凌水地形，并按对应建筑基面调整镜头高度。每批只重新生成受影响校区，核对建筑基面、道路、广场、台阶、植被和保存服务端的一致性；上述命令不是精度或通行验收的替代品。
