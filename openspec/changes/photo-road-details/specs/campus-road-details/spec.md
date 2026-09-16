## ADDED Requirements

### Requirement: Photo-supported road finishes
系统 SHALL 仅在可由归档照片定位的室外道路使用对应铺装，并保留来源 URL、对象 ID、读取日期及精度说明。

#### Scenario: EDA photographed paths
- **WHEN** 离线构建开发区道路
- **THEN** 选定 OSM 路段使用连续红色路面与估计 0.12 米浅色收边，红色与沥青交界不生成同层重复面

### Requirement: Bounded outdoor stairs
系统 SHALL 将令希图书馆南侧照片可见的局部石板路、红砖曲线与两处台阶保存为可替换静态场景，不扩展到未确认的室内或其他场地。

#### Scenario: Walking over photo stairs
- **WHEN** 玩家在客户端或权威服务端从任一方向走过台阶
- **THEN** 明确坡道碰撞支持无跳跃通行，台阶外观与坡道最大高度差不超过一个估计踏步；记录近似尺寸、标高及非测绘性质

### Requirement: Offline details and package consistency
系统 SHALL 从本地照片依据配置生成细节，原始照片不得进入客户端包；客户端静态场景与服务端碰撞均从同一来源更新。

#### Scenario: Export verification
- **WHEN** 导出客户端与游戏服资源
- **THEN** 客户端包含铺装材质和静态细节，服务端包含同源碰撞，检查地形遮埋与双向通行
