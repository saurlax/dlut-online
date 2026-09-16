## ADDED Requirements

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
