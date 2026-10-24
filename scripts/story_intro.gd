class_name StoryIntro
extends Node2D
## Story intro between the title and the level. The samurai wakes in the
## dark (grunts, a muffled murmur), then a Chronos Corp hologram flickers on
## and addresses him: each Japanese line types out with an English subtitle
## underneath. Any key finishes the line or moves to the next; Esc skips.
##
## With StoryIntro.ending set (after beating Kuro) it skips the wake-up,
## speaks ENDING_LINES instead and hands over to the reverse-card screen.

const LEVEL := "res://scenes/main.tscn"
const REVERSE_CARD := "res://scenes/reverse_card.tscn"
const JP_FONT := preload("res://assets/fonts/NotoSansJP-subset.ttf")
## The city he wakes up in, glimpsed through fluttering eyelids.
const CITY_LAYERS := [preload("res://assets/ui/menu/sky.png"), preload("res://assets/ui/menu/far.png"),
	preload("res://assets/ui/menu/city.png"), preload("res://assets/ui/menu/near.png")]
const VIEW := Vector2(640, 360)
const CYAN := Color("#30e8ff")
const PINK := Color("#ff3d8b")
const INK := Color("#eae6ff")

## [Japanese, English]
const LINES := [
	["目覚めよ、古の武士よ。", "Awaken, warrior of an age long past."],
	["汝の名は、千年の時を越えて語り継がれてきた。", "Your name has echoed across a thousand years."],
	["我らは汝を、未来へと呼び寄せた。", "We have summoned you into the future..."],
	["その伝説が、真実かどうかを確かめるために。", "...to learn whether your legend is true."],
	["そして、汝がどれほどの伝説なのかを。", "And just how great a legend you are."],
	["元の世界へ帰りたくば、クロを討て。", "If you wish to return to your world, defeat Kuro."],
	["奴は時をも操る、恐るべき者。", "He bends time itself. No foe you have faced compares."],
	["ゆえに我らは、汝に力を授けた。", "So we have granted you powers."],
	["だが、その使い方は――自ら見出すがよい。", "But how to wield them... you must discover yourself."],
	["さあ、行け。汝の伝説を証明せよ。", "Now go. Prove your legend."],
]

const ENDING_LINES := [
	["見事だ、武士よ。クロは討たれた。", "Well done, warrior. Kuro has fallen."],
	["汝の伝説は、真実であった。", "Your legend was true."],
	["約束通り、元の世界へ帰るがよい。", "As promised, you may return to your home world."],
]

## Set before changing to this scene to play the ending instead.
static var ending := false

const CHARS_PER_SEC := 16.0
const HOLD := 2.4 # after a line finishes typing
const WAKE_END := 4.6 # grunts and murmur play before this
const BOOT_TIME := 1.0
const OUTRO := 1.2

enum Phase { WAKE, BOOT, TALK, OUTRO }

var _phase := Phase.WAKE
var _t := 0.0
var _phase_t := 0.0
var _line := 0
var _lines: Array = LINES
var _ending := false
var _typed := 0.0
var _hold_t := 0.0
var _events: Array = []
var _leaving := false
var _rng := RandomNumberGenerator.new()
var _font: Font
## Noto Sans JP at a bold weight (the variable font defaults to a thin one).
var _jp := FontVariation.new()


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_jp.base_font = JP_FONT
	_jp.variation_opentype = {"weight": 700}
	_ending = ending
	ending = false
	if _ending:
		_lines = ENDING_LINES
	if Array(OS.get_cmdline_user_args()).any(func(a: String) -> bool: return a.begins_with("--autopilot=") and a != "--autopilot=story"):
		get_tree().change_scene_to_file.call_deferred(REVERSE_CARD if _ending else LEVEL)
		return
	Game.set_state(Game.State.TITLE)
	Sfx.set_music_volume(-40.0)
	if _ending:
		_set_phase(Phase.BOOT)
		Sfx.play("holo_on", 0.0, 0.0)
		return
	_events = [
		[0.5, func() -> void: Sfx.play("grunt_wake", 0.0, 0.0)],
		[1.6, func() -> void: Sfx.play("grunt_breath", -2.0, 0.0)],
		[2.5, func() -> void: Sfx.play("mumble", -3.0, 0.0)],
		[4.3, func() -> void: Sfx.play("grunt_hm", -1.0, 0.0)],
	]


func _process(delta: float) -> void:
	_t += delta
	_phase_t += delta
	for event in _events.duplicate():
		if _t >= event[0]:
			_events.erase(event)
			event[1].call()
	match _phase:
		Phase.WAKE:
			if _t >= WAKE_END:
				_set_phase(Phase.BOOT)
				Sfx.play("holo_on", 0.0, 0.0)
		Phase.BOOT:
			if _phase_t >= BOOT_TIME:
				_set_phase(Phase.TALK)
		Phase.TALK:
			_update_talk(delta)
		Phase.OUTRO:
			if _phase_t >= OUTRO:
				_go()
	queue_redraw()


