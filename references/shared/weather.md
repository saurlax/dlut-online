# 天气与太阳位置数据


2026-09-11 再次读取 [官方校区接口](http://map.dlut.edu.cn/openmap/mapi/campus/v1)，与 `mapping/campuses.json` 一致。以下经纬度沿用源站未声明的坐标系，作为天气格点查询与近似太阳位置输入，不作为测绘坐标。

| 游戏 ID | 官方对象 ID | 纬度 | 经度 |
|---|---|---|---|
| lingshui | 77291 | 38.879216 | 121.526959 |
| eda | 77298 | 39.084522 | 121.816327 |
| panjin | 77299 | 40.686249 | 122.124453 |

同日实测 [Open-Meteo Forecast API](https://open-meteo.com/en/docs)：`https://api.open-meteo.com/v1/forecast`，参数 `latitude`、`longitude`、`current=cloud_cover,weather_code,wind_speed_10m,wind_direction_10m`、`wind_speed_unit=ms`、`timeformat=unixtime`、`timezone=Asia/Shanghai`、`forecast_days=1`。三位置均返回有效数据。返回格点位置可偏离查询中心数公里，数据来自天气模型，不能视为校内传感器实时实测。

[服务与许可](https://open-meteo.com/en/pricing)：免费接口适用非商业用途，当前限每日 10,000 次；商业使用采用付费 customer-api 与 API Key。默认三校区每 15 分钟各一次，每日约 288 次，不随玩家数增长，失败重试另计。数据署名 Open-Meteo，许可 [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)。游戏将云量、风向和天气代码转换为程序化体积云层、光照与雾效，属于视觉化处理，不还原真实云形；桌面包内嵌根目录 `CREDITS.md`，macOS DMG 同时附带该声明。

太阳位置使用 NOAA [Solar Calculation Details](https://gml.noaa.gov/grad/solcalc/calcdetails.html) 的分数年、太阳赤纬与时间方程近似法，固定 UTC+8，无夏令时。没有大气折射、高程遮蔽或精密天文历表，不保证地平线日出时刻的分钟级精度。

来源与许可统一见 [CREDITS](../../CREDITS.md#三天气数据与计算方法)。

2026-09-20 水面复用上述天气字段，不新增上游请求。10 米风速驱动视觉波幅、传播相位速度和细波强度；气象来向转换为局部传播方向 `(−sin θ, cos θ)`，对应 X 向东、Z 向南。20 秒时间常数平滑，逐帧连续推进波相位。这是风场驱动的美术近似，不是水文模型或实测水流。单人模式保持离线，沿用本地天气中的风参数；过期/缺失多人样本采用既有中性轻风回退。
