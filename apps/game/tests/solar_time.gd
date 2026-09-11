extends SceneTree

const Solar = preload("res://scripts/shared/solar_time.gd")
func _initialize() -> void:
	# Equinox, local times UTC+8, independent of host timezone.
	var midnight := float(Time.get_unix_time_from_datetime_string("2026-03-20T00:00:00")) - Solar.UTC8
	for campus: String in Solar.LOCATIONS:
		var morning := Solar.sun_direction(midnight+7*3600, campus)
		var noon := Solar.sun_direction(midnight+12*3600, campus)
		var evening := Solar.sun_direction(midnight+17*3600, campus)
		assert(morning.x > 0.5 and evening.x < -0.5, "Sun must rise in east and set in west")
		assert(noon.y > 0.65 and noon.z > 0.4, "Noon sun must be elevated to the south")
		assert(Solar.sun_direction(midnight, campus).y < -0.6, "Local midnight must be dark")
		var summer := float(Time.get_unix_time_from_datetime_string("2026-06-21T12:00:00"))-Solar.UTC8
		var winter := float(Time.get_unix_time_from_datetime_string("2026-12-21T12:00:00"))-Solar.UTC8
		assert(Solar.sun_direction(summer,campus).y > Solar.sun_direction(winter,campus).y+0.3)
	assert(not Solar.usable_weather({},midnight))
	assert(Solar.usable_weather({"status":"stale","observed_at":midnight-7200},midnight))
	assert(not Solar.usable_weather({"status":"stale","observed_at":midnight-10801},midnight))
	print("PASS: UTC+8 solar orientation, seasonal altitude and weather expiry")
	quit()
