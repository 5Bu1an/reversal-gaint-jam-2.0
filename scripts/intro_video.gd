class_name IntroVideo
extends Control
## Full-screen video, then on to another scene. By default it's the opening
## cinematic (assets/video/intro.ogv) going to the title; play_next() reuses
## it for other videos (the studio animation after the ending). Any key or
## click skips.

const SCENE := "res://scenes/intro_video.tscn"
const TITLE := "res://scenes/title.tscn"
const OPENING := preload("res://assets/video/intro.ogv")

static var _video: VideoStream = null
static var _next := ""
const FADE := 0.6
## The skip hint fades in after this long.
const HINT_DELAY := 2.0

var _player := VideoStreamPlayer.new()
var _hint := Label.new()
var _fade := ColorRect.new()
var _t := 0.0
var _leaving := false
var _target := TITLE


## Switch to this scene to play video, then go to next_scene.
static func play_next(video: VideoStream, next_scene: String) -> void:
	_video = video
	_next = next_scene
	(Engine.get_main_loop() as SceneTree).change_scene_to_file(SCENE)


func _ready() -> void:
	var video: VideoStream = _video if _video else OPENING
	_target = _next if _next != "" else TITLE
	_video = null
	_next = ""
	if Array(OS.get_cmdline_user_args()).any(func(a: String) -> bool: return a.begins_with("--autopilot=")):
		get_tree().change_scene_to_file.call_deferred(_target)
		return
	Game.set_state(Game.State.TITLE)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(black)

	_player.stream = video
	_player.expand = true
	_player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_player.finished.connect(_leave)
	add_child(_player)

	_hint.text = "press any key to skip"
	_hint.add_theme_font_size_override("font_size", 8)
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.position -= Vector2(12, 8)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.modulate.a = 0.0
	add_child(_hint)

	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

	_player.play()


func _process(delta: float) -> void:
	_t += delta
	if not _leaving:
		_hint.modulate.a = clampf((_t - HINT_DELAY) / 0.5, 0.0, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if _t < 0.3:
		return
	if (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		_leave()


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	_hint.visible = false
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, FADE)
	tween.parallel().tween_property(_player, "volume_db", -40.0, FADE)
	tween.tween_callback(func() -> void: get_tree().change_scene_to_file(_target))
