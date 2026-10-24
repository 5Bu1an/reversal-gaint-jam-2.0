class_name Player
extends CharacterBody2D
## Hollow Knight-style controller: instant run and stop, a jump that rises at a
## steady speed while held and falls fast, dash, directional slash with recoil
## and pogo off enemies with a down-slash. Hold toward a wall in the air to
## cling and slide; jump to kick off it (Mantis Claw). Hold attack to charge an echo slash
## (nail art): its echo strikes the same spot again a moment later as a ghost
## hit, so it can hurt inverted enemies. Spikes cost 1 HP and put you back
## on the last safe ground you stood on. Drawn as placeholder shapes until
## sprites land in assets/art.

const SIZE := Vector2(12, 24)
const RUN_SPEED := 155.0
const GRAVITY := 1400.0
const MAX_FALL := 440.0
## Holding jump keeps rising at JUMP_SPEED for up to JUMP_HOLD, then gravity
## takes over: ~58 px at full hold, a short hop on a tap.
const JUMP_SPEED := 260.0
const JUMP_HOLD := 0.13
## Letting go early caps the rise at this speed, so taps stay small.
const JUMP_RELEASE_SPEED := 90.0
const COYOTE_TIME := 0.08
const JUMP_BUFFER := 0.1
const DASH_SPEED := 400.0
const DASH_TIME := 0.14
const DASH_COOLDOWN := 0.4
const ATTACK_TIME := 0.15
const ATTACK_COOLDOWN := 0.3
const POGO_VELOCITY := -340.0
## Landing a sideways slash pushes you back a little, like the nail does.
const RECOIL_SPEED := 170.0
const RECOIL_TIME := 0.08
const MAX_HP := 5
const INVULN_TIME := 0.8
const HURT_TIME := 0.25
const KNOCKBACK := Vector2(180, -200)
const MS_PER_HIT := 400.0
## Spike hit: fade out, warp to safe ground halfway through, fade back in.
const SPIKE_RESPAWN_TIME := 0.5
## Floor this close to a hazard doesn't count as safe ground.
const SAFE_MARGIN := 10.0
## Echo slash: hold attack this long, release to swing; the echo lands later.
const CHARGE_TIME := 0.6
const CHARGE_GLOW_FROM := 0.15
const ECHO_DELAY := 0.5
const ECHO_FLASH := 0.12
const WALL_SLIDE_SPEED := 60.0
const WALL_JUMP_X := 190.0
## Push away from the wall this long before input steers again.
const WALL_JUMP_LOCK := 0.16
## Grace window to wall-jump just after letting go of a wall.
const WALL_COYOTE := 0.1

const COLOR_BODY := Color("#ff2a6d")
const COLOR_VISOR := Color("#05d9e8")

var facing := 1
var hp := MAX_HP
var dead := false
var coyote_t := 0.0
var buffer_t := 0.0
var jump_hold_t := 0.0
var recoil_t := 0.0
var recoil_dir := 0
var dash_t := 0.0
var dash_cd := 0.0
var air_dash_used := false
var attack_t := 0.0
var attack_cd := 0.0
var attack_dir := Vector2.RIGHT
var attack_id := 0
var invuln_t := 0.0
var hurt_t := 0.0
var grounded := true
## Cosmetic squash and stretch, eases back to 1.
var squash := Vector2.ONE
## Last floor spot clear of hazards; spikes send you back here.
var safe_pos := Vector2.ZERO
var respawn_t := 0.0
## How long attack has been held since the last swing.
var charge_t := 0.0
## Pending echo strikes: {rect, dir, id, t}; t counts down to the hit, then
## below zero for the flash.
var echoes: Array[Dictionary] = []
var wall_t := 0.0
## Which way a wall jump pushes: +1 when the wall is on your left.
var wall_dir := 0
var wall_lock_t := 0.0
var wall_sliding := false

var _sprite := RoninSprite.new()
var _afterimage_t := 0.0

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


func _ready() -> void:
	add_to_group("rewindable")
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = SIZE
	add_child(shape)
	add_child(_sprite)
	safe_pos = position


