# DLUT Online

## 项目定位

- 产品名固定为 **DLUT Online**：以整个大连理工大学为主题的第一人称 MMORPG。
- 仅支持 Windows x86_64 和 macOS universal 桌面客户端，共用 Godot 项目与交互；不支持或导出 Web 游戏。
- 当前建设可行走的校园世界、PocketBase 账号和 ENet 玩家同步，所有玩家必须使用真实账号；室内必须先具备实景照片或有效平面数据再建设，不自行增加活动、战斗、任务或奖励功能。
- 第一批地域素材来自开发区校区。地域名称用于资产、数据与来源记录，不反复出现在产品主界面。
- 美术采用真实比例、自然材质和实景参考。不得用卡通锥体树、统一盒子立面或随意色块冒充精细建模。

## 交互与范围

- 禁止修改字间距。网站、游戏界面和其他设计均保留字体默认字间距，不设置 CSS `letter-spacing`、字体 tracking 或等效字符间距属性；不得通过插入空格模拟字距。

- 界面文案、文档与回复中慎用“·”，不将其作为默认分隔符；优先使用自然语句、逗号或换行，仅在确有必要时使用。
- 每次只增加用户当前要求所必需的内容，优先改进已有场景，不添加无关功能或装饰性产品界面。
- 探索时保持画面干净：不显示项目定位、操作教程、地区标签、技术说明、建模免责声明、参考链接或调试文本。
- 首次启动显示 Godot 封面与邮箱、密码登录表单，直接通过 PocketBase 认证，游戏服确认后进入；正常进入后不再显示登录或继续按钮，认证失效时返回登录封面，传送直接回到游戏。暂停/失焦停止行走，点击世界或 Escape 恢复。操作与数据精度写入文档。
- 保持第一人称行走、环视、奔跑、暂停、失焦停止与碰撞。不增加地标搜索和无关导览工具。用户已授权左上圆形小地图、M/点击打开地图及三校区场景传送。

## 技术与代码规范

- 项目自定义环境变量统一使用 `DO_` 前缀和大写下划线命名（DO 为 DLUT Online 简称）。环境名称使用 `DO_ENV`（`development` / `production`），服务器根地址使用 `DO_API_SERVER_URL`，不使用含义模糊的 `ENV`、`BASE_URL` 或 `BASEURL`。平台约定变量（如现有 `PORT`）保留其兼容用途，不作为项目自定义变量命名范例。
- `DO_API_SERVER_URL` 是 Go HTTP API 根地址，包含协议、主机和可选端口，不含末尾斜杠或接口路径；开发默认 `http://localhost:8415`，生产默认 `https://dlut.online`。客户端从 Go 获取一次性票据和游戏服公网地址后直连游戏服。
- `DO_API_KEY` 是 Go、Godot 游戏服及其他可信服务调用方共享的 API Bearer Key，至少 32 字符；受保护服务接口统一使用 `Authorization: Bearer <DO_API_KEY>`。该变量不进入桌面客户端。
- 游戏、角色、场景和 UI 全部使用 Godot 4 / GDScript / 原生节点。默认使用 Forward+ 渲染器，暂不设置移动端渲染覆盖，后续适配移动端时再添加。
- Godot 游戏不引入外部前端框架、自定义 HTML 游戏 UI 或 JavaScriptBridge；客户端使用 Godot 原生 HTTPRequest 与 ENet，账号 token 在运行时保留于内存，并按 API 根地址隔离存入 macOS 钥匙串或 Windows 凭据管理器；游戏提供原生密码登录，无游客入口；网站提供登录注册与邮箱验证。
- 尺度以米为单位，Y 向上；地图局部 X 向东、Z 向南。角色眼高约 1.7 米。
- 工具代码放 tools/，客户端代码放 scripts/client/，游戏服代码放 scripts/server/，共享代码放 scripts/shared/，原始参考放 references/，运行时资源放 assets/。
- 按职责拆分模型生成器，避免把建筑内部、植被和 UI 混入同一模块。GDScript 使用 snake_case，常量 UPPER_SNAKE_CASE；类型推断不明确时显式标注类型。
- 静态世界模型、环境和灯光必须挂入 .tscn 主场景，打开编辑器即可查看；不要只在 _ready() 中实例化静态世界。运行时逻辑不得重复创建已挂载的节点。
- 场景保留官方 Feature ID 和轮廓。建筑应有独立可替换的模型；改变形状、高度和入口时记录依据。
- 碰撞与装饰分离：可步行楼面、墙、柱和家具使用明确碰撞标记；窗框、树叶等细碎装饰不创建 trimesh 碰撞。
- 桌面客户端导出三个校区现有完整模型与共享材质，地图在本地异步加载，不再维护 Web 网格分包、浏览器资源下载器或第二套源模型。
- 优先按材质合并静态网格，控制三角形、材质、透明玻璃和实时灯光开销，精修须兼顾桌面运行性能。
- 避免无必要的新依赖、框架、抽象、HUD 和测试。涉及门洞、室内通行和碰撞时必须进行有意义的物理检查。

