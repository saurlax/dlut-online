## Why

当前只有两个固定服务与一个游戏实例，减少低频环境变量配置。

## What Changes

- 游戏服固定监听 *、实例 main，删除监听地址和实例标识环境变量。
- Compose 固定回环发布地址和本地证书目录，删除相应变量。
- 保留内外端口、服务地址、凭据、TLS 和环境模式。

## Capabilities

### New Capabilities
- `service-environment`: 固定拓扑的精简配置。

### Modified Capabilities

## Impact

Godot 服务端、Compose、Docker 和技术规范。现有部署如使用已移除变量，需要直接调整部署配置。
