shader_type canvas_item;
// Drifting low fog in world space, thickest near the floor.

uniform vec4 tint : source_color = vec4(0.42, 0.36, 0.8, 1.0);
uniform float density = 0.15;
uniform vec2 world_size = vec2(3200.0, 360.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.0;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 world = UV * world_size;
	vec2 p = world / vec2(140.0, 50.0) + vec2(TIME * 0.08, 0.0);
	float n = fbm(p);
	float floor_fade = smoothstep(0.35, 1.0, UV.y);
	COLOR = vec4(tint.rgb, n * floor_fade * density);
}
