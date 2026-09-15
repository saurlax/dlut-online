## Why

校园模型缺少可追溯的高程基础。需先为凌水和开发区准备独立的真实地表高程数据，再为地形与建筑分离提供依据。

## What Changes

- 引入固定版本 Copernicus GLO-30 两校区缓冲范围裁剪与无损高度网格。
- 增加可复现下载、校验及裁剪工具，保留坐标、基准、来源和精度边界。
- 更新目录索引及正式第三方许可声明。

## Capabilities

### New Capabilities

- `campus-terrain-data`：独立高程参考数据及可复现处理。

### Modified Capabilities

无。

## Non-goals

本次不更改运行时场景、道路、建筑基础或碰撞；不将 DSM 宣称为裸地测绘，不猜测官方轮廓的坐标基准。

## Impact

影响 references、离线工具及 CREDITS。离线生成依赖系统 GDAL，游戏无新增依赖。数据库、API、环境变量、migration 及发布配置：无。
