## ADDED Requirements

### Requirement: One OSM geographic frame for the world

三校区世界平面数据 SHALL 使用 OSM WGS84 坐标底稿，每校区使用唯一原点和共享转换。坐标底稿 MUST NOT 被视为几何真值；几何与外观证据优先级为照片 > 官网俯视图 > OSM。道路、建筑、广场、水域、植被及室外设施 MUST 不再独立叠加旧官网质心平移。

#### Scenario: Rebuild a campus

- **WHEN** 从归档来源重建校园
- **THEN** 所有运行要素、地图和碰撞共用一致坐标，保留来源 ID、版本、转换及精度限制
- **AND** 高程仍明确标注真实来源；不能把缺失的 OSM 高程臆造为连续测量地形

#### Scenario: Import archived terrain and building features

- **WHEN** 从 OSM 原始归档转换地表及建筑数据
- **THEN** 转换保留多边形内环并避免重复生成关系成员，开放或不完整的面记录为缺口
- **AND** 同名但不同几何的建筑保留身份冲突，不能直接平均或以名称唯一性自动覆盖
- **AND** 连续高程通过同一 WGS84 地理点采样已归档 DSM，缺少来源时不能推断为零高程
- **AND** 尚未核对身份、立面锚点及关联设施的数据仅作为离线迁移输入，不能表示运行场景已经完成切换

#### Scenario: Preserve existing buildings outside the OSM university boundary

- **WHEN** 既有北山宿舍等建筑位于 OSM 大学校园边界之外
- **THEN** 身份匹配搜索完整归档，不因大学边界遗漏而删除既有建筑 ID
- **AND** 未匹配、同名冲突及官网一个 ID 对应多个 OSM 体量的情况必须保留，不能静默丢弃或生成统一外包框

### Requirement: Evidence-based top-view refinement

照片 SHALL 优先用于核对可见形状和细节，其次使用官网俯视图，最后以 OSM 补足缺口。官网俯视图 MUST NOT 默认视为精确测绘数据。修正 MUST 保存原始 OSM、照片日期与视角、配准依据、修正范围和不确定项；照片透视外包络、屋檐及官网斜视交互外轮廓 MUST NOT 直接充当建筑基底。

#### Scenario: Resolve conflicting source geometry

- **WHEN** 照片、官网俯视图与 OSM 的形状或相对位置不一致
- **THEN** 优先采用照片可确认的证据，其次采用俯视图，OSM 作为底稿；不强制高优先级证据贴合 OSM
- **AND** 核对拍摄日期、视角、遮挡与几何可观测性，无法判断的墙脚或高程保留缺口，不以源排名推定照片未显示的内容
- **AND** 已由俯视图派生的框保留暂定标记，后续照片证据可以修正它们；不通过多源平均掩盖冲突

#### Scenario: Resolve EDA building and plaza mismatch

- **WHEN** 重建开发区综合楼附近
- **THEN** 建筑、北侧环岛和南侧广场的位置关系按照片、俯视图、OSM 的优先级核对，广场不再错误侵入楼体下方
- **AND** 信息楼边框仅在有效证据支持的范围内精修，不能因方便而强制为矩形
