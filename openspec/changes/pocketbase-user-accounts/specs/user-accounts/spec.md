## ADDED Requirements

### Requirement: 用户身份
系统 SHALL 使用 PocketBase Auth Collection 的 record ID 作为唯一内部用户 ID，以经过验证的唯一邮箱登录。username 必填且只含字母、数字、下划线和连字符，按大小写不敏感全局唯一；display_name 必填、可重复且可使用中文。外部身份 SHALL 使用 PocketBase 的 OAuth2 绑定机制。

#### Scenario: username 冲突
- **WHEN** 两个注册请求提交仅大小写不同的 username
- **THEN** 数据库唯一索引只允许其中一个成功

#### Scenario: 重复显示名
- **WHEN** 不同邮箱和 username 注册相同 display_name
- **THEN** 两个账号均可创建

### Requirement: 账户生命周期
系统 SHALL 嵌入 PocketBase 并提供其注册、邮箱验证、密码登录与重置、邮箱变更、auth refresh、OAuth2 和管理界面能力。未验证或被禁用账号 SHALL 不能完成认证，用户不能通过公开 API 修改 disabled。

#### Scenario: 未验证邮箱登录
- **WHEN** 用户记录尚未完成邮箱验证
- **THEN** PocketBase AuthRule 拒绝签发可用的 auth token

#### Scenario: 用户修改禁用状态
- **WHEN** 普通用户通过更新记录提交 disabled 变更
- **THEN** PocketBase API rule 拒绝请求

### Requirement: SQLite 运行边界
系统 SHALL 将所有持久数据保存于 PocketBase SQLite 数据目录，容器部署 SHALL 使用持久卷。Go Web SHALL 作为唯一 SQLite 写入者，Godot 游戏服 SHALL 仅通过受保护的 HTTP API 访问持久数据。

#### Scenario: Web 容器重建
- **WHEN** Go Web 容器重建并继续挂载原命名卷
- **THEN** PocketBase 集合、用户和设置仍可用

### Requirement: 可信入场身份
账号票据 SHALL 在签发时验证 PocketBase auth token，并使用服务端 record ID 和 display_name。游客票据 SHALL 仅接受 15 位大写十六进制客户端进程 ID，以与 PocketBase 小写 record ID 分隔。

#### Scenario: 客户端伪造身份
- **WHEN** 已登录用户在票据请求中提交任意客户身份字段
- **THEN** 账号 ID 和显示名仍完全由 PocketBase auth token 对应记录决定
