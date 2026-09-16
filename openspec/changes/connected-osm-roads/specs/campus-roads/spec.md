## ADDED Requirements

### Requirement: Archived OSM road network
系统 SHALL 从已归档 OSM way 几何生成三校区道路，并记录原始 URL、读取日期、对象 ID、版本、许可、坐标转换与宽度依据；运行和导出不得联网取路网。

#### Scenario: Offline build
- **WHEN** 从现有归档重新生成道路
- **THEN** 只读取本地数据，并生成与地图共用的中心线数据及可在编辑器查看的静态路面

### Requirement: Connected road junctions
系统 SHALL 沿连续中心线构建道路，在共享节点填充转弯和交叉口，将重叠路面合并成不重叠三角形，并保留路网围合的空地。

#### Scenario: Bend and intersection
- **WHEN** 两条源路径共用一个节点或路面相交
- **THEN** 同层路面无拼接缺口与共面重复面，未相接的端点不按距离强行连接

### Requirement: Terrain and collision agreement
系统 SHALL 使凌水及开发区道路按当前地形三角平面贴合，使用同一静态网格生成客户端和服务端碰撞。

#### Scenario: Sloped junction
- **WHEN** 路口位于地形网格边界或斜坡
- **THEN** 接缝两侧使用相同高度函数，路面内部不因不同细分方式陷入地形

### Requirement: Evidence and accuracy boundaries
系统 SHALL 保留官方 Feature ID 与源轮廓记录，缺少宽度标签时标记视觉估计；桥梁、隧道、台阶及非地面层道路不得伪装为普通贴地路段。

#### Scenario: Unsupported geometry
- **WHEN** OSM 道路被标记为桥梁、隧道、台阶或非地面层
- **THEN** 保存排除记录并说明未建范围，不臆造垂直结构
