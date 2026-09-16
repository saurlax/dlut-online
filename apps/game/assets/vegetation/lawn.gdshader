shader_type spatial;
render_mode cull_disabled;
varying vec3 tint;
varying vec2 ground;
varying float edge;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() {
	tint = pow(COLOR.rgb, vec3(2.2));
	ground = VERTEX.xz;
	edge = UV2.x;
}
void fragment() {
	float fibres = noise(ground*120.0);
	float patches = noise(ground*1.7)*0.6+noise(ground*0.24)*0.4;
	ALBEDO = tint * (0.64 + patches*0.45 + fibres*0.20);
	ROUGHNESS = 1.0;
	SPECULAR = 0.05;
	ALPHA = step(noise(ground*19.0), edge);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
