## ADDED Requirements

### Requirement: Continuous photographed lake junction
开发区湖边三岔口 SHALL 保留三条道路拓扑，并以连续沥青面填充中心及已登记入口，禁止沿中心线路带留下虚假的草地隔断。

#### Scenario: Walk across the junction
- **WHEN** 玩家从任一路臂走过路口中心
- **THEN** 路面连续且贴合同一地形，客户端和服务端碰撞一致

### Requirement: Photo bounded lake landscaping
湖边广场、砖铺人行道、环形绿篱和湖畔植被 SHALL 以归档照片、共同 WGS84 原点与版本固定的 OSM 地面节点登记，记录日期、遮挡、用途及估计边界。

#### Scenario: Regenerate outdoor details
- **WHEN** 离线重新生成开发区环境
- **THEN** 检查来源锚点，保留未配准部位，树木避开道路水面和广场，人行道在支路交叉处留通行口，静态模型可直接在编辑器查看

### Requirement: Local road details
已登记环湖路段 SHALL 包含贴地标线和十二盏具有简单灯杆碰撞、既有昼夜控制与距离渐隐的路灯。

#### Scenario: Inspect day and night
- **WHEN** 时间从白天转到夜间
- **THEN** 既有控制器同步灯罩和路面照明，不为标线、叶片或细碎灯具创建碰撞

### Requirement: Smooth bounded lake outlines
开发区两湖 SHALL 根据鸟瞰图可见的连续岸线，将原9点和16点折线细化为闭合、切向连续的有界曲线；保留原始节点、OSM ID及版本，不把新增曲线点当作测量数据。

#### Scenario: Refine the shoreline
- **WHEN** 离线重建两湖轮廓
- **THEN** 曲线控制点在原线段2米走廊内，采样边长不超过2米，保留凹口及两湖分隔；水面、地图、水域判定、岸坡、附近道路、植被和服务端碰撞共同使用新轮廓重新生成
