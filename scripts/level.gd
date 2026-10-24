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
const COLOR_DEEP := Color("#140c22")
const COLOR_POST := Color("#1b3a48")

## Deck art is drawn at half size (one art pixel per screen pixel) and sunk
## so feet land on the middle of its top face.
const DECK_SCALE := 0.5
const DECK_SINK := 5.0

var player: Player
var boss: Boss
var _ghosts := Node2D.new()
var _overlay := ColorRect.new()
var _glitch := ColorRect.new()


func _ready() -> void:
	Rewind.reset()
	Sfx.play_music()
	Game.set_state(Game.State.PLAYING)
	add_child(preload("res://scripts/env/backdrop.gd").new())
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


## Street facade, sky traffic, street lamps, fog, foreground silhouettes
## and glow.
func _build_scenery() -> void:
	var street := Parallax2D.new()
	street.scroll_scale = Vector2(0.85, 1.0)
	street.z_index = -4
	street.add_child(preload("res://scripts/env/facade.gd").new())
	add_child(street)

	var sky := Parallax2D.new()
	sky.scroll_scale = Vector2(0.3, 1.0)
	sky.z_index = -18
	sky.add_child(preload("res://scripts/env/traffic.gd").new())
	add_child(sky)

	for x in range(150, int(LEVEL_W) - 100, 260):
		if Sectors.index_at(x) == 3:
			continue # the shrine keeps its own light
		var lamp := Warped.piece(Warped.WC1_TILES, Warped.CLUTTER.lamp)
		lamp.position = Vector2(x, FLOOR_Y - Warped.CLUTTER.lamp.size.y)
		lamp.z_index = -2
		add_child(lamp)

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
		var glow := Color(accent, 0.06)
		draw_polygon(
			PackedVector2Array([Vector2(x0, FLOOR_Y - 180), Vector2(x1, FLOOR_Y - 180), Vector2(x1, FLOOR_Y), Vector2(x0, FLOOR_Y)]),
			PackedColorArray([clear, clear, glow, glow]))


## Warped City walkway deck along every walkable top, support posts under
## floating platforms, a block texture on the side walls and a girder for
## the ceiling. Collision is still the plain rect; this is only the look.
## A thin neon strip in the sector's accent marks the walkable edge.
func _draw_solid(rect: Rect2) -> void:
	if rect.position.y <= 0.0:
		draw_rect(rect, COLOR_DEEP)
		_draw_deck(rect, rect.end.y - Warped.DECK.size.y * DECK_SCALE, true)
		return
	if rect.size.x < 20.0:
		_draw_wall(rect)
		return
	if rect.end.y < FLOOR_Y:
		for post_x in [rect.position.x + 8.0, rect.end.x - 12.0]:
			draw_rect(Rect2(post_x, rect.end.y, 3, FLOOR_Y - rect.end.y), COLOR_POST)
			draw_rect(Rect2(post_x + 3, rect.end.y, 1, FLOOR_Y - rect.end.y), COLOR_DEEP)
	else:
		draw_rect(Rect2(rect.position.x, rect.position.y + 10, rect.size.x, rect.size.y), COLOR_DEEP)
	_draw_deck(rect, rect.position.y - DECK_SINK, false)
	for i in Sectors.LIST.size():
		var x0 := maxf(rect.position.x, Sectors.LIST[i].start)
		var x1 := minf(rect.end.x, Sectors.end_of(i, LEVEL_W))
		if x1 > x0:
			var accent: Color = Sectors.LIST[i].accent
			draw_line(Vector2(x0, rect.position.y), Vector2(x1, rect.position.y), Color(accent, 0.55), 1.0)


## Tiles the deck art across rect's width with its top at top_y.
func _draw_deck(rect: Rect2, top_y: float, flip: bool) -> void:
	var tile := Warped.DECK.size * DECK_SCALE
	var x := rect.position.x
	while x < rect.end.x:
		var w := minf(tile.x, rect.end.x - x)
		var src := Rect2(Warped.DECK.position, Vector2(w / DECK_SCALE, Warped.DECK.size.y))
		var dest := Rect2(x, top_y, w, tile.y)
		if flip:
			dest = Rect2(x, top_y + tile.y, w, -tile.y)
		draw_texture_rect_region(Warped.WC2_TILES, dest, src)
		x += tile.x


func _draw_wall(rect: Rect2) -> void:
	var tile := Warped.BLOCK.size * DECK_SCALE
	var y := rect.position.y
	while y < rect.end.y:
		var h := minf(tile.y, rect.end.y - y)
		var src := Rect2(Warped.BLOCK.position, Vector2(Warped.BLOCK.size.x, h / DECK_SCALE))
		draw_texture_rect_region(Warped.WC2_TILES, Rect2(rect.position.x, y, rect.size.x, h), src)
		y += tile.y


## Neon torii gate marking the checkpoint; lights up once reached.
func _draw_shrine() -> void:
	var lit := Game.checkpoint >= 1
	var color := COLOR_SHRINE if lit else Color(COLOR_SHRINE, 0.3)
	var x := CHECKPOINT_X
	draw_rect(Rect2(x - 26, FLOOR_Y - 56, 4, 56), color)
	draw_rect(Rect2(x + 22, FLOOR_Y - 56, 4, 56), color)
	draw_rect(Rect2(x - 34, FLOOR_Y - 62, 68, 4), color)
	draw_rect(Rect2(x - 28, FLOOR_Y - 48, 56, 3), color)