## 参考与交付

- 优先使用用户指定的 http://map.dlut.edu.cn 公开照片/地图和 https://360.toowtech.com/dalian/DUT/ 实景全景。记录源 URL、对象 ID、读取日期和照片用途。全景只证明可见内容，不等于深度、实测尺寸或完整室内平面。
- 照片参考不等于测绘依据。**没有数据的就不做，不要臆想。** 缺少有效照片或平面数据的室内，不生成门厅、房间、家具、楼梯和入口；空接口响应不算数据依据。外观只精修照片能确认的特征，不把已知立面样式扩展到未核实部位。已有尺寸估计必须留档，不声称为真实复刻。
- 原始照片仅作为离线参考，默认不打进客户端包，不显示在游戏中。
- 用 OpenSpec 维护当前变更，最新用户要求优先；规范必须与最终实现一致，不保留相互矛盾的要求。
- 更新中文文案后检查字体子集；新增依赖后检查导出清单。按变更运行相关物理检查、OpenSpec 校验、桌面/服务器导出及客户端实际渲染检查，不再执行 Web 导出或浏览器游戏验收。
- 交付说明清楚写出已实现的建筑/室内范围、验证结果和剩余精度限制，不夸称完成全校室内或照片级复刻。

## 三校区场景

- 固定 ID：lingshui（凌水主校区）、eda（开发区校区）、panjin（盘锦校区），默认 lingshui。场景位于 scenes/campuses/，每个都能直接在编辑器打开。
- 校区传送通过 SceneTree 场景切换，卸载旧场景；不同时加载三个校园模型。
- lingshui 使用官方主校区轮廓和已核对的局部照片立面，精度边界见 references/lingshui/README.md；panjin 保留可落地占位场景，占位体块不代表真实校园布局。eda 保留已有官方轮廓模型。
- 圆形小地图与地图面板全用 Godot 控件绘制；M 或点击打开，打开时暂停行走并释放鼠标，关闭时恢复原状态。

- 大地图必须铺满整个屏幕，使用固定默认比例尺，支持滚轮缩放及左键拖动，禁止拖出边界；校区选择列表在右上角竖直排列；不显示关闭按钮，使用 M 或 Escape 收起。

- 校区专属数据和模型放 assets/campuses/<campus_id>/data/ 与 models/，由校区注册表声明数据路径；共享字体保留 assets/fonts/。无数据的占位校区不复制其他校区资源。

## 仓库整理与提交规范

