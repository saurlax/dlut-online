## Context

用户要求 SVG 格式、扁平化，可参考大工校徽。产品名称固定为 DLUT Online。

## Decisions

- 参考大连理工大学官网 `https://www.dlut.edu.cn/`，对象为页眉标志 `https://www.dlut.edu.cn/images/logo.svg` 与 `https://www.dlut.edu.cn/images/logo.png`，读取日期 2026-09-15。用途仅为校徽圆环和中心几何结构的视觉参考；原始资源留在本地，不打包。
- 重新绘制同心圆与工字骨架，外环右上留出开口并放置连接节点；中部箭头表达第一人称向前探索。没有使用官方校名题字、1949 年份或完整校徽。
- 使用项目设计蓝 `#005BAC`，不将其宣称为校方标准色；背景透明，无渐变或阴影。单色使用时统一替换填充和描边颜色即可。
- 图标 `dlut-online-mark.svg` 使用 512×512 viewBox，建议至少以 64×64 显示以保留中心箭头间隙。横版 `dlut-online-logo.svg` 使用 840×256 viewBox，名称为 Arial Bold 默认字距及字体 kerning 后的路径，使用时无需安装字体。
- 本次交付设计资源，不替换现有菜单或系统应用图标。预览和一次性验证脚本放入已忽略的 `.local/logo/`。

## Risks / Trade-offs

- 细节针对常规品牌展示尺寸设计，16 像素 favicon 需要后续单独简化。
- 标志是游戏项目设计，与官方校徽保持区分。
