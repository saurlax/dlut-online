# 开发区校区建模依据

读取时间：2026-09-09。来源为用户指定的大连理工大学官方校园地图 `http://map.dlut.edu.cn`。

## 可核对的数据

- `campuses.json`：`/openmap/mapi/campus/v1` 的公开返回。开发区校区 ID 77298，中心为 (121.816326506145, 39.084522240291)。
- `development-campus-bounds.json`：`/openmap/mapi/bd/v1/bound` 中筛选到开发区的 27 个轮廓。源站全部 550 条记录按每个点位于经度 121.80–121.83、纬度 39.07–39.10 筛选，不含其他校区。
- `tiles/`：官方二维底图 `/map?lyrs=lm30&x={x}&y={y}&z=16` 的局部参考瓦片，用于人工描摹道路中心线；瓦片不包含在客户端成品中。

## 精度边界

建筑和场地名称、占地多边形及相对位置来自官方数据。坐标沿用源站坐标系，转换为校园局部近似米制坐标，不宣称测绘级定位精度。

原始轮廓数据没有建筑楼高、楼层或地形高程。现已通过独立照片接口取得部分外观照片，见 photos/README.md。楼高、窗带、屋顶、校门外观、树木分布、山体起伏、运动场内部划线和场地材质均为初版近似表现。道路中心线参照底图人工描摹，宽度与转角细节近似。矩形底座不是校区实际红线边界。

本模型是公开地图覆盖范围的初版模型，其中信息楼与图书馆已按官方照片修正部分立面，不代表全部现状建筑，也不是官方发布的三维模型。二期用地保留地图标注的地面区域，未凭空添加未核实建筑。

## 更新

修改原始来源数据或 `apps/game/tools/prepare_campus.py` 中的高度估计，然后在仓库根目录依次执行 `python3 apps/game/tools/prepare_campus.py`和 `godot --headless --path apps/game --script tools/build_model.gd`，最后运行 `godot --headless --path apps/game --script tools/server_export/build_worlds.gd` 更新服务端碰撞。精细建筑可以以相同 Feature ID 替换，保持 Feature ID 和空间坐标一致。
