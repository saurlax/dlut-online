## ADDED Requirements

### Requirement: Preview OSM on official top-view tiles

工具 SHALL 将三校区已转换 OSM 轮廓投影到官网 lm30 图面，保留内环，支持底图和两类轮廓开关、平移缩放及按米临时平移 OSM。初始平移 MUST 标为未验证，不修改源轮廓、模型或碰撞。

#### Scenario: Open campus overlay

- **WHEN** 用户打开叠图并切换校区
- **THEN** 显示该校区 OSM 与俯视底图，明确初始定位依据；盘锦单样本推算不得宣称为全校区可靠配准
- **AND** 显示瓦片加载与失败状态，缺失底图不冒充已加载

#### Scenario: Cache visible tiles

- **WHEN** 指定下载选项启动本机服务
- **THEN** 仅按视口请求官网 lm30 瓦片并记录 URL、读取时间和摘要；未指定下载时缺失缓存返回明确失败

### Requirement: Normalize sources without fabricating consensus

工具 SHALL 将已取得多边形转换为带 source、frame、摘要和有效性标记的 bound；未取得几何的地图页面、栅格 PDF 和数据目录 MUST 列为缺口。OSM 下载框不等于校园边界，官网记录不等于建筑清单。关系对象 MUST 保留成员，不得丢弃内院后冒充单环轮廓。

#### Scenario: Conservative fitting

- **WHEN** 已配对样本具有有效图面多边形
- **THEN** 可尝试边方向矩形约束，仅当采样边界差不超过 0.6 米且面积变化不超过 3% 时采用，其他情况保留原形
- **AND** 结果保持未验证，绝对精度未知；图面误差不得解释为实测精度，官网交互轮廓不得参与平均

#### Scenario: Source is not acquired

- **WHEN** 来源只有可浏览页面、目录或未配准栅格
- **THEN** 不生成虚假 bound，不将其计为独立几何证据
- **AND** 对比页列明各来源实际取得的资料，区分几何来源数量和样本数量；候选明确标为派生数据，重合线使用不同宽度与虚实线，并支持逐层开关

#### Scenario: Browse all downloaded geometry

- **WHEN** 生成本地 bound 结果
- **THEN** 提供三校区全部已转换轮廓总览，支持校区切换、平移缩放、边线点击查看来源及 JSON 下载
- **AND** 官网与 OSM 各用原始坐标独立显示；完整 multipolygon 成员按节点 ID 组环，保留 outer/inner 角色为 multiRing，无法组环的关系保留待处理清单
- **AND** 明示单环检查不代表多环嵌套及重叠已验证，关系与单 way 可能重复，记录数不得宣称为建筑总数

### Requirement: Separate source outlines from review drafts

工具 SHALL 使用官网 `lm30` 二维瓦片图面为参考，分别保留官网 bound、OSM 原始点与初始定位、人工修正草稿。地图来源未知的地理基准和精度 MUST 明示，初始质心平移不得标为已通过配准。

#### Scenario: Compare a building

- **WHEN** 用户选择样本
- **THEN** 显示二维底图、三组可独立开关的轮廓、官方 ID 和 OSM ID/版本，未审核匹配保留疑点
- **AND** 支持缩放、平移和适应画面，不将六个节点自动归类为错误轮廓

### Requirement: Preserve edits and provenance

工具 SHALL 支持移动草稿、顶点调整、增删顶点、重新描绘和撤销。保存 MUST 包含输入来源、瓦片信息、读取时间、摘要、图面坐标、原始 OSM 坐标、初始定位及人工备注；状态保持未验证，不能写入游戏模型或碰撞。

#### Scenario: Save and reopen

- **WHEN** 用户保存没有退化或自交的草稿
- **THEN** 仅在本地输出目录原子写入草稿，重新加载或重新生成后可恢复
- **AND** 来源摘要、样本集或坐标框架改变时拒绝沿用旧草稿

#### Scenario: Invalid geometry

- **WHEN** 草稿包含不足三个顶点、非有限坐标、重复相邻顶点、零面积或自交
- **THEN** 不允许保存，并显示错误

### Requirement: Keep reference acquisition offline by default

工具 SHALL 从自身路径解析仓库资料，仅在明确提供下载选项时获取缺失公开数据；重放只读取缓存，校验摘要。底图和下载数据 MUST 放在本地忽略目录，不进入运行时资源。

#### Scenario: Cached replay

- **WHEN** 缓存完整且未指定下载
- **THEN** 不发起外部网络请求即可生成复核页

#### Scenario: Local editing server

- **WHEN** 启动编辑服务
- **THEN** 仅监听本机回环地址，仅接收同源 JSON 保存请求，写入固定草稿文件
