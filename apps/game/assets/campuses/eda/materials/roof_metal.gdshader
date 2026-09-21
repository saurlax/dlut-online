shader_type spatial;
render_mode cull_disabled;

varying vec2 position_m;
void vertex() { position_m = (MODEL_MATRIX*vec4(VERTEX,1.0)).xz; }
void fragment() {
	vec2 uv=position_m/vec2(0.75,3.0);
	vec2 edge=min(fract(uv),1.0-fract(uv));
	float aa=max(fwidth(uv.x),0.001);
	float seam=1.0-smoothstep(0.008-aa,0.008+aa,edge.x);
	float joint=1.0-smoothstep(0.001-fwidth(uv.y),0.001+fwidth(uv.y),edge.y);
	float fade=1.0-smoothstep(0.12,0.5,max(fwidth(uv.x),fwidth(uv.y)));
	ALBEDO=vec3(0.20,0.30,0.31)*(1.0-fade*(0.18*seam+0.08*joint));
	METALLIC=0.45;
	ROUGHNESS=0.42+0.12*seam*fade;
}
