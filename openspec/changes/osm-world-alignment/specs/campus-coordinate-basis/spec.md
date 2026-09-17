## ADDED Requirements

### Requirement: One OSM geographic frame for the world

三校区世界平面数据 SHALL 使用 OSM WGS84 坐标底稿，每校区使用唯一原点和共享转换。坐标底稿 MUST NOT 被视为几何真值；几何与外观证据优先级为照片 > 官网俯视图 > OSM。道路、建筑、广场、水域、植被及室外设施 MUST 不再独立叠加旧官网质心平移。

#### Scenario: 已知身份的几何迁移被明确暂缓
- **WHEN** 对象已匹配OSM身份，但来源记录设置defer_geometry以等待相邻建筑或墙脚核对
- **THEN** 身份输出保留候选及geometry_deferred标记，准备工具清空无独立地面来源的运行几何，仅保留身份及原始档案，不因名称或ref对应成功而自动迁移；待核对状态不得计入已应用来源几何

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

#### Scenario: North roundabout paving preserves its planted island
- **WHEN** 综合楼北环岛可见铺装与院内暂定铺装合并生成
- **THEN** 使用共同地面控制配准，明确区分影像描边与受遮挡的图面估计，扣除中央绿岛及建筑占地
- **AND** 客户端和保存服务端均须验证引道接缝双向步行，不以固定路宽或屋顶外缘代替可见地面范围

#### Scenario: 相连楼群有多个官方身份但只有一个整体来源面

- **WHEN** 照片及俯视图支持多个官方对象属于同一相连楼群，OSM只提供整体外圈和内孔，旧斜视体块产生重复覆盖
- **THEN** 显式登记共享楼群，整体来源几何只生成一次；保留所有官方ID、离线原始档案和可替换节点，未分区身份引用几何所有者
- **AND** 不人为划分内部边界，不将来源身份引用计作独立轮廓匹配；重新导入若来源版本、孔洞、成员几何或照片立面发生变化则拒绝沿用共享配置
- **AND** 移除重复体块时同步地形基台、植被、地图和两端碰撞，检查内孔净空及地面；共享几何不证明真实高度、完整院落或外部入口

### Requirement: 保留合并对象的不同来源语义

合并官方对象对应多个OSM要素时，来源提取 SHALL 分别保留每个要素的ID、版本、标签、类别和原始轮廓。leisure=swimming_pool 且没有building标签的区域 SHALL 保持泳池区域语义，MUST NOT 自动作为建筑墙脚挤出。

#### Scenario: 体育馆与游泳馆共用官方对象
- **WHEN** 官方77445同时包含主馆与游泳馆，OSM分别提供主馆建筑和具名室内泳池区域
- **THEN** 身份登记保留两份参考，建模前分别核对其几何适用范围，不用主馆单一轮廓覆盖两馆

### Requirement: 区分非建筑统计参考区域

经逐项来源审查的非建筑统计点 SHALL 保留原始身份与离线档案，但 MUST NOT 作为缺省估计楼体挤出；分类覆盖必须有显式来源配置。

#### Scenario: 统计点被官方通用类型误标为建筑
- **WHEN** 单项官方详情和图面核对证明该对象是统计或交互参考区域，缺乏独立建筑依据
- **THEN** 以显式审查配置保留ID、离线原始档案及可替换空节点，不挤出估计楼体，不生成建筑基台或碰撞
- **AND** 不因相册为空而批量移除楼体；源轮廓、照片立面或OSM匹配变化时拒绝沿用该配置并要求重新审查

### Requirement: Reject incompatible generation frames
道路与地形生成器 SHALL 在写入前验证运行清单的 EPSG:4326 标记、共享坐标基准路径和校区原点；不匹配时 MUST 报错，MUST NOT 隐式回退旧官网质心平移。

#### Scenario: An old manifest is used for regeneration
- **WHEN** 清单缺少 WGS84 标记，或坐标基准路径、原点与共享登记不一致
- **THEN** 生成失败且不写入运行道路或地形文件，历史配准记录不被自动应用

### Requirement: 禁用斜视选择框几何

DLUTMap bound 已确认为三维选择框，运行数据与生成器 MUST NOT 将其作为轮廓或兜底几何。旧框仅保留在原始来源档案。没有独立地面来源的对象 SHALL 保留空参考节点；依照旧框手工定位且尚未独立配准的植被区域 SHALL 暂停生成。

#### Scenario: Withhold unsupported geometry throughout the pipeline
- **WHEN** 官方对象没有已登记的独立地面轮廓
- **THEN** 运行 points 与 render_polygons 为空，保留来源 ID 与缺口原因，不生成模型、基台、地图轮廓或碰撞
- **AND** 客户端与保存的服务端世界同时重建；有照片但仍依赖旧框定位的立面不能绕过限制

#### Scenario: Ground paving registration uses observable ground controls
- **WHEN** 可见影像地面铺装与图绘轮廓不一致
- **THEN** 按有日期影像的可见地面修正历史参考，并保留原图绘档案、遮挡和改造时效限制
- **AND** 南北广场使用共同OSM地面环线控制点，不以楼顶边长决定铺装比例；缺失或版本变化的控制点使生成失败，两点拟合不宣称独立测量精度

### Requirement: Independently registered planting areas

植被区域 SHALL 逐项使用已核对的独立地面来源，MUST NOT 根据整个配置文件的坐标声明批量启用旧区域。OSM区域的对象版本、几何摘要和地表语义 SHALL 在生成前校验。

#### Scenario: Restore reviewed woodland without restoring old selection zones
- **WHEN** 锦屏山林地已通过OSM与影像核对，其余区域仍为旧框坐标
- **THEN** 仅从已登记OSM林地生成树木，记录其余区域为withheld，旧点列改变不影响已登记区域
- **AND** 保存实例位于来源范围内，根部贴合共同地形，避让道路/建筑/水面，近远模型位置一致；生成数量不得标为实测数量

### Requirement: Sourced elevation uses the common geographic frame

三校区连续高程 SHALL 记录独立DSM来源、垂直基准、原始样本与处理步骤，MUST NOT 称为OSM高程或实测裸地。整数窗口裁剪 SHALL 保持原样本与采样中心，运行地形 SHALL 静态挂入校园场景。

#### Scenario: Panjin elevation replaces the flat approximation
- **WHEN** 盘锦取得经哈希验证的WGS84、EGM2008 DSM裁剪
- **THEN** 建筑、道路和地形在同一校区原点重建，客户端与保存的服务端碰撞保持一致
- **AND** 校园边界覆盖负高程地面，出生点经过落地检查；细化网格与滤波不得宣称增加测量精度

#### Scenario: Restore only reviewed OSM parking ground
- **WHEN** 停车地面已有独立OSM范围，并通过可见影像核对用途和大致范围
- **THEN** 生成器校验OSM版本与几何摘要，地图、可见地面和两端碰撞共用轮廓与地形
- **AND** 渲染抬升不制造无依据的路沿阻挡，进行落地与双向通行检查；有未登记绿岛或不在影像范围内的停车场继续保留待核对，不整框填满
