# 部署

## 单镜像

从仓库根目录构建、启动：

```sh
docker build -t dlut-online:local .
docker compose up -d
```

访问 http://127.0.0.1:8415 ，健康检查为 `/api/health`，管理后台为 `/_/`。Compose 默认只绑定本机地址，公网部署通过 HTTPS 反向代理接入。当前镜像提供基础入口和 PocketBase 后端，尚无可玩的校园或游戏传输。

正式镜像地址为 `ghcr.io/saurlax/dlut-online`，主线标签 `latest`，版本标签如 `v0.1.0`。部署时使用对应标签下的文档与发布说明。

## 数据与管理

`pb_data` 卷挂载到 `/data/pb_data`。默认运行用户 UID/GID 为 10001；绑定宿主机目录时需提供相应写权限，数据卷独立备份。

首次管理员通过一次性 CLI 创建，不在配置或镜像中预置账号：

```sh
docker compose exec dlut-online /app/dlut-online superuser create <email> <password> --dir=/data/pb_data
```

该命令参数可能被本机进程列表和 shell 历史记录；在受控终端执行，不把实际密码写进仓库、工单或日志。生产环境限制管理入口访问，配置 SMTP 与邮箱策略后再开放注册。

PocketBase 命令行参数管理监听和数据路径。`DO_WEB_ROOT` 指向构建静态文件，容器默认 `/app/public`。程序启动时检查首页存在，缺少前端构建则直接失败，不静默运行残缺发行包。

## 发布与回滚

测试成功后由同一个 Dockerfile 发布单一镜像。上线前备份数据库，使用 PocketBase 官方支持的备份方式或停机备份一致的数据目录。涉及 schema 或 PocketBase 版本升级时先验证迁移；回滚应用前确认数据库兼容性，必要时恢复匹配备份。

更新镜像采用重建容器方式，保留 `pb_data` 卷。当前只有 HTTP 服务，未来 WebRTC UDP、TURN 和 EdgeOne 四层配置需在对应功能交付时补充，不能只映射一个未监听的 UDP 端口。
