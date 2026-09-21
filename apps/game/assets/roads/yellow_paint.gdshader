shader_type spatial;

uniform vec4 paint_color : source_color = vec4(0.77, 0.66, 0.32, 1.0);
uniform vec4 aggregate_color : source_color = vec4(0.33, 0.35, 0.36, 1.0);
varying vec2 ground_position;

float grain_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	ground_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 grain_position = ground_position * 180.0;
	float footprint = max(length(dFdx(grain_position)), length(dFdy(grain_position)));
	float detail = 1.0 - smoothstep(0.35, 1.4, footprint);
	float grain = grain_hash(floor(grain_position));
	float exposed = mix(0.07, smoothstep(0.90, 1.0, grain), detail);
	vec3 coating = paint_color.rgb * mix(0.97, 0.91 + 0.12 * grain, detail);
	ALBEDO = mix(coating, aggregate_color.rgb, exposed);
	ROUGHNESS = 0.94;
	SPECULAR = 0.1;
}
