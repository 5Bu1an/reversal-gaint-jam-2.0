class_name Player
extends CharacterBody2D
## Hollow Knight-style controller: run, variable jump, dash, directional slash
## and pogo off enemies with a down-slash. Spikes cost 1 HP and put you back
## on the last safe ground you stood on. Drawn as placeholder shapes until
## sprites land in assets/art.

const SIZE := Vector2(12, 24)
const RUN_SPEED := 150.0
const GRAVITY := 980.0
const MAX_FALL := 420.0
const JUMP_VELOCITY := -330.0
const JUMP_CUT := 0.45
const COYOTE_TIME := 0.08
const JUMP_BUFFER := 0.1
const DASH_SPEED := 400.0
const DASH_TIME := 0.14
const DASH_COOLDOWN := 0.4
const ATTACK_TIME := 0.15
const ATTACK_COOLDOWN := 0.3
const POGO_VELOCITY := -300.0
const MAX_HP := 5
const INVULN_TIME := 0.8
const HURT_TIME := 0.25
const KNOCKBACK := Vector2(180, -200)
const MS_PER_HIT := 400.0
## Spike hit: fade out, warp to safe ground halfway through, fade back in.
const SPIKE_RESPAWN_TIME := 0.5
## Floor this close to a hazard doesn't count as safe ground.
const SAFE_MARGIN := 10.0

const COLOR_BODY := Color("#ff2a6d")
const COLOR_VISOR := Color("#05d9e8")

var facing := 1
var hp := MAX_HP
var dead := false
var coyote_t := 0.0
var buffer_t := 0.0
var dash_t := 0.0
var dash_cd := 0.0
var air_dash_used := false
var attack_t := 0.0
var attack_cd := 0.0
var attack_dir := Vector2.RIGHT
var attack_id := 0
var invuln_t := 0.0
var hurt_t := 0.0
## Cosmetic squash and stretch, eases back to 1.
var squash := Vector2.ONE
var _was_on_floor := true
## Last floor spot clear of hazards; spikes send you back here.
var safe_pos := Vector2.ZERO
var respawn_t := 0.0

## Damage rects in world space, set by the level.
var hazards: Array[Rect2] = []


## Slash hitbox for a swing, shared with the ghost so its replayed swings hit
## exactly where the original did.
static func attack_rect(origin: Vector2, dir: Vector2) -> Rect2:
	if dir == Vector2.UP:
		return Rect2(origin + Vector2(-12, -38), Vector2(24, 26))
	if dir == Vector2.DOWN:
		return Rect2(origin + Vector2(-12, 12), Vector2(24, 26))
	var x := origin.x + 6.0 if dir.x > 0 else origin.x - 34.0
	return Rect2(x, origin.y - 12, 28, 22)


static func draw_body(canvas: CanvasItem, f: int, body: Color, visor: Color) -> void:
	canvas.draw_rect(Rect2(-SIZE / 2, SIZE), body)
	var visor_x := 0.0 if f > 0 else -6.0
	canvas.draw_rect(Rect2(visor_x, -8, 6, 3), visor)


static func draw_slash(canvas: CanvasItem, origin: Vector2, dir: Vector2, color: Color) -> void:
	var r := attack_rect(origin, dir)
	r.position -= origin
	canvas.draw_rect(r, Color(color, 0.35))
	canvas.draw_rect(r, color, false, 1.0)


func _ready() -> void:
	add_to_group("rewindable")
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = SIZE
	add_child(shape)
	safe_pos = position


func _physics_process(delta: float) -> void:
	queue_redraw()
	squash = squash.move_toward(Vector2.ONE, 4.0 * delta)
	if Rewind.is_rewinding or dead:
		return
	_tick_timers(delta)
	if respawn_t > 0.0:
		_tick_respawn(delta)
		return

	if is_on_floor():
		coyote_t = COYOTE_TIME
		air_dash_used = false
	if Input.is_action_just_pressed("jump"):
		buffer_t = JUMP_BUFFER

	var input_x := Input.get_axis("move_left", "move_right")
	if dash_t > 0.0:
		velocity = Vector2(facing * DASH_SPEED, 0)
	elif hurt_t > 0.0:
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	else:
		if input_x != 0.0:
			facing = int(signf(input_x))
		velocity.x = input_x * RUN_SPEED
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
		if buffer_t > 0.0 and coyote_t > 0.0:
			velocity.y = JUMP_VELOCITY
			buffer_t = 0.0
			coyote_t = 0.0
			squash = Vector2(0.75, 1.3)
			Fx.dust(_feet())
			Sfx.play("jump")
		if Input.is_action_just_released("jump") and velocity.y < 0.0:
			velocity.y *= JUMP_CUT
		if Input.is_action_just_pressed("dash") and dash_cd <= 0.0 and (is_on_floor() or not air_dash_used):
			dash_t = DASH_TIME
			dash_cd = DASH_COOLDOWN
			air_dash_used = not is_on_floor()
			squash = Vector2(1.35, 0.8)
			Fx.burst(position, COLOR_VISOR, 8, 90.0, 30.0, Vector2(-facing, 0))
			Sfx.play("dash")
		if Input.is_action_just_pressed("attack") and attack_cd <= 0.0:
			_start_attack()

	var fall_speed := velocity.y
	move_and_slide()
	if is_on_floor() and not _was_on_floor and fall_speed > 150.0:
		squash = Vector2(1.3, 0.75)
		Fx.dust(_feet(), 8)
	_was_on_floor = is_on_floor()
	if is_on_floor() and hurt_t <= 0.0 and _on_safe_ground():
		safe_pos = position
	if attack_t > 0.0:
		_resolve_attack()
	_check_damage()


