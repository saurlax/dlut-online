# 参与开发

## 工具

- Go 1.27，具体补丁版本由本地工具链和构建镜像管理。
- Node.js 24 与 pnpm 11.6.0，前端依赖使用锁文件安装。
- Docker 与 Compose 用于完整镜像验证和部署。

## 本地运行

先构建静态网页：

```sh
cd apps/web
pnpm install --frozen-lockfile
pnpm build
```

再从 `apps/api/` 启动后端，显式提供静态网页路径：

```sh
cd apps/api
# POSIX shell
DO_WEB_ROOT=../web/out go run . serve --http=127.0.0.1:8415
```

PowerShell 使用：

```powershell
Set-Location apps/api
$env:DO_WEB_ROOT = '../web/out'
go run . serve --http=127.0.0.1:8415
```

访问 http://127.0.0.1:8415 。前端单独开发可在 `apps/web/` 运行 `pnpm dev`；该开发服务不代理 PocketBase API，涉及后端的联调使用上述静态构建路径。

## 像素地图资源

地图生成使用 Python 与 Pillow：

```sh
python -m pip install -r tools/requirements.txt
python tools/generate_eda_map.py
```

生成工具读取仓库 `references/eda/` 中的来源记录，不需要原始照片或另一个项目目录。地面和植被输出为原生 16×16 PNG；建筑为与地面保持同一像素密度的独立透明整图。预览湖岸连接可运行 `python tools/generate_lakeside_grid.py`，结果位于忽略的 `.local/`。

资源或来源更新后先核对北朝上坐标、建筑落地点、原生尺寸及连接接缝，再执行前端类型检查、生产构建和浏览器检查。原始照片只作离线参考，不进入 `public/`。

## 代码检查

```sh
cd apps/web
pnpm typecheck
pnpm build
```

```sh
cd apps/api
go test -timeout 60s ./...
go vet ./...
go build -o ../../build/dlut-online .
```

涉及打包、静态路由或运行配置时，从根目录验证统一镜像：

```sh
docker build -t dlut-online:local .
docker compose up -d
```

验证首页、`/api/health`、PocketBase 管理入口 `/_/`、未知路径 404，以及重启后的数据持久化。不要把真实数据库或凭据放进 Git。

## 规范与提交

实现前确认所属 `spec/` 文档；较大需求先明确行为、边界与验证方式，再同步实现。提交使用英文 Conventional Commits；PR 正文使用中文，并记录接口兼容性、配置、迁移和实际验证结果。