func _set_phase(phase: Phase) -> void:
	_phase = phase
	_phase_t = 0.0


func _update_talk(delta: float) -> void:
	var text: String = _lines[_line][0]
	if _typed < text.length():
		var before := int(_typed)
		_typed = minf(_typed + CHARS_PER_SEC * delta, text.length())
		if int(_typed) > before and text[int(_typed) - 1] not in ["、", "。", "―"]:
			Sfx.play("holo_type", -10.0, 0.15)
	else:
		_hold_t += delta
		if _hold_t >= HOLD:
			_next_line()


func _next_line() -> void:
	_line += 1
	_typed = 0.0
	_hold_t = 0.0
	if _line >= _lines.size():
		_line = _lines.size() - 1
		_typed = _lines[_line][0].length()
		_set_phase(Phase.OUTRO)
		Sfx.play("holo_off", 0.0, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventMouseButton) or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("ui_cancel"):
		_go()
	elif _phase == Phase.TALK:
		var text: String = _lines[_line][0]
		if _typed < text.length():
			_typed = text.length()
		else:
			_next_line()
	elif _phase == Phase.WAKE and _t > 1.0:
		_set_phase(Phase.BOOT)
		Sfx.play("holo_on", 0.0, 0.0)
		_events.clear()


func _go() -> void:
	if _leaving:
		return
	_leaving = true
	Sfx.set_music_volume(Sfx.MUSIC_DB)
	get_tree().change_scene_to_file(REVERSE_CARD if _ending else LEVEL)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color("#020207"))
	_draw_wake()
	if _phase != Phase.WAKE:
		_draw_hologram()
	var fade_in := clampf(1.0 - _t / 0.5, 0.0, 1.0)
	var fade_out := clampf(_phase_t / OUTRO, 0.0, 1.0) if _phase == Phase.OUTRO else 0.0
	if fade_in + fade_out > 0.0:
		draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0, 0, 0, maxf(fade_in, fade_out)))
	if _phase == Phase.TALK or _phase == Phase.WAKE:
		draw_string(_font, Vector2(0, 350), "any key: next      esc: skip   ", HORIZONTAL_ALIGNMENT_RIGHT, VIEW.x, 7, Color(INK, 0.3))


## How open his eyes are over the wake-up: a flutter at each grunt, then
## open as the hologram appears.
func _lids() -> float:
	if _phase != Phase.WAKE:
		return 1.0
	var keys := [[0.0, 0.0], [1.3, 0.0], [1.7, 0.22], [2.2, 0.05], [2.9, 0.12], [3.6, 0.4], [3.9, 0.15], [4.4, 0.7]]
	for i in keys.size() - 1:
		if _t < keys[i + 1][0]:
			var k: float = (_t - keys[i][0]) / (keys[i + 1][0] - keys[i][0])
			return lerpf(keys[i][1], keys[i + 1][1], smoothstep(0.0, 1.0, k))
	return keys[-1][1]


## Coming to: a blurred, red-tinted glimpse of the neon city between the
## eyelids, a heartbeat pulse and drifting dust. Behind the hologram the city
## stays, dimmed.
func _draw_wake() -> void:
	var open := _lids()
	var tint := Color(0.5, 0.32, 0.42) if _phase == Phase.WAKE else Color(0.28, 0.24, 0.36)
	var wobble := Vector2(sin(_t * 1.7) * 3.0, cos(_t * 1.3) * 2.0) * (1.0 - open * 0.6)
	for i in CITY_LAYERS.size():
		# Doubled, offset draws stand in for blurry, unfocused eyes.
		for ghost: float in [-1.0, 1.0]:
			var off := wobble + Vector2(ghost * (1.0 - open) * 6.0, 0)
			draw_texture_rect(CITY_LAYERS[i], Rect2(off - VIEW * 0.02, VIEW * 1.04), false, Color(tint, 0.5))
	var beat := pow(maxf(sin(_t * 2.6), 0.0), 6.0)
	if _phase == Phase.WAKE:
		draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.35, 0.02, 0.06, 0.25 * beat))
	var lid := VIEW.y / 2 * (1.0 - open)
	draw_rect(Rect2(0, 0, VIEW.x, lid), Color.BLACK)
	draw_rect(Rect2(0, VIEW.y - lid, VIEW.x, lid), Color.BLACK)
	_rng.seed = 11
	for i in 40:
		var p := Vector2(_rng.randf_range(0, VIEW.x), fposmod(_rng.randf_range(0, VIEW.y) - _t * _rng.randf_range(3, 9), VIEW.y))
		draw_circle(p, _rng.randf_range(0.5, 1.2), Color(1, 0.9, 0.8, 0.15))


