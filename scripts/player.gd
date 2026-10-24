class_name Player
extends CharacterBody2D
## Hollow Knight-style controller: instant run and stop, a jump that rises at a
## steady speed while held and falls fast, dash, directional slash with recoil
## and pogo off enemies with a down-slash. Hold toward a wall in the air to
## cling and slide; jump to kick off it (Mantis Claw). Hold attack to charge
## a nail art, then: release for the Great Slash (double damage, and its echo
## strikes the same spot again a moment later as a ghost hit, so it can hurt
## inverted enemies); dash for the Dash Slash (a lunge that cuts through
## everything in its path); or release holding up/down for the Cyclone Slash
## (a spin that hits all around); Q fires the same nail arts at once, on a
## cooldown. Sideways swings chain into a three-hit combo: a high-to-low
## diagonal, a low-to-high return cut, then a wide flat finisher. Slashes aim
## at the mouse cursor (above: up, below in the air: down, otherwise toward
## it). Holding block (right click) guards against hits from the front for a
## little time each; raising it just as a hit lands is a time-parry that turns
## the attack back. Spikes cost 1 HP and put you back
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
const ATTACK_COOLDOWN := 0.26
## A click this soon before the cooldown ends still swings, instead of being
## swallowed.
const ATTACK_BUFFER := 0.15
## Jumps allowed in mid-air before landing or grabbing a wall.
const AIR_JUMPS := 1
const AIR_JUMP_SPEED := 250.0
## What enemies can hit: the drawn body (~52 px tall), not the small physics box.
const HURT_SIZE := Vector2(18, 46)
const POGO_VELOCITY := -340.0
## Landing a sideways slash pushes you back a little, like the nail does.
const RECOIL_SPEED := 100.0
const RECOIL_TIME := 0.08
const MAX_HP := 6
const INVULN_TIME := 1.2
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
const NAIL_ART_DAMAGE := 2
const DASH_SLASH_SPEED := 460.0
const DASH_SLASH_TIME := 0.2
## The lunge hits from just behind you to a sword's reach in front.
const DASH_SLASH_REACH := 34.0
const CYCLONE_TIME := 0.45
const CYCLONE_HITS := 3
const CYCLONE_SIZE := Vector2(72, 44)
## Spinning drifts at this fraction of run speed and barely falls.
const CYCLONE_DRIFT := 0.5
const CYCLONE_FALL := 40.0
## Swing again within this long to continue the combo.
const COMBO_WINDOW := 0.5
const COMBO_LENGTH := 3
## Raising your guard this soon before a hit lands parries it.
const PARRY_WINDOW := 0.15
## Holding block: slower walk; each blocked hit costs this much time and
## pushes you back, and with too little time left the guard breaks.
const BLOCK_SLOW := 0.4
const BLOCK_COST_MS := 300.0
const BLOCK_GRACE := 0.3
## Q fires a nail art at once (no charge), then needs this long to recover.
const SPECIAL_COOLDOWN := 1.2
const PARRY_MS := 600.0
## Untouchable this long after a parry (without the hurt blink).
const PARRY_GRACE := 0.35
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
var air_jumps_left := AIR_JUMPS
var attack_buffer_t := 0.0
var attack_t := 0.0
var attack_cd := 0.0
var attack_dir := Vector2.RIGHT
var attack_id := 0
## 1 for a normal swing; nail arts hit harder.
var attack_damage := 1
var dash_slash_t := 0.0
var cyclone_t := 0.0
var parry_t := 0.0
## Which swing of the combo comes next, and how long it stays open.
var combo_step := 0
var combo_t := 0.0
## Aim at the cursor. Input state, not part of the rewind snapshot; the
## autopilot turns it off so scripted swings aim with W/S.
var aim_with_mouse := true
var blocking := false
## Time since the guard went up, for the parry window.
var block_t := 0.0
var special_cd := 0.0
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
var _step_t := 0.0

## Damage rects in world space, set by the level.
var hazards: Array[Rect2] = []


## Slash hitbox for a swing, shared with the ghost so its replayed swings hit
## exactly where the original did.
## Sized to the drawn sword, which reaches well past the small physics box.
static func attack_rect(origin: Vector2, dir: Vector2) -> Rect2:
	if dir == Vector2.UP:
		return Rect2(origin + Vector2(-20, -64), Vector2(40, 48))
	if dir == Vector2.DOWN:
		return Rect2(origin + Vector2(-20, 4), Vector2(40, 44))
	var x := origin.x + 2.0 if dir.x > 0 else origin.x - 46.0
	return Rect2(x, origin.y - 30, 44, 42)


