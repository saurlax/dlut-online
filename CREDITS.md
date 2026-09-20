# 第三方版权与许可声明

Third-Party Notices

## 三校区周边背景资料

2026年9月18日扩展三校区 Copernicus GLO-30 原生裁剪及开发区 OpenStreetMap 档案，沿用下文 Copernicus WorldDEM-30 许可与 OSM ODbL 1.0 署名。来源URL、源瓦片摘要、裁剪窗口、OSM版本、原始档案与精度限制见各校区 `terrain/surroundings-source.json` 和 [背景地形依据](references/shared/terrain/basis.md)。背景派生几何仍采用相同来源，不把OSM称为高程来源。

开发区山体颜色和植被层次参考 [学校KFQ00全景](https://360.toowtech.com/dalian/DUT/)，新增背向面离线参考的URL、用途与摘要见 [记录](references/eda/terrain/daheishan-panorama.json)。周边住宅另用已归档前向面及49张 Esri World Imagery 瓦片核对楼群位置、近似高度和浅色体量，见 [楼群记录](references/eda/buildings/surroundings-review.json)。署名及许可沿用下文学校全景、Esri 说明；照片与瓦片仅离线参考，未进入客户端，无新增再分发授权。颜色、树冠和分组高度为近似表现，不代表实测复刻。

## 一、适用范围

本声明列明 DLUT Online 桌面客户端、服务端及网站所使用的第三方资料、素材、数据服务和软件的来源、权利归属及适用许可。

第三方内容的著作权、商标权及其他合法权利归各自权利人所有。相关内容的使用、修改及分发受其适用许可、服务条款及法律规定约束。本声明不构成对第三方权利的转让或额外授权；本声明与适用许可原文不一致的，以许可原文为准。

## 二、校园地图、建筑资料与影像

### 2.1 资料来源

| 发布者或服务提供者 | 来源 | 使用范围 |
|---|---|---|
| 大连理工大学 | [官方校园地图](http://map.dlut.edu.cn)、[校区目录](http://map.dlut.edu.cn/openmap/mapi/campus/v1)、[建筑与场地轮廓](http://map.dlut.edu.cn/openmap/mapi/bd/v1/bound) | 三校区名称、位置、平面轮廓、建筑详情及照片，用于校园模型、地图和天气查询位置 |
| 大连理工大学 | [新闻网](https://news.dlut.edu.cn/)，包括[学生公寓主体封顶报道](https://news.dlut.edu.cn/info/1022/81930.htm)及[校园建设报道](https://news.dlut.edu.cn/info/1022/82977.htm) | 建筑描述、公布尺寸、建设照片与效果图，用于建筑形态和立面的参考 |
| 大连理工大学基建处 | [博士生公寓8号楼竣工报道](https://jjc.dlut.edu.cn/info/1018/3095.htm)，2023-09-08发布，2026-09-17读取 | 竣工高度、层数与现场照片的离线核对；原图和摘要见 [来源记录](references/lingshui/buildings/photos/2034766-completion.json)，不进入客户端；未发现明确第三方再分发许可 |
| 大连理工大学图书馆全景站及其影像提供者 | [校园全景](https://360.toowtech.com/dalian/DUT/)，影像服务域名 `imgs.toowtech.com` | 航拍、建筑内外景及场地布局的视觉参考 |
| 大连理工大学基建处、文体场馆中心、校园管理与修缮中心及资产与实验室管理处 | [西山公寓封顶报道](https://jjc.dlut.edu.cn/info/1018/3053.htm)、[建设简报](https://jjc.dlut.edu.cn/info/1085/3093.htm)、[西山体育中心](https://tycgzx.dlut.edu.cn/info/1020/3884.htm)、[2025年宿舍及通道修缮](https://xszx.dlut.edu.cn/info/1007/6901.htm)、[招租公告](https://zcglc.dlut.edu.cn/info/1061/3388.htm)，2026-09-17读取 | 双塔/裙房、局部场馆与通道变化的离线核对；[来源记录](references/lingshui/buildings/xishan-30-31/source.json)区分设计效果图与实景，原图不进入客户端；未发现明确第三方再分发许可 |
| 大连理工大学工程训练中心 | [中心平面图](https://xlzx.dlut.edu.cn/zxgk/zxpmt.htm)，2026-09-17读取 | 航拍、正门、位置图与楼层导览的离线核对；[来源记录](references/lingshui/buildings/training-center/source.json)区分现址楼群与旧77420车间，图片不进入客户端；未发现明确第三方再分发许可 |
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

盘锦C01道路与建筑身份核对参考[2024年校史文化展厅启用报道](https://news.dlut.edu.cn/info/1011/106214.htm)及[校区物业服务范围](https://pjxqzwb.dlut.edu.cn/fwzn/xqfw/xqwyfw.htm)，读取日期2026-09-17。仅用于区分旧地图名称与后续用途，不能据此迁移建筑或推导平面尺寸；照片80090及lm30瓦片来源摘要见共享footprint-review.json的77977记录，原图未打入客户端，适用第2.1条授权说明。

室外道路细节还参考 [令希图书馆南侧阅读空间报道](https://news.dlut.edu.cn/info/1292/117214.htm)、[开发区校园风光](https://news.dlut.edu.cn/info/1292/147345.htm)和[教学区南侧阅读空间报道](https://news.dlut.edu.cn/info/1022/143385.htm)。读取日期为 2026-09-16，照片对象、原始 URL、哈希与用途见 [道路细节依据](references/shared/mapping/roads.md)及对应照片索引。仅离线参考铺装与台阶，原图不打入游戏；开放许可仍未确认，适用第 2.1 条授权说明。程序生成纹理不直接复用照片像素。

### 2.4 Copernicus 高程数据

**数据产品：** [Copernicus DEM GLO-30 Public](https://registry.opendata.aws/copernicus-dem/)，由 Sinergise 在 AWS 发布的 2021 版 Cloud Optimized GeoTIFF。

**适用许可：** [Copernicus WorldDEM-30 Licence](https://dataspace.copernicus.eu/sites/default/files/media/files/2025-06/copernicus_contributing_mission_data_access_v2_cop_dem_licenses.pdf)（文内同名许可）。该许可授予全球范围、无期限、免费的非独占复制、分发、向公众传播、改编、修改及与其他数据组合使用的权利，使用者及后续分发者须遵守其署名、责任声明及其他条款。

DLUT Online 对 N38E121、N39E121、N40E122 瓦片进行像素窗口裁剪及高度网格格式转换，作为三校区的地形基础资料（盘锦瓦片于2026-09-17取得），并经过过滤、插值、共同WGS84局部坐标转换及局部地坪调整生成客户端和游戏服使用的地形。原始数据的著作权归 DLR e.V. 及 Airbus Defence and Space GmbH 等相应权利人所有。

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

DLUT Online 的三校区基础平面数据直接使用 OSM WGS84 来源，并按照片、官网俯视图、OSM 的证据顺序核对局部形状。早期以同名建筑估计地形水平平移的 `references/<campus_id>/terrain/alignment.json` 仅保留作历史记录；当前道路及地形生成器禁止回退至该平移。该等 OSM 摘录与衍生数据库按 ODbL 1.0 提供，后续使用者须遵守其署名、共享及数据库分发条件。

三校区建筑轮廓的离线复核另使用 [样本登记](references/shared/mapping/footprint-review.json) 中的 OSM way，并与官网 `lm30` 俯视瓦片、原始 `bound` 对比。[复核工具及边界](references/shared/mapping/map-coordinate-handling.json)保存源 URL、读取时间、摘要、way/node 版本、初始定位与未验证草稿。下载资料和底图仅置于 `.local/`，不随游戏分发；官网底图仍适用第 2.1 条授权说明。OSM 摘录及其衍生数据库保留 ODbL 署名和许可信息。官网 bound 存在斜视外轮廓，既有质心平移不能再作为已验证的建筑基底配准。
三个校区的道路中心线和校园范围使用 2026-09-16 读取的 OSM 数据，原始查询、way/node ID 与版本归档于 `references/<campus_id>/mapping/osm-roads.json`；盘锦旧配准控制点作为历史记录保留于 `references/panjin/mapping/road-alignment.json`，不用于当前坐标转换。离线裁剪、坐标转换及估计宽度生成的 `apps/game/assets/campuses/<campus_id>/data/osm_roads.json` 同样按 ODbL 1.0 提供，随仓库公开分发。道路模型及游戏地图含 © OpenStreetMap contributors 数据，转换方式及精度限制见 [道路数据依据](references/shared/mapping/roads.md)。

三校区统一平面基准迁移使用 2026-09-16 已下载 OSM 原始数据，压缩归档及校验摘要见 `references/<campus_id>/mapping/osm-world.osm.gz` 与 `osm-world-source.json`。这些原始数据库摘录保留节点、道路、建筑、地表和关系对象的 ID、版本及时间戳，按 ODbL 1.0 提供。统一 WGS84 局部原点见 `references/shared/mapping/osm-world-frame.json`；归档范围包含校外要素，不能将归档数量视为校园建筑总数。地形高程继续单独标注 Copernicus 来源，不声称由 OSM 提供连续高程。

离线迁移工具 `apps/game/tools/prepare_osm_world.py` 按上述归档提取地表面及道路、水道等线要素，保留多环孔洞、边界相交状态和身份冲突；`prepare_osm_terrain.py` 在同一地理坐标下采样已归档的三校区 DSM，不叠加旧官网平移。离线分析候选输出位于 `.local/osm-world/`，其存在不证明运行场景已完成迁移。当前运行道路清单与三校区 `terrain.json` 由对应生成器按同一基准产生，仍有待核对的旧建筑轮廓及局部冲突，不能声称全要素已对齐。盘锦已补入有来源的粗分辨率DSM，仍不能称为OSM高程或实测裸地。

`apps/game/tools/prepare_osm_identities.py` 为既有建筑生成 OSM 身份清单，名称别名和显式消歧依据维护于 `references/<campus_id>/mapping/osm-identity-overrides.json`。匹配搜索完整归档，避免大学边界遗漏北山宿舍；完整归档中无关校外建筑不会因此自动加入模型。候选保留未匹配 ID、原始多边形、OSM 版本及输入摘要；名称或位置对应不证明轮廓精度，立面锚点及局部形状仍须复核。

信息楼局部凹口的图面修正登记于 `references/eda/mapping/footprint-refinements.json`，使用官网 `lm30` 瓦片及既有全景、外观照片辅助检查，保留 OSM 外角锚点和原轮廓。`prepare_osm_world.py --refine` 通过 `refine_osm_footprints.py` 重放局部修正；这是带来源记录的近似形状，不是经过测绘验证的正射建筑基底。官网图像只作为离线参考，来源权限仍适用第 2.1 条说明。

综合楼南侧广场使用 [地表描绘记录](references/eda/mapping/ground-surfaces.json) 中的官网 `lm30` 瓦片，分别描绘铺装外缘与中央绿岛。`prepare_map_surfaces.py` 以归档 OSM 环线定位、已注册综合楼边长约束局部比例，保留源 ID、版本与瓦片摘要；该地表是图面支持的近似，非测绘地籍面。原始 OSM 道路线不改写，仅在生成模型时遮掉铺装范围内的重复沥青并保留绿岛。

南广场时效核对另参考校方[2026年成交公告](http://cgbmis.dlut.edu.cn/sfw_cms/e?page=cms.detail&cid=100645&aid=51465)、[结果公示及工程清单](http://cgbmis.dlut.edu.cn/sfw_cms/e?page=cms.detail&cid=18816&aid=51586)和[暑期改造报道](https://kfqxqzhb.dlut.edu.cn/info/1081/1912.htm)，2026-09-17读取。来源页、附件哈希、875平方米沥青与170平方米植草砖的采购范围及适用限制见[开发区地图依据](references/eda/mapping/basis.md)。仅离线核对，不把采购结果当作完工证明，不据面积总数反推边界；未发现第三方再分发许可，PDF不进入客户端或发行资源。

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

Android 图标布局参考 [Android 自适应图标文档](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive)与 [Godot Android 导出文档](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html)。Android 打包采用 [Godot 官方 Gradle 构建](https://docs.godotengine.org/en/4.7/tutorials/export/android_gradle_build.html)，使用对应版本的官方模板与 Gradle Wrapper，不自行改写 APK 资源表。读取日期为 2026-09-16。Godot 代码适用 MIT，Gradle 适用 [Apache-2.0](https://github.com/gradle/gradle/blob/master/LICENSE)，文档许可见各来源页；未引入外部图标素材。

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

## 校园植被参考与树皮材质

- 大连理工大学[校园风光](https://www.dlut.edu.cn/xxgk/xyfg.htm)及其[凌水湖图集 92404](https://news.dlut.edu.cn/info/1020/92404.htm)、[图书馆阅读空间 117214](https://news.dlut.edu.cn/info/1292/117214.htm)、[景观建设 143385](https://news.dlut.edu.cn/info/1022/143385.htm)、[开发区双湖改造 147345](https://news.dlut.edu.cn/info/1292/147345.htm)、[盘锦春季绿化 3901](https://pjxqzwb.dlut.edu.cn/info/1071/3901.htm)，用于植被形态和可见区域参考。读取日期 2026-09-16。具体对象、原图 URL、压缩方法与哈希见各校区 references/vegetation 档案（实际路径为 references/<campus_id>/vegetation）。照片授权适用第 2.1 条，只作离线参考，不打入客户端。
- 树皮：[Bark Brown 02](https://polyhaven.com/a/bark_brown_02)，作者 Rob Tuytel，由 Poly Haven 发布，采用 [CC0 1.0](https://polyhaven.com/license)。客户端使用 1K JPEG 漫反射与 OpenGL 法线贴图，三校区共享；只是通用树皮表面，不是对应校园树种扫描。[下载、SHA-256 与许可记录](references/shared/vegetation/textures.json)。
- 折面叶片、枝干结构、草簇、花瓣、草坪细节与近远级别由本项目原生生成工具制作；不包含新闻照片像素，不将程序化种植数量写成实测数据。植物冠形、尺寸及材质效果属于参考支持的近似表达。

开发区体育场地的图像配准及照片复核记录见 `references/eda/mapping/sports-refinements.json`，包含官网 lm30 瓦片与 KFQ00 后向全景高清11行16—18列的来源、读取时间和校验值。按照片、俯视图、OSM 的证据优先级处理；图像边界保持暂定，不是独立实测。原始照片仅作为离线参考。

## 凌水校园正射影像参考

辽宁省生态环境厅公开的[三维X射线CT系统应用项目环境影响报告表](https://sthj.ln.gov.cn/sthj/zfxxgk/fdzdgknr/xzxkxxgk/czzj/hbzxzjxm/2024092515455333124/2024092515450714943.pdf)（2024年5月报批稿），PDF第22页、印刷页18的附图1-3包含校园管理与修缮中心署名的校园正射影像，图示拍摄日期2023年5月。2026年9月17日读取，仅用于离线布局核对，尚未用于几何生成；附件未提供可核实坐标系及精度报告。来源、摘要、覆盖与使用边界见 [影像记录](references/lingshui/imagery/orthophoto-2023.json)。未发现明确的第三方复制或再分发许可，原PDF及图片不纳入客户端或发行资源。

海山楼分区核对参考校园管理与修缮中心[创新园大厦（海山楼）幕墙维修改造项目竣工](https://xszx.dlut.edu.cn/info/1007/2661.htm)，2024-04-28发布、2026-09-17读取。仅采用官方A/B区高度说明作为分体核对证据，未据此推断墙脚或架空净高；对应照片、OSM版本和俯视图限制见[建筑依据](references/lingshui/buildings/basis.md)及共享footprint-review.json的77414记录。未发现明确第三方再分发许可，网页图片未打入客户端。

## Esri World Imagery 补充参考

2026年9月17日读取[World Imagery](https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer)与对应元数据，仅离线核对凌水西校区、西山8舍和开发区综合楼的地面布局。署名为 Esri、Vantor、Earthstar Geographics 和 GIS User Community。中心点元数据分别标明2025-09-20（凌水）与2025-09-07（开发区），不代表当前现状；分辨率、位置精度、查询范围、瓦片摘要与用途见[来源记录](references/shared/mapping/world-imagery-review.json)。原瓦片不提交、不进入客户端，使用条款见[服务说明](https://goto.arcgisonline.com/maps/World_Imagery)，未获得再分发授权。

## MapTiler 与天地图补充数据核对

2026年9月17日使用用户提供的本地凭据读取 [MapTiler Tiles API](https://docs.maptiler.com/cloud/api/tiles/) 的 Satellite v2、Planet v3/v4 和 Terrain RGB v2 局部样本，仅用于离线对照。返回署名为 MapTiler 与 OpenStreetMap contributors，见 [MapTiler版权信息](https://www.maptiler.com/copyright/)。瓦片地址中的凭据已脱敏；来源摘要、坐标转换、样本范围、与OSM关系及高程限制见[数据核对记录](references/shared/mapping/provider-data-review.json)。原始瓦片、解码结果与临时图像不纳入客户端或发行资源，不用于自动提取或平均建筑轮廓；已核对地面范围的应用另见下文。

[天地图地图服务文档](http://lbs.tianditu.gov.cn/server/MapService.html)与WMTS能力声明用于确认图层及参数。更换为服务器类型凭据后，已取得综合楼及博留餐厅周边28张影像瓦片和开发区14条地名点结果，供离线位置与身份核对；署名国家基础地理信息中心、天地图。影像采集日期及绝对精度未确认，地名点不作为建筑边界；三维地形尚未取到，不将接口列表记作已采集数据。凭据保留于被Git忽略的本地配置，不进入本记录或客户端。

综合楼南广场采用Esri World Imagery中2025-09-07影像的可见地面历史轮廓，并与北侧地面绿岛共同配准到OSM；北环岛外侧沥青与中央绿岛同样按该影像可见地面补齐，阴影下的院内范围仍保留官网俯视图暂定描绘。像素控制点、瓦片来源及摘要、屋檐遮挡与2026改造时效限制记录于[开发区地表依据](references/eda/mapping/ground-surfaces.json)和[影像审查](references/shared/mapping/world-imagery-review.json)。运行包仅包含生成几何，不包含原始影像；不将双点配准精度等同测绘精度。

学生文化中心外部空间另参考设计单位天津大学建筑设计规划研究总院的[项目页](https://www.aatu.com.cn/project/post/301/)，2026-09-17读取并离线归档4张外观原图，来源和SHA-256见[照片记录](references/lingshui/buildings/photos/83718-design.json)。版权归来源权利人，未发现再分发许可，原图不进入客户端；未从照片推断净高、完整平面或内部通行结构。

锦屏山植被改用OSM林地way/232560269 v2，结合学校双湖航拍和Esri影像核对范围。完整来源、版本、瓦片摘要及林木近似分布限制见[独立配准记录](references/eda/vegetation/jinping-registration.json)。沿用OSM和Esri既有来源与许可说明，原始影像不进入客户端，不将程序化树木视作逐树调查。

博留公寓6号楼另核对25张Esri、12张天地图和12张MapTiler影像瓦片及学校相册13张照片，登记屋顶与墙脚错位疑点。仅将一张楼群航拍作为离线上下文归档，见[照片用途记录](references/lingshui/buildings/photos/77572-context.json)和[轮廓审查](references/shared/mapping/footprint-review.json)；相册包含邻楼，不能全部用于6号楼。原始影像和照片不进入客户端，未据此采用未经控制点验证的平移。

图书馆北侧草坪采用OSM way/1076344098 v4，并以[学校KFQ00全景](https://360.toowtech.com/dalian/DUT/)和30块Esri影像核对，见[配准记录](references/eda/vegetation/library-lawn-registration.json)。全景原图公开URL内容摘要与离线档案一致；仍按既有学校全景、OSM与Esri来源和许可边界，仅离线使用原图。草叶数量与高度为视觉参数，不恢复照片不支持的内部均匀乔木。

盘锦北侧停车区域另核对20张天地图和20张MapTiler影像瓦片。运行地面仅恢复独立OSM停车区域1263777289，影像用于确认其地面用途与大致范围；未据此描绘内部树带或新增车辆。原始瓦片仍仅离线留存；采集日期未知，两家影像可能共享底层来源，不视为独立测量。脱敏地址、摘要、已采用范围及其余停车场缺口见[盘锦地面记录](references/panjin/mapping/ground-surfaces.json)。

开发区一舍弯段另核对25张Esri、9张天地图和9张MapTiler瓦片。争议转角的Esri z19元数据为2019-09-18，道路西北节点有不同日期覆盖重叠，不能使用综合楼的2025日期代表全校区；其余两家影像日期未确认。本次仅用于识别时效与地面控制缺口，不修改运行道路。来源摘要与逐点查询见[一舍影像审查](references/shared/mapping/world-imagery-review.json)，原图不进入运行包。

建筑艺术馆道路核对复用已归档的6张官网原图，并读取9张天地图影像瓦片；来源、摘要、拍摄日期缺口与用途见[轮廓审查](references/shared/mapping/footprint-review.json)。照片及瓦片仅用于离线核对，本轮未改动运行几何，也未新增运行照片。


## 图形设置技术参考

2026-09-20 为校医院既有面砖局部新增项目程序生成的法向及粗糙度数据图，生成器为 `apps/game/tools/build_ceramic_pbr.gd`；照片来源、适用范围、参数与哈希沿用并补充于[建筑材质来源](references/shared/buildings/textures.json)。石铺地微表面同样为项目程序化近似。均不是实景扫描，不增加照片授权范围，不将原有生成颜色图或参考照片标记为 CC0。通过 Context7 核对 Godot 的 [SurfaceTool 切线生成](https://docs.godotengine.org/en/4.7/classes/class_surfacetool.html)及[标准材质法向约定](https://docs.godotengine.org/en/4.7/tutorials/3d/standard_material_3d.html)，文档归属沿用下述许可说明。

2026-09-18 通过 Context7 与 Godot 4.7 官方文档核对图形选项及兼容性：[渲染器比较](https://docs.godotengine.org/en/4.7/tutorials/rendering/renderers.html)、[Viewport](https://docs.godotengine.org/en/4.7/classes/class_viewport.html)、[Environment](https://docs.godotengine.org/en/4.7/classes/class_environment.html)、[RenderingDevice](https://docs.godotengine.org/en/4.7/classes/class_renderingdevice.html)、[SDFGI](https://docs.godotengine.org/en/4.7/tutorials/3d/global_illumination/using_sdfgi.html)。用于 MSAA/FXAA/SMAA/TAA、FSR/MetalFX、屏幕空间效果、动态 GI 与设备能力判断；文档按 Godot 的 CC BY 3.0 许可说明归属。设置齿轮为项目自行绘制的 SVG，没有引入第三方图标资源。
