extends RefCounted
## Local exploration state survives campus switches, never enters the network protocol.

static var enabled := false
static var minutes := 720
static var weather_code := 0
static var revision := 0
const WEATHER := {"晴天": 0, "多云": 3, "雾": 45, "雨": 63, "雪": 73, "雷雨": 95}

static func unix_time() -> float:
	var today := int(Time.get_unix_time_from_system()) + 28800
	return float(today - today % 86400 + minutes * 60 - 28800)

static func weather() -> Dictionary:
	return {"status": "live", "observed_at": unix_time(), "weather_code": weather_code,
		"cloud_cover": 10 if weather_code == 0 else 95, "wind_direction": 270, "wind_speed": 2}
