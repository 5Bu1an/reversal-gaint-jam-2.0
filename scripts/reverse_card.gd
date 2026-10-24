extends Node2D
## The ending's joke: a reverse card spins in and keeps flipping in fake 3D,
## while "you thought this was a 3D game, didn't you?" types out. Then the
## studio animation plays and the game returns to the title. Any key skips.
## (A generic red reverse card, no card-game branding.)

const STUDIO := preload("res://assets/video/studio.ogv")
const VIEW := Vector2(640, 360)
const CARD := Vector2(96, 144)
const RED := Color("#e3262b")
const RED_DARK := Color("#9e1418")
const PINK := Color("#ff3d8b")
const CYAN := Color("#30e8ff")
const INK := Color("#f4f0ff")
const LINE_1 := "YOU THOUGHT THIS WAS A 3D GAME,"
const LINE_2 := "DIDN'T YOU?"
const LENGTH := 7.0

var _t := 0.0
var _leaving := false
var _slam_played := false
var _typed_last := 0
var _font: Font
var _card_style := StyleBoxFlat.new()
var _back_style := StyleBoxFlat.new()
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_font = ThemeDB.fallback_font
	if Array(OS.get_cmdline_user_args()).any(func(a: String) -> bool: return a.begins_with("--autopilot=") and a != "--autopilot=ending"):
		_leave.call_deferred()
		return
	Game.set_state(Game.State.TITLE)
	for style: StyleBoxFlat in [_card_style, _back_style]:
		style.set_corner_radius_all(10)
		style.border_color = Color.WHITE
		style.set_border_width_all(4)
		style.anti_aliasing = false
	_card_style.bg_color = RED
	_back_style.bg_color = Color("#14101c")
	Sfx.play("dash", 0.0, 0.0)


func _process(delta: float) -> void:
	_t += delta
	var typed := _typed_count()
	if typed > _typed_last:
		Sfx.play("holo_type", -8.0, 0.2)
		_typed_last = typed
	if not _slam_played and _t >= 3.4:
		_slam_played = true
		Sfx.play("kill", 0.0, 0.0)
		Sfx.play("rewind_end", 0.0, 0.0)
	if _t >= LENGTH:
		_leave()
	queue_redraw()


func _typed_count() -> int:
	return clampi(int((_t - 1.2) * 18.0), 0, LINE_1.length())


func _unhandled_input(event: InputEvent) -> void:
	# A grace period so keys mashed through the hologram don't skip the joke.
	if _t > 1.5 and (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		_leave()


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	IntroVideo.play_next(STUDIO, IntroVideo.TITLE)


func _draw() -> void:
	_draw_sunburst()
	_draw_card()
	_draw_text()
	var fade := clampf(1.0 - _t / 0.3, 0.0, 1.0) + clampf((_t - (LENGTH - 0.4)) / 0.4, 0.0, 1.0)
	if fade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0, 0, 0, minf(fade, 1.0)))


func _draw_sunburst() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color("#1a0b2e"))
	var center := Vector2(VIEW.x / 2, 150)
	var spin := _t * 0.35
	for i in 16:
		var a0 := spin + TAU * i / 16.0
		var a1 := a0 + TAU / 32.0
		draw_colored_polygon(PackedVector2Array([center, center + Vector2.from_angle(a0) * 800, center + Vector2.from_angle(a1) * 800]),
			Color("#2c1450") if i % 2 == 0 else Color("#3a1a63"))
	for r in [60.0, 110.0, 170.0]:
		draw_arc(center, r + sin(_t * 2.0 + r) * 4.0, 0, TAU, 64, Color(PINK, 0.12), 2.0)


