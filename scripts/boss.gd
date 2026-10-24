class_name Boss
extends Enemy
## The Kuro Shogun, arena boss. Stalks the player, then alternates a dash
## charge and a jump slam whose shockwaves run along the floor. Below half
## health every wind-up and rest gets shorter, and it keeps flipping into an
## inverted state where only your ghost can hurt it.
##
## It bends time too: take too much damage too fast and it rewinds itself to
## where (and how healthy) it was a few seconds ago. It's inverted while it
## does, so only a ghost hit can interrupt it. Twice per fight.
##
## Parrying its charge stops it dead; parrying a shockwave sends it back the
## other way, and when it reaches the boss it lands as a ghost hit.

enum Mode { STALK, WINDUP_CHARGE, CHARGE, WINDUP_SLAM, AIR, RECOVER, REVERSING }

const NAME := "KURO SHOGUN"
const CHARGE_SPEED := 300.0
const CHARGE_TIME := 1.4
const SLAM_JUMP := -420.0
const SLAM_DRIFT := 220.0
const WAVE_SPEED := 210.0
const WAVE_SIZE := Vector2(10, 14)
const INVERTED_TIME := 3.5
const NORMAL_TIME := 3.0
const SNAP_EVERY := 0.25
const SNAPS := 12 # 3 s of its own history
const BURST_SNAPS := 8 # damage counted over the last 2 s
const BURST_DAMAGE := 4
const REVERSE_TIME := 1.2
const REVERSALS := 2

const COLOR_ARMOR := Color("#2a2140")
const COLOR_TRIM := Color("#ff2a6d")
const COLOR_GOLD := Color("#f5c542")

## Arena walls, so shockwaves know where to stop.
var arena_left := 0.0
var arena_right := 0.0

var mode := Mode.STALK
var mode_t := 1.0
var attacks := 0
## Live shockwaves as (x, floor_y, dir).
var waves: Array[Vector3] = []
## Parried shockwaves heading back at the boss, same layout.
var reflected: Array[Vector3] = []
var reflect_id := 0
## Counts down to the next inverted/normal flip once enraged.
var invert_t := 0.0
## Its own short history as (x, y, hp), oldest first.
var snaps: Array[Vector3] = []
var snap_t := 0.0
var reversals_left := REVERSALS
## Snapshots being played backwards during a reversal, newest first.
var reverse_path: Array[Vector3] = []
var reverse_t := 0.0


func _init() -> void:
	size = Vector2(42, 60)
	speed = 55.0
	max_hp = 24
	knockback = 0.0


func enraged() -> bool:
	return hp <= max_hp / 2


func _act(delta: float) -> void:
	mode_t = maxf(mode_t - delta, 0.0)
	if mode == Mode.REVERSING:
		_reverse(delta)
		return
	snap_t -= delta
	if snap_t <= 0.0:
		snap_t = SNAP_EVERY
		snaps.append(Vector3(position.x, position.y, hp))
		if snaps.size() > SNAPS:
			snaps.pop_front()
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	var pace := 0.6 if enraged() else 1.0
	if enraged():
		invert_t -= delta
		if invert_t <= 0.0:
			inverted = not inverted
			invert_t = INVERTED_TIME if inverted else NORMAL_TIME
			hurt_t = HURT_TIME # flash on every flip
	var player: Player = get_tree().get_first_node_in_group("player")
	var to_player := 0
	if player:
		to_player = int(signf(player.position.x - position.x))

	match mode:
		Mode.STALK:
			if to_player != 0:
				dir = to_player
			velocity.x = dir * speed / pace
			if mode_t <= 0.0:
				attacks += 1
				mode = Mode.WINDUP_CHARGE if attacks % 2 == 1 else Mode.WINDUP_SLAM
				Fx.telegraph(position + Vector2(dir * size.x * 0.25, -size.y * 0.3), 18.0)
				mode_t = 0.55 * pace
		Mode.WINDUP_CHARGE:
			velocity.x = 0.0
			if to_player != 0:
				dir = to_player
			if mode_t <= 0.0:
				mode = Mode.CHARGE
				mode_t = CHARGE_TIME
		Mode.CHARGE:
			velocity.x = dir * CHARGE_SPEED
		Mode.WINDUP_SLAM:
			velocity.x = 0.0
			if mode_t <= 0.0:
				mode = Mode.AIR
				velocity.y = SLAM_JUMP
				var dx := player.position.x - position.x if player else 0.0
				velocity.x = clampf(dx * 1.2, -SLAM_DRIFT, SLAM_DRIFT)
		Mode.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if mode_t <= 0.0:
				mode = Mode.STALK
				mode_t = 1.4 * pace

	move_and_slide()

	if mode == Mode.CHARGE and (is_on_wall() or mode_t <= 0.0):
		_recover(0.7 * pace)
	elif mode == Mode.AIR and is_on_floor():
		var floor_y := position.y + size.y / 2
		waves.append(Vector3(position.x - size.x / 2, floor_y, -1))
		waves.append(Vector3(position.x + size.x / 2, floor_y, 1))
		Sfx.play("boss_slam")
		Fx.ground_crack(Vector2(position.x, floor_y - 2.0), COLOR_TRIM)
		Fx.shake(2.5)
		Fx.dust(Vector2(position.x - size.x / 2, floor_y), 6)
		Fx.dust(Vector2(position.x + size.x / 2, floor_y), 6)
		_recover(0.6 * pace)

	var wave_speed := WAVE_SPEED / pace
	for i in range(waves.size() - 1, -1, -1):
		var w := waves[i]
		w.x += w.z * wave_speed * delta
		waves[i] = w
		if w.x < arena_left or w.x > arena_right:
			waves.remove_at(i)
	for i in range(reflected.size() - 1, -1, -1):
		var w := reflected[i]
		w.x += w.z * wave_speed * delta
		reflected[i] = w
		if _wave_rect(w).intersects(hurt_rect()):
			reflected.remove_at(i)
			reflect_id += 1
			take_hit("g_reflect%d" % reflect_id, Vector2(w.z, 0))
		elif w.x < arena_left or w.x > arena_right:
			reflected.remove_at(i)


