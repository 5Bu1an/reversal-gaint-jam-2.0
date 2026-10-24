extends Node2D
## The level, built from rectangles until the tileset lands. Five sections left
## to right: intro, spike run, locked wave arena, shrine checkpoint, boss arena.
## Owns the player, enemies, ghosts, camera and the rewind screen effect.

const LEVEL_W := 3200.0
const FLOOR_Y := 328.0

const SOLIDS: Array[Rect2] = [
	Rect2(0, 328, 3200, 32), # floor
	Rect2(0, 0, 3200, 16), # ceiling
	Rect2(0, 0, 16, 360), # left wall
	Rect2(3184, 0, 16, 360), # right wall
	# 1. Intro
	Rect2(150, 280, 80, 10),
	Rect2(300, 236, 90, 10),
	Rect2(460, 280, 80, 10),
	# 2. Spike run
	Rect2(720, 280, 48, 10),
	Rect2(820, 262, 48, 10),
	Rect2(980, 280, 48, 10),
	Rect2(1060, 262, 48, 10),
	# 3. Wave arena
	Rect2(1400, 270, 80, 10),
	Rect2(1560, 226, 80, 10),
	Rect2(1720, 270, 80, 10),
	# 4. Shrine
	Rect2(2180, 280, 80, 10),
	Rect2(2330, 250, 80, 10),
	# 5. Boss arena
	Rect2(2700, 262, 72, 10),
	Rect2(2990, 262, 72, 10),
]
const SPIKES: Array[Rect2] = [
	Rect2(700, 320, 180, 8),
	Rect2(950, 320, 140, 8),
]
const SHARDS: Array[Vector2] = [Vector2(345, 222), Vector2(915, 236), Vector2(1600, 210), Vector2(2370, 236)]

const PLAYER_SPAWN := Vector2(48, 316)
const CHECKPOINT_X := 2060.0
const CHECKPOINT_SPAWN := Vector2(2060, 316)

const WAVE_ARENA_TRIGGER := Rect2(1340, 16, 520, 312)
const WAVE_ARENA_GATES: Array[Rect2] = [Rect2(1296, 16, 12, 312), Rect2(1892, 16, 12, 312)]
const BOSS_ARENA_TRIGGER := Rect2(2640, 16, 540, 312)
const BOSS_ARENA_GATES: Array[Rect2] = [Rect2(2576, 16, 12, 312)]
const BOSS_SPAWN := Vector2(3020, 306)
const PORTAL := Rect2(3130, 276, 30, 52)

const MIN_GHOST_FRAMES := 6

const COLOR_WALL := Color("#1a1a2e")
const COLOR_EDGE := Color("#05d9e8")
const COLOR_SPIKE := Color("#ff2a6d")
const COLOR_SHRINE := Color("#f5c542")

var player: Player
var boss: Boss
var _ghosts := Node2D.new()
var _overlay := ColorRect.new()
var _glitch := ColorRect.new()


func _ready() -> void:
	Rewind.reset()
	Game.set_state(Game.State.PLAYING)
	_build_skyline()
	for rect in SOLIDS:
		_add_solid(rect)
	for pos in SHARDS:
		var shard := Shard.new()
		shard.position = pos
		add_child(shard)

	# Roaming enemies outside the arenas.
	_grunt(Vector2(260, 316))
	_grunt(Vector2(520, 316))
	_drone(Vector2(850, 180))
	_drone(Vector2(1150, 190))
	_grunt(Vector2(1210, 316))
	_grunt(Vector2(2440, 316))

	var waves: Array = []
	if Game.checkpoint < 1:
		waves = [
			[_grunt(Vector2(1450, 316)), _grunt(Vector2(1650, 316)), _grunt(Vector2(1800, 316))],
			[_drone(Vector2(1450, 170)), _drone(Vector2(1750, 170)), _grunt(Vector2(1500, 316)), _grunt(Vector2(1700, 316))],
			[_drone(Vector2(1400, 160)), _drone(Vector2(1600, 130)), _drone(Vector2(1800, 160)), _grunt(Vector2(1600, 316))],
		]
	_arena(WAVE_ARENA_TRIGGER, WAVE_ARENA_GATES, waves)

	boss = Boss.new()
	boss.position = BOSS_SPAWN
	boss.arena_left = BOSS_ARENA_GATES[0].end.x
	boss.arena_right = LEVEL_W - 16
	add_child(boss)
	Game.boss = boss
	_arena(BOSS_ARENA_TRIGGER, BOSS_ARENA_GATES, [[boss]])

	_ghosts.name = "Ghosts"
	add_child(_ghosts)
	player = Player.new()
	player.position = CHECKPOINT_SPAWN if Game.checkpoint >= 1 else PLAYER_SPAWN
	player.hazards = SPIKES
	add_child(player)

	var camera := Camera2D.new()
	camera.limit_left = 0
	camera.limit_right = int(LEVEL_W)
	camera.limit_top = 0
	camera.limit_bottom = 360
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	player.add_child(camera)
	camera.reset_smoothing.call_deferred()
	camera.add_child(preload("res://scripts/scenery/rain.gd").new())
	_build_scenery()

	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 20
	hud_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	hud_layer.add_child(preload("res://scripts/hud.gd").new())
	add_child(hud_layer)

	var fx_layer := CanvasLayer.new()
	fx_layer.layer = 10
	_overlay.material = ShaderMaterial.new()
	_overlay.material.shader = preload("res://shaders/rewind.gdshader")
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = false
	fx_layer.add_child(_overlay)
	_glitch.material = ShaderMaterial.new()
	_glitch.material.shader = preload("res://shaders/glitch.gdshader")
	_glitch.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glitch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glitch.visible = false
	fx_layer.add_child(_glitch)
	add_child(fx_layer)

	Rewind.rewind_started.connect(_on_rewind_started)
	Rewind.rewind_ended.connect(_on_rewind_ended)


