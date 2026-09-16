shader_type spatial;
render_mode cull_disabled;

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
	ALBEDO = leaf_color * (0.92 + 0.06 * veins + 0.09 * midrib);
	ROUGHNESS = 0.9;
	SPECULAR = 0.12;
	BACKLIGHT = leaf_color * 0.12;
	if (!FRONT_FACING) { NORMAL = -NORMAL; }
}
