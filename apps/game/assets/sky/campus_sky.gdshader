shader_type sky;
render_mode use_half_res_pass;

uniform vec3 sun_direction = vec3(0.2, 0.7, 0.5);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.3;
uniform float storm : hint_range(0.0, 1.0) = 0.0;
uniform vec2 cloud_offset = vec2(0.0);
uniform vec3 camera_position = vec3(0.0, 1.7, 0.0);

float hash(vec3 p) {
 p = fract(p * 0.1031);
 p += dot(p, p.yzx + 33.33);
 return fract((p.x + p.y) * p.z);
}
float noise(vec3 p) {
 vec3 i = floor(p), f = fract(p);
 f = f*f*(3.0-2.0*f);
 return mix(
  mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),
  mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
// A 900 m thick world-space volume. Height profile forms flat bases and soft tops.
float density(vec3 position) {
 float height = (position.y - 1200.0) / 900.0;
 if (height <= 0.0 || height >= 1.0) { return 0.0; }
 vec3 p = (position - vec3(cloud_offset.x,0.0,cloud_offset.y)) * 0.0018;
 float shape = noise(p) * 0.625 + noise(p*2.03+vec3(5.2,1.3,7.1))*0.25 + noise(p*4.11)*0.125;
 float threshold = mix(0.8,0.23,cloud_cover);
 float body = smoothstep(threshold,threshold+0.2,shape);
 float profile = smoothstep(0.0,0.12,height)*(1.0-smoothstep(0.55,1.0,height));
 return body*profile*smoothstep(0.0,0.08,cloud_cover);
}
vec3 atmosphere(vec3 ray) {
 float daylight = smoothstep(-0.12,0.22,sun_direction.y);
 float horizon = pow(1.0-max(ray.y,0.0),3.0);
 float sunset = (1.0-smoothstep(0.0,0.32,abs(sun_direction.y))) * smoothstep(-0.15,0.0,sun_direction.y);
 float toward = pow(max(dot(normalize(vec3(ray.x,0.05,ray.z)),normalize(vec3(sun_direction.x,0.05,sun_direction.z))),0.0),5.0);
 vec3 zenith = mix(vec3(0.004,0.009,0.024),vec3(0.12,0.34,0.64),daylight);
 vec3 edge = mix(vec3(0.016,0.023,0.048),vec3(0.65,0.76,0.83),daylight);
 edge = mix(edge,vec3(0.98,0.34,0.12),sunset*toward*0.8);
 vec3 color = mix(zenith,edge,horizon);
 color = mix(color,mix(vec3(0.012,0.017,0.025),vec3(0.43,0.48,0.53),daylight),cloud_cover*0.55+storm*0.2);
 float sun_dot = dot(ray,sun_direction);
 float disk = smoothstep(0.99994,0.99997,sun_dot);
 float glow = pow(max(sun_dot,0.0),64.0)*0.18;
 color += (disk*5.0+glow)*mix(vec3(1.0,0.36,0.12),vec3(1.0,0.94,0.8),smoothstep(0.0,0.25,sun_direction.y))*smoothstep(-0.04,0.01,sun_direction.y);
 return color;
}
vec3 volume_clouds(vec3 ray, vec3 background) {
 if (ray.y <= 0.025 || cloud_cover < 0.005) { return background; }
 vec3 origin = vec3(camera_position.x,clamp(camera_position.y,0.0,1100.0),camera_position.z);
 float begin = (1200.0-origin.y)/ray.y;
 float end = min((2100.0-origin.y)/ray.y,32000.0);
 if (begin >= end) { return background; }
 float step_length = (end-begin)/32.0;
 float transmission = 1.0;
 vec3 scattered = vec3(0.0);
 float daylight = smoothstep(-0.12,0.2,sun_direction.y);
 float sunlight = smoothstep(-0.06,0.12,sun_direction.y);
 float forward_scatter = pow(max(dot(ray,sun_direction),0.0),10.0);
 vec3 sun_color = mix(vec3(1.0,0.4,0.17),vec3(1.0,0.96,0.87),smoothstep(0.0,0.3,sun_direction.y));
 // Fixed midpoint sampling avoids temporal noise/flicker and needs no history buffer.
 for (int i=0;i<32;i++) {
  vec3 position = origin + ray*(begin+(float(i)+0.5)*step_length);
  float amount = density(position);
  if (amount > 0.001) {
   // Two additional density probes towards the sun approximate internal cloud shadowing.
   float optical_depth = density(position+sun_direction*120.0)*120.0 + density(position+sun_direction*360.0)*240.0;
   float lighting = exp(-optical_depth*0.009);
   float height = clamp((position.y-1200.0)/900.0,0.0,1.0);
   vec3 ambient = mix(vec3(0.012,0.019,0.033),mix(vec3(0.20,0.25,0.32),vec3(0.47,0.55,0.65),height),daylight);
   vec3 source = ambient + sun_color*sunlight*lighting*(0.68+forward_scatter*0.55);
   source *= 1.0-storm*0.4;
   float opacity = 1.0-exp(-amount*step_length*0.008);
   scattered += transmission*opacity*source;
   transmission *= 1.0-opacity;
   if (transmission < 0.025) { break; }
  }
 }
 vec3 result = scattered+transmission*background;
 // Blend the remote horizon into the atmosphere rather than expose the layer boundary.
 return mix(background,result,smoothstep(0.025,0.10,ray.y)*exp(-begin*0.000012));
}
void sky() {
 if (AT_HALF_RES_PASS || AT_CUBEMAP_PASS) {
  vec3 ray = normalize(EYEDIR);
  COLOR = volume_clouds(ray,atmosphere(ray));
  ALPHA = 1.0;
 } else {
  COLOR = HALF_RES_COLOR.rgb;
 }
}
