## Why

整校区包会随精修持续增长。三校区统一采用 100 米网格，让 Web 先进入校园，再按距离下载细节。

## What Changes

- 三校区按世界坐标整百米对齐划分，建筑完整归属并记录覆盖格，非建筑表面按格裁切。
- Web 保留轻量轮廓及通行碰撞，附近细节渐进下载，远离后释放实例。
- 校区切换取消旧请求，支持下载进度、失败重试与资源复用。
- 编辑器和桌面完整资源继续离线可用；本次渐进下载针对 Web。

## Capabilities

### New Capabilities
- `campus-grid-streaming`: 三校区百米网格导出与渐进加载。

### Modified Capabilities

无。此变更接替 campus-resource-packs 中的整校区细节包策略。

## Impact

Godot 校区导出插件、资源加载器、运行时调度、地图进度、相关测试和文档。不新增地理或室内内容。
