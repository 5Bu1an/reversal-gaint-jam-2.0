extends Node2D
## Title screen: neon logo mirrored in a rain puddle (TENET reads the same
## either way), start / controls / quit menu, rain and the music loop.

const LEVEL := "res://scenes/main.tscn"
const COLOR_TIME := Color("#05d9e8")
const COLOR_HP := Color("#ff2a6d")
const COLOR_DIM := Color(1, 1, 1, 0.35)
const COLOR_INK := Color("#0b0b14")
const VIEW := Vector2(640, 360)
const HORIZON := 200.0
## Reflection squash: 1 = full height mirror.
const MIRROR := 0.5

const CONTROLS := [
	["MOVE", "A / D   or   arrows"],
	["JUMP", "SPACE   or   Z"],
	["SLASH", "J   or   X     (hold W / S to aim)"],
	["DASH", "K   or   C"],
	["REWIND", "hold L   or   SHIFT"],
	["PAUSE", "ESC"],
]

var _items: Array[String] = ["START", "CONTROLS"]
var _selected := 0
var _show_controls := false
var _starting := false
var _t := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if Array(OS.get_cmdline_user_args()).any(func(a: String) -> bool:
			return a.begins_with("--autopilot=") and a != "--autopilot=title"):
		get_tree().change_scene_to_file.call_deferred(LEVEL)
		return
	if not OS.has_feature("web"):
		_items.append("QUIT")
	Game.set_state(Game.State.TITLE)
	Sfx.play_music()
	Sfx.set_music_volume(-14.0)

	var rain_anchor := Node2D.new()
	rain_anchor.position = Vector2(VIEW.x / 2, 0)
	rain_anchor.add_child(preload("res://scripts/scenery/rain.gd").new())
	add_child(rain_anchor)

	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_hdr_threshold = 0.6
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _starting:
		return
	if _show_controls:
		if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("attack") \
				or Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_cancel"):
			_show_controls = false
			Sfx.play("ui_move")
		return
	if Input.is_action_just_pressed("move_up") or Input.is_action_just_pressed("ui_up"):
		_move(-1)
	elif Input.is_action_just_pressed("move_down") or Input.is_action_just_pressed("ui_down"):
		_move(1)
	elif Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("attack") \
			or Input.is_action_just_pressed("ui_accept"):
		_choose()


func _move(step: int) -> void:
	_selected = wrapi(_selected + step, 0, _items.size())
	Sfx.play("ui_move", -2.0, 0.0)


func _choose() -> void:
	Sfx.play("ui_select", 0.0, 0.0)
	match _items[_selected]:
		"START":
			_starting = true
			Game.checkpoint = 0
			Fx.flash(Color.WHITE, 0.6)
			Sfx.set_music_volume(Sfx.MUSIC_DB)
			await get_tree().create_timer(0.35).timeout
			get_tree().change_scene_to_file(LEVEL)
		"CONTROLS":
			_show_controls = true
		"QUIT":
			get_tree().quit()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	_draw_city()
	_draw_logo(font)
	if _show_controls:
		_draw_controls(font)
	else:
		_draw_menu(font)
	draw_string(font, Vector2(0, 16), "GIANT JAM 2  ·  THEME: REVERSAL   ", HORIZONTAL_ALIGNMENT_RIGHT, VIEW.x, 8, Color(1, 1, 1, 0.25))