## The body enemies can hit, standing on the same feet as the physics box.
func hurt_rect() -> Rect2:
	var feet := position.y + SIZE.y / 2
	return Rect2(position.x - HURT_SIZE.x / 2, feet - HURT_SIZE.y, HURT_SIZE.x, HURT_SIZE.y)


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
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)


## Where a slash goes: toward the cursor (turning to face it), or for the
## autopilot up/down from W/S, else forward.
func _face_cursor() -> void:
	if not aim_with_mouse:
		return
	var to_x := get_global_mouse_position().x - position.x
	if to_x != 0.0:
		facing = 1 if to_x > 0.0 else -1


func _aim_dir() -> Vector2:
	if aim_with_mouse:
		var to := get_global_mouse_position() - position
		if to.y < -absf(to.x):
			return Vector2.UP
		if to.y > absf(to.x) and not is_on_floor():
			return Vector2.DOWN
		if to.x != 0.0:
			facing = 1 if to.x > 0.0 else -1
		return Vector2(facing, 0)
	if Input.is_action_pressed("move_up"):
		return Vector2.UP
	if Input.is_action_pressed("move_down") and not is_on_floor():
		return Vector2.DOWN
	return Vector2(facing, 0)


## Cyclone needs an up/down aim: the cursor well above or below, or W/S held.
func _aims_vertically() -> bool:
	if aim_with_mouse:
		var to := get_global_mouse_position() - position
		return absf(to.y) > absf(to.x)
	return Input.is_action_pressed("move_up") or Input.is_action_pressed("move_down")


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
		air_jumps_left = AIR_JUMPS
	if Input.is_action_just_pressed("jump"):
		buffer_t = JUMP_BUFFER
	if Input.is_action_just_pressed("attack") and attack_cd > 0.0:
		attack_buffer_t = ATTACK_BUFFER

	var input_x := Input.get_axis("move_left", "move_right")
	if dash_slash_t > 0.0:
		velocity = Vector2(facing * DASH_SLASH_SPEED, 0)
	elif cyclone_t > 0.0:
		velocity.x = input_x * RUN_SPEED * CYCLONE_DRIFT
		velocity.y = minf(velocity.y + GRAVITY * delta, CYCLONE_FALL)
	elif dash_t > 0.0:
		velocity = Vector2(facing * DASH_SPEED, 0)
		charge_t = 0.0
		if Input.is_action_just_pressed("special") and special_cd <= 0.0:
			special_cd = SPECIAL_COOLDOWN
			_dash_slash()
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
			air_jumps_left = AIR_JUMPS
		if wall_lock_t > 0.0:
			velocity.x = wall_dir * WALL_JUMP_X
		elif recoil_t > 0.0:
			velocity.x = recoil_dir * RECOIL_SPEED
		else:
			if input_x != 0.0:
				facing = int(signf(input_x))
			velocity.x = input_x * RUN_SPEED
		if Input.is_action_just_pressed("block"):
			block_t = 0.0
			charge_t = 0.0
		blocking = Input.is_action_pressed("block")
		if blocking:
			_face_cursor()
			if recoil_t <= 0.0:
				velocity.x *= BLOCK_SLOW
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
		elif buffer_t > 0.0 and air_jumps_left > 0:
			# Double jump: a fresh, slightly lower jump in mid-air.
			velocity.y = -AIR_JUMP_SPEED
			jump_hold_t = JUMP_HOLD
			buffer_t = 0.0
			air_jumps_left -= 1
			squash = Vector2(0.7, 1.35)
			Fx.sprite_fx("landing_dust", _feet() + Vector2(0, -16), 0.6)
			Fx.burst(_feet(), Color(0.8, 0.95, 1.0, 0.7), 8, 90.0, 60.0, Vector2.DOWN)
			Sfx.play("jump", 0.0, 0.0)
		if Input.is_action_just_released("jump") and velocity.y < 0.0:
			jump_hold_t = 0.0
			velocity.y = maxf(velocity.y, -JUMP_RELEASE_SPEED)
		if Input.is_action_just_pressed("dash") and charge_t >= CHARGE_TIME:
			_dash_slash()
		elif Input.is_action_just_pressed("dash") and dash_cd <= 0.0 and (is_on_floor() or not air_dash_used):
			dash_t = DASH_TIME
			dash_cd = DASH_COOLDOWN
			air_dash_used = not is_on_floor()
			squash = Vector2(1.35, 0.8)
			Fx.burst(position, COLOR_VISOR, 4, 80.0, 30.0, Vector2(-facing, 0))
			Fx.sprite_fx("smoke_puff", position + Vector2(-facing * 10, 4), 0.5, 0.0, facing < 0, null, false)
			Sfx.play("dash")
		if blocking:
			pass
		elif Input.is_action_just_pressed("special") and special_cd <= 0.0:
			special_cd = SPECIAL_COOLDOWN
			charge_t = 0.0
			if _aims_vertically():
				_cyclone_slash()
			else:
				_echo_slash()
		elif (Input.is_action_just_pressed("attack") or attack_buffer_t > 0.0) and attack_cd <= 0.0:
			attack_buffer_t = 0.0
			_start_attack()
		elif Input.is_action_just_released("attack"):
			if charge_t >= CHARGE_TIME and _aims_vertically():
				_cyclone_slash()
			elif charge_t >= CHARGE_TIME:
				_echo_slash()
			charge_t = 0.0
		elif Input.is_action_pressed("attack"):
			var was_ready := charge_t >= CHARGE_TIME
			charge_t += delta
			if charge_t - delta < CHARGE_GLOW_FROM and charge_t >= CHARGE_GLOW_FROM:
				Fx.sprite_fx("focus_charge", Vector2(0, -6), 0.55, 0.0, false, self)
			if not was_ready and charge_t >= CHARGE_TIME:
				Fx.burst(position, Ghost.COLOR, 5, 70.0)
				Sfx.play("charge")

	var fall_speed := velocity.y
	move_and_slide()
	if is_on_floor() and not grounded and fall_speed > 150.0:
		squash = Vector2(1.3, 0.75)
		Fx.dust(_feet(), 4 if fall_speed > 300.0 else 2)
		if fall_speed > 300.0:
			Fx.sprite_fx("landing_dust", _feet() + Vector2(0, -16), 0.55, 0.0, false, null, false)
	grounded = is_on_floor()
	_dash_trail(delta)
	_run_dust(delta)
	if is_on_floor() and hurt_t <= 0.0 and _on_safe_ground():
		safe_pos = position
	if attack_t > 0.0:
		_resolve_attack()
	if cyclone_t > 0.0:
		_update_cyclone(delta)
	_update_echoes(delta)
	_check_damage()


