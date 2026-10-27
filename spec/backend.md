# 账号与持久化

## 服务组成

Go 直接集成 PocketBase，复用其 Router、账号 API、管理后台、SQLite 与迁移机制。当前注册前端静态文件服务，保留 PocketBase 自带 `/api/health` 和 `/_/`，不重复建设健康检查或认证系统。

沿用默认 users 认证集合，新增 profiles、items、inventory 集合。每个账号一个 profile，以 userId 唯一约束。inventory 记录 userId、itemId、slotId 与 color；userId 和 slotId 联合唯一。items 新增整数 capacity（0–30），背包定义提供 10、20、30 格。slotId 为 head/top/bottom/feet/backpack、独立 hotbar:0 至 hotbar:9 或 bag:0 至 bag:29，bag 位置必须在已穿背包容量内。玩家仅能读取自己的角色和背包，所有物品写操作经过 Go 接口。

GET /api/v1/character 返回本人角色、物品和由已穿背包计算的 capacity，未穿背包时为 0；POST /api/v1/character 在同一事务内创建角色并发放初始衣物，重复创建返回已有角色；POST /api/v1/character/wear 接收物品实例 id，在事务内完成穿脱及同槽交换；POST /api/v1/character/move 接收实例 id 与目标 slotId，允许常驻物品栏、已解锁背包格与匹配装备槽间移动或交换，验证交换双方均能占用最终位置。所有操作校验归属、唯一位置与操作后容量，容量不足时整个事务回滚。四个接口均要求 users 认证，注册与密码登录沿用 PocketBase API。未知 API 返回错误，不能返回网页首页。

升级迁移为 items 增加 capacity 并登记三个背包定义。已有角色补发并穿上至少 10 格背包；存在旧背包内容的角色按最高占用格补发足够的 10/20/30 格背包，原有背包物品位置保持不变。旧 hand 位置迁移至 hotbar:0；物品栏固定 10 格，不占背包容量。新角色在创建事务中直接穿上 10 格校园背包，重复创建不重复发放。

## 数据权威

后续多人会话必须绑定有效账号。客户端不能直接写入权威位置、移动速度、校区或其他游戏规则字段。游戏会话使用短期凭据与登录会话关联；身份校验与撤销策略随会话功能一同实现。

逐帧位置和输入在 Go 世界内存维护，经 Pion 数据通道同步；PocketBase Realtime 为 SSE 记录订阅，不用于移动同步。需要持久化的角色状态按检查点保存，数据库操作不阻塞模拟时间步。后端进程异常后的恢复以持久化检查点为准，不承诺逐帧恢复。

当前部署为单实例。不得让多个独立写实例共享同一个 SQLite 数据目录；扩容前需设计世界归属和持久化服务边界。

## 当前配置

| 配置 | 约定 |
| --- | --- |
| `DO_WEB_ROOT` | 静态导出目录，默认 `./public`，容器为 `/app/public` |
| `--http` | PocketBase 监听地址，容器固定默认 `0.0.0.0:8415` |
| `--dir` | PocketBase 数据目录，容器为 `/data/pb_data` |

未使用的环境变量不提前加入。任何管理员密码、账号令牌和后续 TURN 凭据均不打入前端或镜像层。
