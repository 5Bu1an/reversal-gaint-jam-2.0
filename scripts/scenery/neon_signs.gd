extends Node2D
## Mid-ground neon signs on the buildings, tinted by sector. Lives in a
## Parallax2D, so positions are in that layer's scrolled space.

const WORDS := ["OPEN 24H", "CHRONO", "NOODLES", "NO FUTURE", "REWIND", "HOTEL", "SYNTH", "BAR", "TENET", "LIVE"]
const SPACING := 210.0

var scroll_scale := 0.7
var level_w := 3200.0

var _signs: Array[Dictionary] = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var span := (level_w - 640.0) * scroll_scale + 640.0
	var x := 60.0
	var i := 0
	while x < span:
		var vertical := i % 3 == 1
		_signs.append({
			"pos": Vector2(x, rng.randf_range(60, 170)),
			"text": WORDS[i % WORDS.size()],
			"vertical": vertical,
			"accent": Sectors.accent_at(x / scroll_scale),
			"flicker": rng.randf() < 0.35,
			"seed": rng.randf() * 100.0,
		})
		x += SPACING + rng.randf_range(-40, 40)
		i += 1


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var t := Time.get_ticks_msec() / 1000.0
	for sign in _signs:
		var on := true
		if sign.flicker:
			on = sin(t * 9.0 + sign.seed) > -0.6 and fmod(t + sign.seed, 4.0) > 0.25
		var accent: Color = sign.accent
		var lit := accent if on else accent.darkened(0.75)
		var text: String = sign.text
		var box: Rect2
		if sign.vertical:
			box = Rect2(sign.pos, Vector2(16, 12 * text.length() + 8))
		else:
			box = Rect2(sign.pos, Vector2(text.length() * 7 + 12, 18))
		draw_rect(box, Color("#0b0b14"))
		if on:
			draw_rect(box.grow(3), Color(accent, 0.08))
			draw_rect(box.grow(1), Color(accent, 0.15), false, 2.0)
		draw_rect(box, lit, false, 1.0)
		if sign.vertical:
			for c in text.length():
				var ch := text[c]
				if ch != " ":
					draw_string(font, box.position + Vector2(4, 16 + c * 12), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, lit)
		else:
			draw_string(font, box.position + Vector2(6, 13), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, lit)
