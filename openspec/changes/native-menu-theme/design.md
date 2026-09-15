## Context

登录与主菜单使用原生白色简洁控件，背景轮播现有校园模型的真实渲染。运行时不复制校园模型文件，也不加载玩法场景来充当背景。

## Goals / Non-Goals

目标：多镜头缓慢漫游轮播、简洁前景、编辑器可预览、认证行为保持正确。
非目标：新增建筑与室内、改动校园精度、引入视频或 HTML UI、增加玩法和导览工具。

## Decisions

- `scenes/ui/login_menu.tscn` 保存原生控件、渐变遮罩与独立 SubViewport；`scenes/main.tscn` 静态挂载该菜单。
- `assets/ui/campus_theme.tres` 统一默认中文字体、白色文字、半透明输入框、细边按钮和焦点状态。字间距保持默认。
- `scripts/client/menu_cover.gd` 异步加载 `scenes/ui/campus_backdrop.tscn`。后者静态引用现有凌水模型和原生环境、相机，可直接在 3D 编辑器打开；不调用 campus.gd，不生成玩家、地图数据或碰撞。
- `scripts/client/campus_backdrop.gd` 保存三段相机起终点与注视点，每段 14 秒，用平滑插值移动，首尾各 0.8 秒黑场渐变，循环顺序固定。切换只更新一台相机，始终仅有一个背景校园实例。
- 取景使用已具备照片支持立面的主楼 77386、伯川图书馆 77447 和令希图书馆 77357。依据与精度边界见 references/lingshui/buildings/basis.md。相机位置是展示构图参数，不是实测路线；不新增地形、绿化或未核实建筑。
- 背景使用固定白天展示光照，与正式校园实时天气无关。展示脚本不访问账号服务或系统凭据库。
- 前景以 1280×720 等比缩放，背景按窗口铺满；主菜单隐藏正常账号提示，加载/断线错误仍显示必要状态。
- 校园内 HUD 复用菜单控件时关闭背景加载，避免探索时再创建一套校园视觉实例。离开菜单后视口与背景随场景一起释放。

## Editor Preview

打开 `apps/game/project.godot`，打开 `res://scenes/ui/login_menu.tscn` 并切到 2D。选择根节点 Menu：Preview Page 切换 Login/Main menu；Preview Shot 选择三个取景；Animate Preview 控制编辑器里的自动漫游，默认关闭以便编辑。背景异步加载后显示。

F6 运行当前展示场景，可以看到自动镜头轮播和按钮状态，不执行认证。F5 从 `scenes/main.tscn` 运行真实登录。镜头场景位于 `res://scenes/ui/campus_backdrop.tscn`，镜头参数位于 `scripts/client/campus_backdrop.gd`，共享主题在 `assets/ui/campus_theme.tres`。

## Risks / Trade-offs

背景会增加登录页的视觉资源与 GPU 开销，但不会启动游戏物理或连接服务。源模型的未精修区域仍保持既有精度，不把当前展示称为照片级复刻。macOS DMG、原生签名与 Linux 服务端二进制需要相应平台检查；本地可验证其资源包。
