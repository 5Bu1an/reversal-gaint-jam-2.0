shader_type canvas_item;
// "System failure" look while the player is down: torn scanline bands,
// split colour channels and a drained red tint.

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float amount = 1.0;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float tick = floor(TIME * 12.0);
	float band = floor(uv.y * 24.0);
	if (hash(band + tick * 7.0) > 0.78) {
		uv.x += (hash(band * 3.1 + tick) - 0.5) * 0.06 * amount;
	}
	float split = 0.006 * amount;
	vec3 c = vec3(
		texture(screen_texture, uv + vec2(split, 0.0)).r,
		texture(screen_texture, uv).g,
		texture(screen_texture, uv - vec2(split, 0.0)).b);
	float gray = dot(c, vec3(0.3, 0.59, 0.11));
	c = mix(c, gray * vec3(1.0, 0.5, 0.58), 0.6 * amount);
	c *= 0.88 + 0.12 * sin(uv.y * 360.0 * 3.14159);
	COLOR = vec4(c, 1.0);
}
