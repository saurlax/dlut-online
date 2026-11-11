# 盘锦校区参考资料

当前生成规则见 [地图规范](../../spec/map-generation.md#全校生成与发布)。来源提交、原场景路径和校验值见 [archive.json](archive.json)。

| 文件或目录 | 用途 |
| --- | --- |
| `campus.json` | 归档版已配准地理要素、建筑及立面参数 |
| `osm_roads.json`、`osm.osm.gz` | 已登记道路与原始 OSM 数据 |
| `mapping/` | 原始布局、排除记录、OSM 身份及地面配准 |
| `buildings/` | 建模依据、立面、照片 URL 和对象索引 |
| `vegetation.json`、`vegetation/` | 植被来源及暂缓状态 |
| `pixel-layout.json` | 像素版主楼南侧游戏出生点 |
| `sports-models.json` | 已迁入体育设施的地面碰撞投影 |
| `geometry.json`、`planting.json` | 像素流水线生成适配数据 |
| `generated.json` | 当前生成数据规模与限制 |

`buildings/basis.md` 等主题说明保留旧版归档内容，其中的历史计数和 Godot 发布命令不作为当前运行说明。原始照片和地形影像未导入客户端，照片索引保留原 URL；当前地图采用平面地面。原版未完成地面配准的轮廓和植被继续暂缓。
