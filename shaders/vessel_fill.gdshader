shader_type canvas_item;
// Clips the painted soul-fill orb from the bottom up to `fill`, with a moving
// surface line. While rewinding the surface churns backwards and the liquid
// bleaches white. The empty part stays faintly visible as glass.

uniform float fill : hint_range(0.0, 1.0) = 0.5;
uniform float rewinding = 0.0;
// Vertical extent of the painted orb inside the texture, in UV.
uniform float orb_top = 0.2375;
uniform float orb_bottom = 0.8125;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float t = TIME * mix(1.0, -4.0, rewinding);
	float surface = mix(orb_bottom, orb_top, fill) + 0.012 * sin(UV.x * 28.0 + t * 3.0);
	float wet = step(surface, UV.y) * step(0.001, fill);
	vec3 col = mix(c.rgb * 1.6 + vec3(0.0, 0.08, 0.1), vec3(0.85, 1.0, 1.0), rewinding * 0.55);
	col += 0.4 * smoothstep(0.008, 0.0, abs(UV.y - surface)) * wet;
	COLOR = vec4(col, c.a * mix(0.15, 1.0, wet));
}