## Afterimages while dashing.
func _dash_trail(delta: float) -> void:
	_afterimage_t -= delta
	if (dash_t > 0.0 or dash_slash_t > 0.0) and _afterimage_t <= 0.0:
		_afterimage_t = 0.035
		Fx.afterimage(_sprite)


## Little puffs kicked up while running.
func _run_dust(delta: float) -> void:
	_step_t -= delta
	if is_on_floor() and absf(velocity.x) > 60.0 and dash_t <= 0.0 and _step_t <= 0.0:
		_step_t = 0.22
		Fx.dust(_feet() - Vector2(facing * 4.0, 0), 2)


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
	dash_slash_t = maxf(dash_slash_t - delta, 0.0)
	parry_t = maxf(parry_t - delta, 0.0)
	combo_t = maxf(combo_t - delta, 0.0)
	attack_buffer_t = maxf(attack_buffer_t - delta, 0.0)
	special_cd = maxf(special_cd - delta, 0.0)
	block_t += delta


func _start_attack() -> void:
	attack_t = ATTACK_TIME
	attack_cd = ATTACK_COOLDOWN
	attack_id += 1
	attack_damage = 1
	attack_dir = _aim_dir()
	# Lean into the swing.
	squash = Vector2(1.12, 0.9)
	if attack_dir.x != 0.0:
		_combo_swipe()
	else:
		Fx.swipe(self, attack_dir)
		_slash_fx(attack_dir, false, 0.0, 0.8)
	Sfx.play("swing", -2.0)


## Each sideways swing in a row cuts a different way.
func _combo_swipe() -> void:
	combo_step = (combo_step + 1) % COMBO_LENGTH if combo_t > 0.0 else 0
	combo_t = COMBO_WINDOW
	match combo_step:
		0: # high to low, tilted up
			Fx.swipe(self, attack_dir, 26.0, Color.WHITE, facing, -0.3 * facing)
			_slash_fx(attack_dir, false, -0.3 * facing, 0.8)
		1: # low to high, tilted down
			Fx.swipe(self, attack_dir, 26.0, Color.WHITE, -facing, 0.3 * facing)
			_slash_fx(attack_dir, true, 0.3 * facing, 0.8)
		2: # wide flat finisher
			Fx.swipe(self, attack_dir, 36.0, Color.WHITE, facing, 0.0, 0.45)
			_slash_fx(attack_dir, false, 0.0, 1.05)


