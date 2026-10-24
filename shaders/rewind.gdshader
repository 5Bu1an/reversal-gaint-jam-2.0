shader_type canvas_item;
// Full-screen rewind look: split colour channels, dark teal negative, scanlines.

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float split = 0.004;
uniform float invert = 0.9;
uniform vec3 tint = vec3(0.35, 0.7, 0.8);

void fragment() {
	vec2 uv = SCREEN_UV;
	float r = texture(screen_texture, uv + vec2(split, 0.0)).r;
	float g = texture(screen_texture, uv).g;
	float b = texture(screen_texture, uv - vec2(split, 0.0)).b;
	vec3 col = vec3(r, g, b);
	col = mix(col, (vec3(1.0) - col) * tint, invert);
	col *= 0.88 + 0.12 * sin(uv.y * 360.0 * 3.14159);
	COLOR = vec4(col, 1.0);
}
