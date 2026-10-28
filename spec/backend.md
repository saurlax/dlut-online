# 账号与持久化

## 服务组成

Go 直接集成 PocketBase，复用其 Router、账号 API、管理后台、SQLite 与迁移机制。当前注册前端静态文件服务，保留 PocketBase 自带 `/api/health` 和 `/_/`，不重复建设健康检查或认证系统。

沿用默认 users 认证集合，新增 profiles、items、inventory 集合。每个账号一个 profile，以 userId 唯一约束。游戏显示名仅存于 profiles.name，按 Unicode 码点计数为 1–20 字符，去除首尾空白并拒绝换行、控制字符；profiles.gender 为 male/female/unspecified，appearance 为身体外观 JSON。users 不保留 name 或 username 字段，密码认证 IdentityFields 固定为 email；SSO 为独立认证方式，游戏名字不能作为密码登录标识。inventory 记录 userId、itemId、slotId 与 color；userId 和 slotId 联合唯一。items 新增整数 capacity（0–30），背包定义提供 10、20、30 格。slotId 为 head/top/bottom/feet/backpack、独立 hotbar:0 至 hotbar:9 或 bag:0 至 bag:29，bag 位置必须在已穿背包容量内。玩家仅能读取自己的角色和背包，所有物品写操作经过 Go 接口。

GET /api/v1/character 返回本人角色、物品和由已穿背包计算的 capacity，未穿背包时为 0；POST /api/v1/character 在同一事务内创建角色并发放初始衣物，重复创建返回已有角色；POST /api/v1/character/wear 接收物品实例 id，在事务内完成穿脱及同槽交换；POST /api/v1/character/move 接收实例 id 与目标 slotId，允许常驻物品栏、已解锁背包格与匹配装备槽间移动或交换，验证交换双方均能占用最终位置。所有操作校验归属、唯一位置与操作后容量，容量不足时整个事务回滚。四个接口均要求 users 认证，密码登录沿用 PocketBase API。未知 API 返回错误，不能返回网页首页。

注册使用邮箱验证码与确认密码：`POST /api/v1/registration/code` 发送验证码，`POST /api/v1/registration` 在同一浏览器校验验证码、密码确认及有效期后创建已验证邮箱账号。验证码十分钟有效，每邮箱发送间隔一分钟，最多尝试五次，使用后失效。禁用公开 PocketBase users 创建接口，避免绕过验证；邮件服务使用 PocketBase SMTP 配置。

升级迁移为 items 增加 capacity 并登记三个背包定义。已有角色补发并穿上至少 10 格背包；存在旧背包内容的角色按最高占用格补发足够的 10/20/30 格背包，原有背包物品位置保持不变。旧 hand 位置迁移至 hotbar:0；物品栏固定 10 格，不占背包容量。新角色在创建事务中直接穿上 10 格校园背包，重复创建不重复发放。

迁移保留现有 profiles.name、外观与物品，将旧角色性别设为 unspecified；移除 users 中未用作游戏显示名的 name/username 字段，清空 OAuth2 对这两个字段的自动映射。POST /api/v1/character 继续提交 name，并新增必填 gender，未升级客户端不能创建角色，前后端需要一同发布。

OIDC 登录时从服务端取得的 UserInfo 读取 preferred_username 和 gender，仅提取这两个创建提示到 users.characterDefaults JSON。GET /api/v1/character 在角色不存在时返回 defaults（name、gender），没有 SSO 时分别为空字符串、unspecified。preferred_username 不回退到真实姓名或学号；性别仅识别明确的 male/female、m/f、男/女字符串，其余视为 unspecified，不从角色、姓名或衣物推断。创建表单允许修改这些提示，保存后的 profiles.name/gender 是游戏显示依据，后续 SSO 登录不修改已有角色。characterDefaults 不参与认证授权，不保存学校 Token 或完整 UserInfo。

## 数据权威

后续多人会话必须绑定有效账号。客户端不能直接写入权威位置、移动速度、校区或其他游戏规则字段。游戏会话使用短期凭据与登录会话关联；身份校验与撤销策略随会话功能一同实现。

逐帧位置和输入在 Go 世界内存维护，经 Pion 数据通道同步；PocketBase Realtime 为 SSE 记录订阅，不用于移动同步。需要持久化的角色状态按检查点保存，数据库操作不阻塞模拟时间步。后端进程异常后的恢复以持久化检查点为准，不承诺逐帧恢复。

当前部署为单实例。不得让多个独立写实例共享同一个 SQLite 数据目录；扩容前需设计世界归属和持久化服务边界。

## 当前配置

| 配置 | 约定 |
| --- | --- |
| `--http` | PocketBase 监听地址，容器固定默认 `0.0.0.0:8415` |
| `--dir` | PocketBase 数据目录，容器为 `/data/pb_data` |

