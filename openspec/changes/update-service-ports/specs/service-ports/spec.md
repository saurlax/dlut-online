## ADDED Requirements

### Requirement: 双服务默认端口
系统 SHALL 默认在 UDP 1949 提供游戏服务，在 TCP 8415 提供 Go HTTP 服务。开发客户端和游戏服内部查询 SHALL 默认连接 Go 的 8415 端口，Go 返回的默认游戏端点 SHALL 使用 1949。既有显式端口和地址覆盖 SHALL 保持有效。

#### Scenario: 使用默认配置启动
- **WHEN** 两个服务未配置端口覆盖
- **THEN** 客户端从 8415 获取票据并通过 UDP 1949 进入游戏

#### Scenario: 显式覆盖
- **WHEN** 配置 DO_API_SERVER_PORT、平台 PORT、-addr、DO_GAME_SERVER_PORT 或相应连接地址
- **THEN** 系统按既有优先级采用显式值
