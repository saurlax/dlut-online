shader_type spatial;
render_mode cull_disabled;

uniform vec2 field_origin;
uniform vec2 field_axis;
uniform float field_length;
uniform vec4 markings[7];
uniform vec4 light_turf : source_color = vec4(0.34,0.44,0.22,1.0);
uniform vec4 dark_turf : source_color = vec4(0.23,0.34,0.19,1.0);
varying vec2 ground;

float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void vertex() { ground=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz; }
void fragment() {
	vec2 relative=ground-field_origin;
	vec2 p=vec2(dot(relative,field_axis),dot(relative,vec2(-field_axis.y,field_axis.x)));
	float course=p.x/(field_length/14.0);
	float aa=max(fwidth(course),0.0001);
	float stripe=smoothstep(-aa*3.141593,aa*3.141593,-sin(course*3.141593));
	float footprint=max(length(dFdx(p)),length(dFdy(p)));
	float fiber=hash(floor(p*vec2(280.0,90.0)));
	fiber=mix(fiber,0.5,smoothstep(0.003,0.025,footprint));
	ALBEDO=mix(light_turf.rgb,dark_turf.rgb,stripe)*(0.9+0.2*fiber);
	float line_distance=1000.0;
	for (int i=0; i<7; i++) {
		vec2 start=markings[i].xy;
		vec2 delta=markings[i].zw-start;
		float t=clamp(dot(ground-start,delta)/max(dot(delta,delta),0.0001),0.0,1.0);
		line_distance=min(line_distance,length(ground-start-delta*t));
	}
	vec2 center=(markings[0].xy+markings[0].zw)*0.5;
	// Radius is an approximate modelling dimension, consistent with the pitch finish.
	line_distance=min(line_distance,abs(length(ground-center)-9.15));
	float line_aa=max(fwidth(line_distance),0.002);
	float paint=1.0-smoothstep(0.06-line_aa,0.06+line_aa,line_distance);
	ALBEDO=mix(ALBEDO,vec3(0.91,0.90,0.82)*(0.96+0.04*fiber),paint);
	ROUGHNESS=0.96;
	SPECULAR=0.12;
}
