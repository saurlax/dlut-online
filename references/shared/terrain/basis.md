# 高程数据结构与使用依据

## 数据选择

[Copernicus GLO-30](https://registry.opendata.aws/copernicus-dem/) 提供可公开取得的全球地表高程，使用的 AWS COG 来自 2021 版。主采集期为 2011–2015，补洞可能采用更早来源，不能代表当前校园建设状态。水平坐标为 WGS84，垂直基准为 EGM2008，单位为米。源文件地址、瓦片编号、读取日期、SHA-256、许可与覆盖范围固定在 [copernicus.json](copernicus.json)，各校区裁剪结果见对应 `terrain/source.json`。

这是包含建筑与植被的 **DSM（数字表面模型）**，不是已去除地物的 DTM（裸地地形模型）。约 1 角秒的采样间距，在大连约为东西 24 米、南北 31 米；不支持路沿、台阶、入口、挡墙或小平台的精确建模。重采样到 1 米也不会增加测量精度。未取得校内高程控制点和逐像元质量掩膜，不能保证每个像元代表可信地面；有限数值与无 NoData 不等于无误差。覆盖矩形包含校园周边，统计最大值、最小值不能称为校内高差。

OSM 是三校区平面要素的基础数据，不提供这里使用的连续高程。当前模型与 DSM 通过[统一 WGS84 坐标基准](../mapping/osm-world-frame.json)直接对应。凌水、开发区的 `terrain/alignment.json` 仅为迁移前的历史配准档案，保存当时匹配对象、版本、质心及经验平移；其中4组/6组控制对象和约2–7米/3–17米残差既不是当前转换参数，也不是绝对测绘精度，禁止再叠加到当前模型或 DSM 上。

Mapzen Terrain Tiles 等其他高程来源未混入网格；混合前须核实底层数据、采集期及垂直基准。更细致的可步行地面仍需可靠 DTM、带基准的测量点或等高线。

MapTiler Terrain RGB v2 已取得三校区局部样本并完成RGB解码，属于候选比对来源，尚未混入运行网格。全球标称水平分辨率为30米，校园是否属于5米覆盖未确认；512像素瓦片和较细渲染采样不能证明新增测量精度。样本缺少本地采集日期、明确垂直基准与独立控制点，不直接与EGM2008高程相加或替换。天地图地形晕渲仅为绘制图像，另列的三维地形服务尚未取得有效实体数据。具体来源及范围见[补充数据记录](../mapping/provider-data-review.json)。

## 校园周边背景与大黑山

背景覆盖配置见 [surroundings.json](surroundings.json)，每校区 `terrain/surroundings-dem.tif` 保存扩大的原始像元裁剪，`surroundings-source.json` 记录像元窗口、摘要、共同垂直偏移与过滤方法。凌水和盘锦沿用既有 OSM 档案；开发区另存 `mapping/osm-surroundings.osm.gz` 和来源记录，不改校园已核对的几何。OSM 建筑只取校界外有效闭合多边形，保留孔洞、对象 ID 与版本；数据仍不完整，不补造缺失墙脚。

离线工具 `apps/game/tools/prepare_surroundings.py` 需要 NumPy、Rasterio、Shapely 2.1（仅离线环境，本次分别为2.5.3、1.5.1、2.1.2）。运行 `python apps/game/tools/prepare_surroundings.py` 后，再执行 `godot --headless --path apps/game --script tools/build_surroundings.gd`。工具按自身位置解析目录，首次下载固定摘要的 DSM 瓦片，后续复用 `.local/surroundings/` 缓存。源数据变更后须重新生成背景并检查接缝。

背景剔除原校园地形矩形，采样包含校园边界全部顶点，边外150米平滑衔接地坪及颜色。一般区域沿用3×3最小值与均值过滤；开发区西侧绝对高程130–230米以上渐进保留65%的原始DSM起伏，减少山脊削平，不是地形放大。开发区30米、其余50米的网格间距并非测量精度。坡度控制的岩面、林木颜色与稀疏树冠是视觉近似，不是逐树或地质调查。

大黑山参考 [KFQ00背向全景](../../eda/terrain/daheishan-panorama.json)，云层遮挡山顶以DSM为形状依据；东侧住宅色彩和分组高度见 [楼群复核](../../eda/buildings/surroundings-review.json)。照片拍摄日期未知，影像与DSM有时效差。照片分组高度优先于旧DSM，仍有约9–18米或更大的不确定性；其他建筑依次使用OSM高度、层数×估计3米、DSM屋顶差，最后为明确标识的9米占位。未经独立墙脚数据支持的西侧高楼不生成，不能把照片或屋檐投影到地面。

模型位于专属 `models/surroundings.tscn`，输入为注册表声明的 `data/surroundings.json`。地形按600米单元剔除、楼体按颜色合批、树冠采用MultiMesh且关闭远景投影，不在运行时生成或下载。玩家相机远裁剪为12公里，仅影响可见性；`Daheishan` 保留独立节点与高程供后续副本建设，当前无新碰撞，现有校园通行边界不变。开放区域须另行建设通行面和服务端碰撞，背景不是已完成的副本。

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

三校区已挂载独立 `models/terrain.tscn`，静态三角网格和碰撞均在编辑器可见。原平板基底和开发区示意山体已移除；保留官方 Feature 身份，平面轮廓采用已登记的 OSM 对应及有证据的局部修正，未迁移轮廓仍明确标记待处理。建筑保持刚性形体，地面覆盖物贴合地形，树木实例按位置更新高度。客户端和游戏服由同一场景生成碰撞。边界墙按地形最低点向下延伸10米，避免负高程处出现底部通行空隙；该余量不代表实测墙体。盘锦于2026-09-17补入N40E122原始DSM裁剪，73×70个样本保持源像元值；运行91×113网格经同样滤波与47个建筑基面估计，相对高度约−2.31至2.49米。这些数值仅描述当前预览，不是实测校园高差。

`prepare_terrain_preview.py` 从原始网格生成 `apps/game/assets/campuses/<id>/data/terrain.json`：

1. 校验当前 `campus.json` 的 `geographic_crs=EPSG:4326`、`coordinate_frame` 和校区原点与共享基准一致；不符合时拒绝生成，不回退旧平移。以 `lon=origin_lon+x/(111320*cos(origin_lat))`、`lat=origin_lat-z/111320` 对应原始 WGS84 高程网格，禁止再应用 `alignment.json`。
2. 对源 DSM 做 3×3 最小值滤波，再做 3×3 均值滤波，压低孤立的树冠/屋顶峰值。此方法也会压低自然山顶，属于地面估计，不能称为去除了全部地物的实测 DTM。
3. 以当前清单 `spawn_xz` 处过滤后的高程为 Y 零点，输出 `absolute_y_offset_egm2008_m`，用10米网格插值。源网格范围不足时拒绝越界采样。10米是渲染网格间距，原始测量精度没有增加。
4. 建筑、场地和水面以同一 Feature 的轮廓采样中位数估计水平基面；周边 7.5 米范围贴近基面，至 20 米平滑过渡。相邻对象按最近轮廓分配网格点，避免远处过渡覆盖近处基面。相邻地坪冲突、粗网格边缘和楼门接口仍可能出现局部高差或穿插，不生成无实测依据的楼梯、挡墙或室内。
5. OSM 道路先合并路口路面，再沿地形网格单元和对角线裁切，确保三角形内部及相邻路段使用同一地形平面；三校区路面和默认地面覆盖层高于地形0.02米，开发区边带0.012米、无碰撞的装饰边条0.014米，仅用于渲染分离。旧的0.12–0.22米抬升已因阻挡普通行走而撤销，不能作为实测路沿。其他地面覆盖物仍细分至最长水平边不超过 5 米后投影。建筑组仅整体升降，不改变其楼高或立面比例。道路来源及限制见 [道路数据依据](../mapping/roads.md)。

这是用户授权查看整体起伏的近似版本，不作为全校入口可通行或精确基础标高的保证。后续取得测绘资料时替换过滤、配准与地坪参数，保留地形/建筑/植被分离的结构。

## 生成方式

需要 Python 3 及 GDAL 命令行 `gdalinfo`、`gdal_translate`；也可在独立离线环境安装 Rasterio，并传入 `--backend rasterio`，本次使用Rasterio 1.5.1 / GDAL 3.12.4。两种后端均按整数窗口读取，不重采样，源PixelIsPoint标签与采样中心保持不变。不增加游戏运行依赖，不在客户端导出时联网下载。完整瓦片缓存于已忽略的 `.local/terrain-research/`，仓库只保存小范围裁剪数据。

```sh
python3 apps/game/tools/prepare_terrain.py
python3 apps/game/tools/prepare_terrain.py --campus lingshui
python3 apps/game/tools/prepare_terrain.py --output-root .local/terrain-check
```

工具从自身路径定位仓库；默认路径不依赖调用目录。缓存缺失时按固定 URL 下载并核对 SHA-256，缓存不符时拒绝继续。生成过程校验覆盖、样本数量、有限高程、NoData 和行列方向；工具不将质量未知像元推定为裸地。更新来源须先更新配置及其读取日期、哈希和许可依据，再生成受影响校区数据；不得复制其他校区网格来填补缺口。

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

三校区模型生成器同步更新独立地形，三个校区的模型生成器均重建各自植被。服务端碰撞必须在对应源场景更新后重新生成，不能只移动可见模型。桌面导出通过校园场景引用携带地形，首页背景同样引用凌水地形，并按对应建筑基面调整镜头高度。每批只重新生成受影响校区，核对建筑基面、道路、广场、台阶、植被和保存服务端的一致性；上述命令不是精度或通行验收的替代品。

## 禁用 DLUTMap 三维选择框

DLUTMap 交互 bound 已确认为斜视三维选择框，不再作为地面轮廓或兜底来源。原始 `references/<campus>/mapping/bounds.json` 只供来源 ID、名称与历史审查；运行清单不携带旧点列。没有独立、已登记地面几何的对象保留空参考节点和 `withheld_geometry`，不产生基台、地图形状、立面或碰撞。现有 OSM 配准和基于独立俯视图/照片的局部修正继续使用，不自动平均多源外包框。

当前凌水、开发区、盘锦分别有127、3、17个空来源参考（包含本来就不生成实体的参考点和重复身份，不等于撤掉147栋建筑）。禁用时三校区25处植被区域依照官方轮廓手工对齐，全部暂停。随后锦屏山以独立OSM林地区域及全域影像恢复900个近似树木实例，图书馆北侧草坪随后恢复4053个近景草叶和贴地草坪，未恢复内部均匀乔木；剩余23处仍暂停，照片与植物资源留存。恢复种植区域必须明确共同坐标基准与原点并完成独立地面配准。校园范围使用OSM边界与已采用要素的包围范围，避免被撤下的框继续控制边界。

已保存的历史出生点作为操作位置继续保留，落地须进行物理验证；其旧换算不用于要素几何。此次处理只撤销无效来源，不能证明剩余OSM轮廓、楼高、道路宽度或过滤后的DSM地形已经达到实测精度。
