shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D skin_texture : source_color, filter_linear_mipmap_anisotropic;
uniform float skin_depth : hint_range(0.0, 1.0) = 0.0;
uniform float skin_warmth : hint_range(-1.0, 1.0) = 0.0;

void fragment() {
	vec3 base = texture(skin_texture, UV).rgb;
	// Retain the source's local color variation and reduce tint on red lip areas.
	float lip_mask = smoothstep(1.45, 2.1, base.r / max(base.g, 0.025));
	vec3 pigment = mix(vec3(1.0), vec3(0.32, 0.22, 0.16), skin_depth);
	vec3 warmth = vec3(1.0 + skin_warmth * 0.08, 1.0, 1.0 - skin_warmth * 0.12);
	ALBEDO = clamp(base * mix(pigment * warmth, sqrt(pigment), lip_mask * 0.65), vec3(0.0), vec3(1.0));
	ROUGHNESS = mix(0.56, 0.43, lip_mask);
	SPECULAR = 0.32;
	SSS_STRENGTH = 0.08;
}