func _draw_city() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW), COLOR_INK)
	# Sky glow above the horizon.
	draw_polygon(PackedVector2Array([Vector2(0, 60), Vector2(VIEW.x, 60), Vector2(VIEW.x, HORIZON), Vector2(0, HORIZON)]),
		PackedColorArray([Color(COLOR_HP, 0.0), Color(COLOR_HP, 0.0), Color(COLOR_HP, 0.18), Color(COLOR_HP, 0.18)]))
	_rng.seed = 3
	for layer in 2:
		var shade := Color("#10101c") if layer == 0 else Color("#17172b")
		var x := -10.0
		while x < VIEW.x:
			var w := _rng.randf_range(24, 56)
			var h := _rng.randf_range(50, 150) * (0.8 if layer == 0 else 0.55)
			draw_rect(Rect2(x, HORIZON - h, w - 3, h), shade)
			if layer == 1 and _rng.randf() < 0.4:
				var accent := COLOR_TIME if _rng.randf() < 0.5 else COLOR_HP
				var on := sin(_t * 7.0 + x) > -0.7
				draw_rect(Rect2(x + 5, HORIZON - h + 8, 3, 14), Color(accent, 0.7 if on else 0.15))
			x += w
	# Wet street: darker, with the skyline smeared into it.
	draw_rect(Rect2(0, HORIZON, VIEW.x, VIEW.y - HORIZON), Color("#07070d"))
	for i in 18:
		var y := HORIZON + 4 + i * 7.0
		var wobble := sin(_t * 2.0 + i) * 6.0
		draw_line(Vector2(40 + wobble, y), Vector2(VIEW.x - 40 + wobble, y), Color(COLOR_HP, 0.05), 1.0)
	draw_line(Vector2(0, HORIZON), Vector2(VIEW.x, HORIZON), Color(COLOR_TIME, 0.5), 1.0)


func _draw_logo(font: Font) -> void:
	var size := 56
	var text := "T E N E T"
	var y := 110.0
	var glitch := fmod(_t, 3.1) < 0.12
	var jitter := Vector2(_rng.randf_range(-3, 3), 0) if glitch else Vector2.ZERO
	# Glow passes, split channels, then the face.
	for spread in [3.0, 2.0]:
		draw_string(font, Vector2(spread, y), text, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, size, Color(COLOR_HP, 0.15))
		draw_string(font, Vector2(-spread, y), text, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, size, Color(COLOR_TIME, 0.15))
	draw_string(font, Vector2(2, y) + jitter, text, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, size, Color(COLOR_HP, 0.8))
	draw_string(font, Vector2(-2, y) - jitter, text, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, size, Color(COLOR_TIME, 0.8))
	draw_string(font, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, size, Color.WHITE)
	# Reflection in the street, upside down: still reads TENET.
	# Maps y to HORIZON + (HORIZON - y) * MIRROR.
	draw_set_transform(Vector2(0, HORIZON * (1.0 + MIRROR)), 0.0, Vector2(1, -MIRROR))
	draw_string(font, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, size, Color(COLOR_TIME, 0.18))
	draw_string(font, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, size, Color(COLOR_HP, 0.08))
	draw_set_transform(Vector2.ZERO)
	draw_string(font, Vector2(0, y + 26), "EVERY MISTAKE CAN BE UNDONE.  FOR A FEW MILLISECONDS.",
		HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 9, Color(1, 1, 1, 0.6))


func _draw_menu(font: Font) -> void:
	for i in _items.size():
		var y := 290.0 + i * 18.0
		var chosen := i == _selected
		var label := " ".join(_items[i].split(""))
		var color := COLOR_TIME if chosen else COLOR_DIM
		draw_string(font, Vector2(0, y), label, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 12, color)
		if chosen:
			var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			var pulse := 2.0 * sin(_t * 6.0)
			for side in [-1, 1]:
				var c := Vector2(VIEW.x / 2 + side * (w / 2 + 14 + pulse), y - 4)
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -3), c + Vector2(3, 0), c + Vector2(0, 3), c + Vector2(-3, 0)]), COLOR_TIME)
	draw_string(font, Vector2(0, 350), "W / S to choose   ·   SPACE to select", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 8, Color(1, 1, 1, 0.3))


func _draw_controls(font: Font) -> void:
	var panel := Rect2(150, 190, 340, 140)
	draw_rect(panel, Color(0, 0, 0, 0.75))
	draw_rect(panel, Color(COLOR_TIME, 0.6), false, 1.0)
	for i in CONTROLS.size():
		var y := panel.position.y + 22 + i * 19.0
		draw_string(font, Vector2(panel.position.x + 18, y), CONTROLS[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COLOR_TIME)
		draw_string(font, Vector2(panel.position.x + 96, y), CONTROLS[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
	draw_string(font, Vector2(0, panel.end.y + 16), "SPACE to go back", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 8, COLOR_DIM)
