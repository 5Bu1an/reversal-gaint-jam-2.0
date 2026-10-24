extends Node2D
## Prototype arena: one screen built from rectangles until the tileset lands.
## Owns the player, enemies, ghosts and the rewind screen effect.

const SOLIDS: Array[Rect2] = [
	Rect2(0, 328, 640, 32), # floor
	Rect2(0, 0, 640, 16), # ceiling
	Rect2(0, 0, 16, 360), # left wall
	Rect2(624, 0, 16, 360), # right wall
	Rect2(110, 262, 96, 10),
	Rect2(290, 214, 96, 10),
	Rect2(460, 262, 96, 10),
]
const SPIKES: Array[Rect2] = [Rect2(250, 320, 48, 8)]
const ENEMY_SPAWNS: Array[Vector2] = [Vector2(200, 316), Vector2(420, 316), Vector2(510, 250)]
const PLAYER_SPAWN := Vector2(48, 316)
const MIN_GHOST_FRAMES := 6

const COLOR_WALL := Color("#1a1a2e")
const COLOR_EDGE := Color("#05d9e8")
const COLOR_SPIKE := Color("#ff2a6d")

var player: Player
var _ghosts := Node2D.new()
var _overlay := ColorRect.new()


func _ready() -> void:
	Rewind.reset()
	for rect in SOLIDS:
		_add_solid(rect)
	for spawn in ENEMY_SPAWNS:
		var enemy := Enemy.new()
		enemy.position = spawn
		add_child(enemy)
	_ghosts.name = "Ghosts"
	add_child(_ghosts)
	player = Player.new()
	player.position = PLAYER_SPAWN
	player.hazards = SPIKES
	add_child(player)

	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 20
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
	_overlay.visible = Rewind.is_rewinding
	if player.dead and not Rewind.can_rewind() and Input.is_action_just_pressed("jump"):
		get_tree().reload_current_scene()


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


func _draw() -> void:
	# Far skyline so the room doesn't read as a void.
	for i in 14:
		var w := 30.0 + float((i * 37) % 23)
		var h := 80.0 + float((i * 53) % 120)
		draw_rect(Rect2(16 + i * 46, 328 - h, w, h), Color("#12121f"))
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
