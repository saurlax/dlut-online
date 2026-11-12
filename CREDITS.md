# 素材与数据来源

开发区校区实时天气使用 [Open-Meteo](https://open-meteo.com/) 天气数据，按 [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) 署名。

## 界面交互

设置与关于弹窗使用 [Radix Primitives](https://www.radix-ui.com/primitives/docs/overview/introduction) 的 `@radix-ui/react-dialog` 1.3.1，按 [MIT License](https://github.com/radix-ui/primitives/blob/main/LICENSE) 授权。按钮外观及书籍、禾苗等像素图标由本项目制作，沿用标题标志的大工意象。

按钮与面板的轮廓、高光和阴影层次参考星露谷物语角色创建界面的[游戏截图](https://stardewguide.com/wp-content/uploads/2022/04/Main_Menu.jpg)，图像版权属于 ConcernedApe。仅作离线视觉参考，项目按蓝白配色独立绘制界面，不分发或使用该游戏的 UI 贴图。

## 界面字体

界面使用 [缝合像素字体 / Fusion Pixel Font](https://github.com/TakWolf/fusion-pixel-font)，版本 [2026.10.25](https://github.com/TakWolf/fusion-pixel-font/releases/tag/2026.10.25)，12px 简体中文比例版（`fusion-pixel-12px-proportional-zh_hans.otf.woff2`）。字体版权归 TakWolf 及相应上游作者，按 SIL Open Font License 1.1 授权。本地字体文件仅更名，未修改字形；完整授权及随包上游授权保留在 `apps/web/public/fonts/fusion-pixel/`，随站点静态资源发布。

## OpenStreetMap

凌水主校区与盘锦校区同样使用 © OpenStreetMap contributors 的 ODbL 1.0 数据。原始归档、请求范围、版本、读取时间与摘要分别见 `references/lingshui/mapping/osm-world-source.json` 与 `references/panjin/mapping/osm-world-source.json`，身份配准及照片来源保留在对应 `mapping/`、`buildings/` 与 `references/shared/` 中。学校照片与航拍仅作离线参考，不随客户端分发。两校区的像素建筑和体育设施由本项目旧版已登记体块与立面重建，逐对象模型路径和摘要见各校区 `models/manifest.json`；地面材质复用本项目已有原生像素原片，大地图直接按地理网格绘制。未引入旧照片或旧 PBR 贴图作为游戏纹理。

开发区校区地图来源于 © OpenStreetMap contributors，采用 [Open Database License 1.0](https://opendatacommons.org/licenses/odbl/1-0/)。来源及署名信息见 [OpenStreetMap Copyright](https://www.openstreetmap.org/copyright)。

校园行走画面的署名与许可入口集中于首页“关于”；全屏大地图另保留来源链接。游戏采用 OSMF [署名指南中游戏与模拟](https://osmfoundation.org/wiki/Licence/Attribution_Guidelines#Computer_games_and_simulations)允许的菜单署名位置。

`references/eda/osm.osm.gz` 保存 2026-09-16 下载的原始数据；请求范围、版本与校验值见 `references/eda/osm-source.json`。涌泉湖生成工具使用其中的水面和步道几何，导出的材质网格保留来源对象 ID、版本与署名。数据库及其派生数据遵循 ODbL；像素贴图与数据库分开维护。

全校区地面沿用同一份 OSM 数据，建筑配准记录在 `references/eda/geometry.json` 与 `footprint-refinements.json`。`planting.json` 中的种植点为来源区域内的估计布置，不代表单株实测坐标；没有有效地面区域依据的点位未导入。

## 大连理工大学湖区照片

[大连理工大学新闻网](https://news.dlut.edu.cn/info/1292/147345.htm)的湖区航拍与岸边照片用于核对红步道、白路缘、草岸及景观物件的视觉特征。照片拍摄日期未知；照片作为离线参考，不随生成结果分发。参考用途记录于 `references/eda/yongquan-grid.json`。

## 原生像素绘制

原创人物和物品图标以透明 PNG 存放在 `apps/web/public/sprites/characters/` 和 `apps/web/public/sprites/items/`。人物帧为 16×32，比例与分层参考[星露谷人物精灵说明](https://wiki.stardewvalley.net/Modding%3AFarmer_sprite)，未使用其角色贴图。

校园动物使用 `apps/web/public/sprites/animals/` 中的原创透明 PNG，每帧 20×16。野猪和大狗的像素动作图由 ImageGen 生成后裁切为游戏帧。公开参考资料与采用情况见[校园动物来源](references/campus-animals.md)。参考影像版权归原权利人，仅作离线参考。

[大连理工大学校园地图](http://map.dlut.edu.cn)及既有七舍照片用于建筑颜色、楼层和可见立面参考，原始 URL、对象 ID、读取日期及用途保留在 `references/eda/building-photos.json`。照片版权归原权利人，原图只作离线参考，不随项目分发。独立建筑透明 PNG 由 `tools/campus_objects.py` 在原生像素画布绘制，属于简化外观，不代表完整立面测绘。

`tools/terrain_tiles.py` 直接在 16×16 画布生成原创像素贴图；`tools/draw_yongquan_study.py` 为独立美术构图工具。未使用星露谷物语的游戏贴图；该游戏只作为视觉风格参考。

湖岸的朝向、坡面与水线层次具体参考星露谷 Wiki 的 [ThePond.png](https://stardewvalleywiki.com/File:ThePond.png) 和 [CindersapForest.png](https://stardewvalleywiki.com/File:CindersapForest.png)，图像版权属于 ConcernedApe。参考图仅存于忽略的本地目录，不提交、不作为地图贴图分发；岸坡颜色及像素由 `tools/shore_tiles.py` 独立绘制。

## 标题画面

首页标志与主楼广场背景由 imagegen 生成，经像素网格采样、有限调色板整理后使用。标志的书籍与幼苗意象参考[大连理工大学校徽说明](https://www.dlut.edu.cn/info/1364/35309.htm)，蓝色为游戏美术配色。

背景以学校官网的[主楼广场照片](https://www.dlut.edu.cn/__local/F/15/C0/3CF32C7A03F1F6164F28544D708_61DC62F5_5F904.jpg)、校园地图建筑 77386 的正面照片和[主楼介绍](https://news.dlut.edu.cn/info/1261/83254.htm)为地域参考。照片版权归原权利人，仅离线参考；插画不用于测绘。构图与像素氛围参考星露谷官方[游戏页面](https://store.playstation.com/en-au/product/EP2319-CUSA26625_00-2010147637670638)的标题美术，未使用其贴图或标志。生成提示词、来源与处理参数见 `references/branding/title-screen.json`。

## 全屏大地图

全屏地图使用 [MapLibre GL JS](https://maplibre.org/) 6.16.0，按 BSD 3-Clause 许可使用；许可随静态资源保存在 `world/atlas/MapLibre-LICENSE.txt`。它只负责地图交互和图层渲染，不使用 MapLibre 在线演示底图。

大连及盘锦周边的区域海陆轮廓、城镇范围、道路、河流和地名使用 [Natural Earth](https://www.naturalearthdata.com/) 的 1:10m 数据，按 [Public Domain](https://www.naturalearthdata.com/about/terms-of-use/) 使用。区域高程使用 [Mapzen Terrain Tiles](https://registry.opendata.aws/terrain-tiles/) 的 Terrarium 数据；USGS 的 SRTM/GMTED2010 与 NOAA ETOPO1 等来源署名依上游 [attribution](https://github.com/tilezen/joerd/blob/master/docs/attribution.md) 保留在 `references/city/terrain-attribution.md` 和随客户端提供的 `world/atlas/NOTICE.txt`。

区域范围、源 URL、下载日期和 SHA-256 记录在 `references/city/sources.json`，已裁切地理数据与高程原片位于同目录。像素颜色和纹理由本项目直接绘制，区域概览不作为校园精确轮廓或场景碰撞依据。校园图层由内置 imagegen 按[学校官方校园地图](http://map.dlut.edu.cn/)的二维位置图与斜视建筑图生成，构图与建筑辨识度参考 umasou／莫卡设计工作室的[《大连理工大学手绘四季》](https://www.zcool.com.cn/work/ZMjgyNjc4Mjg%3D.html)；参考图片仅离线使用，未作为原图分发。三张插画由 [Retro Diffusion Pixel Art Fixer Standard](https://github.com/Retro-Diffusion/pixel-art-fixer)（MIT）整理像素网格，量化为每校区最多 48 色并裁切校园范围，并按现有 WGS84 地标近似配准，用于全屏地图本地预览，不是新增建筑测绘或碰撞依据。提示词、来源和输出摘要见 `references/city/campus-art.json`，人工选点及配准误差见 `references/city/campus-registration.json`。此前逐栋建筑与运动场美术及其模型来源继续保留在 `landmarks.json` 和 `building-art.json`，运行时不再作为独立建筑图标叠加。

## 场景材质

草地、屋面、墙面与玻璃材质由 imagegen 生成，经 tools/campus_materials.py 整理为 16×16、每片最多 8 色的原生贴图。建筑沿用登记轮廓和实景配色，程序仅按原材质遮罩拼合贴图；不新增未经核实的建筑结构。风格参考[星露谷物语](https://www.stardewvalley.net/)，未使用其贴图。提示词与处理约定见 references/eda/materials.json。

## 环境动画

水面循环波纹由 tools/generate_environment_animations.py 在原有 16×16 水面瓦片上生成，保持岸线与透明遮罩。树冠风摆复用当前植被图块，以整数像素偏移播放；不引入外部动图素材。

## 树木与灌木

阔叶树、柳树、针叶树及灌木由 imagegen 生成，每类两种变体，参考[星露谷物语](https://www.stardewvalley.net/)的像素美术层次，未使用其游戏素材。经 tools/prepare_vegetation.py 缩到登记的原生画布、量化为最多 16 色和二值透明，并拆成 16×16 游戏图块。形象为物种类别的风格化表达，种植位置仍采用已有来源区域与估计布置；来源、提示词和处理约定见 references/eda/vegetation-art.json。

## HD-2D 场景与建筑

校园渲染使用 [Three.js](https://threejs.org/)，按 [MIT 许可](https://github.com/mrdoob/three.js/blob/dev/LICENSE)使用。像素人物、地面及植被沿用本文已有来源；泛光和景深仅为视觉效果。

15 栋建筑以本项目旧版 3D 分支的登记体块、地理轮廓及分区高度重建简化底模，并将既有模型的窗格、楼层线和基础色烘焙为逐栋 48 色以内的像素 UV 贴图。原始提交、路径、校验值、主体对象与贴图尺寸见 `apps/web/public/campuses/eda/models/manifest.json`。表面颗粒复用本文已登记的墙面像素原片；图书馆和 C 区圆体采用旧版登记的近似椭圆。结构依据仍为已有 OSM 与学校建筑照片记录，不新增室内，不代表完整测绘。照片、旧 PBR 贴图和细节高模未随新建筑发布。

## 室外路灯与公告栏

开发区弯臂路灯、圆环灯与桥头公告栏根据本项目旧版已登记资料重新绘制简化体块。来源提交、原始工具与配置路径、照片引用及估计落点见 `references/eda/site-fixtures.json`。环湖道路以 [OpenStreetMap](https://www.openstreetmap.org/copyright) 为坐标底稿，灯具外形与历史相对位置参考已归档的 [KFQ00 航拍](https://imgs.toowtech.com/dalian/DUT/panos/DUT_KFQ00.tiles/vr/pano_d.jpg) 和[大连理工大学湖区照片](https://news.dlut.edu.cn/info/1292/147345.htm)，不分发原照片。夜间灯罩、自发光光晕及照射范围为游戏美术表达，不是实测照度。
