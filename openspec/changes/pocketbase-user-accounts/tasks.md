## 1. 实现

- [x] 1.1 嵌入 PocketBase，保留现有 Go API 与 Vue 站点，并接入可配置 SQLite 数据目录。
- [x] 1.2 用 Go 代码定义 users Auth Collection，实现邮箱验证登录、唯一 username、可重复 display_name 和管理员禁用。
- [x] 1.3 让游戏票据使用 PocketBase auth token 的权威 ID 和显示名，并将网络身份切换到 PocketBase ID 格式。
- [x] 1.4 更新容器、Compose、环境参数和 apps/api 技术文档，使用 PocketBase 持久卷。
- [x] 1.5 验证 PocketBase Collection 与认证规则、游戏票据、Go/Vue 测试、Docker 构建和 OpenSpec，然后提交。
- [x] 1.6 移除 Chi，将业务 API 和 Vue 站点直接注册到 PocketBase Router，并完成回归验证。
- [x] 1.7 将服务接口统一到 `/api/v1/`，使用 DO_API_KEY 的 Bearer Auth，并清理旧凭据配置。
