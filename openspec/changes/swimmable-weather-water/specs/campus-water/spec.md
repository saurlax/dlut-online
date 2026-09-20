## ADDED Requirements

### Requirement: Enterable water
游戏 SHALL 在有有效轮廓的既有水域支持落水，客户端和服务端使用一致的平均水位、浅岸和水底碰撞，水面自身不阻挡角色。

#### Scenario: Falling and ascending
- **WHEN** 角色进入水域且脚点低于水位 0.65 米
- **THEN** 水平速度为 3 m/s，松键趋向缓慢下沉，按住空格或触屏跳跃按钮持续上浮，越过水面阈值给予轻跳以便回岸。

#### Scenario: Input interruption
- **WHEN** 玩家松开上浮键、暂停、失焦、切图或服务端超过 500 ms 未收到输入
- **THEN** 上浮控制停止，输入不能粘住；多人持续输入接受服务端校验，旧协议客户端不能申请票据。

### Requirement: Underwater view
客户端 SHALL 根据相机深度切换独立水下环境，并在离水时恢复当前天气环境。

#### Scenario: Camera crossing the surface
- **WHEN** 相机进入水下
- **THEN** 呈现青绿色浑浊、距离雾和较低亮度；抬升出水恢复正常视角，不新增说明 HUD。

### Requirement: Weather driven waves
水面 SHALL 具有三维波浪和细波法线，多人波幅、传播速度与角度参考现有有效天气风速及风向。

#### Scenario: Wind changes
- **WHEN** 收到新的校区风样本
- **THEN** 平滑更新传播方向与强度，连续推进波相位；天气过期或缺失沿用明确的视觉回退，单人继续纯离线。

### Requirement: Evidence and offline construction
水域 SHALL 沿用有效地面边界，静态水面与地形写入场景，不根据官网斜视 bound 推测轮廓或宣称水底实测。

#### Scenario: Missing bathymetry or polygon
- **WHEN** 缺少实测水深或校区没有有效水域轮廓
- **THEN** 4 米水下空间与 6 米浅岸仅记录为玩法近似；无有效轮廓的校区不添加水域。