func _wave_rect(w: Vector3) -> Rect2:
	return Rect2(w.x - WAVE_SIZE.x / 2, w.y - WAVE_SIZE.y, WAVE_SIZE.x, WAVE_SIZE.y)


func blood_color() -> Color:
	return COLOR_INVERTED if inverted else COLOR_TRIM


func parried(rect: Rect2, _from: Vector2) -> void:
	for i in waves.size():
		if _wave_rect(waves[i]) == rect:
			var w := waves[i]
			waves.remove_at(i)
			reflected.append(Vector3(w.x, w.y, -w.z))
			return
	# The body: a parried charge stops dead.
	hurt_t = HURT_TIME
	velocity.x = 0.0
	if mode == Mode.CHARGE:
		_recover(0.8)


func _start_reversal() -> void:
	mode = Mode.REVERSING
	reverse_path = snaps.duplicate()
	reverse_path.reverse()
	reverse_t = 0.0
	reversals_left -= 1
	snaps.clear()
	inverted = true
	waves.clear()
	velocity = Vector2.ZERO
	Fx.shake(3.0)
	Fx.burst(position, COLOR_INVERTED, 12, 160.0)
	Sfx.play("boss_rewind")


func _reverse(delta: float) -> void:
	reverse_t += delta
	var last := reverse_path.size() - 1
	var k := minf(reverse_t / REVERSE_TIME, 1.0) * last
	var i := mini(int(k), last - 1)
	var p := reverse_path[i].lerp(reverse_path[i + 1], k - i) if last > 0 else reverse_path[0]
	position = Vector2(p.x, p.y)
	hp = maxi(hp, int(p.z))
	if reverse_t >= REVERSE_TIME:
		_end_reversal()


func _end_reversal() -> void:
	inverted = false
	invert_t = NORMAL_TIME
	reverse_path.clear()
	_recover(0.5)


func _recover(time: float) -> void:
	mode = Mode.RECOVER
	mode_t = time


## Its body hurts while it charges or leaps; shockwaves always do.
func damage_rects() -> Array[Rect2]:
	if not is_active():
		return []
	var rects: Array[Rect2] = []
	if mode == Mode.CHARGE or mode == Mode.AIR:
		rects.append(hurt_rect())
	for w in waves:
		rects.append(_wave_rect(w))
	return rects


func take_hit(key: String, from_dir: Vector2, damage := 1) -> bool:
	var landed := super(key, from_dir, damage)
	if landed and mode == Mode.REVERSING:
		# A ghost hit knocks it out of the reversal where it stands.
		_end_reversal()
	elif landed and not dead and reversals_left > 0 and snaps.size() >= BURST_SNAPS \
			and snaps[snaps.size() - BURST_SNAPS].z - hp >= BURST_DAMAGE:
		_start_reversal()
	if dead:
		waves.clear()
		reflected.clear()
		Fx.hit_stop(0.35)
		Fx.shake(6.0)
		Fx.burst(position, COLOR_GOLD, 24, 220.0)
		Fx.kill(position, from_dir, COLOR_GOLD)
		Fx.enemy_kill(position, from_dir, COLOR_TRIM, size)
	return landed


