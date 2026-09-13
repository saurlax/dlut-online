shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_lambert;

uniform bool snow = false;
uniform vec3 fall_direction = vec3(0.0, -1.0, 0.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
varying float camera_distance;

void vertex() {
	vec3 centre = MODEL_MATRIX[3].xyz;
	vec3 toward_camera = INV_VIEW_MATRIX[3].xyz - centre;
	camera_distance = length(toward_camera);
	vec3 up = snow ? INV_VIEW_MATRIX[1].xyz : -normalize(fall_direction);
	vec3 right = cross(up, normalize(toward_camera));
	if (length(right) < 0.01) { right = INV_VIEW_MATRIX[0].xyz; }
	right = normalize(right);
	vec3 normal = normalize(cross(right, up));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(right * length(MODEL_MATRIX[0].xyz), 0.0),
		vec4(up * length(MODEL_MATRIX[1].xyz), 0.0),
		vec4(normal * length(MODEL_MATRIX[2].xyz), 0.0),
		MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float shape = snow ? 1.0 - smoothstep(0.25, 1.0, length(p))
		: (1.0 - smoothstep(0.1, 1.0, abs(p.x))) * (1.0 - pow(abs(p.y), 3.0));
	float fade = smoothstep(0.5, 1.5, camera_distance) * (1.0 - smoothstep(16.0, 24.0, camera_distance));
	ALBEDO = snow ? vec3(0.88, 0.92, 0.97) : vec3(0.62, 0.72, 0.8);
	ROUGHNESS = 0.8;
	ALPHA = shape * fade * COLOR.a * (snow ? 0.85 : 0.45) * smoothstep(0.0, 0.08, intensity);
}
