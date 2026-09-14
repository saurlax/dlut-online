## ADDED Requirements

### Requirement: Individual building evidence and geometry

系统 SHALL 对开发区官方轮廓中的16个建筑对象逐栋维护来源、建模范围和尺度依据，并将有依据的外观落实为静态场景；不得以通用立面或少数样本的检查宣称所有楼完成。

#### Scenario: Review all buildings

- **WHEN** 检查开发区建筑完成状态
- **THEN** 每栋均有与该对象匹配的照片/有效几何依据、已实现范围和对应实际渲染，未核实部分明确留空并登记。

### Requirement: Distinct height volumes

系统 SHALL 按已核实的楼层和屋顶分界表达七舍及其他建筑的高低体量，不再把已知不同高度的分区拉伸成统一屋顶。

#### Scenario: Seventh residence and activity center

- **WHEN** 生成Feature 2304982
- **THEN** 有依据的高低分区分别生成对应屋顶与墙体，保留官方外轮廓和分区估计来源，服务器碰撞与视觉高度一致。

### Requirement: Verified desktop geometry

系统 SHALL 运行相关物理、实际渲染及桌面/服务器导出校验，并保持未涉及校区的资源不变；原图仅作离线参考。

#### Scenario: Deliver refined campus

- **WHEN** 提交本批建筑改动
- **THEN** 检查对应屋顶、外墙和结构碰撞以及导出包中的几何，不将原照片打入客户端，不生成未核实室内。