func _draw_card() -> void:
	var center := Vector2(VIEW.x / 2, 150)
	# Fly in: from tiny and spinning, overshoot, settle.
	var arrive := clampf(_t / 0.9, 0.0, 1.0)
	var ease := 1.0 - pow(1.0 - arrive, 3.0)
	var overshoot := 1.0 + sin(arrive * PI) * 0.25
	var spin := (1.0 - ease) * TAU * 2.0
	# Then a fake-3D flip that never stops (the joke).
	var flip := cos(maxf(_t - 0.9, 0.0) * 2.6)
	var bob := sin(_t * 2.2) * 5.0
	var scale_by := ease * overshoot
	if scale_by <= 0.01:
		return
	draw_set_transform(center + Vector2(0, bob) + Vector2(4, 6), spin, Vector2(flip, 1.0) * scale_by)
	draw_rect(Rect2(-CARD / 2, CARD), Color(0, 0, 0, 0.35))
	draw_set_transform(center + Vector2(0, bob), spin, Vector2(flip, 1.0) * scale_by)
	if flip >= 0.0:
		_draw_card_face()
	else:
		_draw_card_back()
	draw_set_transform(Vector2.ZERO)


func _draw_card_face() -> void:
	var rect := Rect2(-CARD / 2, CARD)
	draw_style_box(_card_style, rect)
	# Tilted white oval in the middle with the reverse arrows.
	_oval(Vector2.ZERO, Vector2(34, 56), -0.5, Color.WHITE)
	_reverse_arrows(Vector2.ZERO, 1.0, RED)
	for corner: Vector2 in [Vector2(-CARD.x / 2 + 14, -CARD.y / 2 + 16), Vector2(CARD.x / 2 - 14, CARD.y / 2 - 16)]:
		_reverse_arrows(corner, 0.32, Color.WHITE)


func _draw_card_back() -> void:
	var rect := Rect2(-CARD / 2, CARD)
	draw_style_box(_back_style, rect)
	_oval(Vector2.ZERO, Vector2(32, 54), -0.5, RED)
	_oval(Vector2.ZERO, Vector2(24, 44), -0.5, Color(RED_DARK, 0.9))
	var pulse := 0.5 + 0.5 * sin(_t * 6.0)
	_oval(Vector2.ZERO, Vector2(8, 14), -0.5, Color(PINK, pulse))


func _oval(center: Vector2, radii: Vector2, tilt: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y).rotated(tilt))
	draw_colored_polygon(points, color)


## Two curved arrows chasing each other: the reverse symbol.
func _reverse_arrows(center: Vector2, size: float, color: Color) -> void:
	for side: float in [1.0, -1.0]:
		var arc := PackedVector2Array()
		for i in 9:
			var a := lerpf(-0.2, PI - 0.6, i / 8.0) + (0.0 if side > 0 else PI)
			arc.append(center + Vector2.from_angle(a - 0.5) * Vector2(14, 22) * size)
		draw_polyline(arc, color, 5.0 * size)
		var tip := arc[arc.size() - 1]
		var along := (arc[arc.size() - 1] - arc[arc.size() - 2]).normalized()
		var normal := along.orthogonal()
		draw_colored_polygon(PackedVector2Array([tip + along * 8 * size, tip + normal * 7 * size, tip - normal * 7 * size]), color)


func _draw_text() -> void:
	var line1 := LINE_1.left(_typed_count())
	draw_string(_font, Vector2(2, 286), line1, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 18, Color(CYAN, 0.5))
	draw_string(_font, Vector2(0, 285), line1, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 18, INK)
	if _t >= 3.4:
		var k := clampf((_t - 3.4) / 0.25, 0.0, 1.0)
		var size := int(lerpf(60.0, 30.0, k))
		var shake := Vector2(_rng.randf_range(-3, 3), _rng.randf_range(-2, 2)) * (1.0 - k)
		draw_string(_font, Vector2(3, 326) + shake, LINE_2, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, size, Color(CYAN, 0.6))
		draw_string(_font, Vector2(-3, 326) - shake, LINE_2, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, size, Color(PINK, 0.8))
		draw_string(_font, Vector2(0, 326) + shake, LINE_2, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, size, INK)
