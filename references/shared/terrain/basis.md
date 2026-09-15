# 高程数据结构与使用依据

## 数据选择

[Copernicus GLO-30](https://registry.opendata.aws/copernicus-dem/) 提供可公开取得的全球地表高程，使用的 AWS COG 来自 2021 版。主采集期为 2011–2015，补洞可能采用更早来源，不能代表当前校园建设状态。水平坐标为 WGS84，垂直基准为 EGM2008，单位为米。源文件地址、瓦片编号、读取日期、SHA-256、许可与覆盖范围固定在 [copernicus.json](copernicus.json)，各校区裁剪结果见对应 `terrain/source.json`。

这是包含建筑与植被的 **DSM（数字表面模型）**，不是已去除地物的 DTM（裸地地形模型）。约 1 角秒的采样间距，在大连约为东西 24 米、南北 31 米；不支持路沿、台阶、入口、挡墙或小平台的精确建模。重采样到 1 米也不会增加测量精度。未取得校内高程控制点和逐像元质量掩膜，不能保证每个像元代表可信地面；有限数值与无 NoData 不等于无误差。覆盖矩形包含校园周边，统计最大值、最小值不能称为校内高差。

OSM 可补充道路、建筑轮廓、台阶和少量 `ele` 属性，但本次检查的两个校区资料没有形成连续的实测高程依据，未纳入高度网格。Mapzen Terrain Tiles 等其他来源未与本数据混合；混合前须核实底层数据、采集期及垂直基准，不能直接平均 EGM96 与 EGM2008 高程。更细致的可步行地面仍需可靠 DTM、带基准的测量点或等高线。

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

## 与校园模型的关系

当前模型按 Feature ID 保留建筑组，网格在组内按材质和碰撞属性合并；地面、道路和建筑仍包含在校园模型场景中。凌水使用平地基底，开发区另有估计高度的示意山体。新增数据独立存于参考目录，未替换这些场景或碰撞，也不随客户端自动加载。

[官方地图坐标依据](../mapping/map-coordinate-handling.json) 尚未确认校园轮廓的水平基准。地形网格的局部原点也不同于现有 `campus.json`，不得直接叠加，亦不得凭偏移猜测并写回官方轮廓。后续接入须先以可靠控制点核实水平配准，再统一高程零点、处理 DSM 地物影响并调整道路和建筑基础。

运行时建议分别维护地形、建筑、植被与碰撞资源，按区域组织加载和优化；地形细分与建筑独立模型并不冲突。实际接入时必须移除对应平地/示意山体的重复碰撞，核验入口与坡面通行。

## 生成方式

需要 Python 3 标准库及 GDAL 命令行 `gdalinfo`、`gdal_translate`。不增加游戏运行依赖，不在客户端导出时联网下载。完整瓦片缓存于已忽略的 `.local/terrain-research/`，仓库只保存小范围裁剪数据。

```sh
python3 apps/game/tools/prepare_terrain.py
python3 apps/game/tools/prepare_terrain.py --campus lingshui
python3 apps/game/tools/prepare_terrain.py --output-root .local/terrain-check
```

工具从自身路径定位仓库；默认路径不依赖调用目录。缓存缺失时按固定 URL 下载并核对 SHA-256，缓存不符时拒绝继续。生成过程校验覆盖、样本数量、有限高程、NoData 和行列方向；工具不将质量未知像元推定为裸地。更新来源须先更新配置及其读取日期、哈希和许可依据，再生成两校区数据。