func _physics_process(_delta: float) -> void:
	queue_redraw()
	_overlay.visible = Rewind.is_rewinding
	_glitch.visible = player.dead and not Rewind.is_rewinding
	# Don't fill the history with frames of lying dead.
	Rewind.recording = not player.dead
	if player.dead:
		Game.set_state(Game.State.DOWN if Rewind.can_rewind() else Game.State.GAME_OVER)
		return
	Game.set_state(Game.State.PLAYING)
	if player.position.x >= CHECKPOINT_X:
		Game.reach_checkpoint(1)
	if boss.dead and not Rewind.is_rewinding and PORTAL.has_point(player.position):
		Game.win()


func _grunt(pos: Vector2) -> Enemy:
	var enemy := Enemy.new()
	enemy.position = pos
	add_child(enemy)
	return enemy


func _drone(pos: Vector2) -> Drone:
	var drone := Drone.new()
	drone.position = pos
	add_child(drone)
	return drone


func _arena(trigger: Rect2, gates: Array[Rect2], waves: Array) -> void:
	var arena := Arena.new()
	arena.setup(trigger, gates, waves)
	add_child(arena)


func _on_rewind_started() -> void:
	for ghost in _ghosts.get_children():
		ghost.queue_free()


func _on_rewind_ended(undone_frames: Array) -> void:
	var path: Array[Dictionary] = []
	for frame: Dictionary in undone_frames:
		if frame.has(player):
			path.append(frame[player])
	if path.size() < MIN_GHOST_FRAMES:
		return
	var ghost := Ghost.new()
	ghost.setup(path)
	_ghosts.add_child(ghost)


func _add_solid(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = rect.size
	shape.position = rect.get_center()
	body.add_child(shape)
	add_child(body)


## Neon signs, fog, foreground silhouettes and glow.
func _build_scenery() -> void:
	var signs_layer := Parallax2D.new()
	signs_layer.scroll_scale = Vector2(0.7, 1.0)
	signs_layer.z_index = -5
	signs_layer.add_child(preload("res://scripts/scenery/neon_signs.gd").new())
	add_child(signs_layer)

	var fog := ColorRect.new()
	fog.size = Vector2(LEVEL_W, 360)
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fog.material = ShaderMaterial.new()
	fog.material.shader = preload("res://shaders/fog.gdshader")
	fog.z_index = 5
	add_child(fog)

	var front := Parallax2D.new()
	front.scroll_scale = Vector2(1.25, 1.0)
	front.z_index = 30
	front.add_child(preload("res://scripts/scenery/foreground.gd").new())
	add_child(front)

	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 0.6
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)


