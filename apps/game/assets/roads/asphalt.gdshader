shader_type spatial;
varying vec3 world_position;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(hash(cell), hash(cell+vec2(1,0)), f.x), mix(hash(cell+vec2(0,1)), hash(cell+vec2(1,1)), f.x), f.y);
}
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = world_position.xz;
	// Millimetre-scale aggregate fades to its mean before undersampling.
	float footprint = max(length(dFdx(p)), length(dFdy(p)));
	float fine = mix(noise(p*160.0), 0.5, smoothstep(0.002,0.014,footprint));
	float aggregate = mix(noise(p*48.0), 0.5, smoothstep(0.008,0.04,footprint));
	float broad = noise(p*0.45);
	ALBEDO = vec3(0.10,0.11,0.12) * (0.91+0.10*broad+0.13*(aggregate-0.5)+0.09*(fine-0.5));
	ROUGHNESS = clamp(0.91+0.08*(aggregate-0.5), 0.82, 1.0);
}
