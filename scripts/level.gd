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

## Tutorial signs: position, then headline and detail lines.
const HINTS := [
	[Vector2(150, 150), ["HOLD L TO REWIND TIME", "the timeline you undo keeps fighting as a ghost"]],
	[Vector2(470, 150), ["PURPLE = INVERTED", "your blade bounces off - swing, then rewind", "your ghost's swings land"]],
	[Vector2(650, 150), ["S + J IN THE AIR TO POGO", "bounce off enemies to cross the spikes"]],
	[Vector2(1230, 150), ["HITS REFILL YOUR TIME", "so do time shards"]],
	[Vector2(2480, 150), ["THE SHOGUN BENDS TIME TOO", "jump the shockwaves"]],
]

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

	for hint: Array in HINTS:
		var sign_node := Hint.new().setup(PackedStringArray(hint[1]))
		sign_node.position = hint[0]
		add_child(sign_node)

	# Roaming enemies outside the arenas.
	_grunt(Vector2(260, 316))
	# First inverted grunt, alone, so the player learns the ghost trick.
	_inverted(_grunt(Vector2(560, 316)))
	_drone(Vector2(850, 180))
	_drone(Vector2(1150, 190))
	_grunt(Vector2(1210, 316))
	_grunt(Vector2(2440, 316))

	var waves: Array = []
	if Game.checkpoint < 1:
		waves = [
			[_grunt(Vector2(1450, 316)), _grunt(Vector2(1650, 316)), _grunt(Vector2(1800, 316))],
			[_drone(Vector2(1450, 170)), _drone(Vector2(1750, 170)), _grunt(Vector2(1500, 316)), _grunt(Vector2(1700, 316))],
			[_drone(Vector2(1400, 160)), _drone(Vector2(1600, 130)), _drone(Vector2(1800, 160)), _inverted(_grunt(Vector2(1600, 316)))],
		]
	_arena(WAVE_ARENA_TRIGGER, WAVE_ARENA_GATES, waves)

	boss = Boss.new()
	boss.position = BOSS_SPAWN
	boss.arena_left = BOSS_ARENA_GATES[0].end.x
	boss.arena_right = LEVEL_W - 16
	add_child(boss)
	Game.boss = boss
	_arena(BOSS_ARENA_TRIGGER, BOSS_ARENA_GATES, [[boss]])

	if not Game.shade.is_empty():
		var shade := Shade.new()
		shade.position = Game.shade.pos
		shade.ms = Game.shade.ms
		add_child(shade)

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
	add_child(fx_layer)

	Rewind.rewind_started.connect(_on_rewind_started)
	Rewind.rewind_ended.connect(_on_rewind_ended)


func _physics_process(_delta: float) -> void:
	queue_redraw()
	_overlay.visible = Rewind.is_rewinding
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


func _inverted(enemy: Enemy) -> Enemy:
	enemy.inverted = true
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
	for rect in SOLIDS:
		draw_rect(rect, COLOR_WALL)
		draw_line(rect.position, Vector2(rect.end.x, rect.position.y), COLOR_EDGE, 1.0)
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


## Neon torii gate marking the checkpoint; lights up once reached.
func _draw_shrine() -> void:
	var lit := Game.checkpoint >= 1
	var color := COLOR_SHRINE if lit else Color(COLOR_SHRINE, 0.3)
	var x := CHECKPOINT_X
	draw_rect(Rect2(x - 26, FLOOR_Y - 56, 4, 56), color)
	draw_rect(Rect2(x + 22, FLOOR_Y - 56, 4, 56), color)
	draw_rect(Rect2(x - 34, FLOOR_Y - 62, 68, 4), color)
	draw_rect(Rect2(x - 28, FLOOR_Y - 48, 56, 3), color)
