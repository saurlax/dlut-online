shader_type spatial;
render_mode cull_back;

varying vec3 world_position;
varying vec3 world_normal;

float hash3(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i+vec3(1,0,0)), f.x),
		mix(hash3(i+vec3(0,1,0)), hash3(i+vec3(1,1,0)), f.x), f.y),
		mix(mix(hash3(i+vec3(0,0,1)), hash3(i+vec3(1,0,1)), f.x),
		mix(hash3(i+vec3(0,1,1)), hash3(i+vec3(1,1,1)), f.x), f.y), f.z);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	float broad = noise(world_position * 0.012);
	float canopy = noise(world_position * 0.19);
	float grain = noise(world_position * 0.9);
	vec3 open_ground = mix(vec3(0.13, 0.15, 0.085), vec3(0.21, 0.23, 0.13), broad);
	vec3 forest = mix(vec3(0.018, 0.045, 0.025), vec3(0.065, 0.115, 0.05), broad);
	forest *= 0.84 + canopy * 0.32;
	float outcrop = noise(world_position * vec3(0.09, 0.012, 0.09)) * 0.55
		+ noise(world_position * vec3(0.25, 0.07, 0.25)) * 0.3 + grain * 0.15;
	float rock = smoothstep(0.12, 0.30, 1.0 - normalize(world_normal).y) * smoothstep(0.28, 0.78, outcrop);
	vec3 stone = mix(vec3(0.09, 0.085, 0.075), vec3(0.22, 0.21, 0.19), grain * 0.35 + broad * 0.65);
	vec3 ground = mix(mix(open_ground, forest, COLOR.r), stone, rock);
	ALBEDO = mix(vec3(0.1746, 0.1912, 0.1046), ground, COLOR.g);
	ROUGHNESS = 0.96;
}
