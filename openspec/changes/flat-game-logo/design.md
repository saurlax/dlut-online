## Context

用户要求 SVG 格式、扁平化，可参考大工校徽。最终选定尖角导航箭头版，要求加入 README 和 Android APK；先合并 Android PR #19，logo 单独提交 PR。

## Decisions

- 参考大连理工大学官网 `https://www.dlut.edu.cn/`，对象为页眉标志 `https://www.dlut.edu.cn/images/logo.svg` 与 `https://www.dlut.edu.cn/images/logo.png`，读取日期 2026-09-15。用途仅为圆环和中心几何结构的视觉参考；原始资源不打包。
- 同心圆与工字骨架保留校园关联，放大的尖角导航箭头表达向前探索，右上节点表达在线连接。没有使用官方题字、1949 年份或完整校徽。
- 蓝色为项目设计色 `#005BAC`，不宣称为校方标准色。主图标与横版均透明，无渐变、阴影或外部依赖。
- 主图标位于 `apps/game/assets/ui/branding/dlut-online-mark.svg`，512×512 viewBox。横版 `dlut-online-logo.svg` 为 840×256，名称使用 Arial Bold 默认字距和 kerning 后的矢量路径，不依赖系统字体。
- 圆环厚度、连接柱宽度、横条厚度、在线点直径为 32；内外环、在线点与内环和外环断口、横条与内环断口、横条与箭头斜边的主要净距为 32。此尺度仅用于图形，不修改名称字距。
- README 在产品标题后以 420 像素宽度展示横版资源，使用仓库相对链接。保留原产品介绍，不加入构建或操作说明。
- `apps/game/tools/build_brand_icons.py` 从主图标生成 `assets/ui/android_icon.svg`（白底普通图标）、`android_icon_foreground.svg`（透明自适应前景）与 `android_icon_background.svg`（白色背景）。普通版缩放 0.88；自适应版缩放 0.72 并居中，432 像素画布内标志最大半径约 128.79 像素，小于 Android 安全圆半径 132 像素。
- 修改主图标后运行 `python3 apps/game/tools/build_brand_icons.py` 并提交派生 SVG；Android 导出脚本先执行 `--check`，过期资源必须重新生成。工具从自身位置解析路径，不依赖工作目录。
- 不修改游戏菜单或桌面应用图标。未选中的候选、参考、预览及一次性检查脚本仅保留在已忽略的 `.local/`。

## Risks / Trade-offs

- 主图标建议至少以 64×64 展示，16 像素 favicon 需要单独简化。
- Android 系统控制最终遮罩形状，前景遵循安全区；真机启动器效果仍需设备确认。
- APK 沿用 Android PR #19 的测试签名与发行限制，本次不改变签名或版本策略。
