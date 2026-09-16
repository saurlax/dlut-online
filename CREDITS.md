# 第三方版权与许可声明

Third-Party Notices

## 一、适用范围

本声明列明 DLUT Online 桌面客户端、服务端及网站所使用的第三方资料、素材、数据服务和软件的来源、权利归属及适用许可。

第三方内容的著作权、商标权及其他合法权利归各自权利人所有。相关内容的使用、修改及分发受其适用许可、服务条款及法律规定约束。本声明不构成对第三方权利的转让或额外授权；本声明与适用许可原文不一致的，以许可原文为准。

## 二、校园地图、建筑资料与影像

### 2.1 资料来源

| 发布者或服务提供者 | 来源 | 使用范围 |
|---|---|---|
| 大连理工大学 | [官方校园地图](http://map.dlut.edu.cn)、[校区目录](http://map.dlut.edu.cn/openmap/mapi/campus/v1)、[建筑与场地轮廓](http://map.dlut.edu.cn/openmap/mapi/bd/v1/bound) | 三校区名称、位置、平面轮廓、建筑详情及照片，用于校园模型、地图和天气查询位置 |
| 大连理工大学 | [新闻网](https://news.dlut.edu.cn/)，包括[学生公寓主体封顶报道](https://news.dlut.edu.cn/info/1022/81930.htm)及[校园建设报道](https://news.dlut.edu.cn/info/1022/82977.htm) | 建筑描述、公布尺寸、建设照片与效果图，用于建筑形态和立面的参考 |
| 大连理工大学图书馆全景站及其影像提供者 | [校园全景](https://360.toowtech.com/dalian/DUT/)，影像服务域名 `imgs.toowtech.com` | 航拍、建筑内外景及场地布局的视觉参考 |
| 高德地图 | 官方校园地图配置引用的[高德影像服务](https://lbs.amap.com/) | 卫星影像及建筑位置的交叉核对 |

上述资料及影像的权利归原作者及其他合法权利人所有。资料发布者、服务提供者的列示不构成对其享有全部相关权利的认定。高德服务另受其[服务条款](https://lbs.amap.com/pages/terms/)约束。

**授权说明：** 上述校园地图、照片、报道及全景影像的开放许可与本项目再分发授权尚未获得确认。来源署名不替代权利人的许可，公开访问亦不构成复制、改编或分发授权。

### 2.2 网站图像与视频

| 素材 | 原始来源 | 处理及用途 |
|---|---|---|
| [主楼照片](apps/web/src/assets/main-building.jpg) | 官方校园地图，建筑编号 77386，[照片索引](references/lingshui/buildings/photos/77386.json)第 2 张 | 网站校园实景展示 |
| [令希图书馆照片](apps/web/src/assets/library.jpg) | 官方校园地图，建筑编号 77357，[照片索引](references/lingshui/buildings/photos/77357.json)第 8 张 | 网站校园实景展示 |
| [校园绿荫照片](apps/web/src/assets/campus-garden.jpg) | 官方校园地图，建筑编号 77386，[照片索引](references/lingshui/buildings/photos/77386.json)第 5 张 | 网站校园实景展示 |
| [校园视频](apps/web/src/assets/campus-film.mp4)及[封面](apps/web/src/assets/campus-film-poster.jpg) | [大连理工大学英文官网](https://en.dlut.edu.cn/)发布的 [ssdg.mp4](https://en.dlut.edu.cn/video/ssdg.mp4) | 截取 22.0–23.2 秒及 26.0–29.2 秒片段，依原顺序拼接，以原速的 2/3 播放，移除音轨并转码；封面取处理后首帧，用于网站背景展示 |

上述照片、视频及其处理版本的使用受第 2.1 条授权说明约束。裁剪、转码、变速或其他处理不改变原素材的权利归属。

### 2.3 来源档案

资料的原始地址、对象标识、读取日期和处理依据分别载于[凌水主校区档案](references/lingshui/README.md)、[开发区校区档案](references/eda/README.md)及[盘锦校区档案](references/panjin/README.md)。

### 2.4 Copernicus 高程数据

**数据产品：** [Copernicus DEM GLO-30 Public](https://registry.opendata.aws/copernicus-dem/)，由 Sinergise 在 AWS 发布的 2021 版 Cloud Optimized GeoTIFF。

**适用许可：** [Copernicus WorldDEM-30 Licence](https://dataspace.copernicus.eu/sites/default/files/media/files/2025-06/copernicus_contributing_mission_data_access_v2_cop_dem_licenses.pdf)（文内同名许可）。该许可授予全球范围、无期限、免费的非独占复制、分发、向公众传播、改编、修改及与其他数据组合使用的权利，使用者及后续分发者须遵守其署名、责任声明及其他条款。

DLUT Online 对 N38E121、N39E121 瓦片进行像素窗口裁剪及高度网格格式转换，作为凌水主校区和开发区校区的地形基础资料，并经过过滤、插值、坐标平移及局部地坪调整生成客户端和游戏服使用的地形。原始数据的著作权归 DLR e.V. 及 Airbus Defence and Space GmbH 等相应权利人所有。

原始数据版权声明：

> © DLR e.V. 2010-2014 and © Airbus Defence and Space GmbH 2014-2018 provided under COPERNICUS by the European Union and ESA; all rights reserved.

改编数据署名声明：

> produced using Copernicus WorldDEM-30 © DLR e.V. 2010-2014 and © Airbus Defence and Space GmbH 2014-2018 provided under COPERNICUS by the European Union and ESA; all rights reserved

责任声明：

> The organisations in charge of the Copernicus programme by law or by delegation do not incur any liability for any use of the Copernicus WorldDEM-30.

数据按原样提供。后续使用者对相关数据的分发或向公众传播须保留上述声明，并遵守该许可第 6 条的义务。数据提供者、许可方及 Copernicus 相关机构未对本项目作出认可或背书。

### 2.5 OpenStreetMap

**数据来源：** [OpenStreetMap](https://www.openstreetmap.org/)，© OpenStreetMap contributors。

**适用许可：** [Open Data Commons Open Database License 1.0（ODbL）](https://opendatacommons.org/licenses/odbl/1-0/)。版权及署名要求见 [OpenStreetMap Copyright](https://www.openstreetmap.org/copyright)。

DLUT Online 提取凌水主校区及开发区校区的部分建筑轮廓，与官方校园地图的同名建筑匹配，以估算地形预览的水平平移。所使用的 OSM 数据摘录及其转换记录载于两校区 `terrain/alignment.json`；该等数据库内容按 ODbL 1.0 提供，后续使用者须遵守其署名、共享及数据库分发条件。

三个校区的道路中心线和校园范围使用 2026-09-16 读取的 OSM 数据，原始查询、way/node ID 与版本归档于 `references/<campus_id>/mapping/osm-roads.json`；盘锦建筑配准控制点另存 `references/panjin/mapping/road-alignment.json`。离线裁剪、坐标转换及估计宽度生成的 `apps/game/assets/campuses/<campus_id>/data/osm_roads.json` 同样按 ODbL 1.0 提供，随仓库公开分发。道路模型及游戏地图含 © OpenStreetMap contributors 数据，转换方式及精度限制见 [道路数据依据](references/shared/mapping/roads.md)。

### 2.6 建筑表面贴图

照片支持的建筑局部立面使用共享材质，逐栋照片 URL、对象 ID、读取日期、覆盖区段与暂缓理由记录于各校区的 texture_surfaces.json。累计覆盖凌水 70 栋、开发区 13 栋、盘锦 2 栋；不代表完整建筑复刻或全校覆盖。原始照片仅离线参考，不打入客户端。

- [Poly Haven Beige Wall 001](https://polyhaven.com/a/beige_wall_001)：Dimitrios Savva 摄影、Rico Cilliers 处理，用于细抹灰表面。
- [Poly Haven Red Brick](https://polyhaven.com/a/red_brick)：Rob Tuytel，用于照片确认的令希图书馆和东山 5 栋局部砖墙。
- 上述两套材质采用 [CC0](https://polyhaven.com/license)，下载未修改的 1K 颜色、粗糙度和 OpenGL 法线图；运行时调整颜色与法线强度。公共素材不是校园建筑的实测扫描。
- 面砖、细矿物颗粒、陶土微表面为 2026-09-16 使用 OpenAI 内置 image_gen 生成，参考已归档照片的材料类别，未标记为 CC0。颜色、纹理尺度和微观细节为视觉近似，不代表测量或施工材料鉴定。

下载直链、作者、SHA-256、完整生成提示词、尺度和使用索引见 [共享纹理来源](references/shared/buildings/textures.json)。首次面砖生成记录见 [凌水纹理来源](references/lingshui/buildings/texture_sources.json)。选材时还核对了 [Long White Tiles](https://polyhaven.com/a/long_white_tiles) 与 [ambientCG 许可](https://docs.ambientcg.com/license/)，但未使用这些候选资产。

## 三、天气数据与计算方法

### 3.1 Open-Meteo

**数据提供者：** [Open-Meteo](https://open-meteo.com/)。

**适用许可：** [Creative Commons Attribution 4.0 International（CC BY 4.0）](https://creativecommons.org/licenses/by/4.0/)。

DLUT Online 服务端通过 [Open-Meteo Forecast API](https://open-meteo.com/en/docs)获取并缓存云量、天气代码、风速和风向，向客户端提供天气数据。客户端对数据进行转换，用于程序化天空、云层、降水、光照及雾效。

依据 CC BY 4.0，相关使用应保留适当署名、许可链接及修改说明。API 访问另受 Open-Meteo 的[服务条款](https://open-meteo.com/en/terms)和[订阅条件](https://open-meteo.com/en/pricing)约束；免费接口限非商业用途，商业部署应取得相应服务订阅。数据许可与 API 服务条件分别适用。

署名及修改声明：

> Weather data by Open-Meteo, licensed under CC BY 4.0. DLUT Online transforms the data into procedural weather visualizations.

服务端对数据的转发及客户端对数据的可视化使用均适用本条。

### 3.2 NOAA 太阳位置计算资料

太阳位置计算参考美国国家海洋和大气管理局（NOAA）发布的 [Solar Calculation Details](https://gml.noaa.gov/grad/solcalc/calcdetails.html)，涉及太阳赤纬、时间方程等近似计算方法。该署名用于标明计算方法的来源。

### 3.3 水面着色技术资料

水面着色实现参考 Godot 官方 [Spatial shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html) 与 [Environment and post-processing](https://docs.godotengine.org/en/stable/tutorials/3d/environment_and_post_processing.html)（读取日期：2026-09-16），用于法线空间、物理材质参数和屏幕空间反射兼容性核对。文档适用 [CC BY 3.0](https://docs.godotengine.org/en/stable/about/complying_with_licenses.html)。波纹法线由项目内 FastNoiseLite 参数程序化生成，没有引入外部水面图片；沿用已有官方水体轮廓，不新增水文测绘数据。

### 3.4 Android 图标与资源表技术资料

Android 图标布局参考 [Android 自适应图标文档](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive)与 [Godot Android 导出文档](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html)。非 Gradle 导出资源包名兼容处理参考 [Godot 导出实现](https://github.com/godotengine/godot/blob/4.7-stable/platform/android/export/export_plugin.cpp)和 [AOSP ResourceTypes.h](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/main/libs/androidfw/include/androidfw/ResourceTypes.h) 中的资源表格式，读取日期为 2026-09-16。相关上游代码分别适用 MIT 和 Apache-2.0，文档许可见各来源页；本项目工具独立实现固定字段读写，未引入额外运行库或外部图标素材。

## 四、字体

| 字体 | 提供者与来源 | 使用形式 | 许可文本 |
|---|---|---|---|
| Noto Sans SC | [Noto Sans SC 字体项目](https://github.com/google/fonts/tree/main/ofl/notosanssc)；版权声明见随附许可 | 桌面客户端使用 400 字重子集，内部名称为 Campus Sans | [SIL Open Font License 1.1](apps/game/assets/fonts/OFL.txt) |
| Ma Shan Zheng | [The Ma Shan Zheng Project Authors](https://github.com/google/fonts/tree/main/ofl/mashanzheng) | 网站标题使用本地字体子集 | [SIL Open Font License 1.1](apps/web/public/licenses/ma-shan-zheng-OFL.txt) |

字体及其修改版本的使用和分发受 SIL Open Font License 1.1 约束，包括保留版权声明及许可文本、遵守保留字体名称限制，以及不得将字体软件单独出售等条件。具体权利与限制以各字体随附的许可全文为准。

## 五、软件许可

各软件的著作权归其作者及其他合法权利人所有。下列软件及其组成部分分别适用相应许可；第三方组件的版权声明、分发条件与免责条款继续有效。

| 软件 | 用途 | 上游许可入口 |
|---|---|---|
| Godot Engine | 桌面客户端与游戏服 | [MIT 及内置第三方许可](https://godotengine.org/license/) |
| PocketBase | Go HTTP、账号与持久化 | [MIT](https://github.com/pocketbase/pocketbase/blob/master/LICENSE.md) |
| Go | API 编译与标准库 | [BSD 风格许可](https://go.dev/LICENSE) |
| Vue、Naive UI | 网站界面 | [Vue MIT](https://github.com/vuejs/core/blob/main/LICENSE)、[Naive UI MIT](https://github.com/tusen-ai/naive-ui/blob/main/LICENSE) |
| Vite、TypeScript、vue-tsc | 网站构建与类型检查 | [Vite MIT](https://github.com/vitejs/vite/blob/main/LICENSE)、[TypeScript Apache-2.0](https://github.com/microsoft/TypeScript/blob/main/LICENSE.txt)、[Vue Language Tools MIT](https://github.com/vuejs/language-tools/blob/master/LICENSE) |
| FontTools | 离线字体子集工具 | [MIT](https://github.com/fonttools/fonttools/blob/main/LICENSE) |

依赖版本载于 [Go 模块清单](apps/api/go.mod)、[Go 校验清单](apps/api/go.sum)及[前端锁文件](apps/web/pnpm-lock.yaml)。传递依赖适用各自许可，本表不替代相应发行版附带的完整第三方版权及许可文本。

## 六、名称与商标

本声明所列机构名称、产品名称及商标归各自权利人所有，用于识别资料、服务或软件来源。除另有明确授权文件外，相关列示不表示权利人对 DLUT Online 的赞助、认可、认证或合作关系。