func _tick_timers(delta: float) -> void:
	coyote_t = maxf(coyote_t - delta, 0.0)
	buffer_t = maxf(buffer_t - delta, 0.0)
	dash_t = maxf(dash_t - delta, 0.0)
	dash_cd = maxf(dash_cd - delta, 0.0)
	attack_t = maxf(attack_t - delta, 0.0)
	attack_cd = maxf(attack_cd - delta, 0.0)
	invuln_t = maxf(invuln_t - delta, 0.0)
	hurt_t = maxf(hurt_t - delta, 0.0)


func _start_attack() -> void:
	attack_t = ATTACK_TIME
	attack_cd = ATTACK_COOLDOWN
	attack_id += 1
	if Input.is_action_pressed("move_up"):
		attack_dir = Vector2.UP
	elif Input.is_action_pressed("move_down") and not is_on_floor():
		attack_dir = Vector2.DOWN
	else:
		attack_dir = Vector2(facing, 0)
	Sfx.play("slash")


func _resolve_attack() -> void:
	var rect := attack_rect(position, attack_dir)
	for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
		if not rect.intersects(enemy.hurt_rect()):
			continue
		if enemy.take_hit("p%d" % attack_id, attack_dir):
			Rewind.add_time(MS_PER_HIT)
			Fx.hit_stop(0.045)
			Fx.shake(2.0)
			if attack_dir == Vector2.DOWN:
				velocity.y = POGO_VELOCITY
				air_dash_used = false


func _check_damage() -> void:
	var body := Rect2(position - SIZE / 2, SIZE)
	# Spikes ignore i-frames, so you can't walk across them after a hit.
	for rect in hazards:
		if body.intersects(rect):
			_spike_hit()
			return
	if invuln_t > 0.0:
		return
	for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
		for rect in enemy.damage_rects():
			if body.intersects(rect):
				_take_damage(rect.get_center())
				return


func _take_damage(source: Vector2) -> void:
	hp -= 1
	invuln_t = INVULN_TIME
	hurt_t = HURT_TIME
	dash_t = 0.0
	var away := signf(position.x - source.x)
	if away == 0.0:
		away = -facing
	velocity = Vector2(away * KNOCKBACK.x, KNOCKBACK.y)
	Sfx.play("hurt")
	Fx.hit_stop(0.12)
	Fx.shake(6.0)
	Fx.burst(position, COLOR_BODY, 14, 160.0)
	if hp <= 0:
		_die()


func _spike_hit() -> void:
	hp -= 1
	Sfx.play("hurt")
	Fx.hit_stop(0.12)
	Fx.shake(6.0)
	Fx.burst(position, COLOR_BODY, 14, 160.0)
	if hp <= 0:
		_die()
		return
	respawn_t = SPIKE_RESPAWN_TIME
	invuln_t = SPIKE_RESPAWN_TIME + INVULN_TIME
	dash_t = 0.0
	attack_t = 0.0
	velocity = Vector2.ZERO


func _tick_respawn(delta: float) -> void:
	var half := SPIKE_RESPAWN_TIME / 2.0
	var before := respawn_t
	respawn_t = maxf(respawn_t - delta, 0.0)
	if before > half and respawn_t <= half:
		position = safe_pos
		Fx.burst(position, COLOR_VISOR, 12, 100.0)
	velocity = Vector2.ZERO


func _on_safe_ground() -> bool:
	var feet := Rect2(position - SIZE / 2, SIZE).grow_individual(SAFE_MARGIN, 0.0, SAFE_MARGIN, 4.0)
	for rect in hazards:
		if feet.intersects(rect):
			return false
	return true


func _die() -> void:
	dead = true
	velocity = Vector2.ZERO
	Fx.shake(10.0)
	Fx.burst(position, COLOR_BODY, 30, 220.0)


func _feet() -> Vector2:
	return position + Vector2(0, SIZE.y / 2)


func _draw() -> void:
	var body := COLOR_BODY
	if respawn_t > 0.0:
		# Fade out at the spikes, fade back in on safe ground.
		var half := SPIKE_RESPAWN_TIME / 2.0
		body = Color(COLOR_BODY, absf(respawn_t - half) / half)
	elif dead:
		body = Color(0.35, 0.35, 0.4)
	elif invuln_t > 0.0 and int(invuln_t * 20.0) % 2 == 0:
		body = Color.WHITE
	# Scale around the feet so squashing doesn't lift the body off the floor.
	draw_set_transform(Vector2(0, SIZE.y / 2 * (1.0 - squash.y)), 0.0, squash)
	draw_body(self, facing, body, COLOR_VISOR)
	draw_set_transform(Vector2.ZERO)
	if attack_t > 0.0:
		draw_slash(self, position, attack_dir, COLOR_VISOR)


func capture_state() -> Dictionary:
	return {
		"position": position, "velocity": velocity, "facing": facing, "hp": hp, "dead": dead,
		"dash_t": dash_t, "dash_cd": dash_cd, "air_dash_used": air_dash_used,
		"attack_t": attack_t, "attack_cd": attack_cd, "attack_dir": attack_dir, "attack_id": attack_id,
		"invuln_t": invuln_t, "hurt_t": hurt_t, "coyote_t": coyote_t,
		"safe_pos": safe_pos, "respawn_t": respawn_t,
	}


func apply_state(state: Dictionary) -> void:
	for key in state:
		set(key, state[key])
