# 官方照片与建模记录

读取日期：2026-09-09。来源：http://map.dlut.edu.cn 。原图仅作离线参考，不打入游戏包。照片 URL 中的年份是文件名信息，不保证拍摄时间或现状。

## 已用于本轮的外观依据

- 信息楼（77914）：77914-0.jpg、77914-1.jpg。可见灰褐墙面、浅色横向饰带、成组窗带、顶部独立窗及屋檐。根据可见楼层调整视觉比例；米制楼高、窗宽仍非实测。
- 图书馆（77917）：77917-0.jpg、77917-1.jpg、77917-2.jpg。可见弧形玻璃幕墙、深色窗格、浅色竖向构件与顶部环架。弧形位置采用原有官方轮廓，不生成未核实背面细节。
- 信息楼、图书馆保留既有局部精修。2026-09-14新增宿舍1、2、3舍的局部外观，范围如下；其余照片仍为后续核对资料。

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

## 宿舍局部精修（2026-09-14）

配准与来源索引见 `residence_facades.json`：保留官方照片对象ID、原图URL、原读取日期、本次复核日期及SHA-256。原图使用既有离线文件，不作为游戏贴图。

| Feature ID | 配准 | 本次外观 |
|---|---|---|
| 77931 学生宿舍1舍 | 77931-0楼号1；77933-0右侧同框1舍位于2舍东侧，对应官方地图；南边9由东向西 | 可见中段五层窗列、浅紫色窗下饰板、顶层窗及栏杆、偏西黄色双层双格阳台框 |
| 77933 学生宿舍2舍 | 77933-0/1楼号2；左邻3舍、右邻1舍与官方地图对应；南边7由东向西 | 可见中段五层窗列、浅紫色窗下饰板、顶层窗及栏杆、偏东黄色双层双格阳台框 |
| 77935 学生宿舍3舍 | 77935-0右端楼号3，77933-0左侧同框3舍与官方地图中2舍西南邻接互证；东边4由北向南 | 可见中段五层窗列、浅紫色窗下饰板、顶层窗及栏杆；不复制1、2舍黄色框 |

三栋保留原官方轮廓及原有23米估计高度，均非测绘复刻。中段暂配准为边长14%—86%；1、2舍各12列、3舍14列是按可辨分格作的模型离散，遮挡及透视使精确列距仍待测量。窗中心4.8米起、五排间距3.15米，窗高2.15米、宽为列距77%；顶层窗中心20.65米，窗高1.75米。顶层楼板19.25米、挑檐23.1米，栏杆高约0.94米。黄色框中心分别在有向边69%和28%，宽约两列、楼板标高9.85/13/16.15米、厚0.2米、深1.25米、框带宽0.55米；以上米制尺寸、突出量和色彩均为照片比例估计。当前没有校准照片拍摄位姿。

仅这些可见中段制作细节。两端竖向窄窗、端墙、底层店面/门窗、连廊、阳台后方门窗、照片未显示的背面和室内待进一步核实；保留封闭外壳，不提供进入阳台或室内的门洞。照片中的空调、晾衣、车辆和招牌不属于本次范围。原有三栋通用全周窗格被替换，不把同一立面款式扩展到未验证的面。

外壳、屋顶、顶层楼板/柱及双层阳台楼板/隔墙参与碰撞；窗框、栏杆、黄色饰框和饰板只渲染。静态网格按每栋材质及碰撞属性合并，使用不透明玻璃，不增加实时灯光。楼栋仍可通过Feature节点独立替换。
