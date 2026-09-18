## ADDED Requirements

### Requirement: 原生设置入口与输入隔离

客户端 SHALL 在首页加载完成后及校园探索时显示右上角齿轮按钮。校园中按 Esc SHALL 停止移动并释放鼠标，点击齿轮 SHALL 打开只有图形选项卡的原生设置页。设置页 SHALL 阻止点击穿透、地图和聊天快捷键抢占；关闭或 Esc 收起后 SHALL 保持暂停，下一次世界点击或 Esc 才恢复。失焦 SHALL 不自动恢复移动。移动端入口 SHALL 避开暂停触控区。

#### Scenario: 暂停后进入设置
- **WHEN** 玩家按 Esc 后点击设置，操作下拉框并关闭
- **THEN** 光标保持可见，角色全程停止行走，点击不传给世界或地图

#### Scenario: 失焦与覆盖层
- **WHEN** 设置中失焦、按 M 或 Enter
- **THEN** 设置保持打开，角色不走动，不打开地图或聊天编辑

### Requirement: 有效且兼容的图形选项

图形页 SHALL 提供窗口/全屏、垂直同步、帧率上限、双线性/FSR/MetalFX、渲染比例、FSR 锐化、MSAA/FXAA/SMAA/TAA、各向异性过滤、阴影质量/距离、SSAO、SSIL、SSR、SDFGI、辉光、体积雾、消除色带和色调映射。系统 MUST 根据当前渲染器与设备能力禁用不支持项并说明原因。PBR、烘焙 GI 和探针 MUST NOT 被表示为缺乏配套资源的通用开关。

#### Scenario: 时域升频与抗锯齿
- **WHEN** 玩家选择 FSR 2 或 MetalFX 时域
- **THEN** 独立抗锯齿关闭且不可选，超采样不可选，渲染比例遵守设备限制

#### Scenario: Android Mobile
- **WHEN** 客户端使用 Mobile 渲染器
- **THEN** SDFGI、SSIL、SSR、SSAO、体积雾、TAA 与 FSR 1/2 不可开启；普通选项仍然可用

### Requirement: 应用、保存与跨场景继承

更改 SHALL 在点击应用后生效，成功保存到本机 `user://graphics.cfg`，不访问账号/API。恢复默认 SHALL 修改待应用值，关闭 SHALL 丢弃未应用值。下次启动、首页背景和校区切换 SHALL 继承图形配置。无效配置 SHALL 回退安全默认值，保存失败 SHALL 明确提示且允许重试。效果应用 MUST NOT 覆盖天气数据或改变游戏模拟。

#### Scenario: 切换校区
- **WHEN** 玩家应用 120 FPS、67% 比例和阴影选项后传送
- **THEN** 新校区使用相同配置，帧率不重置为 60，天气仍由原控制器更新

#### Scenario: 配置损坏与放弃修改
- **WHEN** 配置字段类型/取值不合法，或用户修改后直接关闭
- **THEN** 非法值回退默认；直接关闭不应用或保存草稿