func _draw_hologram() -> void:
	var boot := clampf(_phase_t / BOOT_TIME, 0.0, 1.0) if _phase == Phase.BOOT else 1.0
	var off := clampf(_phase_t / OUTRO, 0.0, 1.0) if _phase == Phase.OUTRO else 0.0
	# Flicker while booting and while shutting down.
	var flicker := 1.0
	if boot < 1.0 or off > 0.0:
		flicker = 0.25 if _rng.randf() < 0.3 else 1.0
	var power := boot * (1.0 - off) * flicker
	if power <= 0.0:
		return
	var center := Vector2(VIEW.x / 2, 150)
	# Projection beam from an emitter below.
	var emitter := Vector2(VIEW.x / 2, 330)
	draw_polygon(PackedVector2Array([emitter + Vector2(-6, 0), emitter + Vector2(6, 0), Vector2(center.x + 230, 230), Vector2(center.x - 230, 230)]),
		PackedColorArray([Color(CYAN, 0.35 * power), Color(CYAN, 0.35 * power), Color(CYAN, 0.0), Color(CYAN, 0.0)]))
	draw_rect(Rect2(emitter.x - 14, emitter.y, 28, 4), Color(CYAN, 0.8 * power))

	# Panel unfolds vertically as it boots.
	var panel := Rect2(center.x - 260, center.y - 110 * boot, 520, 220 * boot)
	if panel.size.y < 30.0:
		draw_line(Vector2(panel.position.x, center.y), Vector2(panel.end.x, center.y), Color(CYAN, power), 2.0)
		return
	var shape := MenuList.chamfer(panel, 14.0)
	draw_colored_polygon(shape, Color(0.01, 0.08, 0.13, 0.78 * power))
	var edge := shape.duplicate()
	edge.append(shape[0])
	draw_polyline(edge, Color(CYAN, 0.8 * power), 1.0)
	draw_polyline(edge, Color(CYAN, 0.15 * power), 5.0)
	# Scanlines and a rolling bright band.
	var band_y := panel.position.y + fposmod(_t * 60.0, maxf(panel.size.y, 1.0))
	for y in range(int(panel.position.y), int(panel.end.y), 3):
		draw_line(Vector2(panel.position.x + 4, y), Vector2(panel.end.x - 4, y), Color(CYAN, 0.05 * power), 1.0)
	draw_rect(Rect2(panel.position.x + 2, band_y, panel.size.x - 4, 6), Color(CYAN, 0.06 * power))
	if boot < 1.0:
		return

	# Chronos Corp emblem: a rotating ring with clock ticks around an eye.
	var emblem := Vector2(center.x, panel.position.y + 44)
	var spin := _t * 0.8
	draw_arc(emblem, 22, spin, spin + TAU * 0.8, 40, Color(CYAN, 0.9 * power), 1.5)
	draw_arc(emblem, 16, -spin * 1.5, -spin * 1.5 + TAU * 0.6, 32, Color(PINK, 0.8 * power), 1.0)
	for i in 12:
		var a := TAU * i / 12.0 + spin * 0.3
		draw_line(emblem + Vector2.from_angle(a) * 25, emblem + Vector2.from_angle(a) * 28, Color(CYAN, 0.6 * power), 1.0)
	draw_colored_polygon(PackedVector2Array([emblem + Vector2(-9, 0), emblem + Vector2(0, -5), emblem + Vector2(9, 0), emblem + Vector2(0, 5)]), Color(CYAN, 0.9 * power))
	draw_circle(emblem, 2.5, Color(0.02, 0.05, 0.1, power))
	draw_string(_font, Vector2(panel.position.x, emblem.y + 40), "C H R O N O S   C O R P", HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 7, Color(CYAN, 0.6 * power))

	# The current line: Japanese typing out, English fading in beneath.
	var jp: String = _lines[_line][0]
	var shown := jp.left(int(_typed))
	var jp_y := panel.position.y + 134
	var jitter := Vector2(_rng.randf_range(-1, 1), 0) if _rng.randf() < 0.04 else Vector2.ZERO
	for glow in [Vector2(0, 2), Vector2(0, -2), Vector2(2, 0), Vector2(-2, 0)]:
		draw_string(_jp, Vector2(panel.position.x, jp_y) + glow, shown, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 21, Color(CYAN, 0.18 * power))
	draw_string(_jp, Vector2(panel.position.x + 1.5, jp_y) + jitter, shown, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 21, Color(PINK, 0.5 * power))
	draw_string(_jp, Vector2(panel.position.x, jp_y), shown, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 21, Color(1, 1, 1, power))
	var done := _typed >= jp.length()
	var english_alpha := clampf(_hold_t / 0.4, 0.0, 1.0) if done else 0.0
	if _phase == Phase.OUTRO:
		english_alpha = 1.0
	draw_string(_font, Vector2(panel.position.x, jp_y + 32), _lines[_line][1], HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 12, Color(INK, english_alpha * power))
	# Progress pips.
	for i in _lines.size():
		var pip := Vector2(center.x - (_lines.size() - 1) * 6 + i * 12, panel.end.y - 14)
		draw_circle(pip, 2.0, Color(CYAN, (0.9 if i <= _line else 0.2) * power))
