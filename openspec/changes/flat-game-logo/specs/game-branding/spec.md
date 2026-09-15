## ADDED Requirements

### Requirement: 扁平化矢量标志
项目 SHALL 提供透明背景蓝色主图标和完整产品名 DLUT Online 的横版标志，使用同心圆、尖角导航箭头和右上在线点，主要间距统一为 32 单位。所有可见元素采用矢量路径或基础形状，无位图、渐变、阴影和自定义字间距。

#### Scenario: 展示标志
- **WHEN** 打开主图标或横版 SVG
- **THEN** 正确显示最终选定的尖箭头版，横版额外显示路径化的完整产品名，未选中的候选不作为交付资源

### Requirement: README 品牌展示
README SHALL 展示横版标志，图片使用仓库内相对链接且具备 DLUT Online 替代文本，不改变已有产品介绍。

#### Scenario: 浏览仓库首页
- **WHEN** GitHub 渲染 README
- **THEN** 在产品标题后以 420 像素宽度展示横版标志

### Requirement: Android 启动图标
Android APK SHALL 将选定主图标用于普通和自适应启动图标；普通图标白底蓝标，自适应图标使用白色背景与透明前景，完整图形位于安全圆内。

#### Scenario: 应用启动器遮罩
- **WHEN** 启动器采用圆形或圆角方形遮罩
- **THEN** 尖箭头、圆环和在线点保持完整，前景在 432 像素画布中的最大半径不超过 132 像素

### Requirement: 图标来源一致
Android 图标 SHALL 由主 SVG 通过可复用工具生成，导出 APK 前检查派生文件是否过期。

#### Scenario: 过期图标
- **WHEN** 主标志已修改但未重新生成 Android 图标
- **THEN** APK 导出前检查失败并提示运行生成工具，不继续使用旧图标打包
