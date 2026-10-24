class_name Enemy
extends CharacterBody2D
## Corporate grunt, and the base class for every other enemy. Behaves like a
## Hollow Knight husk: wanders and pauses, turns at walls and ledges, and when
## it notices you it winds up (eye flashes), charges, then stops to recover. A
## hit staggers it. Dead enemies stay in the tree
## (hidden) so a rewind can revive them; dormant ones wait for an arena wave.
##
## Subclasses set their stats in _init() and override _act() and _draw_body().
##
## Inverted enemies move backwards through time, like in Tenet: the player's
## own slashes bounce off, and only a ghost (a rewound timeline) can hurt them.

const GRAVITY := 980.0
const MAX_FALL := 420.0
const HURT_TIME := 0.2
const SPAWN_TIME := 0.5

enum Ai { WANDER, PAUSE, WINDUP, CHARGE, RECOVER }
const WANDER_TIME := 2.4
const PAUSE_TIME := 0.9
const NOTICE_RANGE := 110.0
const NOTICE_HEIGHT := 30.0
const WINDUP_TIME := 0.45
const RUSH_TIME := 0.9
const CHARGE_MULT := 3.0
const RECOVER_TIME := 0.7
const STAGGER_TIME := 0.4

const COLOR_BODY := Color("#05d9e8")
const COLOR_EYE := Color("#ff2a6d")
const COLOR_INVERTED := Color("#b967ff")

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
## Only ghost swings can hurt it.
var inverted := false
var ai := Ai.WANDER
var ai_t := WANDER_TIME


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
		move_and_slide()
		return
	ai_t -= delta
	match ai:
		Ai.WANDER, Ai.PAUSE:
			velocity.x = dir * speed if ai == Ai.WANDER else 0.0
			if _sees_player():
				_set_ai(Ai.WINDUP, WINDUP_TIME)
			elif ai_t <= 0.0 and ai == Ai.WANDER:
				_set_ai(Ai.PAUSE, PAUSE_TIME)
			elif ai_t <= 0.0:
				_set_ai(Ai.WANDER, WANDER_TIME)
		Ai.WINDUP:
			velocity.x = 0.0
			if ai_t <= 0.0:
				_set_ai(Ai.CHARGE, RUSH_TIME)
		Ai.CHARGE:
			velocity.x = dir * speed * CHARGE_MULT
			if ai_t <= 0.0:
				_set_ai(Ai.RECOVER, RECOVER_TIME)
		Ai.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			if ai_t <= 0.0:
				_set_ai(Ai.WANDER, WANDER_TIME)
	move_and_slide()
	var blocked := is_on_wall() or (is_on_floor() and not _ground_ahead())
	if blocked and ai == Ai.CHARGE:
		_set_ai(Ai.RECOVER, RECOVER_TIME)
	elif blocked and ai == Ai.WANDER:
		dir = -dir


func _set_ai(state: Ai, time: float) -> void:
	ai = state
	ai_t = time


## Noticing turns it to face you.
func _sees_player() -> bool:
	var player: Player = get_tree().get_first_node_in_group("player")
	if player == null or player.dead:
		return false
	var dx := player.position.x - position.x
	if absf(dx) > NOTICE_RANGE or absf(player.position.y - position.y) > NOTICE_HEIGHT:
		return false
	dir = 1 if dx > 0.0 else -1
	return true


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


## Returns true if the hit landed. Nail arts pass a bigger damage.
func take_hit(key: String, from_dir: Vector2, damage := 1) -> bool:
	if not is_active() or key == last_hit:
		return false
	last_hit = key
	if inverted and not key.begins_with("g"):
		Fx.burst(position, COLOR_INVERTED, 4, 140.0, 40.0, -from_dir if from_dir != Vector2.ZERO else Vector2.UP)
		Sfx.play("deflect")
		return false
	hp -= damage
	hurt_t = HURT_TIME
	_set_ai(Ai.RECOVER, STAGGER_TIME)
	if from_dir.x != 0.0:
		velocity.x = from_dir.x * knockback
	Sfx.play("hit")
	Fx.burst(position, Color.WHITE, 4, 120.0, 50.0, Vector2(from_dir.x, -0.5).normalized() if from_dir.x != 0.0 else from_dir)
	if hp <= 0:
		dead = true
		Sfx.play("kill")
		Fx.burst(position, COLOR_BODY, 10, 150.0)
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
	_draw_body(Color.WHITE if hurt_t > 0.0 else (COLOR_INVERTED if inverted else COLOR_BODY))
	if inverted:
		# Backwards-pointing chevrons mark an inverted enemy.
		var top := -size.y / 2 - 6
		for i in 2:
			var x := -dir * (2.0 + i * 5.0)
			draw_polyline(PackedVector2Array([
				Vector2(x + dir * 3, top - 3), Vector2(x, top), Vector2(x + dir * 3, top + 3),
			]), COLOR_INVERTED, 1.0)


func _draw_body(body: Color) -> void:
	draw_rect(Rect2(-size / 2, size), body)
	var eye_x := 2.0 if dir > 0 else -6.0
	var eye := COLOR_BODY if inverted else COLOR_EYE
	if ai == Ai.WINDUP and int(ai_t * 20.0) % 2 == 0:
		eye = Color.WHITE
	draw_rect(Rect2(eye_x, -6, 4, 3), eye)


func capture_state() -> Dictionary:
	return {
		"position": position, "velocity": velocity, "hp": hp, "dead": dead, "dormant": dormant,
		"dir": dir, "hurt_t": hurt_t, "spawn_t": spawn_t, "last_hit": last_hit, "inverted": inverted,
		"ai": ai, "ai_t": ai_t,
	}


func apply_state(state: Dictionary) -> void:
	for key in state:
		set(key, state[key])
