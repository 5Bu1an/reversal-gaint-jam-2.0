class_name Arena
extends Node2D
## Locks the player in when they walk into the trigger zone and releases them
## once every wave is dead. Wave enemies are spawned dormant up front, so a
## rewind past the trigger puts the whole fight back exactly as it was.

enum Phase { WAITING, FIGHTING, CLEARED }

const COLOR_GATE := Color("#ff2a6d")

var trigger := Rect2()
var gates: Array[Rect2] = []
var waves: Array = [] # Array of Array[Enemy]

var phase := Phase.WAITING
var wave := 0

var _gate_shapes: Array[CollisionShape2D] = []


func setup(trigger_rect: Rect2, gate_rects: Array[Rect2], enemy_waves: Array) -> void:
	trigger = trigger_rect
	gates = gate_rects
	waves = enemy_waves
	for wave_enemies: Array in waves:
		for enemy: Enemy in wave_enemies:
			enemy.dormant = true
	if waves.is_empty():
		phase = Phase.CLEARED


func _ready() -> void:
	add_to_group("rewindable")
	for rect in gates:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape2D.new()
		shape.shape = RectangleShape2D.new()
		shape.shape.size = rect.size
		shape.position = rect.get_center()
		shape.disabled = true
		body.add_child(shape)
		add_child(body)
		_gate_shapes.append(shape)


func _physics_process(_delta: float) -> void:
	queue_redraw()
	if not _gate_shapes.is_empty() and _gate_shapes[0].disabled == _gates_closed():
		_sync_gates() # god mode was toggled
	if Rewind.is_rewinding:
		return
	var player: Player = get_tree().get_first_node_in_group("player")
	match phase:
		Phase.WAITING:
			if player and not player.dead and trigger.has_point(player.position):
				phase = Phase.FIGHTING
				wave = 0
				_start_wave()
				_sync_gates()
				Sfx.play("gate")
		Phase.FIGHTING:
			if waves[wave].all(func(e: Enemy) -> bool: return e.dead):
				wave += 1
				if wave >= waves.size():
					phase = Phase.CLEARED
					_sync_gates()
					Sfx.play("gate", 0.0, 0.0)
				else:
					_start_wave()


func is_fighting() -> bool:
	return phase == Phase.FIGHTING


func _start_wave() -> void:
	for enemy: Enemy in waves[wave]:
		enemy.activate()


## Gates are solid only mid-fight, and never in god mode (testing).
func _gates_closed() -> bool:
	return phase == Phase.FIGHTING and not Game.god_mode


func _sync_gates() -> void:
	for shape in _gate_shapes:
		shape.set_deferred("disabled", not _gates_closed())


func _draw() -> void:
	if not _gates_closed():
		return
	var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 120.0)
	for rect in gates:
		draw_rect(rect, Color(COLOR_GATE, 0.25 * pulse))
		for y in range(int(rect.position.y), int(rect.end.y), 12):
			draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y + 6), Color(COLOR_GATE, pulse), 1.0)
		draw_rect(rect, COLOR_GATE, false, 1.0)


func capture_state() -> Dictionary:
	return {"phase": phase, "wave": wave}


func apply_state(state: Dictionary) -> void:
	var was := phase
	phase = state.phase
	wave = state.wave
	if phase != was:
		_sync_gates()
