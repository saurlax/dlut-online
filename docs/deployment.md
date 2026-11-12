# 部署

## 单镜像

从仓库根目录构建、启动：

```sh
docker build -t dlut-online:local .
docker compose up -d
```

访问 http://127.0.0.1:8415 ，健康检查为 `/api/health`，管理后台为 `/_/`。Compose 默认只绑定本机地址。镜像包含 Vite / React 页面、Three.js 校园、PocketBase 账号及 WebSocket 玩家移动、外观、聊天与天气。

Actions 仅运行测试与编译验证，不发布镜像或 Release。正式部署使用根 Dockerfile 手动构建带版本标识的镜像；k3s 示例使用节点本地镜像，不依赖 GHCR。

## k3s 部署示例

将 `deploy/k3s.yaml` 复制到 `.local/deploy/k3s.yaml`，设置两个容器的镜像、Ingress 域名和目标集群所需的调度与入口配置。单副本 Deployment 使用 Recreate 更新，`local-path` 的 2 GiB PVC 保存 `/data/pb_data`。PVC 与节点绑定，迁移节点前需备份与恢复数据。

```sh
mkdir -p .local/deploy
cp -n deploy/k3s.yaml .local/deploy/k3s.yaml
```

将 `DO_KUBE_CONTEXT` 设为目标集群的 kubeconfig 上下文，`DO_IMAGE` 设为本地清单的镜像名和标签。构建镜像，将归档传到调度节点后导入，再应用本地清单。

```sh
docker build -t "$DO_IMAGE" .
docker save "$DO_IMAGE" -o .local/deploy/dlut-online.tar
# 在调度节点执行
sudo k3s ctr images import dlut-online.tar
kubectl --context "$DO_KUBE_CONTEXT" apply -f .local/deploy/k3s.yaml
kubectl --context "$DO_KUBE_CONTEXT" -n dlut-online rollout status deployment/dlut-online
```

清单使用 `imagePullPolicy: Never`。更新时同步修改主容器和初始化容器的镜像标签，并先导入新镜像。

在 `dlut-online` 命名空间创建 Secret `dlut-online-oidc`，键名为 `provider.json`，格式见下文。初始化容器使用它配置持久化数据库。OIDC 客户端的回调地址为游戏公开源下的 `/api/oauth2-redirect`。在入口配置 TLS、外部 HTTPS 协议转发和 WebSocket 升级。

## 数据与管理

`pb_data` 卷挂载到 `/data/pb_data`。默认运行用户 UID/GID 为 10001；绑定宿主机目录时需提供相应写权限，数据卷独立备份。

首次管理员通过一次性 CLI 创建，不在配置或镜像中预置账号：

```sh
docker compose exec dlut-online /app/dlut-online superuser create <email> <password> --dir=/data/pb_data
```

该命令参数可能被本机进程列表和 shell 历史记录；在受控终端执行，不把实际密码写进仓库、工单或日志。生产环境限制管理入口访问，配置 SMTP 与邮箱策略后再开放注册。需要授予世界指令权限时，在 PocketBase 后台的 `user_roles` 集合将目标用户关联到 `admin` 角色。

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
