shader_type canvas_item;
// Enemy sprites: a tint (inverted enemies go purple) and a hit flash that
// washes the whole sprite to a solid colour.

uniform vec4 tint : source_color = vec4(1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	c.rgb = mix(c.rgb, c.rgb * tint.rgb * 1.4 + tint.rgb * 0.15, tint_amount);
	c.rgb = mix(c.rgb, flash_color.rgb, flash);
	COLOR = c;
}
