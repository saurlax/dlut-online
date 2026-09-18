## Context

核对日期：2026-09-18，项目引擎 Godot 4.7.2。桌面 Forward+，Android Mobile。使用 Context7 查询并对照官方类文档；能力来自实际渲染器和 RenderingDevice，不单凭操作系统猜测。

## Rendering Research

| 技术 | 能力与本次处理 |
| --- | --- |
| PBR | Godot 标准材质已有金属度、粗糙度、法线等工作流。它不是独立画质开关，效果取决于现有材质、纹理和光照；不伪造新材质数据。 |
| MSAA / FXAA / SMAA / TAA | 单选关闭、MSAA 2/4/8×、FXAA、SMAA、TAA；TAA 限 Forward+，FXAA/SMAA 限 Mobile/Forward+。MSAA 对几何边缘有效，时域方法可能拖影。 |
| SSAA / 分辨率缩放 | 双线性支持 50–200% 的离散比例；大于 100% 为超采样，开销明显。仅缩放三维缓冲，不缩放 UI。 |
| FSR | FSR 1.0 和 FSR 2.2 均限 Forward+（4.7.2 实际 Mobile 渲染会报告 FSR1 不支持，不采信文档摘要的过宽归纳）；FSR 2 自带时域 AA，100% 可作原生分辨率 AA。不支持大于 100% 的升频。锐化控件映射 Godot 反向参数 2→0。 |
| MetalFX | 空间与时域选项仅在 Forward+ 且 RenderingDevice 报告对应能力时可选；Metal 驱动与 Apple 硬件是前提。时域比例遵守设备报告的上下限，不宣称在 Windows 或 Android 可用。 |
| 各向异性过滤 | 关闭、2/4/8/16×，控制 Viewport 上限，仅作用于已经启用各向异性采样的材质，不替换所有材质。 |
| 太阳阴影 | 关闭、低/中/高，对应 1024/2048/4096 阴影图与不同过滤质量；距离 100/250/500 米。 |
| SSAO / SSIL / SSR | Forward+ 可开启。SSAO 增强接触阴影；SSIL 近似屏幕内反弹光；SSR 不能反射屏幕外物体。维持桌面 SSR 默认开启，其余默认关闭。 |
| SDFGI | Forward+ 可动态开启，不需新增离线烘焙文件；静态场景默认 GI_MODE_STATIC，移动玩家显式 GI_MODE_DISABLED，避免烘入残影。默认关闭，生成/更新与光照收敛存在开销，不保证全场景无漏光。 |
| VoxelGI / LightmapGI | 引擎支持，但需要专门节点、烘焙与资源流程，当前没有这些资源，不提供无效开关。LightmapGI 的静态照明也不能直接替代当前日夜循环。 |
| ReflectionProbe | 引擎支持，需按具体场景布局与更新预算配置，不属于通用一键画质选项。本次不增加探针。 |
| 辉光 / 体积雾 / 消除色带 / 色调映射 | 提供开关和 Linear/Reinhard/Filmic/ACES/AgX 映射；体积雾限 Forward+，默认关闭。体积雾为密度 0.0002 的薄散射层；天气继续控制原有普通雾密度。 |
| 其他能力 | 景深需结合相机焦点设计；遮挡剔除需 Occluder 资源，网格 LOD 需已有层级。硬件光追底层接口不等于现成通用光追开关。本次不增加这些没有配套内容的开关，也不接入外部 DLSS 或帧生成插件。 |

## Decisions

- `graphics_settings.gd` 负责白名单校验、能力判断、ConfigFile 和渲染应用；`graphics_panel.gd` 负责原生 UI；不新增服务端 Autoload。
- 保存到 `user://graphics.cfg` 的 `graphics` 段。未知字段忽略、损坏值回默认、不支持值回退。应用但保存失败时明确提示并允许重试。
- 选项先在草稿修改，应用生效；关闭丢弃未应用修改，恢复默认也需应用。不切换渲染器，不要求重启。
- 默认保留原有 60 FPS、MSAA 2×、100% 比例、Filmic、250 米阴影距离；昂贵的新效果关闭。首页背景 SubViewport 与每个校园的新 Environment 都重新应用保存值。
- 设置是独占输入覆盖层，停走并释放鼠标；关闭仍保持暂停，由另一次世界点击或 Esc 恢复。设置打开时地图/聊天快捷键不能抢占，失焦不恢复走动。Android 设置入口左移，避开现有暂停触控区。
- 原生滚动列表配合固定页头页脚，在窗口缩放下保持按钮可见；保留默认字间距。

## Risks / Trade-offs

- SDFGI、体积雾、8× MSAA、超采样会显著增加显卡负担；以说明和保守默认值控制，不声称低端设备流畅。
- SSR/SSIL 的屏幕空间缺失、SDFGI 的薄壁漏光与收敛不是 UI 能消除的问题。
- MetalFX 的可用性依赖真实设备；Windows 的能力门控验证不等于 macOS 的视觉验收。

## Sources

来源与许可同时维护于根目录 CREDITS.md。
- https://docs.godotengine.org/en/4.7/tutorials/rendering/renderers.html
- https://docs.godotengine.org/en/4.7/classes/class_viewport.html
- https://docs.godotengine.org/en/4.7/classes/class_renderingdevice.html
- https://docs.godotengine.org/en/4.7/classes/class_environment.html
- https://docs.godotengine.org/en/4.7/tutorials/3d/global_illumination/using_sdfgi.html


## Quality Presets

预设按当前渲染器校验后应用，显示模式、垂直同步、帧率上限不参与档位识别，也不被预设覆盖。所有档位使用 Filmic，FSR 锐化保持默认 80%；以下为 Forward+ 配置，Mobile 自动禁用 FSR、SSAO/SSIL/SSR/SDFGI 和体积雾。默认值继续对应平衡，不迁移已有用户配置。自定义是参数匹配结果，不是第五组覆盖值。

| 预设 | 分辨率与抗锯齿 | 过滤与阴影 | 效果 |
| --- | --- | --- | --- |
| 性能 | 67%，FSR 1 + FXAA | 2×，低阴影 100 米 | 关闭反射和新增后期效果 |
| 平衡 | 100%，MSAA 2× | 4×，中阴影 250 米 | SSR，沿用原有默认画质 |
| 画质 | 100%，MSAA 4× | 8×，高阴影 250 米 | SSAO、SSR、辉光、消除色带 |
| 极致 | 100%，MSAA 8× | 16×，高阴影 500 米 | SSAO、SSIL、SSR、SDFGI、辉光、体积雾、消除色带 |

极致不自动开启 200% 超采样，避免把像素数量和 MSAA 成本同时放大；用户仍可手动选择超采样。不承诺任何档位达到固定帧率。
