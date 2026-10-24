extends Node2D
## Title screen on the painted Edo-cyberpunk city: ornate header and footer,
## neon TENET logo, plaque-button menu, controls panel, rain and music.

const LEVEL := "res://scenes/main.tscn"
const COLOR_TIME := Color("#05d9e8")
const COLOR_HP := Color("#ff2a6d")
const COLOR_DIM := Color(1, 1, 1, 0.35)
const COLOR_INK := Color("#0b0b14")
const VIEW := Vector2(640, 360)
const BUTTON_H := 40.0
const BUTTON_Y := 204.0
const BUTTON_STEP := 40.0

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
var _press_t := 0.0


func _ready() -> void:
	if Array(OS.get_cmdline_user_args()).any(func(a: String) -> bool:
			return a.begins_with("--autopilot=") and a != "--autopilot=title"):
		get_tree().change_scene_to_file.call_deferred(LEVEL)
		return
	if not OS.has_feature("web"):
		_items.append("QUIT")
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
	_press_t = maxf(_press_t - delta, 0.0)
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
	_press_t = 0.15
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
	draw_texture_rect(UiArt.MENU_BACKGROUND, Rect2(Vector2.ZERO, VIEW), false)
	# Darken toward the centre column so the menu reads over the painting.
	var shade := Color(0, 0, 0, 0.5)
	var clear := Color(0, 0, 0, 0)
	draw_rect(Rect2(220, 0, 200, VIEW.y), shade)
	for side: float in [-1.0, 1.0]:
		var inner := VIEW.x / 2 + side * 100.0
		var outer := VIEW.x / 2 + side * 230.0
		draw_polygon(PackedVector2Array([Vector2(inner, 0), Vector2(outer, 0), Vector2(outer, VIEW.y), Vector2(inner, VIEW.y)]),
			PackedColorArray([shade, clear, clear, shade]))
	UiArt.draw_painted(self, UiArt.HEADER, Vector2(VIEW.x / 2, 46), 46.0)
	_draw_logo(font)
	if _show_controls:
		_draw_controls(font)
	else:
		_draw_menu(font)
	draw_string(font, Vector2(16, 16), "GIANT JAM 2  ·  THEME: REVERSAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(UiArt.INK, 0.45))


func _draw_logo(font: Font) -> void:
	var size := 52
	var text := "T E N E T"
	var y := 132.0
	var glitch := fmod(_t, 3.1) < 0.12
	var jitter := Vector2(_rng.randf_range(-3, 3), 0) if glitch else Vector2.ZERO
	for spread in [3.0, 2.0]:
		draw_string(font, Vector2(spread, y), text, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, size, Color(COLOR_HP, 0.15))
		draw_string(font, Vector2(-spread, y), text, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, size, Color(COLOR_TIME, 0.15))
	draw_string(font, Vector2(2, y) + jitter, text, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, size, Color(COLOR_HP, 0.8))
	draw_string(font, Vector2(-2, y) - jitter, text, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, size, Color(COLOR_TIME, 0.8))
	draw_string(font, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, size, UiArt.INK)
	draw_string(font, Vector2(0, y + 22), "EVERY MISTAKE CAN BE UNDONE.  FOR A FEW MILLISECONDS.",
		HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 9, Color(UiArt.INK, 0.75))


func _draw_menu(font: Font) -> void:
	for i in _items.size():
		var center := Vector2(VIEW.x / 2, BUTTON_Y + i * BUTTON_STEP)
		var chosen := i == _selected
		var plaque := UiArt.BUTTON
		if chosen:
			plaque = UiArt.BUTTON_PRESSED if _press_t > 0.0 else UiArt.BUTTON_HOVER
		UiArt.draw_painted(self, plaque, center, BUTTON_H)
		var label := " ".join(_items[i].split(""))
		var color := Color.WHITE if chosen else Color(UiArt.INK, 0.7)
		draw_string(font, Vector2(0, center.y + 4), label, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 10, color)
	var bottom := BUTTON_Y + (_items.size() - 1) * BUTTON_STEP
	UiArt.draw_painted(self, UiArt.FOOTER, Vector2(VIEW.x / 2, bottom + 38), 28.0)
	draw_string(font, Vector2(0, 352), "W / S to choose   ·   SPACE to select", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 8, Color(UiArt.INK, 0.45))


func _draw_controls(font: Font) -> void:
	var panel := Rect2(165, 160, 310, 194)
	draw_texture_rect(UiArt.MODAL, panel, false)
	for i in CONTROLS.size():
		var y := panel.position.y + 42 + i * 21.0
		draw_string(font, Vector2(panel.position.x + 40, y), CONTROLS[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COLOR_TIME)
		draw_string(font, Vector2(panel.position.x + 112, y), CONTROLS[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiArt.INK)
	draw_string(font, Vector2(0, panel.end.y - 26), "SPACE to go back", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 8, Color(UiArt.INK, 0.6))
