# 部署

## 单镜像

从仓库根目录构建、启动：

```sh
docker build -t dlut-online:local .
docker compose up -d
```

访问 http://127.0.0.1:8415 ，健康检查为 `/api/health`，管理后台为 `/_/`。Compose 默认只绑定本机地址。镜像包含 Vite / React 页面、Three.js 校园、PocketBase 账号及 WebSocket 玩家移动、外观、聊天与天气。

Actions 仅运行测试与编译验证，不发布镜像或 Release。正式部署使用根 Dockerfile 手动构建带版本标识的镜像；当前 Tokyo 使用节点本地镜像，不依赖 GHCR。

## Tokyo / k3s / EdgeOne

部署清单位于 `deploy/k3s.yaml`，固定调度到 `example-worker`。单副本 Deployment 使用 Recreate 更新，避免两个进程同时写 SQLite；`local-path` 的 2 GiB PVC 保存 `/data/pb_data`。PVC 与节点绑定，更新时保留，迁移节点前需单独备份与恢复数据。

构建并导入清单指定的镜像，然后应用部署：

```sh
docker build -t docker.io/local/dlut-online:hud-20261107-v1 .
docker save docker.io/local/dlut-online:hud-20261107-v1 -o dlut-online.tar
# 在 Tokyo 节点执行
sudo k3s ctr images import dlut-online.tar
kubectl --context example-worker apply -f deploy/k3s.yaml
kubectl --context example-worker -n dlut-online rollout status deployment/dlut-online
```

后续更新同时修改主容器与初始化容器的镜像标签，导入新镜像后再应用。镜像为节点本地资源，清单使用 `imagePullPolicy: Never`，不向注册表发起拉取。

生产 OIDC 使用独立的 `dlut-online` 客户端，回调为 `https://dlut.online/api/oauth2-redirect`。部署前在 `dlut-online` namespace 创建 Secret `dlut-online-oidc`，其中 `provider.json` 使用本文后续的提供商配置格式。初始化容器读取 Secret 并配置持久化数据库；Secret 不进入仓库，不复用本地客户端。

流量路径为浏览器 HTTPS → EdgeOne → Tokyo `192.0.2.1:80` → Traefik HTTP `web` → Service `8415`。`dlut.online` 的 DNS 保留现有 EdgeOne CNAME `edge.example.com`；EdgeOne 源站设为 Tokyo IP，回源协议固定 `HTTP`、端口 `80`、Host 为 `dlut.online`。

k3s Ingress 不配置 TLS 或 HTTPS 重定向；边缘证书由 EdgeOne 管理。Ingress 复用集群已有的 `external-https@file` 中间件向应用传递外部 HTTPS 协议信息，该中间件不终止 TLS。WebSocket 沿同一入口升级连接。

## 数据与管理

`pb_data` 卷挂载到 `/data/pb_data`。默认运行用户 UID/GID 为 10001；绑定宿主机目录时需提供相应写权限，数据卷独立备份。

首次管理员通过一次性 CLI 创建，不在配置或镜像中预置账号：

```sh
docker compose exec dlut-online /app/dlut-online superuser create <email> <password> --dir=/data/pb_data
```

该命令参数可能被本机进程列表和 shell 历史记录；在受控终端执行，不把实际密码写进仓库、工单或日志。生产环境限制管理入口访问，配置 SMTP 与邮箱策略后再开放注册。

PocketBase 命令行参数管理监听和数据路径。网页静态文件固定从运行目录的 `public/` 读取，容器中为 `/app/public`，无需配置环境变量。程序启动时检查首页存在，缺少前端构建则直接失败，不静默运行残缺发行包。

## 发布与回滚

测试成功后由同一个 Dockerfile 发布单一镜像。上线前备份数据库，使用 PocketBase 官方支持的备份方式或停机备份一致的数据目录。涉及 schema 或 PocketBase 版本升级时先验证迁移；回滚应用前确认数据库兼容性，必要时恢复匹配备份。

更新镜像采用重建容器方式，保留 `pb_data` 卷。当前只有 HTTP 服务，未来 WebRTC UDP、TURN 和 EdgeOne 四层配置需在对应功能交付时补充，不能只映射一个未监听的 UDP 端口。

## OIDC

统一认证在 PocketBase 的 `users` 集合 OAuth2 配置中设置，不使用部署环境变量。本地和正式环境使用独立客户端；回调地址与密钥约定见 `spec/backend.md`。

也可将下面格式的 JSON 放入仅部署操作员可访问的私密文件，再执行一次配置命令：

```json
{
  "name": "oidc",
  "clientId": "dlut-online",
  "clientSecret": "填写本环境的实际密钥，不提交此文件",
  "authURL": "https://dlutsso.saurlax.com/authorize",
  "tokenURL": "https://dlutsso.saurlax.com/token",
  "userInfoURL": "https://dlutsso.saurlax.com/userinfo",
  "displayName": "大工统一认证",
  "pkce": true
}
```

```sh
/app/dlut-online configure-oidc --file /data/oidc-client.json --dir /data/pb_data
```

完成后移除临时配置文件并重启服务；提供商配置及密钥已保存在持久化数据库中。注册 SSO 客户端时同时允许 `openid profile email`，学校未提供邮箱的用户也可登录。
