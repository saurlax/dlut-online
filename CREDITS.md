# 来源、致谢与许可

本文件是 DLUT Online 的外部信息、素材与参考方法总账本，覆盖游戏、Go 服务端和网站。它记录实际用途与授权状态，不授予源站没有提供的许可，也不代替协议全文。资料组织遵循 [references 目录规范](references/README.md)。

“离线参考”指用于分析或建模；“生成资源”指转换后的数据或模型进入产品；“分发”指原素材或其裁剪、转码、子集等副本随网站或客户端提供。三者分别登记。新增来源或用途变化时同步更新本文件与对应资料索引；读取日期不等于拍摄、测量或许可生效日期。

## 校园地图、影像与建筑资料

| 来源 ID | 发布者与来源 | 资料与实际用途 | 许可及署名状态 |
|---|---|---|---|
| `dlut-map` | 大连理工大学 [官方校园地图](http://map.dlut.edu.cn)，[校区接口](http://map.dlut.edu.cn/openmap/mapi/campus/v1)、[轮廓接口](http://map.dlut.edu.cn/openmap/mapi/bd/v1/bound) | 三校区轮廓、名称、中心点、照片和详情；用于模型、地图及天气查询中心。最早归档 2026-09-09，逐对象读取日期在各 JSON | 未归档明确开放数据/影像许可，第三方复制、衍生数据分发授权待确认；不可因接口公开而标作 CC 或公共领域 |
| `dlut-news` | 大连理工大学 [新闻网](https://news.dlut.edu.cn/)；包括 [七舍主体封顶](https://news.dlut.edu.cn/info/1022/81930.htm)、[暑期建设](https://news.dlut.edu.cn/info/1022/82977.htm) 等报道 | 官方建筑描述、七舍 63.6 米高度、建设照片和效果图；离线参考，局部体量参数进入模型。每篇 URL、摘录、日期与哈希见建筑索引 | 未见明确开放许可，照片/文章再分发及衍生使用授权待确认；效果图不当作竣工实照 |
| `dut-panorama` | 大连理工大学图书馆全景站，[入口](https://360.toowtech.com/dalian/DUT/)，图片由 `imgs.toowtech.com` 提供 | 凌水与开发区航拍、建筑和室内可见内容的离线参考；配置、场景 ID、瓦片 URL 与读取日期在影像索引 | 未见允许第三方游戏复制发布影像的明确许可；当前不把原图或播放器打进游戏。配置中的 krpano 说明不构成图像授权 |
| `amap-imagery` | 官方地图配置引用的[高德](https://lbs.amap.com/)影像服务，`webst04.is.autonavi.com/appmaptile` | 开发区卫星影像和建筑候选位置核对，离线参考；2026-09-14 索引保存参数、URL 与哈希 | [高德服务条款](https://lbs.amap.com/pages/terms/)；未归档允许本项目再分发影像的专项授权，不作为游戏贴图 |

来源原记录与精度依据：

- 凌水：[平面轮廓](references/lingshui/mapping/bounds.json)、[建筑依据](references/lingshui/buildings/basis.md)、[照片索引](references/lingshui/buildings/photos/)、[全景索引](references/lingshui/imagery/panoramas/index.json)。
- 开发区：[平面轮廓](references/eda/mapping/bounds.json)、[建筑依据](references/eda/buildings/basis.md)、[七舍资料](references/eda/buildings/seventh-residence/)、[全景索引](references/eda/imagery/panoramas/index.json)、[卫星配准](references/eda/imagery/satellite/eda-lab-satellite.json)。
- 盘锦：[平面轮廓](references/panjin/mapping/bounds.json)、[建筑依据](references/panjin/buildings/basis.md)、[照片索引](references/panjin/buildings/photos/)。

官方底图和归档配置中的其他第三方服务地址只作为原始响应保留，不代表本项目接入、获得 SDK 许可或使用了其中所有资源。照片比例、估计楼高、未标定全景和程序生成材质不能称为实测成果。

## 网站实际分发的校园素材

以下副本已经存在于网站资源中，不能归入“仅离线参考”。归档记录没有明确开放许可或单独授权凭证，授权状态均为**待确认**。

| 来源 ID | 产品文件 | 原始来源、处理与日期 |
|---|---|---|
| `dlut-map-web-photos` | [main-building.jpg](apps/web/src/assets/main-building.jpg) | 主楼 Feature 77386，官方照片 result[1]；原图 [77386-1.jpg](references/lingshui/buildings/photos/77386-1.jpg)，URL/图片 ID 见 [77386.json](references/lingshui/buildings/photos/77386.json) |
| `dlut-map-web-photos` | [library.jpg](apps/web/src/assets/library.jpg) | 令希图书馆 Feature 77357，result[7]；原图 [77357-7.jpg](references/lingshui/buildings/photos/77357-7.jpg)，URL/图片 ID 见 [77357.json](references/lingshui/buildings/photos/77357.json) |
| `dlut-map-web-photos` | [campus-garden.jpg](apps/web/src/assets/campus-garden.jpg) | 主楼旁绿荫，Feature 77386，result[4]；原图 [77386-4.jpg](references/lingshui/buildings/photos/77386-4.jpg)。三图原读取 2026-09-09，网站来源复核 2026-09-10 |
| `dlut-campus-film` | [campus-film.mp4](apps/web/src/assets/campus-film.mp4)、[封面](apps/web/src/assets/campus-film-poster.jpg) | [大工英文官网](https://en.dlut.edu.cn/)发布的 [ssdg.mp4](https://en.dlut.edu.cn/video/ssdg.mp4)，首页对象 78290；2026-09-10 读取。截取 22.0–23.2 秒及 26.0–29.2 秒，按顺序拼接、2/3 速度、去音轨，转 H.264，封面取首帧 |

这些是校园实景宣传素材，不是游戏截图，也不进入 Godot 客户端。片段处理不改变原素材版权归属。

## 服务端 Weather API 与太阳位置

### `open-meteo`：天气数据和 API 服务

- 提供者：[Open-Meteo](https://open-meteo.com/)，[Forecast API 文档](https://open-meteo.com/en/docs)。服务端调用 `https://api.open-meteo.com/v1/forecast`；配置服务密钥时使用 `https://customer-api.open-meteo.com/v1/forecast`。
- 实际用途：[apps/api/weather.go](apps/api/weather.go) 查询并缓存三校区云量、WMO 天气代码、风速和风向，经项目 API 提供给客户端；Godot 将它们转换为程序化天空、云、降水、光照和雾效。源数据是天气模型结果，不是校内传感器实测。
- 数据许可：[Creative Commons Attribution 4.0 International（CC BY 4.0）](https://creativecommons.org/licenses/by/4.0/)。使用时署名 Open-Meteo、链接许可，并说明可视化转换；不把数据许可与接口套餐混为一谈。
- API 服务条件：[定价与用途范围](https://open-meteo.com/en/pricing)、[服务条款](https://open-meteo.com/en/terms)。免费接口面向非商业用途；商业部署须使用相应订阅。项目支持服务端 `DO_WEATHER_API_KEY`，配置密钥本身不代表已取得订阅或授权。
- 归档核实日期：2026-09-11。查询中心、参数和精度说明见 [共享天气资料](references/shared/weather.md)。套餐与额度可能变化，部署时以服务方当前条款为准。
- 桌面随包署名：[WEATHER-CREDITS.txt](apps/game/WEATHER-CREDITS.txt)。本总账本和该文件共同维护；更换供应商、增加字段或改变用途时同时更新。服务端经项目 API 转发数据仍属于本来源的使用。

建议署名：Weather data by Open-Meteo, licensed under CC BY 4.0. DLUT Online transforms the data into procedural weather visualizations.

### `noaa-solar`：太阳位置计算参考

[NOAA Solar Calculation Details](https://gml.noaa.gov/grad/solcalc/calcdetails.html) 是太阳赤纬、时间方程等近似计算的方法参考，2026-09-11 归档说明。客户端实现不调用 NOAA 天气服务，也不复制 NOAA 标识。当前来源记录未单独归档该页面的许可条款，不将它登记为 CC BY；此项记录算法参考，不宣称 NOAA 背书。计算与坐标精度见 [共享天气资料](references/shared/weather.md)。

## 字体

| 来源 ID | 字体与用途 | 来源与协议 |
|---|---|---|
| `noto-sans-sc` | Godot 的 [CampusSans.ttf](apps/game/assets/fonts/CampusSans.ttf)，Noto Sans SC 的 400 字重子集，修改内部名称为 Campus Sans | [Noto Sans SC](https://github.com/google/fonts/tree/main/ofl/notosanssc)，SIL Open Font License 1.1；随字体保留 [OFL 全文](apps/game/assets/fonts/OFL.txt)。生成工具为 [subset_font.py](apps/game/tools/subset_font.py)，现有记录未保存原始 TTF 的精确版本/下载日期，待补录 |
| `ma-shan-zheng` | 网站标题的 [字体子集](apps/web/src/assets/fonts/ma-shan-zheng-title.ttf) | [Ma Shan Zheng](https://github.com/google/fonts/tree/main/ofl/mashanzheng)，2026-09-10 从 Google Fonts 获取；SIL OFL 1.1，随网站保留 [OFL 全文](apps/web/public/licenses/ma-shan-zheng-OFL.txt) |

## 视觉与文字参考

2026-09-10 的网站设计参考包含 [燕云十六声](https://www.yysls.cn/)、[FINAL FANTASY XIV](https://freetrial.finalfantasyxiv.com/)、[Guild Wars 2](https://www.guildwars2.com/en/)、[Black Desert](https://www.naeu.playblackdesert.com/en-US/Main/Index) 的页面结构，以及[大工官网样式](https://www.dlut.edu.cn/css/style20230317.css)的品牌蓝和植物主题。此项是设计参考，没有把这些商业游戏的美术、代码或标识作为授权素材。

网站玉兰、竹影及曲线 SVG 是项目绘制的装饰；Godot 自然材质、树木网格与既有示意分布由项目程序生成，不冒充第三方测绘数据。网站健康游戏忠告参考 [洛克王国：世界官网](https://rocom.qq.com/)公开文本，未归档该文本的专项再分发许可，不视为腾讯背书。具体设计依据见 [网站设计规范](openspec/changes/vue-web-dashboard/design.md)。

## 软件依赖的许可入口

本节索引主要软件，不把源码依赖当作校园数据来源。传递依赖以 [Go 模块清单](apps/api/go.mod)、[校验清单](apps/api/go.sum) 和 [前端锁文件](apps/web/pnpm-lock.yaml)确定精确版本；各依赖及构建工具的许可全文仍以对应发行版为准。本文件不代替完整的二进制第三方许可清单。

| 软件 | 用途 | 上游许可入口 |
|---|---|---|
| Godot Engine | 桌面客户端与游戏服 | [MIT 及内置第三方许可](https://godotengine.org/license/) |
| PocketBase | Go HTTP、账号与持久化 | [MIT](https://github.com/pocketbase/pocketbase/blob/master/LICENSE.md) |
| Go | API 编译与标准库 | [BSD 风格许可](https://go.dev/LICENSE) |
| Vue、Naive UI | 网站界面 | [Vue MIT](https://github.com/vuejs/core/blob/main/LICENSE)、[Naive UI MIT](https://github.com/tusen-ai/naive-ui/blob/main/LICENSE) |
| Vite、TypeScript、vue-tsc | 网站构建与类型检查 | [Vite MIT](https://github.com/vitejs/vite/blob/main/LICENSE)、[TypeScript Apache-2.0](https://github.com/microsoft/TypeScript/blob/main/LICENSE.txt)、[Vue Language Tools MIT](https://github.com/vuejs/language-tools/blob/master/LICENSE) |
| FontTools | 离线字体子集工具 | [MIT](https://github.com/fonttools/fonttools/blob/main/LICENSE) |

## 已调研但尚未纳入产品的数据

以下仅为 2026-09-15 的来源候选；没有因写入本表而下载完整数据、生成地形或完成许可核验。

| 来源 ID | 候选与许可入口 | 状态 |
|---|---|---|
| `copernicus-dem` | [Copernicus GLO-30](https://dataspace.copernicus.eu/explore-data/data-collections/copernicus-contributing-missions/collections-description/COP-DEM)，专用免费许可及规定署名 | 已确认凌水 N38 E121、开发区 N39 E121 公开文件存在，未用于模型；30 米级 DSM 不等于裸地 |
| `osm` | [OpenStreetMap](https://www.openstreetmap.org/copyright)，ODbL 1.0，须署名 © OpenStreetMap contributors；数据库衍生与分发义务依条款判断 | 查询到两校区及周边的台阶/坡向标注，尚未归档或用于生成游戏资源；不能提供完整连续高程 |
| `opentopomap` | [OpenTopoMap](https://opentopomap.org/about)，其地图绘制注明 CC BY-SA，底层 OSM/SRTM 来源另计 | 只核实了服务说明，未使用地图瓦片 |
| `mapzen-terrain` | [Mapzen Terrain Tiles](https://registry.opendata.aws/terrain-tiles/)，各来源分别见其 attribution 清单 | 只核实公开目录，两个校区具体底层数据与许可待核实 |
| `fabdem` | [FABDEM](https://data.bris.ac.uk/data/dataset/s5hqmjcdj8yo2ibzi9b4ew3sn) | 本次来源页访问失败，版本、瓦片与用途授权待核实 |
| `aw3d` | [AW3D Standard](https://www.aw3d.jp/en/products/standard/)，商业产品条款 | 仅查阅产品说明，未购买、未获得具体校区数据 |

## 更新约定

每次引入信息或素材都补充稳定来源 ID、原始 URL、读取日期、对象及覆盖范围、实际用途、处理方式、许可条款和授权状态。数据开始进入模型、网站或安装包时，将候选移入对应实际使用章节，并同步随包署名。缺失许可、版本或日期明确标记待核实，不凭推测补齐；旧来源替换后仍保留必要历史溯源。