- 仓库文档可以使用中文编写；commit 信息和 PR 标题使用英文，PR 正文使用中文。
- PR 正文遵循 `.github/pull_request_template.md`，简要说明背景、改动及影响、验证和发布要求；数据库、API 和其他对外接口的变化及兼容性必须写清楚，发布所需配置、环境变量和 migration 无变化时明确写“无”。验证仅记录实际执行的检查及结果，未执行的相关测试说明原因。
- 遵循最小改动：仅修改当前需求直接涉及的文件，不顺带重构、批量格式化、升级依赖或加入无关功能。
- 提交只包含运行所需源码与资源、必要配置、可复用构建工具、有持续价值的回归测试，以及长期维护的规范和来源记录。
- 临时验收报告、过程日志、截图、一次性检查/截图脚本和本机代理生成配置不提交；放入已忽略的 `.local/` 或系统临时目录。现有 docs/verification.md 与 tests/capture.gd 仅供本地使用。
- Godot 缓存、客户端和服务端构建包、可重建的离线 GLB 及其配套纹理不提交；运行时 TSCN、实际依赖的资源与 Godot UID/导入配置按需保留，不一概忽略。
- 根目录 `README.md` 主要用于产品介绍、愿景与长期稳定的产品定位，不写操作按键、启动或部署命令、环境变量、接口协议、架构实现、资源加载细节、验收结果或迭代进度。日常功能开发、修复和架构调整不得顺带修改 README；只有用户明确要求修改 README 或产品介绍时才修改。必要的操作与技术约定维护在对应 OpenSpec、应用技术文档或来源记录中，优先更新已有文档，不为每次迭代新增说明文件。
- README 和长期文档不得依赖未提交的验收文件；验证结果简要写入交付说明，不为每轮工作新增验收 docs。OpenSpec 继续维护需求和任务状态，避免重复过程记录。
- 开始新功能、修复或其他独立任务前，先创建并切换到对应类型的工作分支，不直接在 `main` 上开发。分支使用 `<type>/<short-description>` 命名，描述采用简短的英文 kebab-case；新功能使用 `feat/`，修复使用 `fix/`，纯文档、维护和 CI 任务分别使用 `docs/`、`chore/`、`ci/` 等前缀，例如 `feat/player-connection-hud`、`fix/map-boundaries`。同一任务的后续调整沿用该任务分支；用户明确指定分支时遵循用户要求。
- 提交前检查 git status、diff 和暂存文件清单，逐项确认与当前需求相关；按明确文件路径暂存，不使用 git add . 混入无关内容。用户已授权每次任务完成并通过相关检查后及时创建提交；按独立、可审查的任务拆分，不跨任务堆积未提交改动，不混入他人的未完成工作。
- 所有提交信息使用英文并遵循 Conventional Commits：`type(scope): description`，例如 `feat(server): support PORT environment variable`、`ci: build Docker and desktop clients`；scope 可省略，破坏性变更使用 `!` 或 BREAKING CHANGE 说明。推送包含的提交同样遵循此规范。提交与推送分开：及时提交，用户要求推送时再推送。
- 纯文档、忽略规则或仓库整理不改运行内容时，只做引用和文件清单检查；仅当资源、构建或运行行为受影响时执行相应测试、桌面/服务器导出及客户端渲染验证。

## Monorepo 目录

- 应用按 apps/ 组织：共享 Godot 工程位于 apps/game/；Go HTTP 服务位于 apps/api/，Vue 3 + TypeScript + Vite + Naive UI 网站位于 apps/web/，不另建空的 apps/site/ 或引入 monorepo 框架。
- 本文中的 scenes/、scripts/、assets/、tests/、tools/ 均相对 apps/game/；Godot res:// 也以此为根。编辑器打开 apps/game/project.godot。
- references/、openspec/、AGENTS.md 和 README.md 保留仓库根目录。原始参考路径相对仓库根目录记录，生成工具须从自身位置解析路径，不能依赖调用者工作目录。
- 各应用独立管理依赖和构建产物，桌面客户端导出位于 apps/game/build/windows/ 与 macos/，游戏服位于 server/。Go 提供首页和 /api/v1/ 接口，不再托管 /web/ 或代理 /ws；客户端直连独立 Godot 游戏服。

- Go HTTP 服务位于 apps/api/，自定义业务接口和 Vue 站点直接注册到 PocketBase Router；负责账号、SQLite 持久化、站点、票据与在线查询，不执行世界模拟或代理实时流量。服务启动和参数见 apps/api/README.md。

- 为节省 CI 资源、加快构建，测试归属各自构建工作流，不提取共享 test.yml。build-web.yml 的前置 test 在单个 Linux runner 中仅运行 Vue `vue-tsc --noEmit`、Go `go test -timeout 60s ./...` 和 `go vet ./...`。不运行集成或 E2E 测试，默认不启用 race，不启动真实数据库、系统凭据操作、容器 smoke、游戏联调、物理世界或导出包运行检查；这些仅在相关改动时本地专项执行。Go 集成测试必须带 `//go:build integration`，不进入默认 go test。Godot 将来可加入使用 GUT 的纯函数单元测试，但不得加载校园、连接服务或操作系统凭据；当前轻量测试任务不安装 Godot 或下载 LFS 资产。
- build-web.yml 与 build-game.yml 各自按路径接收 main 分支 push、PR 和手动运行；其他分支 push 不触发构建，避免 PR 重复运行，也提供 workflow_call 供发布复用；Web 的 build 必须 needs: test；Game 当前未接入轻量单元测试，仅做必要生成与导出，不重复执行 Vue/Go 检查，不设空 test 任务；未来加入 Godot 单元测试时直接放在 Game 工作流内并作为其构建前置。不增加 ci.yml 调度层。版本标签由 release.yml 先校验版本，再调用 Web（test → build）和 Game 构建工作流，全部成功后下载本次构建产物上传 GitHub Release。测试失败必须阻止 build 和 release，不能使用 always()、continue-on-error 或跳过测试参数绕过。网站/API 变更构建 Go HTTP 镜像；游戏/API 变更构建 Godot 游戏服镜像并导出 Windows x86_64、macOS universal ZIP，不构建 Godot Web 产物。构建阶段只做必要生成、编译、打包和上传，不运行集成/E2E。Go `DO_API_SERVER_PORT` 默认 8415，并兼容平台 `PORT`；容器 PocketBase 数据位于 `/data/pb_data` 持久卷，Docker 构建上下文为根目录；桌面签名、公证未配置时须如实说明。

