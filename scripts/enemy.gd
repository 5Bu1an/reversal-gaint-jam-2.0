class_name Enemy
extends CharacterBody2D
## Patrolling corporate grunt, and the base class for every other enemy. Walks
## until it hits a wall or a ledge, then turns. Dead enemies stay in the tree
## (hidden) so a rewind can revive them; dormant ones wait for an arena wave.
##
## Subclasses set their stats in _init() and override _act() and _draw_body().

const GRAVITY := 980.0
const MAX_FALL := 420.0
const HURT_TIME := 0.2
const SPAWN_TIME := 0.5

const COLOR_BODY := Color("#05d9e8")
const COLOR_EYE := Color("#ff2a6d")

var size := Vector2(16, 20)
var speed := 40.0
var max_hp := 3
var knockback := 160.0

var hp := 0
var dead := false
## Waiting for its arena wave: not drawn, doesn't move, can't hit or be hit.
var dormant := false
var dir := -1
var hurt_t := 0.0
## Warp-in flicker after activate(); harmless until it runs out.
var spawn_t := 0.0
## Key of the last swing that hit, so one swing only lands once.
var last_hit := ""


func _ready() -> void:
	add_to_group("rewindable")
	add_to_group("enemies")
	hp = max_hp
	collision_layer = 4
	collision_mask = 1
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = size
	add_child(shape)


func _physics_process(delta: float) -> void:
	queue_redraw()
	if Rewind.is_rewinding or dead or dormant:
		return
	hurt_t = maxf(hurt_t - delta, 0.0)
	if spawn_t > 0.0:
		spawn_t = maxf(spawn_t - delta, 0.0)
		return
	_act(delta)


func _act(delta: float) -> void:
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	if hurt_t > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
	else:
		velocity.x = dir * speed
	move_and_slide()
	if hurt_t <= 0.0 and (is_on_wall() or (is_on_floor() and not _ground_ahead())):
		dir = -dir


func activate() -> void:
	dormant = false
	spawn_t = SPAWN_TIME


func is_active() -> bool:
	return not dead and not dormant and spawn_t <= 0.0


func hurt_rect() -> Rect2:
	return Rect2(position - size / 2, size)


## Everything about this enemy that hurts the player on touch.
func damage_rects() -> Array[Rect2]:
	if not is_active():
		return []
	return [hurt_rect()]


## Returns true if the hit landed.
func take_hit(key: String, from_dir: Vector2) -> bool:
	if not is_active() or key == last_hit:
		return false
	last_hit = key
	hp -= 1
	hurt_t = HURT_TIME
	if from_dir.x != 0.0:
		velocity.x = from_dir.x * knockback
	if hp <= 0:
		dead = true
	return true


func _ground_ahead() -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = global_position + Vector2(dir * (size.x / 2 + 2), size.y / 2 + 4)
	query.collision_mask = 1
	return not get_world_2d().direct_space_state.intersect_point(query, 1).is_empty()


func _draw() -> void:
	if dead or dormant:
		return
	if spawn_t > 0.0:
		if int(spawn_t * 24.0) % 2 == 0:
			draw_rect(Rect2(-size / 2, size), COLOR_EYE, false, 1.0)
		return
	_draw_body(Color.WHITE if hurt_t > 0.0 else COLOR_BODY)


func _draw_body(body: Color) -> void:
	draw_rect(Rect2(-size / 2, size), body)
	var eye_x := 2.0 if dir > 0 else -6.0
	draw_rect(Rect2(eye_x, -6, 4, 3), COLOR_EYE)


func capture_state() -> Dictionary:
	return {
		"position": position, "velocity": velocity, "hp": hp, "dead": dead, "dormant": dormant,
		"dir": dir, "hurt_t": hurt_t, "spawn_t": spawn_t, "last_hit": last_hit,
	}


func apply_state(state: Dictionary) -> void:
	for key in state:
		set(key, state[key])