func _physics_process(delta: float) -> void:
	squash = squash.move_toward(Vector2.ONE, 4.0 * delta)
	_sprite.scale = squash
	_sprite.show_state(capture_state())
	_sprite.visible = invuln_t <= 0.0 or dead or int(invuln_t * 20.0) % 2 == 0
	# Fade out at the spikes, fade back in on safe ground.
	var half := SPIKE_RESPAWN_TIME / 2.0
	_sprite.modulate.a = absf(respawn_t - half) / half if respawn_t > 0.0 else 1.0
	queue_redraw()
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
		charge_t = 0.0
	elif hurt_t > 0.0:
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
		charge_t = 0.0
	else:
		var wall_x := get_wall_normal().x if is_on_wall_only() else 0.0
		wall_sliding = not is_on_floor() and wall_x != 0.0 and input_x != 0.0 and signf(input_x) == -signf(wall_x)
		if wall_sliding:
			wall_t = WALL_COYOTE
			wall_dir = int(signf(wall_x))
			air_dash_used = false
		if wall_lock_t > 0.0:
			velocity.x = wall_dir * WALL_JUMP_X
		elif recoil_t > 0.0:
			velocity.x = recoil_dir * RECOIL_SPEED
		else:
			if input_x != 0.0:
				facing = int(signf(input_x))
			velocity.x = input_x * RUN_SPEED
		if jump_hold_t > 0.0 and Input.is_action_pressed("jump"):
			velocity.y = -JUMP_SPEED
			jump_hold_t = maxf(jump_hold_t - delta, 0.0)
		else:
			jump_hold_t = 0.0
			velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
		if wall_sliding:
			# Face away from the wall so slashes hit what's in front of you.
			facing = wall_dir
			velocity.y = minf(velocity.y, WALL_SLIDE_SPEED)
			if Engine.get_physics_frames() % 8 == 0:
				Fx.dust(position + Vector2(-wall_dir * SIZE.x / 2, 0), 2)
		if buffer_t > 0.0 and coyote_t <= 0.0 and wall_t > 0.0:
			velocity = Vector2(wall_dir * WALL_JUMP_X, -JUMP_SPEED)
			jump_hold_t = JUMP_HOLD
			facing = wall_dir
			wall_lock_t = WALL_JUMP_LOCK
			wall_t = 0.0
			buffer_t = 0.0
			squash = Vector2(0.75, 1.3)
			Fx.dust(position + Vector2(-wall_dir * SIZE.x / 2, 0))
			Sfx.play("jump")
		elif buffer_t > 0.0 and coyote_t > 0.0:
			velocity.y = -JUMP_SPEED
			jump_hold_t = JUMP_HOLD
			buffer_t = 0.0
			coyote_t = 0.0
			squash = Vector2(0.75, 1.3)
			Fx.dust(_feet(), 3)
			Sfx.play("jump")
		if Input.is_action_just_released("jump") and velocity.y < 0.0:
			jump_hold_t = 0.0
			velocity.y = maxf(velocity.y, -JUMP_RELEASE_SPEED)
		if Input.is_action_just_pressed("dash") and dash_cd <= 0.0 and (is_on_floor() or not air_dash_used):
			dash_t = DASH_TIME
			dash_cd = DASH_COOLDOWN
			air_dash_used = not is_on_floor()
			squash = Vector2(1.35, 0.8)
			Fx.burst(position, COLOR_VISOR, 4, 80.0, 30.0, Vector2(-facing, 0))
			Sfx.play("dash")
		if Input.is_action_just_pressed("attack") and attack_cd <= 0.0:
			_start_attack()
		elif Input.is_action_just_released("attack"):
			if charge_t >= CHARGE_TIME:
				_echo_slash()
			charge_t = 0.0
		elif Input.is_action_pressed("attack"):
			var was_ready := charge_t >= CHARGE_TIME
			charge_t += delta
			if not was_ready and charge_t >= CHARGE_TIME:
				Fx.burst(position, Ghost.COLOR, 5, 70.0)
				Sfx.play("charge")

	var fall_speed := velocity.y
	move_and_slide()
	if is_on_floor() and not grounded and fall_speed > 150.0:
		squash = Vector2(1.3, 0.75)
		Fx.dust(_feet(), 4 if fall_speed > 300.0 else 2)
	grounded = is_on_floor()
	_dash_trail(delta)
	if is_on_floor() and hurt_t <= 0.0 and _on_safe_ground():
		safe_pos = position
	if attack_t > 0.0:
		_resolve_attack()
	_update_echoes(delta)
	_check_damage()


