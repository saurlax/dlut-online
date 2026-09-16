shader_type spatial;
render_mode cull_disabled;
uniform vec4 base_color : source_color = vec4(0.58, 0.27, 0.24, 1.0);
uniform float paving = 0.0;
uniform float tile_size = 0.6;
varying vec3 world_position;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
	vec2 p = world_position.xz;
	float grain = hash(floor(p*180.0));
	vec3 color = base_color.rgb * (0.97 + 0.06*grain);
	if (paving > 1.5) {
		vec2 uv = mat2(vec2(0.7071,-0.7071),vec2(0.7071,0.7071))*p/0.12;
		vec2 cell = floor(uv);
		float phase = mod(cell.x+cell.y,4.0);
		vec2 brick = fract(uv);
		vec2 dimensions;
		vec2 anchor = cell;
		if (phase < 2.0) {
			brick.x += phase;
			anchor.x -= phase;
			dimensions = vec2(2.0,1.0);
		} else {
			brick.y += phase-2.0;
			anchor.y -= phase-2.0;
			dimensions = vec2(1.0,2.0);
		}
		vec2 edge = min(brick,dimensions-brick);
		float distance_to_joint = min(edge.x,edge.y);
		float aa = max(fwidth(distance_to_joint),0.001);
		color *= 0.9+0.2*hash(anchor);
		color = mix(color*0.6,color,smoothstep(0.016-aa,0.016+aa,distance_to_joint));
	} else if (paving > 0.5) {
		vec2 uv = mat2(vec2(0.9763,-0.2164),vec2(0.2164,0.9763)) * p / tile_size;
		vec2 cell = floor(uv);
		vec2 edge = min(fract(uv),1.0-fract(uv));
		float distance_to_joint = min(edge.x,edge.y);
		float aa = max(fwidth(distance_to_joint),0.0001);
		float slab = smoothstep(0.007-aa,0.007+aa,distance_to_joint);
		color *= 0.94 + 0.12*hash(cell);
		color = mix(color*0.58,color,slab);
	}
	ALBEDO = color;
	ROUGHNESS = 0.92;
}
