class_name Enemy
extends CharacterBody2D
## Corporate grunt, and the base class for every other enemy. Behaves like a
## Hollow Knight husk: wanders and pauses, turns at walls and ledges, and when
## it notices you it winds up (eye flashes), charges, then stops to recover. A
## hit staggers it. Dead enemies stay in the tree
## (hidden) so a rewind can revive them; dormant ones wait for an arena wave.
##
## Subclasses set their stats in _init() and override _act() and _draw_body(),
## plus _pose() for how the body leans and stretches (drawn around the feet)
## and _draw_extra() for anything that shouldn't lean with it.
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
const JOLT_TIME := 0.15
## Knocked back and stunned this long when the player parries it.
const PARRY_KNOCKBACK := 220.0
const PARRY_STAGGER := 0.9

const COLOR_BODY := Color("#05d9e8")
const COLOR_EYE := Color("#ff2a6d")
const COLOR_INVERTED := Color("#b967ff")

var size := Vector2(24, 30)
var speed := 40.0
var max_hp := 3
## Kept small so a quick combo stays in reach instead of chasing the enemy.
var knockback := 70.0

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

## Cosmetic animation, not recorded: a clock for bobs, a springy squash after
## hits, and a short jolt that shakes the body.
var _anim_t := 0.0
var _squash := Vector2.ONE
var _jolt_t := 0.0


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
	_anim_t += delta
	_squash = _squash.move_toward(Vector2.ONE, 3.0 * delta)
	_jolt_t = maxf(_jolt_t - delta, 0.0)
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
	if state == Ai.WINDUP and ai != Ai.WINDUP:
		Fx.telegraph(position + Vector2(dir * size.x * 0.2, -size.y * 0.25))
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
	Fx.spawn_in(position, COLOR_INVERTED if inverted else COLOR_EYE)


func is_active() -> bool:
	return not dead and not dormant and spawn_t <= 0.0


func hurt_rect() -> Rect2:
	return Rect2(position - size / 2, size)


## Everything about this enemy that hurts the player on touch. Only attacks
## hurt: bumping into an enemy that's just wandering does nothing.
func damage_rects() -> Array[Rect2]:
	if not is_active() or not is_attacking():
		return []
	return [hurt_rect()]


## A grunt is only dangerous mid-charge.
func is_attacking() -> bool:
	return ai == Ai.CHARGE


## Returns true if the hit landed. Nail arts pass a bigger damage.
func take_hit(key: String, from_dir: Vector2, damage := 1) -> bool:
	if not is_active() or key == last_hit:
		return false
	last_hit = key
	if inverted and not key.begins_with("g"):
		Fx.impact(position, -from_dir, 0.6, COLOR_INVERTED)
		Fx.deflect(position, COLOR_INVERTED)
		Sfx.play("deflect")
		return false
	hp -= damage
	hurt_t = HURT_TIME
	# Squashed by the blow, then it springs back.
	_squash = Vector2(1.25, 0.75) if from_dir.x == 0.0 else Vector2(0.72, 1.22)
	_jolt_t = JOLT_TIME
	_set_ai(Ai.RECOVER, STAGGER_TIME)
	if from_dir.x != 0.0:
		velocity.x = from_dir.x * knockback
	Sfx.play("hit")
	Fx.enemy_hit(position, from_dir, blood_color(), 1.4 if damage > 1 else 1.0)
	if hp <= 0:
		dead = true
		Sfx.play("kill")
		Fx.hit_stop(0.08)
		Fx.enemy_kill(position, from_dir, blood_color(), size, position.y + size.y / 2 if is_on_floor() else -1.0)
	return true


## The player turned this attack back (rect is the part of us that touched
## them). By default: knocked away and stunned.
func parried(_rect: Rect2, from: Vector2) -> void:
	var away := signf(position.x - from.x)
	velocity.x = (away if away != 0.0 else -dir) * PARRY_KNOCKBACK
	hurt_t = HURT_TIME
	_set_ai(Ai.RECOVER, PARRY_STAGGER)


## Colour of what splashes out when this enemy is hit.
func blood_color() -> Color:
	return COLOR_INVERTED if inverted else COLOR_BODY


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
	var pose := _pose()
	var feet := Vector2(0, size.y / 2)
	var squash: Vector2 = pose[2] * _squash
	var lean: float = pose[1]
	var offset: Vector2 = pose[0]
	if _jolt_t > 0.0:
		offset.x += sin(_anim_t * 90.0) * 2.0 * (_jolt_t / JOLT_TIME)
	# Lean and stretch around the feet, so the body stays planted.
	draw_set_transform(offset + feet - (feet * squash).rotated(lean), lean, squash)
	_draw_body(Color.WHITE if hurt_t > 0.0 else (COLOR_INVERTED if inverted else COLOR_BODY))
	draw_set_transform(Vector2.ZERO)
	_draw_extra()
	if inverted:
		# Backwards-pointing chevrons mark an inverted enemy.
		var top := -size.y / 2 - 6
		for i in 2:
			var x := -dir * (2.0 + i * 5.0)
			draw_polyline(PackedVector2Array([
				Vector2(x + dir * 3, top - 3), Vector2(x, top), Vector2(x + dir * 3, top + 3),
			]), COLOR_INVERTED, 1.0)


## [offset, lean (radians), stretch] for the body this frame. A grunt bobs as
## it walks, crouches and leans back winding up, and leans into its charge.
func _pose() -> Array:
	match ai:
		Ai.WANDER:
			return [Vector2(0, -absf(sin(_anim_t * 11.0)) * 1.5), 0.0, Vector2.ONE]
		Ai.WINDUP:
			var k := 1.0 - ai_t / WINDUP_TIME
			return [Vector2.ZERO, -dir * 0.2 * k, Vector2(1.0 + 0.2 * k, 1.0 - 0.2 * k)]
		Ai.CHARGE:
			return [Vector2.ZERO, dir * 0.15, Vector2(1.15, 0.9)]
		Ai.RECOVER:
			return [Vector2.ZERO, -dir * 0.06, Vector2.ONE]
	return [Vector2.ZERO, 0.0, Vector2.ONE]


## Speed lines streaming off a charge.
func _draw_extra() -> void:
	if ai != Ai.CHARGE:
		return
	var color := Color(COLOR_INVERTED if inverted else COLOR_BODY, 0.6)
	for i in 3:
		var y := -6.0 + i * 6.0
		var start := -dir * (size.x / 2 + 3)
		draw_line(Vector2(start, y), Vector2(start - dir * (10.0 + i * 4.0), y), color, 1.0)


func _draw_body(body: Color) -> void:
	draw_rect(Rect2(-size / 2, size), body)
	var eye_size := Vector2(size.x * 0.22, size.y * 0.13)
	var eye_x := size.x * 0.1 if dir > 0 else -size.x * 0.1 - eye_size.x
	var eye := COLOR_BODY if inverted else COLOR_EYE
	if ai == Ai.WINDUP and int(ai_t * 20.0) % 2 == 0:
		eye = Color.WHITE
	draw_rect(Rect2(Vector2(eye_x, -size.y * 0.3), eye_size), eye)


func capture_state() -> Dictionary:
	return {
		"position": position, "velocity": velocity, "hp": hp, "dead": dead, "dormant": dormant,
		"dir": dir, "hurt_t": hurt_t, "spawn_t": spawn_t, "last_hit": last_hit, "inverted": inverted,
		"ai": ai, "ai_t": ai_t,
	}


func apply_state(state: Dictionary) -> void:
	for key in state:
		set(key, state[key])
