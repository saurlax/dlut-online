shader_type spatial;
render_mode cull_disabled;
uniform vec4 base_color : source_color = vec4(0.58, 0.27, 0.24, 1.0);
uniform float paving = 0.0;
uniform float tile_size = 0.6;
uniform bool surface_detail = false;
varying vec3 world_position;
varying vec3 view_position;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1,0)), f.x),
		mix(hash(cell + vec2(0,1)), hash(cell + vec2(1,1)), f.x), f.y);
}
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	view_position = (MODELVIEW_MATRIX * vec4(VERTEX,1.0)).xyz;
}
void fragment() {
	vec2 p = world_position.xz;
	float grain = hash(floor(p*180.0));
	float height = 0.0;
	float surface_roughness = 0.92;
	if (surface_detail) {
		// Suppress subpixel grain on distant/grazing surfaces instead of shimmering.
		float visibility = 1.0 - smoothstep(0.35, 1.0, max(fwidth(p.x), fwidth(p.y)) * 180.0);
		grain = mix(0.5, noise(p * 180.0), visibility);
		height = (grain - 0.5) * 0.00008;
	}
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
		if (surface_detail) {
			// Visual microrelief only; preserve the registered surface and collision.
			height += slab * 0.0008;
			surface_roughness = mix(0.94, 0.76 + 0.06 * noise(p * 2.0), slab);
		}
	}
	ALBEDO = color;
	ROUGHNESS = surface_roughness;
	if (surface_detail) {
		// Surface-gradient bump mapping needs no UV/tangent assumptions on terrain-fitted meshes.
		vec3 dpdx = dFdx(view_position);
		vec3 dpdy = dFdy(view_position);
		vec3 n = normalize(NORMAL);
		vec3 r1 = cross(dpdy, n);
		vec3 r2 = cross(n, dpdx);
		float determinant = dot(dpdx, r1);
		vec3 gradient = sign(determinant) * (dFdx(height) * r1 + dFdy(height) * r2);
		NORMAL = normalize(max(abs(determinant), 0.00000001) * n - gradient);
	}
}
