> 现行登录要求由 [account-only-login](../account-only-login/specs/account-only-login/spec.md) 取代：所有玩家必须绑定 PocketBase 已验证账号，通过官网认证后返回游戏。本文中的游客入口、游客 ID 与游客入场描述仅记录历史，不再作为当前实现要求。

## Context

系统使用 PocketBase embed、SQLite 和 PocketBase record ID。username 必填，允许 0-9 a-z A-Z - _ 并大小写不敏感唯一；display_name 必填、允许重复和中文。

## Goals / Non-Goals

使用 PocketBase 提供注册、邮箱验证、密码认证与重置、邮箱修改、OAuth2 外部身份和管理界面。本轮保持 Godot 游客 UI，但后端游戏票据已接受 PocketBase auth token。

## Decisions

Go 使用 `pocketbase.NewWithConfig` 创建应用，通过 Go 代码定义 `users` Auth Collection。集合内置 ID、email、password、verified、tokenKey 作为权威认证数据，额外字段为 username、display_name 和 disabled。

游戏 API、受保护服务 API 和 Vue 静态站点均在 `OnServe` 中直接注册到 PocketBase Router。标准 HTTP handler 通过 PocketBase 官方 `apis.WrapStdHandler` 适配，不保留第二套路由框架。

服务间接口统一位于 `/api/v1/`，使用 `Authorization: Bearer <DO_API_KEY>`。Go、Godot 游戏服和后续可信平台通过部署环境取得同一 API Key；PocketBase 用户 auth token 仅用于用户身份接口。

username 保留用户输入大小写，使用 SQLite `lower(username)` 唯一索引判断冲突；密码登录仅使用 email。AuthRule 要求 `verified = true && disabled = false`，用户更新规则禁止修改 disabled，管理员通过 PocketBase 管理界面管理账号。

PocketBase 负责密码哈希、邮箱验证与重置、token 签发、外部身份记录和 API 限流。SMTP 与 OAuth2/OIDC 提供方通过 PocketBase 设置配置；生产使用 `PB_ENCRYPTION_KEY` 加密数据库内的机密设置。PocketBase auth token 是无状态 JWT，改变 record tokenKey 可使该用户已签发 token 失效。

SQLite 目录默认为 `pb_data`，容器固定为 `/data/pb_data` 并挂载命名持久卷。Go Web 保持单实例写入；Godot 游戏服不打开 SQLite 文件，持久化和查询继续经过 Go 内部 HTTP API。

桌面客户端和 Godot 游戏服统一通过 `DO_API_SERVER_URL` 定位 Go。Go 使用 `DO_API_SERVER_PORT`，游戏服使用 `DO_GAME_SERVER_PORT`，PocketBase 数据目录使用 `PB_DATA_DIR`。客户端可达的 ENet 端点存入 `servers` Collection；票据签发时读取当前启用记录，生产仅接受 `enets://`，没有有效记录时返回服务不可用。测试工程路径和临时端口通过固定仓库布局及命令行参数传入，不占用环境变量。

游戏票据在 Authorization 为有效 PocketBase `users` token 时使用 record ID 和 display_name，否则只接受合法游客身份。身份 ID 统一为 15 位 ASCII：账号使用 PocketBase 小写字母数字 ID，游客使用大写十六进制进程 ID，两个命名空间不重叠。游戏协议版本为 4。

## Risks / Trade-offs

PocketBase 在 1.0 前可能调整 API，升级依赖前必须先备份并验证。SQLite 单写入者限制了 Go Web 水平扩容，但对当前 50 人规模充足。备份必须覆盖完整 pb_data，不能只复制正在写入的 data.db。
