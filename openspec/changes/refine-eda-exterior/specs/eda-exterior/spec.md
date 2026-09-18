## ADDED Requirements

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
