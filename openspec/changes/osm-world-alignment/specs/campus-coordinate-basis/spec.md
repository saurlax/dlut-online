## ADDED Requirements

### Requirement: One OSM geographic frame for the world

三校区世界平面数据 SHALL 以 OSM WGS84 为基础，每校区使用唯一原点和共享转换。道路、建筑、广场、水域、植被及室外设施 MUST 不再独立叠加旧官网质心平移。

#### Scenario: Rebuild a campus

- **WHEN** 从归档来源重建校园
- **THEN** 所有运行要素、地图和碰撞共用一致坐标，保留来源 ID、版本、转换及精度限制
- **AND** 高程仍明确标注真实来源；不能把缺失的 OSM 高程臆造为连续测量地形

### Requirement: Evidence-based top-view refinement

官网俯视图 SHALL 用于独立检查及有依据的局部轮廓修正，MUST 保存原始 OSM、配准依据、修正范围和不确定项；官网斜视交互外轮廓 MUST NOT 直接充当建筑基底。

#### Scenario: Resolve EDA building and plaza mismatch

- **WHEN** 重建开发区综合楼附近
- **THEN** 建筑、北侧环岛和南侧广场的位置关系与 OSM 及俯视参考一致，广场不再错误侵入楼体下方
- **AND** 信息楼边框仅在俯视资料支持的范围内精修，不能因方便而强制为矩形
