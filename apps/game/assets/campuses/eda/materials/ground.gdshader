shader_type spatial;
render_mode cull_disabled;

uniform vec4 base_color : source_color = vec4(0.3,0.3,0.3,1.0);
uniform vec4 band_color : source_color = vec4(0.40,0.48,0.43,1.0);
uniform int surface_kind = 0;
uniform vec2 paving_origin = vec2(0.0);
uniform vec2 paving_axis = vec2(1.0,0.0);
uniform vec4 stone_path_frame = vec4(0.0);
uniform vec2 stone_path_extent = vec2(0.0);
varying vec2 ground;

float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
	vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
vec2 aggregate_hash(vec2 p) {
	vec3 q=fract(vec3(p.x,p.y,p.x)*vec3(0.1031,0.1030,0.0973));
	q+=dot(q,q.yzx+33.33);
	return fract((q.xx+q.yz)*q.zy);
}
vec2 aggregate(vec2 p) {
	vec2 cell=floor(p), local=fract(p);
	float nearest=8.0, second=8.0, tint=0.5;
	for (int y=-1;y<=1;y++) {
		for (int x=-1;x<=1;x++) {
			vec2 offset=vec2(float(x),float(y));
			vec2 seed=aggregate_hash(cell+offset);
			vec2 delta=offset+0.12+seed*0.76-local;
			float distance=dot(delta,delta);
			if (distance<nearest) { second=nearest; nearest=distance; tint=seed.x; }
			else { second=min(second,distance); }
		}
	}
	return vec2(smoothstep(0.006,0.065,second-nearest),tint);
}
void vertex() { ground=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz; }
void fragment() {
	vec2 p=ground;
	int kind=surface_kind;
	vec3 base=base_color.rgb;
	vec2 delta=ground-stone_path_frame.xy;
	vec2 stone_uv=vec2(dot(delta,stone_path_frame.zw),dot(delta,vec2(-stone_path_frame.w,stone_path_frame.z)));
	bool stone=kind==0 && stone_path_extent.x>0.0 && stone_uv.x>=0.0 && stone_uv.x<=stone_path_extent.x && abs(stone_uv.y)<=stone_path_extent.y;
	if (stone) { kind=7; base=vec3(0.26,0.27,0.25); }

	if (kind>=2) { p=UV; }
	if (stone) { p=stone_uv; }
	if (kind==6) { vec2 d=ground-paving_origin; p=vec2(dot(d,paving_axis),dot(d,vec2(-paving_axis.y,paving_axis.x))); }
	float footprint=max(length(dFdx(p)),length(dFdy(p)));
	float grain=mix(noise(p*180.0),0.5,smoothstep(0.008,0.035,footprint));
	float mottling=noise(p*1.9)*0.6+noise(p*0.19)*0.4;
	vec3 color=base*(0.88+0.17*mottling+0.12*grain);
	float joint=1.0;
	if (kind>=1) {
		vec2 size=kind==7 ? vec2(0.4,0.6) : kind==4 ? vec2(0.6) : (kind==1 ? vec2(0.6,0.4) : (kind==2 || kind==5 || kind==6 ? vec2(0.10,0.20) : vec2(0.065,0.24)));
		vec2 uv=kind==1 ? mat2(vec2(0.9763,-0.2164),vec2(0.2164,0.9763))*p/size : p/size;
		if (kind==1) { uv.x+=mod(floor(uv.y),2.0)*0.5; }
		if (kind==2 || kind==6 || kind==7) { uv.y+=mod(floor(uv.x),2.0)*0.5; }
		vec2 cell=floor(uv), f=fract(uv);
		if (kind==5) {
			vec2 grid=mod(p+vec2(2.0,0.0),vec2(4.0));
			float band=1.0-smoothstep(0.18,0.20,min(grid.x,grid.y));
			color=mix(color,band_color.rgb*(0.88+0.17*mottling+0.12*grain),band);
		}
		// Four brick courses across the causeway, snapped to the paving modules.
		// Spacing is an approximate finish dimension, not a surveyed position.
		if (kind==2 && UV2.x>0.5) {
			float band=1.0-step(4.0,mod(floor(p.x/0.10),60.0));
			color=mix(color,band_color.rgb*(0.88+0.17*mottling+0.12*grain),band);
		}
		vec2 edge=min(f,1.0-f)*size;
		float distance_to_joint=min(edge.x,edge.y);
		float aa=max(fwidth(distance_to_joint),0.0005);
		float width=(kind==1 || kind==7) ? 0.003 : 0.002;
		joint=smoothstep(width-aa,width+aa,distance_to_joint);
		// Fade subpixel joints and cell noise to their average, avoiding shimmer.
		float visible=1.0-smoothstep(size.y*0.2,size.y*0.8,footprint);
		color*=mix(1.0,0.88+0.24*hash(cell),visible);
		joint=mix(0.97,joint,visible);
		color=mix(base*0.52,color,joint);
	} else if (kind==0) {
		// Centimetre-scale irregular aggregate, filtered before becoming subpixel.
		float detail=1.0-smoothstep(0.004,0.024,footprint);
		vec2 chip=aggregate(p*105.0);
		float relief=chip.x*(0.7+0.3*chip.y);
		float finish=mix(0.98,0.86+0.19*relief+0.08*(chip.y-0.5),detail);
		color=base*(0.90+0.16*mottling)*finish;
		float height=0.0007*relief*detail;
		vec3 dx=dFdx(VERTEX), dy=dFdy(VERTEX);
		vec3 rx=cross(dy,NORMAL), ry=cross(NORMAL,dx);
		float determinant=dot(dx,rx);
		vec3 gradient=sign(determinant)*(dFdx(height)*rx+dFdy(height)*ry);
		NORMAL=normalize(max(abs(determinant),0.00000001)*NORMAL-gradient);
	}
	ALBEDO=color;
	ROUGHNESS=clamp(0.86+0.1*grain+0.04*(1.0-joint),0.0,1.0);
	SPECULAR=0.16;
}
