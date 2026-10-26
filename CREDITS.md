# 素材与数据来源

## OpenStreetMap

开发区校区地图来源于 © OpenStreetMap contributors，采用 [Open Database License 1.0](https://opendatacommons.org/licenses/odbl/1-0/)。来源及署名信息见 [OpenStreetMap Copyright](https://www.openstreetmap.org/copyright)。

`references/eda/osm.osm.gz` 保存 2026-09-16 下载的原始数据；请求范围、版本与校验值见 `references/eda/osm-source.json`。涌泉湖生成工具使用其中的水面和步道几何，导出的材质网格保留来源对象 ID、版本与署名。数据库及其派生数据遵循 ODbL；像素贴图与数据库分开维护。

## 大连理工大学湖区照片

[大连理工大学新闻网](https://news.dlut.edu.cn/info/1292/147345.htm)的湖区航拍与岸边照片用于核对红步道、白路缘、草岸及景观物件的视觉特征。照片拍摄日期未知；照片作为离线参考，不随生成结果分发。参考用途记录于 `references/eda/yongquan-grid.json`。

## 原生像素绘制

`tools/terrain_tiles.py` 直接在 16×16 画布生成原创像素贴图；`tools/draw_yongquan_study.py` 为独立美术构图工具。未使用星露谷物语的游戏贴图；该游戏只作为视觉风格参考。

湖岸的朝向、坡面与水线层次具体参考星露谷 Wiki 的 [ThePond.png](https://stardewvalleywiki.com/File:ThePond.png) 和 [CindersapForest.png](https://stardewvalleywiki.com/File:CindersapForest.png)，图像版权属于 ConcernedApe。参考图仅存于忽略的本地目录，不提交、不作为地图贴图分发；岸坡颜色及像素由 `tools/shore_tiles.py` 独立绘制。
