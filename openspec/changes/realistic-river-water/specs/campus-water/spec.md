## ADDED Requirements

### Requirement: Shared natural water surface
既有校园水体 SHALL 使用共享原生 Godot ShaderMaterial，在世界坐标下叠加连续移动的细波纹法线，使用非金属反射和随视角变化的物理高光，接受现有天空、太阳、昼夜和雾效。

#### Scenario: Existing water appears in the editor and client
- **WHEN** 打开凌水或开发区的现有校园场景
- **THEN** 已有水面直接引用共享材质，不需要运行时生成或替换节点，生成器重建后仍使用同一材质。

### Requirement: Cross renderer water rendering
水面 SHALL 支持 Forward+ 与 Mobile。桌面使用天空反射和屏幕空间反射，Mobile 使用天空反射；水面材质不得依赖 Forward+ 专用屏幕纹理。

#### Scenario: Distant or mobile water
- **WHEN** 水面远离镜头或由 Mobile 渲染
- **THEN** 远处细波纹衰减并增加粗糙度，Mobile 无 SSR 时仍保留动画、天空反射和太阳高光。

### Requirement: Preserve source geometry and scope
水面修改 SHALL 保留已有官方 Feature ID、轮廓、网格、水位和碰撞，不补造缺乏依据的河床、河岸和新水体。

#### Scenario: No depth or water feature data
- **WHEN** 校园缺少河床深度或没有 water 特征
- **THEN** 已有水面采用不透明材质，不渲染虚构河底；没有 water 特征的校园不新增水面。