## The Crescent Slash sprite, turned to point along the swing (its art arcs
## across the top of the frame, i.e. upward), following the player.
func _slash_fx(dir: Vector2, mirror: bool, tilt: float, size_by: float) -> void:
	var turn := dir.angle() + PI / 2 + tilt
	Fx.sprite_fx("crescent_slash", dir * 8.0 + Vector2(0, -8), size_by, turn, mirror, self)


## Great Slash: a double-damage swing that leaves an echo behind.
func _echo_slash() -> void:
	_start_attack()
	attack_damage = NAIL_ART_DAMAGE
	Fx.swipe(self, attack_dir, 32.0)
	_slash_fx(attack_dir, false, 0.0, 1.15)
	echoes.append({
		"rect": attack_rect(position, attack_dir), "dir": attack_dir, "id": attack_id, "t": ECHO_DELAY,
	})
	Fx.burst(position, Ghost.COLOR, 6, 120.0, 40.0, attack_dir)


## Dash Slash: lunge forward, cutting through everything along the way.
func _dash_slash() -> void:
	charge_t = 0.0
	if aim_with_mouse:
		var to_x := get_global_mouse_position().x - position.x
		if to_x != 0.0:
			facing = 1 if to_x > 0.0 else -1
	attack_id += 1
	attack_damage = NAIL_ART_DAMAGE
	attack_dir = Vector2(facing, 0)
	attack_t = DASH_SLASH_TIME
	attack_cd = ATTACK_COOLDOWN
	dash_slash_t = DASH_SLASH_TIME
	dash_cd = DASH_COOLDOWN
	squash = Vector2(1.4, 0.75)
	Fx.lunge(position, attack_dir)
	Fx.swipe(self, attack_dir, 28.0)
	Sfx.play("dash")
	Sfx.play("swing")


## Cyclone Slash: spin in place, hitting all around a few times.
func _cyclone_slash() -> void:
	attack_id += 1
	attack_cd = CYCLONE_TIME
	cyclone_t = CYCLONE_TIME
	velocity.y = minf(velocity.y, 0.0)
	Sfx.play("swing")


func _update_cyclone(delta: float) -> void:
	var step := CYCLONE_TIME / CYCLONE_HITS
	var before := cyclone_t
	cyclone_t = maxf(cyclone_t - delta, 0.0)
	# One hit at the start of each third of the spin.
	var hit := int((CYCLONE_TIME - cyclone_t) / step)
	if hit != int((CYCLONE_TIME - before) / step) or before == CYCLONE_TIME:
		facing = -facing
		Fx.swipe(self, Vector2(facing, 0), 30.0)
		var rect := Rect2(position - CYCLONE_SIZE / 2, CYCLONE_SIZE)
		for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
			if rect.intersects(enemy.hurt_rect()) and enemy.take_hit("p%d_c%d" % [attack_id, hit], Vector2(facing, 0)):
				Rewind.add_time(MS_PER_HIT)
				Fx.hit_stop(0.02)
		if hit < CYCLONE_HITS:
			Sfx.play("swing", -3.0)


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
	if dash_slash_t > 0.0:
		var back := position.x - facing * SIZE.x
		var front := position.x + facing * DASH_SLASH_REACH
		rect = Rect2(minf(back, front), position.y - 12, absf(front - back), 24)
	for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
		if not rect.intersects(enemy.hurt_rect()):
			continue
		if enemy.take_hit("p%d" % attack_id, attack_dir, attack_damage):
			Rewind.add_time(MS_PER_HIT)
			# A crisp, tiny freeze and a nudge toward the blow; the combo
			# finisher lands harder.
			var finisher := attack_dir.x != 0.0 and combo_step == COMBO_LENGTH - 1
			Fx.hit_stop(0.08 if finisher else 0.05)
			Fx.kick(attack_dir, 5.0 if finisher else 3.0)
			if attack_dir == Vector2.DOWN:
				velocity.y = POGO_VELOCITY
				jump_hold_t = 0.0
				air_dash_used = false
			elif attack_dir.x != 0.0 and dash_slash_t <= 0.0:
				recoil_t = RECOIL_TIME
				recoil_dir = -int(attack_dir.x)


