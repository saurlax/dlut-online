# 素材与数据来源

## 界面交互

设置与关于弹窗使用 [Radix Primitives](https://www.radix-ui.com/primitives/docs/overview/introduction) 的 `@radix-ui/react-dialog` 1.3.1，按 [MIT License](https://github.com/radix-ui/primitives/blob/main/LICENSE) 授权。按钮外观及书籍、禾苗等像素图标由本项目制作，沿用标题标志的大工意象。

按钮与面板的轮廓、高光和阴影层次参考星露谷物语角色创建界面的[游戏截图](https://stardewguide.com/wp-content/uploads/2022/04/Main_Menu.jpg)，图像版权属于 ConcernedApe。仅作离线视觉参考，项目按蓝白配色独立绘制界面，不分发或使用该游戏的 UI 贴图。

## 界面字体

界面使用 [缝合像素字体 / Fusion Pixel Font](https://github.com/TakWolf/fusion-pixel-font)，版本 [2026.10.25](https://github.com/TakWolf/fusion-pixel-font/releases/tag/2026.10.25)，12px 简体中文比例版（`fusion-pixel-12px-proportional-zh_hans.otf.woff2`）。字体版权归 TakWolf 及相应上游作者，按 SIL Open Font License 1.1 授权。本地字体文件仅更名，未修改字形；完整授权及随包上游授权保留在 `apps/web/public/fonts/fusion-pixel/`，随站点静态资源发布。

## OpenStreetMap

开发区校区地图来源于 © OpenStreetMap contributors，采用 [Open Database License 1.0](https://opendatacommons.org/licenses/odbl/1-0/)。来源及署名信息见 [OpenStreetMap Copyright](https://www.openstreetmap.org/copyright)。

游戏内署名与许可入口集中于首页“关于”，不占用地图画面；采用 OSMF [署名指南中游戏与模拟](https://osmfoundation.org/wiki/Licence/Attribution_Guidelines#Computer_games_and_simulations)允许的菜单署名位置。

`references/eda/osm.osm.gz` 保存 2026-09-16 下载的原始数据；请求范围、版本与校验值见 `references/eda/osm-source.json`。涌泉湖生成工具使用其中的水面和步道几何，导出的材质网格保留来源对象 ID、版本与署名。数据库及其派生数据遵循 ODbL；像素贴图与数据库分开维护。

全校区地面沿用同一份 OSM 数据，建筑配准记录在 `references/eda/geometry.json` 与 `footprint-refinements.json`。`planting.json` 中的种植点为来源区域内的估计布置，不代表单株实测坐标；没有有效地面区域依据的点位未导入。

## 大连理工大学湖区照片

[大连理工大学新闻网](https://news.dlut.edu.cn/info/1292/147345.htm)的湖区航拍与岸边照片用于核对红步道、白路缘、草岸及景观物件的视觉特征。照片拍摄日期未知；照片作为离线参考，不随生成结果分发。参考用途记录于 `references/eda/yongquan-grid.json`。

## 原生像素绘制

[大连理工大学校园地图](http://map.dlut.edu.cn)及既有七舍照片用于建筑颜色、楼层和可见立面参考，原始 URL、对象 ID、读取日期及用途保留在 `references/eda/building-photos.json`。照片版权归原权利人，原图只作离线参考，不随项目分发。独立建筑透明 PNG 由 `tools/campus_objects.py` 在原生像素画布绘制，属于简化外观，不代表完整立面测绘。

`tools/terrain_tiles.py` 直接在 16×16 画布生成原创像素贴图；`tools/draw_yongquan_study.py` 为独立美术构图工具。未使用星露谷物语的游戏贴图；该游戏只作为视觉风格参考。

湖岸的朝向、坡面与水线层次具体参考星露谷 Wiki 的 [ThePond.png](https://stardewvalleywiki.com/File:ThePond.png) 和 [CindersapForest.png](https://stardewvalleywiki.com/File:CindersapForest.png)，图像版权属于 ConcernedApe。参考图仅存于忽略的本地目录，不提交、不作为地图贴图分发；岸坡颜色及像素由 `tools/shore_tiles.py` 独立绘制。

## 标题画面

首页标志与主楼广场背景由 imagegen 生成，经像素网格采样、有限调色板整理后使用。标志的书籍与幼苗意象参考[大连理工大学校徽说明](https://www.dlut.edu.cn/info/1364/35309.htm)，蓝色为游戏美术配色。

背景以学校官网的[主楼广场照片](https://www.dlut.edu.cn/__local/F/15/C0/3CF32C7A03F1F6164F28544D708_61DC62F5_5F904.jpg)、校园地图建筑 77386 的正面照片和[主楼介绍](https://news.dlut.edu.cn/info/1261/83254.htm)为地域参考。照片版权归原权利人，仅离线参考；插画不用于测绘。构图与像素氛围参考星露谷官方[游戏页面](https://store.playstation.com/en-au/product/EP2319-CUSA26625_00-2010147637670638)的标题美术，未使用其贴图或标志。生成提示词、来源与处理参数见 `references/branding/title-screen.json`。
