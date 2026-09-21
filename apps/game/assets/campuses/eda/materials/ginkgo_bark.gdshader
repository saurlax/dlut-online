shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D bark_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D bark_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float wash_height = 1.05;
varying float height_above_root;

void vertex() {
	height_above_root = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y - MODEL_MATRIX[3].y;
}

void fragment() {
	vec3 grain = texture(bark_color, UV).rgb;
	float rim = 0.018 * sin(UV.x * 18.84956) + 0.009 * sin(UV.x * 43.98230);
	float wash = 1.0 - smoothstep(wash_height - 0.025, wash_height + 0.025, height_above_root + rim);
	vec3 chalk = vec3(0.78, 0.79, 0.73) * (0.86 + 0.14 * grain.r);
	ALBEDO = mix(grain * COLOR.rgb, chalk, wash);
	ROUGHNESS = mix(0.94, 0.98, wash);
	NORMAL_MAP = texture(bark_normal, UV).rgb;
	NORMAL_MAP_DEPTH = mix(0.45, 0.30, wash);
}