网页静态文件固定读取运行目录下的 `public/`，容器中为 `/app/public`，不通过环境变量覆盖。未使用的环境变量不提前加入。任何管理员密码、账号令牌和后续 TURN 凭据均不打入前端或镜像层。

## 大工统一认证

`users` 支持 PocketBase 内置 OIDC，提供商为 `https://dlutsso.saurlax.com`，授权、Token 和 UserInfo 端点分别为 `/authorize`、`/token`、`/userinfo`。客户端通过官方 JavaScript SDK 的 PKCE 新标签页流程登录，回调为当前源的 `/api/oauth2-redirect`；成功后使用 PocketBase 签发的账号令牌访问现有角色接口，不将学校 Token 当作游戏令牌。

开发客户端 ID 为 `dlut-online-local`，登记 `localhost` 和 `127.0.0.1` 的 8415、18415 端口；正式客户端 ID 为 `dlut-online`，登记 `https://dlut.online/api/oauth2-redirect`。两个客户端使用独立密钥，密钥只存于对应环境的 PocketBase OAuth2 配置和 SSO 客户端配置，不进入浏览器、Git 或日志。不增加 OIDC 环境变量。

统一认证只关联已注册的 users 账号，不自动创建用户。直接绑定必须携带当前账号有效的 PocketBase 登录令牌；未绑定的首次 SSO 可签发仅供注册引导的一次性凭据，不能取得账号令牌。已有绑定的 SSO 才能直接登录。关系复用 PocketBase `_externalAuths`：collectionRef、recordRef、provider=oidc、providerId=sub，固定 oidc 对应 dlutsso.saurlax.com；sub 按不透明标识处理，不解析或假设一定为学号。PocketBase 唯一索引保证每个 sub 只能关联一个账号、每个账号只能关联一个 oidc 身份；当前会话与已绑定账号冲突或试图替换已有绑定时拒绝，不切换或合并账号。

OIDC 提供方适配器在 PocketBase 查找账号之前清除 UserInfo 邮箱及邮箱验证声明，完全禁用按 SSO 邮箱匹配、补全或验证本地邮箱；没有 sub 时拒绝认证。绑定关系与创建提示在一个事务中保存，随后调用 PocketBase 标准 RecordAuthResponse，以 OAuth2 方法执行 AuthRule、MFA 与登录事件并签发令牌；不进入默认 OAuth 自动创建、合并、未验证密码重置及关联清理分支。绑定和后续登录保留注册邮箱、密码、邮箱验证状态、其他提供商关联和已有角色。users.email 必填，SSO 中不返回邮箱也不影响绑定；历史无注册邮箱的 SSO 自动创建账号不能继续登录，需要另行迁移关联，不在本次变更中删除或自动合并。

GET /api/v1/account 要求 users 认证，返回当前注册邮箱、oidcBound 状态及绑定的 oidcSubject（未绑定时为空），不返回学校 Token。绑定通过 PocketBase 官方 authWithOAuth2 完成，客户端使用内存 BaseAuthStore 装载当前本地账号令牌；普通 SSO 登录使用空内存认证存储，不能意外绑定其他账号。其他 OAuth2 提供商配置保留。

可信操作员可通过 `configure-oidc --file <私密配置.json> --dir <pb_data目录>` 更新 OIDC 提供商；文件格式为 PocketBase OAuth2ProviderConfig，命令仅更新 `oidc`、启用 OAuth2 并要求注册邮箱，不覆盖其他提供商。配置持久化至 PocketBase；运行中的服务需重启以刷新集合缓存。

## SSO 注册引导

匿名用户先 POST /api/v1/sso/onboarding/start，由服务端设置随机浏览器证明 Cookie（HttpOnly、SameSite=Lax，HTTPS 下 Secure，Path=/api/，有效 10 分钟）。完成真实 OIDC 代码交换且发现 sub 未绑定时，签发随机 48 字符引导票据，以 HTTP 409、code=sso_onboarding_required 和 data.ticket 返回；不创建用户，也不签发 PocketBase 账号令牌。

私有 sso_onboarding 集合保存票据哈希、浏览器证明哈希、服务端验证的 subject、创建默认值及过期时间；普通用户不能通过记录 API 读写。引导票据最长有效 10 分钟，票据本身不足以授权，必须同时匹配发起认证的浏览器 Cookie。新票据签发时清理过期记录及同一浏览器的旧票据。

POST /api/v1/sso/onboarding/inspect 接收 JSON ticket，验证有效期和浏览器证明后仅返回创建提示和到期时间。POST /api/v1/sso/onboarding/complete 还要求 users 认证：用户先注册或用邮箱密码登录，再在同一事务中校验票据、确认 sub 与账号的唯一关联、保存 SSO 创建默认值并删除票据；成功后清除证明 Cookie。完成失败不消费票据，不改绑现有账号，重放、过期、伪造和跨浏览器使用均被拒绝。绑定身份只取服务端待办记录，不接受请求中的 sub、邮箱或性别声明。
