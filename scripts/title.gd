extends Node2D
## Title screen: the generated future-Japan background (tools/gen_menu_bg.py)
## with parallax, falling sakura and golden motes; the KURO'S TENET logo; a
## techno menu (start, controls, settings, quit) built on MenuList.

const LEVEL := "res://scenes/main.tscn"
const STORY := "res://scenes/story_intro.tscn"
const VIEW := Vector2(640, 360)
const CYAN := Color("#30e8ff")
const PINK := Color("#ff3d8b")
const GOLD := Color("#ffcf5a")
const INK := Color("#eae6ff")
const LAYERS := [["sky", 2.0], ["far", 5.0], ["city", 9.0], ["near", 14.0]]
const MENU_TOP := 190.0

const CONTROLS := [
	["MOVE", "A / D     aim  W / S"],
	["JUMP", "SPACE  or  W     -   again in the air"],
	["ATTACK", "J  or  LEFT CLICK   -   tap fast to combo"],
	["SPECIAL", "Q   or   hold attack"],
	["DASH", "K  or  SHIFT"],
	["BLOCK", "hold F  or  RIGHT CLICK   -   time it to parry"],
	["REWIND", "hold L  or  E"],
	["PAUSE", "ESC"],
]

enum Screen { MAIN, CONTROLS, SETTINGS }

var _screen := Screen.MAIN
var _main := MenuList.new()
var _settings := MenuList.new()
var _controls_back := MenuList.new()
var _layers: Array[Sprite2D] = []
var _starting := false
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	if Array(OS.get_cmdline_user_args()).any(func(a: String) -> bool:
			return a.begins_with("--autopilot=") and a != "--autopilot=title"):
		get_tree().change_scene_to_file.call_deferred(LEVEL)
		return
	Game.set_state(Game.State.TITLE)
	Sfx.play_music()
	Sfx.set_music_volume(-14.0)

	for layer: Array in LAYERS:
		var sprite := Sprite2D.new()
		sprite.texture = load("res://assets/ui/menu/%s.png" % layer[0])
		sprite.centered = false
		# Oversize slightly so parallax never reveals an edge.
		sprite.scale = Vector2.ONE * 1.06
		sprite.position = -VIEW * 0.03
		sprite.z_index = -10
		add_child(sprite)
		_layers.append(sprite)
	_add_petals()
	_add_motes()

	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_hdr_threshold = 0.7
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var ui := CanvasLayer.new()
	add_child(ui)
	var main_items := [{"id": "start", "label": "START"}, {"id": "controls", "label": "CONTROLS"},
		{"id": "settings", "label": "SETTINGS"}]
	if not OS.has_feature("web"):
		main_items.append({"id": "quit", "label": "QUIT"})
	_main.set_items(main_items)
	_main.position = Vector2((VIEW.x - _main.row_width) / 2, MENU_TOP)
	_main.chosen.connect(_on_main)
	ui.add_child(_main)

	_settings.row_width = 260.0
	_settings.gap = 4.0
	_settings.set_items(Settings.menu_items())
	_settings.position = Vector2((VIEW.x - _settings.row_width) / 2, 178)
	_settings.changed.connect(func(id: String, value: Variant) -> void: Settings.set_option(id, value))
	_settings.chosen.connect(func(_id: String) -> void: _show(Screen.MAIN))
	_settings.back.connect(func() -> void: _show(Screen.MAIN))
	ui.add_child(_settings)

	_controls_back.row_width = 120.0
	_controls_back.set_items([{"id": "back", "label": "BACK"}])
	_controls_back.position = Vector2((VIEW.x - 120) / 2, 316)
	_controls_back.chosen.connect(func(_id: String) -> void: _show(Screen.MAIN))
	_controls_back.back.connect(func() -> void: _show(Screen.MAIN))
	ui.add_child(_controls_back)
	_show(Screen.MAIN)


func _show(screen: Screen) -> void:
	_screen = screen
	_main.visible = screen == Screen.MAIN
	_settings.visible = screen == Screen.SETTINGS
	_controls_back.visible = screen == Screen.CONTROLS
	if screen == Screen.SETTINGS:
		_settings.selected = 0
		_settings.set_items(Settings.menu_items())


func _on_main(id: String) -> void:
	if _starting:
		return
	match id:
		"start":
			_starting = true
			Game.reset_run()
			Fx.flash(Color.WHITE, 0.6)
			await get_tree().create_timer(0.35).timeout
			get_tree().change_scene_to_file(STORY)
		"controls":
			_show(Screen.CONTROLS)
		"settings":
			_show(Screen.SETTINGS)
		"quit":
			get_tree().quit()


func _process(delta: float) -> void:
	_t += delta
	# Layers drift with the mouse and a slow sway: nearer layers move more.
	var mouse := (get_viewport().get_mouse_position() / get_viewport().get_visible_rect().size - Vector2(0.5, 0.5)) * 2.0
	var sway := Vector2(sin(_t * 0.25), cos(_t * 0.2) * 0.5)
	for i in _layers.size():
		var depth: float = LAYERS[i][1]
		_layers[i].position = -VIEW * 0.03 - (mouse.clamp(Vector2(-1, -1), Vector2(1, 1)) + sway * 0.4) * depth
	queue_redraw()


