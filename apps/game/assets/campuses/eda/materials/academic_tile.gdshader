shader_type spatial;
render_mode cull_disabled;

uniform vec4 tile_color : source_color = vec4(0.46,0.47,0.44,1.0);
uniform vec4 pale_color : source_color = vec4(0.60,0.60,0.56,1.0);

float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }

void fragment() {
	// UVs of the bounded wall overlays are in metres. Module dimensions are
	// visual approximations; keep the established shell and openings intact.
	vec2 size=vec2(0.20,0.045);
	vec2 uv=UV/size;
	float row=floor(uv.y);
	uv.x+=mod(row,2.0)*0.5;
	vec2 cell=floor(uv);
	vec2 f=fract(uv);
	vec2 edge=min(f,1.0-f)*size;
	float d=min(edge.x,edge.y);
	float footprint=max(length(dFdx(UV)),length(dFdy(UV)));
	float visible=1.0-smoothstep(0.012,0.06,footprint);
	float aa=max(fwidth(d),0.0003);
	float joint=smoothstep(0.0012-aa,0.0012+aa,d);
	// Decouple each course so light bricks form short horizontal runs,
	// rather than repeating the same vertical stripe every three bricks.
	float offset=floor(hash(vec2(row,7.3))*4.0);
	float run=floor((cell.x+offset)/2.0);
	float pale=step(2.0/3.0,hash(vec2(run,row)));
	vec3 color=mix(tile_color.rgb,pale_color.rgb,pale);
	color*=0.92+0.16*hash(cell);
	color=mix(tile_color.rgb*0.65,color,joint);
	vec3 average=mix(tile_color.rgb,pale_color.rgb,1.0/3.0)*0.96;
	ALBEDO=mix(average,color,visible);
	ROUGHNESS=0.78;
	SPECULAR=0.18;
}
