## ADDED Requirements

### Requirement: Photo-registered residence exteriors

系统 SHALL 按官方 Feature ID 和逐栋照片记录生成开发区1、2、3舍的已确认局部外观，保留原始轮廓及估计尺度说明。

#### Scenario: Build observed faces

- **WHEN** 离线生成开发区模型
- **THEN** 1、2舍南侧及3舍东侧具备分别配准的窗框、饰板和顶层栏杆，1、2舍具备黄色双层阳台框；不得将这些窗格延伸到未经核实的背面。

### Requirement: Structural collision and reference isolation

系统 SHALL 仅为外壳、楼板和结构柱生成碰撞，将栏杆、窗框等细节按材质合并；原图仅作离线参考。

#### Scenario: Desktop and server delivery

- **WHEN** 导出桌面客户端和游戏服
- **THEN** 客户端包含更新的静态模型，游戏服包含从同一模型生成的对应碰撞，原始照片不进入客户端且不增加未核实室内或入口。
