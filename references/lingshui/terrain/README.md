# 凌水主校区地形资料

本目录保存本校区高程数据及其来源记录，按数据产品区分 DSM（包含建筑和植被的地表）、DTM（裸地）、等高线和测量点。

| 文件 | 内容 |
|---|---|
| [surface-dem.tif](surface-dem.tif) | Copernicus GLO-30 原生间距地表高程裁剪，WGS84 / EGM2008 |
| [heightfield.json](heightfield.json) | 从北到南、从西到东排列的绝对高度网格 |
| [alignment.json](alignment.json) | 迁移前的轮廓匹配与经验平移档案；当前生成器不使用 |
| [source.json](source.json) | 来源、日期、许可、坐标、覆盖、处理与输出校验值 |

网格结构、生成命令及精度边界见 [高程数据依据](../../shared/terrain/basis.md)，许可声明见 [CREDITS.md](../../../CREDITS.md)。当前已用于共享 WGS84 基准下的过滤 DSM 地形近似，不能称为实测裸地；OSM 平面来源及历史官网档案见 [mapping/](../mapping/)。

新增资料须说明水平坐标系、垂直基准、单位、采集日期、分辨率、精度、覆盖范围与许可；未知项明确标注。录入遵循 [目录规范](../../README.md)，不得用插值或照片估计冒充新增测量精度。
