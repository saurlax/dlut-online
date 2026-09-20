> 本文记录初版原型；后续外观参数、材质与动作以 `../character-quality/design.md` 为准。

## Context

本轮零预算验证免费人体资产是否适合校园项目。使用 MakeHuman Community / MPFB 核心图形数据，原始输入由 `references/shared/characters/source.json` 固定 URL、Git commit 和逐文件 SHA-256。MPFB 本身是 GPL 工具，核心图形资产单独使用 CC0；本工程仅读取图形数据，没有集成 MPFB、MakeHuman 或 Humanizer 的程序代码。

## Decisions

- 采用青年 Asian 男女预设，混合对应标准肌肉/体重形变。该标签是上游分类，不代表中国人外观已经完成美术验收。人物为虚构样本，不来自真实学生肖像。
- 使用上游 game_engine 53 骨骨架和权重。身体与衣物共享骨架；导出时使用带骨架名称的显式相对路径，避免 `..` 被主工程旧版默认值省略后，在 Godot 4.6+ 独立工程中丢失绑定；每顶点保留权重最高的四项并归一化。衣服位置由官方 MHCLO 的身体顶点映射与轴向比例生成，权重按相同映射插值。
- MakeHuman Y 向上数据转换到 Blender Z 向上，再通过 glTF 转换到 Godot Y 向上。脚底归零，裸身参考高度男 1.75 m、女 1.65 m；这是原型设计尺度，不是实测人物尺寸。
- 每人两套整套便装，尚未拆成独立上衣/裤子插槽；使用对应 `delete_verts` 遮蔽衣物内部身体，并保留两套独立遮蔽网格，切换时只显示一组。运动鞋、眼睛、眉毛与睫毛共享材质资源，男女分别使用短发和马尾。
- 第一版四个滑条控制脸宽、下颌宽、鼻宽、嘴宽，各由增/减两个形变组成；最大幅度采用上游形变的 50%。头发和眼部配件同步位移。尚未支持全身体型、眼位变化、表情组合或口型。
- 站立、行走、奔跑为自行编排并烘焙的简易骨骼测试动画，检验蒙皮与动作切换；导出保留静态动画轨道，避免站立手臂恢复绑定姿势；不是动作捕捉或最终运动表现，没有脚底 IK、根运动、裙摆/头发物理。后续可以替换动作库，骨架映射与默认姿势需要重新验证。
- 皮肤和布料使用原始漫反射贴图，最大 2048 像素；启用 mipmap。此原型未采用上游法线、SSS 或专门毛发着色器，黑发以材质乘色实现。眼球透明区域、发片、眉毛和睫毛使用 alpha scissor。
- 捏脸值保留在每个 MeshInstance3D 上，不修改共享 Mesh；切换男女或衣服保留滑条值。重置恢复四项为零、第一套服装和站立，保留当前性别和观察角度。

## Preview and Build

Godot 4.7.2 打开 `apps/game/scenes/characters/preview.tscn` 并运行当前场景（F6）。右侧选择人物、服装与动作；四个滑条调整脸部，拖动空白区域旋转人物，滚轮缩放；全身/面部/背面按钮切换观察位置。界面采用原生控件和默认字距。

从仓库根目录重建，工具自行解析仓库位置，不依赖调用目录。离线输入、GLB 与独立预览工程均存放于忽略的 `.local/characters/`：

```text
python apps/game/tools/characters/fetch_sources.py
blender --background --factory-startup --python-exit-code 1 --python apps/game/tools/characters/build_samples.py -- --inputs <仓库绝对路径>/.local/characters
godot --headless --path apps/game --editor --import --quit
godot --headless --path apps/game --script tools/characters/pack_samples.gd -- <仓库绝对路径>/.local/characters/generated
godot --headless --path apps/game --editor --import --quit
godot --headless --path apps/game --script tests/character_avatar.gd
python apps/game/tools/characters/export_preview.py --godot <Godot可执行文件>
```

生成工具使用 Blender 5.1.2 验证。`fetch_sources.py --verify-only` 仅检查本地输入；`--no-proxy` 可用于当前网络需要直连时。系统资产包通过 HTTP Range 按需取出指定成员，解压后校验 SHA-256；来源内容变化时失败，不静默使用新版。

首次从零生成时，第一轮 Godot 导入可能提示人物 TSCN 尚不存在，`pack_samples.gd` 生成后必须再次导入并检查无人物相关错误。运行模型为 TSCN 和压缩 ArrayMesh `.res`，中间 GLB 不提交。原始服装和人体数据仅留在本地缓存；运行资产按 Git LFS 集中提交。

独立导出工具只复制人物场景、角色脚本、人物资源、字体及第三方声明，生成不含 Autoload 的本地预览工程。Windows 产物为内嵌资源 EXE；支持另行导出 macOS 测试 ZIP，但不替代正式发行签名及架构检查。当前校园入口、正式 export_presets、账号、服务端和网络协议不修改，正式发行包暂不带试衣入口。

## Validation and Limits

本地回归检查覆盖男女两种样本、两套服装、共同骨架、归一化权重、三个动作的多个采样时刻、形变实例隔离、参数边界与重置。形变和衣服还需要实际渲染检查；数值边界检查不等同于完整穿模检测。

尚未接入校园人物、账号外观持久化、多人外观同步、人物 LOD 或 Android 真机验收。服务端不加载视觉人物，本轮不修改碰撞或运动规则。数据库、API、部署环境变量与 migration：无。
