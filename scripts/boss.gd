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
	size = Vector2(30, 44)
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


func damage_rects() -> Array[Rect2]:
	if not is_active():
		return []
	var rects: Array[Rect2] = [hurt_rect()]
	for w in waves:
		rects.append(Rect2(w.x - WAVE_SIZE.x / 2, w.y - WAVE_SIZE.y, WAVE_SIZE.x, WAVE_SIZE.y))
	return rects


func take_hit(key: String, from_dir: Vector2) -> bool:
	var landed := super(key, from_dir)
	if landed and mode == Mode.REVERSING:
		# A ghost hit knocks it out of the reversal where it stands.
		_end_reversal()
	elif landed and not dead and reversals_left > 0 and snaps.size() >= BURST_SNAPS \
			and snaps[snaps.size() - BURST_SNAPS].z - hp >= BURST_DAMAGE:
		_start_reversal()
	if dead:
		waves.clear()
		Fx.hit_stop(0.35)
		Fx.shake(6.0)
		Fx.burst(position, COLOR_GOLD, 24, 220.0)
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
	if mode == Mode.REVERSING:
		# Afterimages along the path it's about to rewind through.
		for j in range(reverse_path.size() - 1, -1, -3):
			var ghost_pos := Vector2(reverse_path[j].x, reverse_path[j].y) - position
			draw_rect(Rect2(ghost_pos - half, size), Color(COLOR_INVERTED, 0.25), false, 1.0)
	var winding := mode == Mode.WINDUP_CHARGE or mode == Mode.WINDUP_SLAM
	var visor := Color.WHITE if winding and int(mode_t * 20.0) % 2 == 0 else trim
	var visor_x := 0.0 if dir > 0 else -half.x
	draw_rect(Rect2(visor_x, -half.y + 8, half.x, 4), visor)
	if mode == Mode.CHARGE:
		draw_line(Vector2(-dir * half.x, -6), Vector2(-dir * (half.x + 18), -6), COLOR_TRIM, 2.0)
		draw_line(Vector2(-dir * half.x, 8), Vector2(-dir * (half.x + 12), 8), COLOR_TRIM, 2.0)
	for w in waves:
		var base := Vector2(w.x, w.y) - position
		draw_colored_polygon(PackedVector2Array([
			base + Vector2(-WAVE_SIZE.x / 2, 0), base + Vector2(0, -WAVE_SIZE.y),
			base + Vector2(WAVE_SIZE.x / 2, 0),
		]), COLOR_TRIM)


func capture_state() -> Dictionary:
	var state := super()
	state.merge({
		"mode": mode, "mode_t": mode_t, "attacks": attacks, "waves": waves.duplicate(), "invert_t": invert_t,
		"snaps": snaps.duplicate(), "snap_t": snap_t, "reversals_left": reversals_left,
		"reverse_path": reverse_path.duplicate(), "reverse_t": reverse_t,
	})
	return state


func apply_state(state: Dictionary) -> void:
	super(state)
	# History frames must never share the live array.
	waves = state.waves.duplicate()
	snaps = state.snaps.duplicate()
	reverse_path = state.reverse_path.duplicate()
