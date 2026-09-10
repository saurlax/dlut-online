## ADDED Requirements

### Requirement: 精简服务环境配置
游戏服 SHALL 使用固定实例 main 和监听地址 *。Compose SHALL 使用固定回环绑定地址和 ./.local/game-tls 证书目录。系统 SHALL 保留既有端口、服务地址、凭据及 TLS 配置。

#### Scenario: 默认双服务部署
- **WHEN** 启动 Compose
- **THEN** Web 和游戏服默认在宿主机 127.0.0.1 发布 8415/TCP、1949/UDP，游戏服以 main 上报

#### Scenario: 自定义端口
- **WHEN** 配置 DO_API_SERVER_PORT 和 DO_GAME_SERVER_PORT
- **THEN** Web 与游戏服按显式端口监听并映射到相同的宿主机端口
