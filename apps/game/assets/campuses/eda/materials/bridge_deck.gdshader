shader_type spatial;
render_mode cull_back;

uniform vec4 base_color : source_color = vec4(0.514,0.576,0.549,1.0);
uniform vec2 deck_origin = vec2(0.0);
uniform vec2 deck_axis = vec2(1.0,0.0);
uniform float stud_pitch = 0.024;
uniform vec2 panel_size = vec2(1.8,1.2);
varying vec2 deck_position;
varying float upward;

float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }

void vertex() {
	vec2 relative=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz-deck_origin;
	deck_position=vec2(dot(relative,deck_axis),dot(relative,vec2(-deck_axis.y,deck_axis.x)));
	upward=(MODEL_NORMAL_MATRIX*NORMAL).y;
}

void fragment() {
	vec3 color=base_color.rgb;
	float roughness=0.83;
	if (upward>0.5) {
		vec2 p=deck_position;
		float footprint=max(length(dFdx(p)),length(dFdy(p)));
		float visible=1.0-smoothstep(stud_pitch*0.22,stud_pitch*0.8,footprint);
		vec2 cell=fract(p/stud_pitch+0.5)-0.5;
		float radius=length(cell)*stud_pitch;
		float aa=max(fwidth(radius),0.00015);
		float stud=1.0-smoothstep(stud_pitch*0.35-aa,stud_pitch*0.40+aa,radius);
		float rim=1.0-smoothstep(max(0.0005-aa,0.0),0.0015+aa,abs(radius-stud_pitch*0.375));
		vec2 panel_uv=p/panel_size;
		// Offset joints are visible; this phase and module sizes are approximations.
		panel_uv.x+=mod(floor(panel_uv.y),2.0)*0.35;
		vec2 edges=min(fract(panel_uv),1.0-fract(panel_uv))*panel_size;
		float seam_distance=min(edges.x,edges.y);
		float seam_aa=max(fwidth(seam_distance),0.0005);
		float seam=1.0-smoothstep(0.0015-seam_aa,0.0015+seam_aa,seam_distance);
		float panel_visible=1.0-smoothstep(0.10,0.4,footprint);
		float tone=mix(1.0,0.97+0.06*hash(floor(panel_uv)),panel_visible);
		color*=tone*(1.0-0.09*rim*visible-0.28*seam*panel_visible);
		// Shallow relief only: neither geometry nor the walking surface is displaced.
		float height=0.0006*stud*visible-0.0003*seam*panel_visible;
		vec3 dx=dFdx(VERTEX),dy=dFdy(VERTEX);
		vec3 rx=cross(dy,NORMAL),ry=cross(NORMAL,dx);
		float determinant=dot(dx,rx);
		vec3 gradient=sign(determinant)*(dFdx(height)*rx+dFdy(height)*ry);
		NORMAL=normalize(max(abs(determinant),0.00000001)*NORMAL-gradient);
		roughness=0.81+0.05*(1.0-stud)*visible+0.04*seam;
	}
	ALBEDO=color;
	ROUGHNESS=roughness;
	SPECULAR=0.25;
}
