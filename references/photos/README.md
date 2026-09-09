# 官方照片与建模记录

读取日期：2026-09-09。来源：http://map.dlut.edu.cn 。原图仅作离线参考，不打入游戏包。照片 URL 中的年份是文件名信息，不保证拍摄时间或现状。

## 已用于本轮的外观依据

- 信息楼（77914）：77914-0.jpg、77914-1.jpg。可见灰褐墙面、浅色横向饰带、成组窗带、顶部独立窗及屋檐。根据可见楼层调整视觉比例；米制楼高、窗宽仍非实测。
- 图书馆（77917）：77917-0.jpg、77917-1.jpg、77917-2.jpg。可见弧形玻璃幕墙、深色窗格、浅色竖向构件与顶部环架。弧形位置采用原有官方轮廓，不生成未核实背面细节。
- 本轮只精修这两栋建筑的照片可见外观，不把照片款式套到其他建筑。其余照片作为后续核对资料。

## 室内：原地图接口无有效几何数据

- 信息楼、教学楼 A 区楼层接口返回空列表。
- 图书馆楼层接口有一层记录，但 graph 接口的 rooms、walls、bounds、doorPoints 均为空。
- 当前取得的照片为外观照片，没有足以重建室内的照片或平面数据。没有生成室内房间、门厅、家具或入口。
- 楼层查询 URL 记录在 *-floors.json；图书馆平面查询为 http://map.dlut.edu.cn/openmap/mapi/indoor/graph/v1/simple?levelAt=1&buildingId=77917 ，响应保存为 77917-floor-1-graph.json。

## 照片索引

| 对象 | 名称 | 张数 | 接口 |
|---|---|---:|---|
| 77912 | 开发区校区南门 | 2 | http://map.dlut.edu.cn/openmap/mapi/image/v1?ownerType=building&ownerId=77912 |
| 77914 | 信息楼 | 2 | http://map.dlut.edu.cn/openmap/mapi/image/v1?ownerType=building&ownerId=77914 |
| 77917 | 图书馆 | 3 | http://map.dlut.edu.cn/openmap/mapi/image/v1?ownerType=building&ownerId=77917 |
| 77921 | 综合楼 | 2 | http://map.dlut.edu.cn/openmap/mapi/image/v1?ownerType=building&ownerId=77921 |
| 77923 | 体育馆 | 2 | http://map.dlut.edu.cn/openmap/mapi/image/v1?ownerType=building&ownerId=77923 |
| 77925 | 教学楼A区 | 1 | http://map.dlut.edu.cn/openmap/mapi/image/v1?ownerType=building&ownerId=77925 |
| 77927 | 教学楼C区 | 2 | http://map.dlut.edu.cn/openmap/mapi/image/v1?ownerType=building&ownerId=77927 |
| 77928 | 教学楼B区 | 1 | http://map.dlut.edu.cn/openmap/mapi/image/v1?ownerType=building&ownerId=77928 |
| 77931 | 学生宿舍1舍 | 1 | http://map.dlut.edu.cn/openmap/mapi/image/v1?ownerType=building&ownerId=77931 |
| 77933 | 学生宿舍2舍 | 2 | http://map.dlut.edu.cn/openmap/mapi/image/v1?ownerType=building&ownerId=77933 |
| 77935 | 学生宿舍3舍 | 1 | http://map.dlut.edu.cn/openmap/mapi/image/v1?ownerType=building&ownerId=77935 |
| 77937 | 学生宿舍4舍 | 1 | http://map.dlut.edu.cn/openmap/mapi/image/v1?ownerType=building&ownerId=77937 |
| 77938 | 学生宿舍5舍 | 1 | http://map.dlut.edu.cn/openmap/mapi/image/v1?ownerType=building&ownerId=77938 |
| 77941 | 第六学生宿舍 | 1 | http://map.dlut.edu.cn/openmap/mapi/image/v1?ownerType=building&ownerId=77941 |
| 77943 | 大连理工大学第六学生食堂 | 1 | http://map.dlut.edu.cn/openmap/mapi/image/v1?ownerType=building&ownerId=77943 |

## 新来源补充

后续调查用户提供的全景站已发现图书馆真实室内影像，见 ../panorama/README.md；因此本节“无室内照片”的判断仅限于本目录原官方地图照片接口。全景没有实测尺寸或深度，不能据此臆造未覆盖区域。
