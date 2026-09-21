shader_type spatial;
render_mode cull_disabled;

uniform bool fan_veins = false;
uniform float vein_strength = 1.0;
uniform bool magnolia_petals = false;

// Opaque, shaped geometry: COLOR.a is flexibility, never transparency.
varying vec3 leaf_color;
varying float flexibility;

void vertex() {
	leaf_color = pow(COLOR.rgb, vec3(2.2));
	flexibility = COLOR.a;
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = dot(world.xz, vec2(0.71, 0.39));
	float breeze = sin(TIME * 1.15 + phase) + 0.35 * sin(TIME * 2.7 + phase * 1.9);
	VERTEX.x += breeze * 0.028 * flexibility;
	VERTEX.z += sin(TIME * 1.4 + phase) * 0.018 * flexibility;
}

void fragment() {
	float midrib = exp(-abs(UV.x - 0.5) * 95.0);
	float veins = pow(max(0.0, cos((UV.y + abs(UV.x - 0.5) * 0.7) * 68.0)), 16.0);
	if (fan_veins) {
		vec2 from_stem = vec2(UV.x - 0.5, max(UV.y, 0.002));
		float phase = atan(from_stem.x, from_stem.y) * 48.0;
		float visible = 1.0 - smoothstep(0.3, 1.2, fwidth(phase));
		veins = mix(0.11, pow(max(0.0, cos(phase)), 12.0), visible);
		midrib = 0.0;
	}
	ALBEDO = leaf_color * (0.92 + vein_strength * (0.06 * veins + 0.09 * midrib));
	ROUGHNESS = 0.9;
	SPECULAR = 0.12;
	if (magnolia_petals) {
		// The narrow petal attachment is UV.y=0; most of the cup stays ivory.
		float base_blush = 1.0 - smoothstep(0.015, 0.19, UV.y);
		vec3 warm_base = pow(vec3(0.48, 0.24, 0.21), vec3(2.2));
		ALBEDO = mix(ALBEDO, warm_base, base_blush * 0.76);
		float fold_phase = (UV.x - 0.5) * 54.0;
		float fold_visibility = 1.0 - smoothstep(0.4, 1.3, fwidth(fold_phase));
		float folds = cos(fold_phase) * 0.014 * fold_visibility;
		ALBEDO *= 1.0 + folds * smoothstep(0.1, 0.4, UV.y);
		ROUGHNESS = 0.82 + folds;
	}
	BACKLIGHT = leaf_color * 0.12;
	if (!FRONT_FACING) { NORMAL = -NORMAL; }
}