## Afterimages while dashing.
func _dash_trail(delta: float) -> void:
	_afterimage_t -= delta
	if dash_t > 0.0 and _afterimage_t <= 0.0:
		_afterimage_t = 0.035
		Fx.afterimage(_sprite)


func _tick_timers(delta: float) -> void:
	coyote_t = maxf(coyote_t - delta, 0.0)
	buffer_t = maxf(buffer_t - delta, 0.0)
	dash_t = maxf(dash_t - delta, 0.0)
	dash_cd = maxf(dash_cd - delta, 0.0)
	attack_t = maxf(attack_t - delta, 0.0)
	attack_cd = maxf(attack_cd - delta, 0.0)
	invuln_t = maxf(invuln_t - delta, 0.0)
	hurt_t = maxf(hurt_t - delta, 0.0)
	recoil_t = maxf(recoil_t - delta, 0.0)
	wall_t = maxf(wall_t - delta, 0.0)
	wall_lock_t = maxf(wall_lock_t - delta, 0.0)


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


func _echo_slash() -> void:
	_start_attack()
	echoes.append({
		"rect": attack_rect(position, attack_dir), "dir": attack_dir, "id": attack_id, "t": ECHO_DELAY,
	})
	Fx.burst(position, Ghost.COLOR, 6, 120.0, 40.0, attack_dir)


## Echo hits use a "g" key, so they count as ghost hits.
func _update_echoes(delta: float) -> void:
	for i in range(echoes.size() - 1, -1, -1):
		var echo := echoes[i]
		var before: float = echo.t
		echo.t -= delta
		if before > 0.0 and echo.t <= 0.0:
			var rect: Rect2 = echo.rect
			for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
				if rect.intersects(enemy.hurt_rect()):
					enemy.take_hit("g_echo%d" % echo.id, echo.dir)
			Fx.burst(rect.get_center(), Ghost.COLOR, 5, 100.0)
			Sfx.play("slash")
		if echo.t <= -ECHO_FLASH:
			echoes.remove_at(i)


func _resolve_attack() -> void:
	var rect := attack_rect(position, attack_dir)
	for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
		if not rect.intersects(enemy.hurt_rect()):
			continue
		if enemy.take_hit("p%d" % attack_id, attack_dir):
			Rewind.add_time(MS_PER_HIT)
			# A crisp, tiny freeze; no screen shake on ordinary hits.
			Fx.hit_stop(0.03)
			if attack_dir == Vector2.DOWN:
				velocity.y = POGO_VELOCITY
				jump_hold_t = 0.0
				air_dash_used = false
			elif attack_dir.x != 0.0:
				recoil_t = RECOIL_TIME
				recoil_dir = -int(attack_dir.x)


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
	if Game.god_mode:
		return
	hp -= 1
	invuln_t = INVULN_TIME
	hurt_t = HURT_TIME
	dash_t = 0.0
	var away := signf(position.x - source.x)
	if away == 0.0:
		away = -facing
	velocity = Vector2(away * KNOCKBACK.x, KNOCKBACK.y)
	Sfx.play("death" if hp <= 0 else "hurt")
	Fx.flash(COLOR_BODY, 0.15)
	Fx.hit_stop(0.12)
	Fx.shake(3.0)
	Fx.burst(position, COLOR_BODY, 8, 140.0)
	if hp <= 0:
		_die()


