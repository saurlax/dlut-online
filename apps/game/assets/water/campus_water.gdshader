shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;

uniform sampler2D ripple_normal : hint_normal, repeat_enable, filter_linear_mipmap;
uniform vec4 water_color : source_color = vec4(0.105, 0.155, 0.135, 1.0);
uniform float ripple_strength : hint_range(0.0, 1.0) = 0.32;
uniform float surface_roughness : hint_range(0.02, 1.0) = 0.16;

varying vec2 water_position;

void vertex() {
	water_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	// World-space sampling keeps metre-scale ripples continuous across polygon seams.
	// Tile offsets repeat at Godot's default TIME rollover (3600 seconds).
	vec2 first = texture(ripple_normal, water_position / 9.0 + TIME * vec2(0.01, 0.005)).rg * 2.0 - 1.0;
	vec2 second = texture(ripple_normal, water_position / 3.0 + TIME * vec2(-0.005, 0.01)).rg * 2.0 - 1.0;
	float distance_to_eye = length(VERTEX);
	float detail = 1.0 - smoothstep(25.0, 140.0, distance_to_eye);
	vec2 slope = (first + second * 0.45 * detail) * ripple_strength;
	vec3 world_normal = normalize(vec3(-slope.x, 1.0, -slope.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);
	ALBEDO = water_color.rgb;
	METALLIC = 0.0;
	// Godot maps SPECULAR to F0 = 0.16 * SPECULAR squared; water is about 0.02.
	SPECULAR = 0.35;
	ROUGHNESS = mix(surface_roughness, 0.24, 1.0 - detail);
	// Keep the opaque pass: existing flat terrain is not a surveyed river bed.
	// Godot provides Fresnel, sky reflections, direct light and fog through its BRDF.
}