## 权威游戏服务

- Godot 无头服务端与客户端共享 apps/game/ 工程，入口为 scenes/server.tscn，客户端逻辑放 scripts/client/，服务端专属逻辑放 scripts/server/，共享运动、碰撞、校区注册表和协议规则放 scripts/shared/。Go apps/api/ 负责站点、票据和在线查询，不执行玩家物理或广播。
- 客户端 GameNetwork Autoload 跨场景保留 ENet 连接；同实例切图不重新取票、不重登，加载期间继续心跳且停止移动，场景就绪后迁移角色。三个校区对所有玩家开放。
- 服务端通过独立 World3D 同时持有三校区碰撞世界，不能同时加载三个视觉校园模型；客户端仍只加载一个校园。服务端静态碰撞从现有场景和标记生成，保留可直接打开的场景，修改来源后重新生成，不能手工复制第二套模型。
- DO_API_KEY 只在可信服务进程环境读取，不导出到客户端。PocketBase Auth Collection 和 SQLite 是用户权威数据源，OIDC/SSO 提供方按部署配置；无有效账号凭据不能申请游戏票据。线上人数必须标记时效，失联不能报告为零人。
- 版本标签发布同时调用 Web 和 Game 工作流，构建 Go HTTP 镜像与独立 Godot Linux amd64 镜像，并导出 Windows/macOS 客户端；双服务及客户端按兼容版本共同发布和回滚。
- 游戏协议版本 5 使用 ENet/UDP，玩家 ID 为 15 字节 ASCII：统一使用 PocketBase 小写账号 ID。控制消息可靠传输，输入与二进制快照使用不可靠有序通道；通过序号、server_tick 和 map_epoch 拒绝迟到状态。客户端可达的 `enet://` 或 `enets://` 端点存入 PocketBase `servers` Collection，由票据接口动态下发；客户端不按环境限制协议，`enet://` 使用明文，`enets://` 启用 DTLS 并校验证书；Go API 的 production 配置仍只下发 `enets://`。游戏服使用 `DO_GAME_SERVER_PORT` 监听 UDP，生产使用 DTLS 证书，客户端校验证书。

- 网站构建从 apps/web 输出到 apps/api/static/，正式编译及前端产物集成测试前先运行 pnpm install --frozen-lockfile、pnpm build。CI 纯单元测试不构建前端，只在临时工作区的 static/ 放入编译用占位文件以满足 go:embed；该文件不提交、不传给构建任务，正式镜像使用独立检出和真实前端产物。apps/api/Dockerfile 构建前端并嵌入 Go，Compose 仍只部署 game 与 web，网站不需要 Node 运行服务。网站可以使用 Vue，游戏 UI 仍限 Godot。

- Web 前端（apps/web）默认不新增或维护测试文件、测试脚本及测试框架；常规改动以 TypeScript 类型检查、生产构建和必要的浏览器检查为主，避免过度测试。仅在用户明确要求前端自动化测试时增加；此约定不影响 Go 服务和 Godot 的必要检查。

- 客户端使用 Godot 原生邮箱、密码表单调用 PocketBase 密码认证，不打开本机回调端口。密码输入隐藏，提交后清空，不写入文件或日志；账号 token 安全保存到系统凭据库，启动时通过 PocketBase auth-refresh 验证并刷新，认证失效或退出时清除；网络暂时故障不删除有效凭据。无账号提示去 dlut.online 注册。未来 OIDC 与移动系统认证另行实现。