func _draw_body(body: Color) -> void:
	var armor := body if hurt_t > 0.0 else COLOR_ARMOR
	var trim := COLOR_INVERTED if inverted else COLOR_TRIM
	var half := size / 2
	draw_rect(Rect2(-half, size), armor)
	draw_rect(Rect2(-half, size), trim, false, 2.0 if inverted else 1.0)
	# Kabuto horns.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(-half.x - 8, -half.y - 12), Vector2(-half.x + 6, -half.y),
	]), COLOR_GOLD)
	draw_colored_polygon(PackedVector2Array([
		Vector2(half.x, -half.y), Vector2(half.x + 8, -half.y - 12), Vector2(half.x - 6, -half.y),
	]), COLOR_GOLD)
	var winding := mode == Mode.WINDUP_CHARGE or mode == Mode.WINDUP_SLAM
	var visor := Color.WHITE if winding and int(mode_t * 20.0) % 2 == 0 else trim
	var visor_x := 0.0 if dir > 0 else -half.x
	draw_rect(Rect2(visor_x, -half.y + 8, half.x, 4), visor)
	if mode == Mode.CHARGE:
		draw_line(Vector2(-dir * half.x, -6), Vector2(-dir * (half.x + 18), -6), COLOR_TRIM, 2.0)
		draw_line(Vector2(-dir * half.x, 8), Vector2(-dir * (half.x + 12), 8), COLOR_TRIM, 2.0)


## Crouches and leans back for wind-ups, leans into the charge, stretches up
## out of a leap and slams flat on landing.
func _pose() -> Array:
	match mode:
		Mode.STALK:
			return [Vector2(0, -absf(sin(_anim_t * 7.0)) * 1.5), 0.0, Vector2.ONE]
		Mode.WINDUP_CHARGE, Mode.WINDUP_SLAM:
			var k := 1.0 - clampf(mode_t / 0.55, 0.0, 1.0)
			return [Vector2.ZERO, -dir * 0.12 * k, Vector2(1.0 + 0.18 * k, 1.0 - 0.18 * k)]
		Mode.CHARGE:
			return [Vector2.ZERO, dir * 0.1, Vector2(1.12, 0.92)]
		Mode.AIR:
			return [Vector2.ZERO, 0.0, Vector2(0.85, 1.2) if velocity.y < 0.0 else Vector2(1.05, 0.95)]
		Mode.RECOVER:
			var k := clampf(mode_t / 0.6, 0.0, 1.0)
			return [Vector2.ZERO, 0.0, Vector2(1.0 + 0.15 * k, 1.0 - 0.15 * k)]
	return [Vector2.ZERO, 0.0, Vector2.ONE]


## Shockwaves and rewind afterimages live in the world, so they don't lean
## and stretch with the body.
func _draw_extra() -> void:
	var half := size / 2
	if mode == Mode.REVERSING:
		# Afterimages along the path it's about to rewind through.
		for j in range(reverse_path.size() - 1, -1, -3):
			var ghost_pos := Vector2(reverse_path[j].x, reverse_path[j].y) - position
			draw_rect(Rect2(ghost_pos - half, size), Color(COLOR_INVERTED, 0.25), false, 1.0)
	for i in waves.size() + reflected.size():
		var is_reflected := i >= waves.size()
		var w: Vector3 = reflected[i - waves.size()] if is_reflected else waves[i]
		var base := Vector2(w.x, w.y) - position
		draw_colored_polygon(PackedVector2Array([
			base + Vector2(-WAVE_SIZE.x / 2, 0), base + Vector2(0, -WAVE_SIZE.y),
			base + Vector2(WAVE_SIZE.x / 2, 0),
		]), Ghost.COLOR if is_reflected else COLOR_TRIM)


func capture_state() -> Dictionary:
	var state := super()
	state.merge({
		"mode": mode, "mode_t": mode_t, "attacks": attacks, "waves": waves.duplicate(), "invert_t": invert_t,
		"snaps": snaps.duplicate(), "snap_t": snap_t, "reversals_left": reversals_left,
		"reverse_path": reverse_path.duplicate(), "reverse_t": reverse_t,
		"reflected": reflected.duplicate(), "reflect_id": reflect_id,
	})
	return state


func apply_state(state: Dictionary) -> void:
	super(state)
	# History frames must never share the live array.
	waves = state.waves.duplicate()
	snaps = state.snaps.duplicate()
	reverse_path = state.reverse_path.duplicate()
	reflected = state.reflected.duplicate()
