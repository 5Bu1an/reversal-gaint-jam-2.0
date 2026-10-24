shader_type canvas_item;
// The chrono vessel: a glass orb of glowing liquid time. fill is 0-1; while
// rewinding the surface churns backwards and the liquid bleaches white.

uniform float fill : hint_range(0.0, 1.0) = 0.5;
uniform float rewinding = 0.0;
uniform vec4 liquid : source_color = vec4(0.02, 0.85, 0.91, 1.0);
uniform vec4 glass : source_color = vec4(0.04, 0.04, 0.09, 0.9);

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}
	float t = TIME * mix(1.0, -4.0, rewinding);
	float surface = 1.0 - fill * 2.0;
	float wave = 0.07 * sin(p.x * 6.0 + t * 3.0) + 0.03 * sin(p.x * 13.0 - t * 5.0);
	vec4 col = glass;
	if (fill > 0.001 && p.y > surface + wave) {
		float depth = (p.y - surface) * 0.5;
		vec3 base = mix(liquid.rgb, vec3(0.9, 1.0, 1.0), rewinding * 0.6);
		col = vec4(base * (1.15 - depth * 0.7), 1.0);
		col.rgb += 0.25 * smoothstep(0.97, 1.0, sin(p.x * 23.0 + t * 2.0) * sin(p.y * 19.0 - t * 6.0));
	}
	float rim = smoothstep(0.8, 0.9, r);
	col.rgb = mix(col.rgb, vec3(0.75, 0.95, 1.0), rim * 0.85);
	col.a = max(col.a, rim);
	col.rgb += 0.3 * smoothstep(0.28, 0.0, length(p - vec2(-0.38, -0.45)));
	COLOR = col;
}
