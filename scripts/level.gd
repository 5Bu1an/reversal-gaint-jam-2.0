extends Node2D
## The level, carved out of solid rock like a Hollow Knight cave: floors that
## step up and down, ledges that grow out of walls, ceilings that hang low,
## and thorns on ceilings and walls (never strips on the floor). Five
## sections left to right: intro cave, thorn tunnel and cavern, locked wave
## arena, shrine checkpoint (with a wall-jump chimney), boss arena.
## Owns the player, enemies, ghosts, camera and the rewind screen effect.

const LEVEL_W := 3200.0
const FLOOR_Y := 328.0

const SOLIDS: Array[Rect2] = [
	Rect2(0, 328, 3200, 32), # floor
	Rect2(0, 0, 3200, 16), # ceiling
	Rect2(0, 0, 16, 360), # left wall
	Rect2(3184, 0, 16, 360), # right wall
	# 1. Intro cave: a stepped rock mound and hanging rock.
	Rect2(180, 296, 140, 32),
	Rect2(250, 250, 70, 46),
	Rect2(120, 16, 60, 56),
	Rect2(400, 16, 90, 40),
	# 2. Thorn tunnel (low ceiling), then a cavern with a rock pillar to climb.
	Rect2(700, 16, 220, 236),
	Rect2(1000, 288, 40, 40),
	Rect2(1040, 240, 44, 88),
	Rect2(1180, 16, 80, 70),
	# 3. Wave arena: rock over both doorways, a low mound in the middle.
	Rect2(1280, 16, 60, 220),
	Rect2(1860, 16, 60, 220),
	Rect2(1540, 290, 120, 38),
	# 4. Shrine: a rock block under a side chimney that only a wall-jumper can
	# climb (the walls stop just above head height on the block), and a step.
	Rect2(2170, 280, 100, 48),
	Rect2(2184, 16, 12, 238),
	Rect2(2244, 16, 12, 238),
	Rect2(2330, 296, 120, 32),
	# 5. Boss arena: rock over the doorway, a mound, a shelf on the far wall.
	Rect2(2560, 16, 40, 200),
	Rect2(2610, 296, 56, 32),
	Rect2(3110, 236, 74, 20),
]
## Thorns: rect, then the way the teeth point (DOWN/UP/LEFT/RIGHT). Ceilings
## and walls only, never strips on the floor.
const THORNS := [
	[Rect2(700, 252, 220, 8), Vector2.DOWN], # tunnel ceiling: full jumps hit it
	[Rect2(1180, 86, 80, 8), Vector2.DOWN],
]
const SHARDS: Array[Vector2] = [
	Vector2(285, 232), Vector2(1062, 222), Vector2(1600, 272), Vector2(2390, 280),
	Vector2(2220, 46), # top of the shrine chimney
]

## Tutorial signs: position, then headline and detail lines.
const HINTS := [
	[Vector2(110, 110), ["HOLD L TO REWIND TIME", "the timeline you undo keeps fighting as a ghost"]],
	[Vector2(470, 100), ["OR HOLD J, THEN RELEASE", "echo slash: the echo strikes again, like a ghost"]],
	[Vector2(470, 150), ["PURPLE = INVERTED", "your blade bounces off - swing, then rewind", "your ghost's swings land"]],
	[Vector2(640, 196), ["THORNS ABOVE", "tap jump for a short hop"]],
	[Vector2(990, 100), ["S + J IN THE AIR TO POGO", "bounce off drones to stay up"]],
	[Vector2(1190, 150), ["HITS REFILL YOUR TIME", "so do time shards"]],
	[Vector2(2110, 120), ["HOLD TOWARD A WALL TO CLING", "jump to kick off - something waits up the chimney"]],
	[Vector2(2480, 150), ["THE SHOGUN BENDS TIME TOO", "jump the shockwaves"]],
]

const PLAYER_SPAWN := Vector2(48, 316)
const CHECKPOINT_X := 2060.0
const CHECKPOINT_SPAWN := Vector2(2060, 316)

const WAVE_ARENA_TRIGGER := Rect2(1340, 16, 520, 312)
const WAVE_ARENA_GATES: Array[Rect2] = [Rect2(1316, 236, 12, 92), Rect2(1872, 236, 12, 92)]
const BOSS_ARENA_TRIGGER := Rect2(2640, 16, 540, 312)
const BOSS_ARENA_GATES: Array[Rect2] = [Rect2(2576, 216, 12, 112)]
const BOSS_SPAWN := Vector2(3020, 306)
const PORTAL := Rect2(3130, 276, 30, 52)

