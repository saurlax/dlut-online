shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;

uniform sampler2D ripple_normal : hint_normal, repeat_enable, filter_linear_mipmap;
uniform vec4 water_color : source_color = vec4(0.105, 0.155, 0.135, 1.0);
uniform float ripple_strength : hint_range(0.0, 1.0) = 0.32;
uniform float surface_roughness : hint_range(0.02, 1.0) = 0.16;
// X east, Y south; weather is converted from meteorological FROM direction.
uniform vec2 wind_velocity = vec2(1.0, 0.0);
uniform float wave_phase = 0.0;

varying vec2 water_position;
varying float shoreline;

vec2 wind_direction() {
	return length(wind_velocity) > 0.01 ? normalize(wind_velocity) : vec2(1.0, 0.0);
}

float amplitude() {
	return 0.008 + 0.16 * (1.0 - exp(-length(wind_velocity) / 9.0));
}

void vertex() {
	water_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	shoreline = UV.x;
	vec2 direction = wind_direction();
	vec2 crosswind = vec2(direction.x * 0.8 - direction.y * 0.6, direction.x * 0.6 + direction.y * 0.8);
	float wave = sin(dot(water_position, direction) * 1.1 - wave_phase);
	wave += 0.38 * sin(dot(water_position, crosswind) * 2.3 - wave_phase * 1.4);
	VERTEX.y += amplitude() * wave * shoreline;
}

void fragment() {
	// World-space sampling keeps metre-scale ripples continuous across polygon seams.
	// Integrated phase keeps motion continuous when weather changes.
	vec2 direction = wind_direction();
	vec2 crosswind = vec2(direction.x * 0.8 - direction.y * 0.6, direction.x * 0.6 + direction.y * 0.8);
	vec2 first = texture(ripple_normal, water_position / 9.0 - wave_phase * direction * 0.035).rg * 2.0 - 1.0;
	vec2 second = texture(ripple_normal, water_position / 3.0 - wave_phase * crosswind * 0.06).rg * 2.0 - 1.0;
	float distance_to_eye = length(VERTEX);
	float detail = 1.0 - smoothstep(25.0, 140.0, distance_to_eye);
	float strength = 0.12 + 0.88 * (1.0 - exp(-length(wind_velocity) / 6.0));
	vec2 slope = (first + second * 0.45 * detail) * ripple_strength * strength;
	slope += amplitude() * shoreline * (direction * 1.1 * cos(dot(water_position,direction) * 1.1 - wave_phase)
		+ crosswind * 0.874 * cos(dot(water_position,crosswind) * 2.3 - wave_phase * 1.4));
	vec3 world_normal = normalize(vec3(-slope.x, 1.0, -slope.y));
	if (!FRONT_FACING) { world_normal = -world_normal; }
	NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);
	ALBEDO = water_color.rgb * (FRONT_FACING ? 1.0 : 0.55);
	METALLIC = 0.0;
	// Godot maps SPECULAR to F0 = 0.16 * SPECULAR squared; water is about 0.02.
	SPECULAR = 0.35;
	ROUGHNESS = mix(surface_roughness, 0.24, 1.0 - detail) + strength * 0.08;
	// Turbid campus water retains an opaque, stable reflection pass on Mobile too.
}
