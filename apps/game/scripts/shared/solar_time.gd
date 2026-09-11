extends RefCounted

const UTC8 := 28800
const LOCATIONS := {
	"lingshui": Vector2(38.879216, 121.526959),
	"eda": Vector2(39.084522, 121.816327),
	"panjin": Vector2(40.686249, 122.124453),
}

# NOAA fractional-year approximation. X east, Y up, Z south.
static func sun_direction(unix_seconds: float, campus: String) -> Vector3:
	var local := Time.get_datetime_dict_from_unix_time(int(unix_seconds) + UTC8)
	var year_start := Time.get_unix_time_from_datetime_dict({"year":local.year, "month":1, "day":1})
	var day := floori((unix_seconds + UTC8 - year_start) / 86400.0) + 1
	var hour := float(local.hour) + float(local.minute) / 60.0 + float(local.second) / 3600.0
	var year: int = local.year
	var days := 366.0 if year % 4 == 0 and (year % 100 != 0 or year % 400 == 0) else 365.0
	var gamma := TAU / days * (day - 1 + (hour - 12.0) / 24.0)
	var equation := 229.18 * (0.000075 + 0.001868*cos(gamma) - 0.032077*sin(gamma) - 0.014615*cos(2*gamma) - 0.040849*sin(2*gamma))
	var declination := 0.006918 - 0.399912*cos(gamma) + 0.070257*sin(gamma) - 0.006758*cos(2*gamma) + 0.000907*sin(2*gamma) - 0.002697*cos(3*gamma) + 0.00148*sin(3*gamma)
	var location: Vector2 = LOCATIONS.get(campus, LOCATIONS.lingshui)
	var latitude := deg_to_rad(location.x)
	var angle := deg_to_rad((hour*60.0 + equation + 4.0*location.y - 480.0)/4.0 - 180.0)
	return Vector3(-cos(declination)*sin(angle), sin(latitude)*sin(declination) + cos(latitude)*cos(declination)*cos(angle), sin(latitude)*cos(declination)*cos(angle) - cos(latitude)*sin(declination)).normalized()

static func usable_weather(sample: Dictionary, unix_seconds: float) -> bool:
	return sample.get("status") in ["live", "stale"] and float(sample.get("observed_at", 0)) > unix_seconds - 10800.0 and float(sample.get("observed_at", 0)) <= unix_seconds + 900.0
