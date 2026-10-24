class_name Enemy
extends CharacterBody2D
## Patrolling corporate grunt. Walks until it hits a wall or a ledge, then
## turns. Dead grunts stay in the tree (hidden) so a rewind can revive them.

const SIZE := Vector2(16, 20)
const SPEED := 40.0
const GRAVITY := 980.0
const MAX_FALL := 420.0
const MAX_HP := 3
const HURT_TIME := 0.2
const HIT_KNOCKBACK := 160.0

const COLOR_BODY := Color("#05d9e8")
const COLOR_EYE := Color("#ff2a6d")

var hp := MAX_HP
var dead := false
var dir := -1
var hurt_t := 0.0
## Key of the last swing that hit, so one swing only lands once.
var last_hit := ""


func _ready() -> void:
	add_to_group("rewindable")
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = SIZE
	add_child(shape)


func _physics_process(delta: float) -> void:
	queue_redraw()
	if Rewind.is_rewinding or dead:
		return
	hurt_t = maxf(hurt_t - delta, 0.0)
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	if hurt_t > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
	else:
		velocity.x = dir * SPEED
	move_and_slide()
	if hurt_t <= 0.0 and (is_on_wall() or (is_on_floor() and not _ground_ahead())):
		dir = -dir


func hurt_rect() -> Rect2:
	return Rect2(position - SIZE / 2, SIZE)


## Returns true if the hit landed.
func take_hit(key: String, from_dir: Vector2) -> bool:
	if dead or key == last_hit:
		return false
	last_hit = key
	hp -= 1
	hurt_t = HURT_TIME
	if from_dir.x != 0.0:
		velocity.x = from_dir.x * HIT_KNOCKBACK
	if hp <= 0:
		dead = true
	return true


func _ground_ahead() -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = global_position + Vector2(dir * (SIZE.x / 2 + 2), SIZE.y / 2 + 4)
	query.collision_mask = 1
	return not get_world_2d().direct_space_state.intersect_point(query, 1).is_empty()


func _draw() -> void:
	if dead:
		return
	var body := Color.WHITE if hurt_t > 0.0 else COLOR_BODY
	draw_rect(Rect2(-SIZE / 2, SIZE), body)
	var eye_x := 2.0 if dir > 0 else -6.0
	draw_rect(Rect2(eye_x, -6, 4, 3), COLOR_EYE)


func capture_state() -> Dictionary:
	return {
		"position": position, "velocity": velocity, "hp": hp, "dead": dead,
		"dir": dir, "hurt_t": hurt_t, "last_hit": last_hit,
	}


func apply_state(state: Dictionary) -> void:
	for key in state:
		set(key, state[key])