func _spike_hit() -> void:
	hp -= 1
	Sfx.play("hurt")
	Fx.hit_stop(0.12)
	Fx.shake(3.0)
	Fx.burst(position, COLOR_BODY, 8, 140.0)
	if hp <= 0:
		_die()
		return
	respawn_t = SPIKE_RESPAWN_TIME
	invuln_t = SPIKE_RESPAWN_TIME + INVULN_TIME
	dash_t = 0.0
	attack_t = 0.0
	charge_t = 0.0
	velocity = Vector2.ZERO


func _tick_respawn(delta: float) -> void:
	var half := SPIKE_RESPAWN_TIME / 2.0
	var before := respawn_t
	respawn_t = maxf(respawn_t - delta, 0.0)
	if before > half and respawn_t <= half:
		position = safe_pos
		Fx.burst(position, COLOR_VISOR, 6, 80.0)
	velocity = Vector2.ZERO


func _on_safe_ground() -> bool:
	var feet := Rect2(position - SIZE / 2, SIZE).grow_individual(SAFE_MARGIN, 0.0, SAFE_MARGIN, 4.0)
	for rect in hazards:
		if feet.intersects(rect):
			return false
	return true


## Where to leave the death shade: here, unless that's over thorns, where it
## couldn't be slashed without getting hurt; then the last safe ground.
func shade_spot() -> Vector2:
	var left := position.x - SIZE.x / 2 - SAFE_MARGIN
	var right := position.x + SIZE.x / 2 + SAFE_MARGIN
	for rect in hazards:
		if rect.position.y > position.y and right > rect.position.x and left < rect.end.x:
			return safe_pos
	return position


func _die() -> void:
	dead = true
	velocity = Vector2.ZERO
	Fx.shake(5.0)
	Fx.burst(position, COLOR_BODY, 16, 180.0)


func _feet() -> Vector2:
	return position + Vector2(0, SIZE.y / 2)


## The sprite draws the body; this layer adds the charge glow and echoes.
func _draw() -> void:
	_draw_charge()
	_draw_echoes()


func _draw_charge() -> void:
	if charge_t < CHARGE_GLOW_FROM:
		return
	var ready := charge_t >= CHARGE_TIME
	var k := minf((charge_t - CHARGE_GLOW_FROM) / (CHARGE_TIME - CHARGE_GLOW_FROM), 1.0)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 60.0) if ready else k
	var color := Color.WHITE if ready else Ghost.COLOR
	draw_arc(Vector2.ZERO, 10.0 + 8.0 * k, 0.0, TAU, 24, Color(color, 0.25 + 0.5 * pulse), 1.0 + k)


func _draw_echoes() -> void:
	for echo in echoes:
		var rect: Rect2 = echo.rect
		rect.position -= position
		if echo.t > 0.0:
			var wait: float = 1.0 - echo.t / ECHO_DELAY
			draw_rect(rect, Color(Ghost.COLOR, 0.15 + 0.35 * wait), false, 1.0)
		else:
			draw_rect(rect, Color(Ghost.COLOR, 0.6))


func capture_state() -> Dictionary:
	return {
		"position": position, "velocity": velocity, "facing": facing, "hp": hp, "dead": dead,
		"dash_t": dash_t, "dash_cd": dash_cd, "air_dash_used": air_dash_used,
		"attack_t": attack_t, "attack_cd": attack_cd, "attack_dir": attack_dir, "attack_id": attack_id,
		"invuln_t": invuln_t, "hurt_t": hurt_t, "coyote_t": coyote_t, "grounded": grounded,
		"safe_pos": safe_pos, "respawn_t": respawn_t, "charge_t": charge_t, "echoes": echoes.duplicate(true),
		"wall_t": wall_t, "wall_dir": wall_dir, "wall_lock_t": wall_lock_t,
		"jump_hold_t": jump_hold_t, "recoil_t": recoil_t, "recoil_dir": recoil_dir,
	}


func apply_state(state: Dictionary) -> void:
	for key in state:
		set(key, state[key])
	# History frames must never share the live array.
	echoes = state.echoes.duplicate(true)