## Two parallax skyline layers so the long level doesn't read as a void.
func _build_skyline() -> void:
	var layers := [
		[0.2, Color("#10101c"), 120.0, []],
		[0.5, Color("#16162a"), 70.0, [COLOR_SPIKE, COLOR_EDGE]],
	]
	for layer: Array in layers:
		var parallax := Parallax2D.new()
		parallax.scroll_scale = Vector2(layer[0], 1.0)
		parallax.repeat_size = Vector2(640, 0)
		parallax.repeat_times = 3
		parallax.z_index = -10
		for i in 14:
			var w := 30.0 + float((i * 37 + int(layer[2])) % 23)
			var h: float = layer[2] + float((i * 53) % 120)
			var x := i * 46.0
			var building := ColorRect.new()
			building.color = layer[1]
			building.position = Vector2(x, FLOOR_Y - h)
			building.size = Vector2(w, h)
			parallax.add_child(building)
			var signs: Array = layer[3]
			if not signs.is_empty() and i % 3 == 0:
				var sign_rect := ColorRect.new()
				sign_rect.color = Color(signs[i % signs.size()], 0.5)
				sign_rect.position = Vector2(x + 6, FLOOR_Y - h + 12)
				sign_rect.size = Vector2(4, 22)
				parallax.add_child(sign_rect)
		add_child(parallax)


func _draw() -> void:
	_draw_haze()
	for rect in SOLIDS:
		_draw_solid(rect)
	for rect in SPIKES:
		var teeth := int(rect.size.x / 8)
		for t in teeth:
			var x := rect.position.x + t * 8
			draw_colored_polygon(PackedVector2Array([
				Vector2(x, rect.end.y), Vector2(x + 4, rect.position.y), Vector2(x + 8, rect.end.y),
			]), COLOR_SPIKE)
	_draw_shrine()
	if boss.dead:
		var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 150.0)
		draw_rect(PORTAL, Color(COLOR_EDGE, 0.3 * pulse))
		draw_rect(PORTAL, COLOR_EDGE, false, 2.0)


## Each sector glows its accent colour up from the floor.
func _draw_haze() -> void:
	for i in Sectors.LIST.size():
		var x0: float = Sectors.LIST[i].start
		var x1 := Sectors.end_of(i, LEVEL_W)
		var accent: Color = Sectors.LIST[i].accent
		var clear := Color(accent, 0.0)
		var glow := Color(accent, 0.08)
		draw_polygon(
			PackedVector2Array([Vector2(x0, FLOOR_Y - 180), Vector2(x1, FLOOR_Y - 180), Vector2(x1, FLOOR_Y), Vector2(x0, FLOOR_Y)]),
			PackedColorArray([clear, clear, glow, glow]))


## Dark panelled block with a glowing neon strip along its walkable top edge,
## split per sector so the strip changes colour at each boundary.
func _draw_solid(rect: Rect2) -> void:
	draw_rect(rect, COLOR_WALL)
	var seam := COLOR_WALL.darkened(0.35)
	for x in range(int(rect.position.x) + 32, int(rect.end.x), 32):
		draw_line(Vector2(x, rect.position.y + 3), Vector2(x, rect.end.y), seam, 1.0)
	if rect.size.y > 20.0:
		draw_line(Vector2(rect.position.x, rect.position.y + 8), Vector2(rect.end.x, rect.position.y + 8), seam, 1.0)
	if rect.position.y <= 0.0:
		# Ceiling: dim underside instead of a walkable strip.
		draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.end.y), Color(COLOR_EDGE, 0.25), 1.0)
		return
	if rect.size.x < 20.0:
		return # side walls
	for i in Sectors.LIST.size():
		var x0 := maxf(rect.position.x, Sectors.LIST[i].start)
		var x1 := minf(rect.end.x, Sectors.end_of(i, LEVEL_W))
		if x1 <= x0:
			continue
		var accent: Color = Sectors.LIST[i].accent
		var y := rect.position.y
		draw_rect(Rect2(x0, y - 2, x1 - x0, 2), Color(accent, 0.18))
		draw_rect(Rect2(x0, y + 1, x1 - x0, 3), Color(accent, 0.22))
		draw_line(Vector2(x0, y), Vector2(x1, y), accent.lightened(0.2), 1.0)


## Neon torii gate marking the checkpoint; lights up once reached.
func _draw_shrine() -> void:
	var lit := Game.checkpoint >= 1
	var color := COLOR_SHRINE if lit else Color(COLOR_SHRINE, 0.3)
	var x := CHECKPOINT_X
	draw_rect(Rect2(x - 26, FLOOR_Y - 56, 4, 56), color)
	draw_rect(Rect2(x + 22, FLOOR_Y - 56, 4, 56), color)
	draw_rect(Rect2(x - 34, FLOOR_Y - 62, 68, 4), color)
	draw_rect(Rect2(x - 28, FLOOR_Y - 48, 56, 3), color)