const MIN_GHOST_FRAMES := 6
## Camera leads the way you're facing.
const LOOKAHEAD := 48.0
const LOOKAHEAD_SPEED := 2.5

const COLOR_WALL := Color("#1a1a2e")
const COLOR_EDGE := Color("#05d9e8")
const COLOR_SPIKE := Color("#ff2a6d")
const COLOR_SHRINE := Color("#f5c542")

var player: Player
var boss: Boss
var _camera := Camera2D.new()
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
	_grunt(Vector2(100, 316))
	# First inverted grunt, alone, so the player learns the ghost trick.
	_inverted(_grunt(Vector2(560, 316)))
	_drone(Vector2(1130, 170))
	_drone(Vector2(1230, 140))
	_grunt(Vector2(2500, 316))

	var waves: Array = []
	if Game.checkpoint < 1:
		waves = [
			[_grunt(Vector2(1450, 316)), _grunt(Vector2(1720, 316)), _grunt(Vector2(1800, 316))],
			[_drone(Vector2(1450, 170)), _drone(Vector2(1750, 170)), _grunt(Vector2(1480, 316)), _grunt(Vector2(1760, 316))],
			[_drone(Vector2(1400, 160)), _drone(Vector2(1600, 130)), _drone(Vector2(1800, 160)), _inverted(_grunt(Vector2(1720, 316)))],
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
	for thorn: Array in THORNS:
		player.hazards.append(thorn[0])
	add_child(player)

	_camera.limit_left = 0
	_camera.limit_right = int(LEVEL_W)
	_camera.limit_top = 0
	_camera.limit_bottom = 360
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 7.0
	player.add_child(_camera)
	_camera.reset_smoothing.call_deferred()

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


func _physics_process(delta: float) -> void:
	queue_redraw()
	_camera.position.x = lerpf(_camera.position.x, player.facing * LOOKAHEAD, LOOKAHEAD_SPEED * delta)
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
		# Faint side edges so stacked rock reads as one mass, not floating bars.
		draw_line(rect.position, Vector2(rect.position.x, rect.end.y), Color(COLOR_EDGE, 0.25), 1.0)
		draw_line(Vector2(rect.end.x, rect.position.y), rect.end, Color(COLOR_EDGE, 0.25), 1.0)
	for thorn: Array in THORNS:
		_draw_thorns(thorn[0], thorn[1])
	_draw_shrine()
	if boss.dead:
		var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 150.0)
		draw_rect(PORTAL, Color(COLOR_EDGE, 0.3 * pulse))
		draw_rect(PORTAL, COLOR_EDGE, false, 2.0)


## Row of teeth along a thorn rect, pointing away from the rock it grows on.
func _draw_thorns(rect: Rect2, dir: Vector2) -> void:
	var along := Vector2.RIGHT if dir.y != 0.0 else Vector2.DOWN
	var length := rect.size.x if dir.y != 0.0 else rect.size.y
	var depth := rect.size.y if dir.y != 0.0 else rect.size.x
	# Teeth start from the side opposite to where they point.
	var base := rect.position
	if dir == Vector2.UP:
		base.y = rect.end.y
	elif dir == Vector2.LEFT:
		base.x = rect.end.x
	for t in int(length / 8):
		var a := base + along * (t * 8)
		draw_colored_polygon(PackedVector2Array([
			a, a + along * 4 + dir * depth, a + along * 8,
		]), COLOR_SPIKE)


## Neon torii gate marking the checkpoint; lights up once reached.
func _draw_shrine() -> void:
	var lit := Game.checkpoint >= 1
	var color := COLOR_SHRINE if lit else Color(COLOR_SHRINE, 0.3)
	var x := CHECKPOINT_X
	draw_rect(Rect2(x - 26, FLOOR_Y - 56, 4, 56), color)
	draw_rect(Rect2(x + 22, FLOOR_Y - 56, 4, 56), color)
	draw_rect(Rect2(x - 34, FLOOR_Y - 62, 68, 4), color)
	draw_rect(Rect2(x - 28, FLOOR_Y - 48, 56, 3), color)
