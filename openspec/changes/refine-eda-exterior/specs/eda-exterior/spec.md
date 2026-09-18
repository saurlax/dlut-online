## ADDED Requirements

### Requirement: Solar controlled street lighting
已建路灯 SHALL 与校园天空共用太阳高度和时间来源，在日落附近渐亮、日出渐灭；灯罩自发光与真实路面光照同步，不仅改变灯罩颜色。

#### Scenario: Local time changes while map is open
- **WHEN** 单人玩家在暂停的大地图中将时间从白天改为夜晚或从夜晚改回白天
- **THEN** 路灯在环境更新周期内自动切换，夜间聚光灯照亮路面并提供近距离阴影，白天关闭实际光源与灯罩自发光

#### Scenario: Multiplayer and campus unloading
- **WHEN** 环境按多人同步时间更新或旧校区卸载
- **THEN** 路灯使用同一太阳高度，仅更新所属校区，卸载不残留灯光；静态光源保存在场景，远处灯光与阴影渐隐以控制开销

### Requirement: Outward bark faces
植物网格 SHALL 使树干与枝条的正面绕序、法线朝外，保持正常背面剔除，并同时更新已保存的近远景网格。

#### Scenario: Tapered and tilted branches
- **WHEN** 生成不同方向和半径的锥台枝干
- **THEN** 三角形正面与法线均指向轴线外部，UV 与对应顶点一起交换，叶片和种植位置不变

### Requirement: Bounded exterior details
开发区外景 SHALL 按照片和统一 OSM 坐标登记局部道线、路灯，尺寸估计与位置不确定性必须留档；静态场景可直接在编辑器打开。

#### Scenario: Road furniture generation
- **WHEN** 离线生成已登记路段细节
- **THEN** 道线与地形三角形精确裁切贴合，灯杆具有简单碰撞，细碎灯具与标线不生成碰撞，按材质合并网格

### Requirement: Withhold unregistered bridge geometry
系统 SHALL 保留学苑桥照片、OSM ID 和待核对项，在桥面高程、桥头与支撑未配准前不臆造可通行桥梁。

#### Scenario: Photo evidence without metric profile
- **WHEN** 近照仅证实骨架、顶棚、栏杆和防滑条外观
- **THEN** 不把 OSM layer 当高度，不凭空把桥头接到 DSM，交付明确说明天桥仍未完成
