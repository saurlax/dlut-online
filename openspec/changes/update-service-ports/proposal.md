## Why

用户指定游戏服使用 1949，Web 服务使用 8415，需要统一默认监听与连接配置。

## What Changes

- 游戏服默认 UDP 端口改为 1949。
- Go HTTP 默认 TCP 端口及开发 API 地址改为 8415。
- 同步 Compose、Docker、CI、测试和现有技术规范。

## Capabilities

### New Capabilities
- `service-ports`: 双服务默认端口与覆盖行为。

### Modified Capabilities

## Impact

Godot、Go 与部署配置须一起更新；已有显式端口覆盖仍有效，生产 HTTPS 根地址不变。
