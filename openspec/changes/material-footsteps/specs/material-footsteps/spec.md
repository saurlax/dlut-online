## ADDED Requirements

### Requirement: Local movement footsteps
客户端 SHALL 仅为本地玩家在有移动输入、实际水平移动且落地时播放脚步声。距离在当前物理移动前后采样，不计入网络纠正；行走每 2.6 米、奔跑每 4 米一次，起步在四分之一步后触发。这是匹配当前 6/13 m/s 游戏速度的听觉节奏，不是实测步幅。每物理帧最多播放一次，超过 16 m/s 加 0.1 米容差的位移视为传送。

#### Scenario: Walk and run
- **WHEN** 玩家在地面行走或奔跑
- **THEN** 按实际位移播放，奔跑节奏更快且响度更高，同类录音不连续重复，音高在 0.96–1.04 内变化。

#### Scenario: Stop, jump and pause
- **WHEN** 玩家停止输入、顶墙无位移、跳起、暂停、打开地图或失焦
- **THEN** 停止脚步播放并重置节奏，不单独增加跳跃或落地音效。

#### Scenario: Multiplayer correction and campus change
- **WHEN** 多人网络纠正位置或玩家切换校区
- **THEN** 纠正不生成脚步，旧玩家销毁后旧音频停止，新校区使用相同规则；不广播远端玩家音效。

### Requirement: Existing ground material mapping
客户端 SHALL 在落脚时用向下射线识别实际地面碰撞，射线错过台阶边缘时使用向上的滑动碰撞法线兜底；不改变几何或建立另一套地面坐标数据。碰撞节点到所属网格的 `footstep_surface` 元数据可指定 concrete、grass、wood。

#### Scenario: Ground categories
- **WHEN** 地面材质名称为 Terrain 或包含 grass/lawn
- **THEN** 使用草地音色；现有未细分的自然地形暂统一视为柔软地面，这不代表草、土、碎石的实测分类。

#### Scenario: Hard and wooden surfaces
- **WHEN** 材质包含 wood/timber
- **THEN** 使用木地音色，其余道路、石材、台阶、运动场及未知材质使用硬地音色；不声称已有木地建筑或为音频新增室内。

### Requirement: Licensed bundled audio
客户端 SHALL 离线打包 Kenney Impact Sounds 1.0 中三类各五条原始 OGG，保留 CC0 许可和来源；不运行时联网下载，不加入音乐、环境音或音频设置界面。

#### Scenario: Offline use and export
- **WHEN** 无网络运行单人模式或导出桌面/Android 客户端
- **THEN** 音效依赖完整可用，服务端导出不引入客户端音频。