func _check_damage() -> void:
	var body := Rect2(position - SIZE / 2, SIZE)
	# Spikes ignore i-frames, so you can't walk across them after a hit.
	for rect in hazards:
		if body.intersects(rect):
			_spike_hit()
			return
	if invuln_t > 0.0 or parry_t > 0.0:
		return
	body = hurt_rect()
	for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
		for rect in enemy.damage_rects():
			if not body.intersects(rect):
				continue
			if blocking and _in_front(rect) and block_t <= PARRY_WINDOW:
				_parry(enemy, rect)
			elif blocking and _in_front(rect) and Rewind.time_ms >= BLOCK_COST_MS:
				_block(rect)
			else:
				_take_damage(rect.get_center())
			return


func _in_front(rect: Rect2) -> bool:
	return (rect.get_center().x - position.x) * facing >= -2.0


## A blocked hit: no damage, but it costs time and shoves you back.
func _block(rect: Rect2) -> void:
	Rewind.time_ms = maxf(Rewind.time_ms - BLOCK_COST_MS, 0.0)
	parry_t = BLOCK_GRACE
	recoil_t = RECOIL_TIME * 2.0
	recoil_dir = -facing
	Fx.hit_stop(0.04)
	Fx.impact(rect.get_center(), Vector2(-facing, 0), 0.7, Color(0.75, 0.97, 1.0))
	Fx.sprite_fx("arcane_parry", rect.get_center(), 0.4)
	Sfx.play("clash", -3.0)


## Time-parry: the attack is turned back, and you gain time for it.
func _parry(enemy: Enemy, rect: Rect2) -> void:
	enemy.parried(rect, position)
	parry_t = PARRY_GRACE
	Rewind.add_time(PARRY_MS)
	Fx.hit_stop(0.08)
	Fx.parry(rect.get_center())
	Sfx.play("clash")
	recoil_t = RECOIL_TIME
	recoil_dir = -facing


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
	Fx.hurt(position)
	Fx.hit_stop(0.12)
	Fx.shake(3.0)
	if hp <= 0:
		_die()


func _spike_hit() -> void:
	hp -= 1
	Sfx.play("hurt")
	Fx.hurt(position)
	Fx.hit_stop(0.12)
	Fx.shake(3.0)
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
		reset_physics_interpolation()
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
	if blocking:
		# Guard: a bright arc in front, flaring during the parry window.
		var parry_ready := block_t <= PARRY_WINDOW
		var guard := Color.WHITE if parry_ready else Color(COLOR_VISOR, 0.85)
		var mid := 0.0 if facing > 0 else PI
		draw_arc(Vector2(facing * 4, -2), 14.0, mid - 1.0, mid + 1.0, 12, guard, 3.0 if parry_ready else 2.0)
	_draw_charge()
	_draw_echoes()
	if cyclone_t > 0.0:
		var spin := (1.0 - cyclone_t / CYCLONE_TIME) * TAU * CYCLONE_HITS
		var r := CYCLONE_SIZE.x / 2 - 6
		draw_arc(Vector2.ZERO, r, spin, spin + PI * 1.2, 20, Color(COLOR_VISOR, 0.8), 2.0)
		draw_arc(Vector2.ZERO, r - 5, spin + PI, spin + PI * 2.0, 20, Color(COLOR_VISOR, 0.4), 1.0)


func _draw_charge() -> void:
	if charge_t < CHARGE_GLOW_FROM:
		return
	var ready := charge_t >= CHARGE_TIME
	var k := minf((charge_t - CHARGE_GLOW_FROM) / (CHARGE_TIME - CHARGE_GLOW_FROM), 1.0)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 60.0) if ready else k
	var color := Color.WHITE if ready else Ghost.COLOR
	draw_arc(Vector2.ZERO, 10.0 + 8.0 * k, 0.0, TAU, 24, Color(color, 0.25 + 0.5 * pulse), 1.0 + k)
	# Sparks spiralling in as the charge builds.
	var spin := Time.get_ticks_msec() / 120.0
	for i in 4:
		var a := spin + i * TAU / 4.0
		var r := 26.0 * (1.0 - k) + 8.0
		draw_circle(Vector2.from_angle(a) * r, 1.5 + k, Color(color, 0.4 + 0.5 * k))


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
		"air_jumps_left": air_jumps_left, "attack_buffer_t": attack_buffer_t,
		"attack_damage": attack_damage, "dash_slash_t": dash_slash_t, "cyclone_t": cyclone_t,
		"parry_t": parry_t, "combo_step": combo_step, "combo_t": combo_t,
		"blocking": blocking, "block_t": block_t, "special_cd": special_cd,
	}


func apply_state(state: Dictionary) -> void:
	for key in state:
		set(key, state[key])
	# History frames must never share the live array.
	echoes = state.echoes.duplicate(true)
