## Context

用户同意精简环境变量，保留开发和生产模式及端口覆盖。

## Goals / Non-Goals

减少低频开关，不合并不同权限的凭据或内外服务地址，不改变游戏协议。

## Decisions

游戏服监听 *，实例标识 main。Compose 仍仅发布在 127.0.0.1，证书源目录固定为 ./.local/game-tls；需要不同绑定或路径时修改部署文件。删除旧环境变量的读取、注入和文档入口。DO_API_SERVER_PORT 和 DO_GAME_SERVER_PORT 同时控制进程监听端口与 Compose 映射，Go 兼容平台 PORT。游戏服公网端点存入 PocketBase，不再由环境变量配置。

## Risks / Trade-offs

直接启动游戏服现在监听所有网卡；Compose 的宿主机发布范围保持回环。生产仍强制 DTLS，密钥不进入客户端。