func _add_petals() -> void:
	var image := Image.create(3, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color("#ffb3d1"))
	image.set_pixel(2, 1, Color("#ff7aae"))
	var petals := CPUParticles2D.new()
	petals.texture = ImageTexture.create_from_image(image)
	petals.amount = 70
	petals.lifetime = 9.0
	petals.preprocess = 9.0
	petals.position = Vector2(VIEW.x * 0.6, -10)
	petals.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	petals.emission_rect_extents = Vector2(VIEW.x * 0.7, 4)
	petals.direction = Vector2(-0.6, 1)
	petals.spread = 20.0
	petals.gravity = Vector2(-6, 14)
	petals.initial_velocity_min = 14.0
	petals.initial_velocity_max = 30.0
	petals.angular_velocity_min = -120.0
	petals.angular_velocity_max = 120.0
	petals.angle_min = 0.0
	petals.angle_max = 360.0
	petals.scale_amount_min = 1.0
	petals.scale_amount_max = 1.8
	petals.z_index = 1
	add_child(petals)


func _add_motes() -> void:
	var motes := CPUParticles2D.new()
	motes.amount = 40
	motes.lifetime = 6.0
	motes.preprocess = 6.0
	motes.position = Vector2(448, 90)
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(140, 40)
	motes.direction = Vector2(0, 1)
	motes.spread = 30.0
	motes.gravity = Vector2(0, 4)
	motes.initial_velocity_min = 4.0
	motes.initial_velocity_max = 12.0
	motes.color = Color(GOLD, 0.9)
	motes.scale_amount_min = 1.0
	motes.scale_amount_max = 2.0
	motes.z_index = -5
	add_child(motes)


func _draw() -> void:
	# Darken behind the logo and menu so they read over the scene.
	var clear := Color(0, 0, 0, 0)
	var shade := Color(0.02, 0.01, 0.05, 0.55)
	for side: float in [-1.0, 1.0]:
		var inner := VIEW.x / 2
		var outer := VIEW.x / 2 + side * 210.0
		draw_polygon(PackedVector2Array([Vector2(inner, 0), Vector2(outer, 0), Vector2(outer, VIEW.y), Vector2(inner, VIEW.y)]),
			PackedColorArray([shade, clear, clear, shade]))
	_draw_logo()
	match _screen:
		Screen.CONTROLS:
			_draw_controls()
		Screen.SETTINGS:
			MenuList.draw_panel(self, Rect2(170, 148, 300, 204), "SETTINGS")
		_:
			draw_string(_font, Vector2(0, 350), "W / S or mouse to choose    ENTER / SPACE / CLICK to select",
				HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 8, Color(INK, 0.4))
	draw_string(_font, Vector2(12, 14), "LIGHTNING & THUNDER  ·  GIANT JAM 2", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(INK, 0.35))


func _draw_logo() -> void:
	var y := 112.0
	var glitch := fmod(_t, 3.7) < 0.1
	var jitter := Vector2(_rng.randf_range(-3, 3), 0) if glitch else Vector2.ZERO
	# KURO'S: small, gold, spaced, with rules either side.
	var kuro := "K U R O ' S"
	draw_string(_font, Vector2(0, y - 46), kuro, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 16, Color(GOLD, 0.25))
	draw_string(_font, Vector2(0, y - 47), kuro, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 16, GOLD)
	var half := _font.get_string_size(kuro, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x / 2 + 10
	for side: float in [-1.0, 1.0]:
		var a := Vector2(VIEW.x / 2 + side * half, y - 52)
		draw_line(a, a + Vector2(side * 60, 0), Color(GOLD, 0.7), 1.0)
		draw_colored_polygon(MenuList.diamond(a + Vector2(side * 64, 0), 2.5), GOLD)
	# TENET: big neon with a split-colour glitch.
	var text := "T E N E T"
	var size := 54
	for spread in [4.0, 2.5]:
		draw_string(_font, Vector2(spread, y), text, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, size, Color(PINK, 0.12))
		draw_string(_font, Vector2(-spread, y), text, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, size, Color(CYAN, 0.12))
	draw_string(_font, Vector2(2, y) + jitter, text, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, size, Color(PINK, 0.85))
	draw_string(_font, Vector2(-2, y) - jitter, text, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, size, Color(CYAN, 0.85))
	draw_string(_font, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, size, INK)
	draw_string(_font, Vector2(0, y + 24), "EVERY MISTAKE CAN BE UNDONE.  FOR A FEW MILLISECONDS.",
		HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 8, Color(INK, 0.7))


func _draw_controls() -> void:
	var panel := Rect2(150, 150, 340, 196)
	MenuList.draw_panel(self, panel, "CONTROLS")
	for i in CONTROLS.size():
		var y := panel.position.y + 46 + i * 16.0
		draw_string(_font, Vector2(panel.position.x + 30, y), CONTROLS[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, CYAN)
		draw_string(_font, Vector2(panel.position.x + 100, y), CONTROLS[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, INK)
