## ADDED Requirements

### Requirement: 动态游戏服发现

系统 SHALL 将客户端可达的游戏服端点保存于 PocketBase `game_servers` Collection，不使用环境变量保存或下发该端点。同一时刻 SHALL 最多启用一条记录；票据签发时 SHALL 读取当前启用端点并校验协议、主机和端口，生产环境 SHALL 只接受 `enets://`。

#### Scenario: 下发启用端点
- **WHEN** 管理员配置一条有效启用记录且客户端请求入场票据
- **THEN** 票据响应包含该记录的 endpoint 和当前协议版本

#### Scenario: 没有可用游戏服
- **WHEN** 没有启用记录、端点格式无效，或生产环境端点使用明文 `enet://`
- **THEN** 票据接口返回 503 和 `game_server_unavailable`，不签发无法使用的票据

### Requirement: 统一运行配置名称

桌面客户端和 Godot 游戏服 SHALL 使用 `DO_API_SERVER_URL` 定位 Go API。Go SHALL 使用 `DO_API_SERVER_PORT` 并兼容平台 `PORT`，Godot 游戏服 SHALL 使用 `DO_GAME_SERVER_PORT`，PocketBase SHALL 使用 `PB_DATA_DIR` 选择数据目录。测试工程路径与临时端口 SHALL 不通过测试专用环境变量配置。

#### Scenario: 自定义双服务端口
- **WHEN** Compose 配置 DO_API_SERVER_PORT 和 DO_GAME_SERVER_PORT
- **THEN** 两个进程按对应端口监听，宿主机映射和游戏服内部 API 地址保持一致
