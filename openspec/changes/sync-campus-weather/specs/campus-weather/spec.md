## ADDED Requirements

### Requirement: Central weather cache
Go SHALL 根据官方地图的三校区中心获取 Open-Meteo 云量、天气代码、10 米风速和风向，通过 API Bearer Key 保护接口提供缓存。默认刷新周期为 15 分钟，DO_WEATHER_REFRESH_MINUTES 支持 5 至 180 分钟，DO_WEATHER_API_KEY 可切换商业服务。

#### Scenario: Provider outage
- **WHEN** 上游超时、限流、缺失字段或返回无效数据
- **THEN** Go 保留最近有效样本，60 秒后允许重试；首次无样本为 unavailable，观测超过 1 小时为 stale，失败不阻塞游戏入场或物理循环。

### Requirement: Authoritative real time
游戏服 SHALL 在首次欢迎、每 60 秒和切图确认时通过可靠通道提供 Unix 时间和三校区天气。客户端以服务器时间锚点和单调时钟推进，日历与太阳计算使用 UTC+8，不依赖客户端时区。

#### Scenario: Campus transfer
- **WHEN** 玩家在同一 ENet 连接传送校区
- **THEN** 客户端保留时钟和天气缓存，新场景选择自身校区样本，无额外取票和上游天气请求。

### Requirement: Scene sky and clouds
三校区 SHALL 挂载可在编辑器查看的共享天空环境和太阳。天空根据经纬度与日期连续呈现昼夜、日出日落；体积云采用世界空间三维密度场与视线步进，计算透光及云内部遮光；云量、平流方向、光照和雾霾按天气平滑变化，暂停不暂停现实时间。

#### Scenario: Missing weather
- **WHEN** 当前校区无有效天气或样本超过 3 小时
- **THEN** 使用中性少云及轻风视觉回退，继续真实昼夜，不将回退标记为真实晴天数据；不增加天气文字 HUD。

#### Scenario: Scope of weather rendering
- **WHEN** 上游返回降雨、降雪或雷暴
- **THEN** 天空呈现相应阴暗云层，客户端按天气代码强度平滑显示随风倾斜的雨丝或缓慢飘落的雪花；雷暴沿用强雨效果，不模拟闪电、积雪和结冰。

#### Scenario: Precipitation shelter and lifetime
- **WHEN** 玩家移动、在屋顶下避雨或切换校区
- **THEN** 有限范围的世界空间 GPU 粒子跟随相机发射，按现有可见模型生成的局部高度场在屋顶和地面消失；大距离移动重置旧粒子，切图随旧环境释放，不加载其他校区视觉模型。高度场仅表示最上层表面，不声称精确模拟多层室内或风驱动的侧向入雨。

#### Scenario: Fog independent of storm lighting
- **WHEN** 天气代码为 45 或 48
- **THEN** 使用独立的较高雾密度与天空雾化，保持近景可见；雾密度为代码对应的视觉估计，不声称实测能见度。雨雪使用更轻的距离雾，未知代码和过期样本不触发降水，回退时雨雪和浓雾平滑消退。
