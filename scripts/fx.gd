extends Node
## Autoload "Fx". Game feel: screen shake, hit-stop, particle bursts, screen
## flashes and afterimages. All cosmetic, so none of it is recorded by Rewind,
## and nothing new starts while time is rewinding.
##
##   Fx.shake(4.0)                   # pixels of trauma, decays on its own
##   Fx.hit_stop(0.05)               # freeze the game for a moment
##   Fx.burst(pos, Color.CYAN, 12)   # one-shot spark burst in world space
##   Fx.flash(Color.RED, 0.3)        # full-screen colour flash
##   Fx.afterimage(sprite)           # fading copy of a sprite's frame
##
## Hollow Knight-style hit effects (see Vfx):
##   Fx.impact(pos, dir)             # a blade connects: streaks, bloom, sparks
##   Fx.kill(pos, dir)               # an enemy dies: bigger burst, drifting sparkles
##   Fx.hurt(pos)                    # the player is hit: dark flash, side streaks
##   Fx.parry(pos)                   # a parry: ring, cross streaks, white flash
##   Fx.enemy_hit(pos, dir, color)   # enemy struck: ink streaks and goo in its colour
##   Fx.enemy_kill(pos, dir, color, size, floor_y)  # dies: glow, splatter, flung body, stain
##   Fx.kick(dir, px)                # camera nudged toward a blow, springs back
##   Fx.telegraph(pos)               # a red glint as an enemy starts its wind-up
##   Fx.deflect(pos, color)          # a blade bouncing off: ring and flare
##   Fx.spawn_in(pos, color)         # an enemy warping in
##   Fx.ground_crack(pos, color)     # streaks racing along the floor from a slam
##   Fx.slow_mo(seconds)             # a beat of slow motion after the hit-stop
##   Fx.swipe(node, dir)             # crescent swipe that follows a swinging node
##   Fx.lunge(pos, dir)              # long streaks trailing a dash slash

const SHAKE_DECAY := 30.0 # pixels per second
## Dark ink for enemy hit streaks, like Hollow Knight's black splashes.
const INK := Color("#07060d")
const MAX_SHAKE := 10.0
const STOP_SCALE := 0.05
const SLOW_SCALE := 0.5
const MAX_KICK := 8.0
const KICK_RETURN := 50.0 # pixels per second

var _shake := 0.0
var _stop_until := 0
var _slow_until := 0
var _kick := Vector2.ZERO
var _flash := ColorRect.new()
var _spark_ramp := Gradient.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 15
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0)
	layer.add_child(_flash)
	add_child(layer)
	_spark_ramp.set_color(0, Color.WHITE)
	_spark_ramp.set_color(1, Color(1, 1, 1, 0))


func _process(delta: float) -> void:
	var now := Time.get_ticks_msec()
	var scale := STOP_SCALE if now < _stop_until else (SLOW_SCALE if now < _slow_until else 1.0)
	if Engine.time_scale != scale:
		Engine.time_scale = scale
	var real_delta := delta / maxf(Engine.time_scale, 0.01)
	_kick = _kick.move_toward(Vector2.ZERO, KICK_RETURN * real_delta)
	_flash.color.a = move_toward(_flash.color.a, 0.0, delta * 2.5)
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	if get_tree().paused:
		camera.offset = Vector2.ZERO
		return
	_shake = maxf(_shake - SHAKE_DECAY * delta, 0.0)
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake + _kick


func shake(amount: float) -> void:
	if Rewind.is_rewinding:
		return
	_shake = minf(maxf(_shake, amount), MAX_SHAKE)


## Uses real time, so stacking stops never freezes the game for long.
func hit_stop(seconds: float) -> void:
	if Rewind.is_rewinding:
		return
	Engine.time_scale = STOP_SCALE
	_stop_until = maxi(_stop_until, Time.get_ticks_msec() + int(seconds * 1000.0))


## Slow motion that starts once any hit-stop ends.
func slow_mo(seconds: float) -> void:
	if Rewind.is_rewinding:
		return
	var from := maxi(_stop_until, Time.get_ticks_msec())
	_slow_until = maxi(_slow_until, from + int(seconds * 1000.0))


## Nudges the camera toward a blow; it springs back on its own.
func kick(dir: Vector2, pixels: float) -> void:
	if Rewind.is_rewinding or dir == Vector2.ZERO:
		return
	_kick = (_kick + dir.normalized() * pixels).limit_length(MAX_KICK)


func flash(color: Color, alpha := 0.3) -> void:
	_flash.color = Color(color, alpha)


func burst(pos: Vector2, color: Color, amount := 10, speed := 120.0, spread := 180.0, dir := Vector2.UP) -> void:
	var scene := get_tree().current_scene
	if scene == null or Rewind.is_rewinding:
		return
	var p := CPUParticles2D.new()
	p.position = pos
	p.z_index = 5
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.35
	p.direction = dir
	p.spread = spread
	p.gravity = Vector2(0, 400)
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = color
	p.color_ramp = _spark_ramp
	p.finished.connect(p.queue_free)
	scene.add_child(p)
	p.emitting = true


## Small puff of dust at someone's feet.
func dust(feet: Vector2, amount := 6) -> void:
	burst(feet, Color(1, 1, 1, 0.35), amount, 60.0, 70.0)


## Fading cyan copy of a sprite's current frame, left behind in the world.
func afterimage(sprite: AnimatedSprite2D) -> void:
	var scene := get_tree().current_scene
	if scene == null or Rewind.is_rewinding:
		return
	var copy := Sprite2D.new()
	copy.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	copy.centered = false
	copy.offset = sprite.offset
	copy.flip_h = sprite.flip_h
	copy.global_position = sprite.global_position
	copy.scale = sprite.scale
	copy.modulate = Color(0.3, 0.95, 1.0, 0.55)
	copy.z_index = -1
	scene.add_child(copy)
	var tween := copy.create_tween()
	tween.tween_property(copy, "modulate:a", 0.0, 0.22)
	tween.tween_callback(copy.queue_free)


func impact(pos: Vector2, dir: Vector2, strength := 1.0, color := Color.WHITE) -> void:
	var aim := dir.angle() if dir != Vector2.ZERO else -PI / 2
	var streaks: Array = []
	for i in int(6 * strength):
		streaks.append([aim + randf_range(-0.55, 0.55), randf_range(32.0, 64.0) * strength, randf_range(2.5, 4.5), 0.0])
	for i in 2:
		streaks.append([aim + PI / 2 + PI * i + randf_range(-0.3, 0.3), randf_range(14.0, 26.0), 2.0, 0.12])
	_spawn(pos, Vfx.Kind.STREAKS, 0.2, color, streaks)
	_spawn(pos, Vfx.Kind.BLOOM, 0.18, color, [], 20.0 * strength)
	_spawn(pos, Vfx.Kind.SPARKLES, 0.4, color, _sparkle_parts(6, aim, 1.2, 160.0))


func kill(pos: Vector2, dir: Vector2, color := Color.WHITE) -> void:
	var aim := dir.angle() if dir != Vector2.ZERO else -PI / 2
	var streaks: Array = []
	for i in 10:
		# Most streaks follow the blow; a few go everywhere.
		var spread := 0.7 if i < 6 else PI
		streaks.append([aim + randf_range(-spread, spread), randf_range(50.0, 100.0), randf_range(3.0, 5.5), randf_range(0.0, 0.2)])
	_spawn(pos, Vfx.Kind.STREAKS, 0.32, color, streaks)
	_spawn(pos, Vfx.Kind.BLOOM, 0.28, color, [], 40.0)
	_spawn(pos, Vfx.Kind.SPARKLES, 0.8, color, _sparkle_parts(20, aim, PI, 150.0))


func hurt(pos: Vector2, color := Color(1.0, 0.75, 0.8)) -> void:
	flash(Color.BLACK, 0.35)
	var streaks: Array = []
	for i in 12:
		var side := PI if i % 2 == 0 else 0.0
		streaks.append([side + randf_range(-0.35, 0.35), randf_range(50.0, 95.0), randf_range(3.0, 5.0), randf_range(0.0, 0.15)])
	_spawn(pos, Vfx.Kind.STREAKS, 0.34, color, streaks)
	_spawn(pos, Vfx.Kind.BLOOM, 0.25, color, [], 32.0)


func parry(pos: Vector2) -> void:
	flash(Color.WHITE, 0.2)
	var streaks: Array = []
	for i in 4:
		streaks.append([i * PI / 2 + PI / 4, 70.0, 4.5, 0.0])
		streaks.append([i * PI / 2, 36.0, 3.0, 0.1])
	_spawn(pos, Vfx.Kind.STREAKS, 0.28, Color.WHITE, streaks)
	_spawn(pos, Vfx.Kind.RING, 0.32, Color.WHITE, [], 54.0)
	_spawn(pos, Vfx.Kind.BLOOM, 0.28, Color.WHITE, [], 34.0)


## Crescent swipe attached to `node`, so it follows a moving swing. sweep_sign
## -1 draws it from the bottom up; tilt turns it; squash < 1 flattens it into
## a wide horizontal cut.
func swipe(node: Node2D, dir: Vector2, radius := 26.0, color := Color.WHITE,
		sweep_sign := 1.0, tilt := 0.0, squash := 1.0) -> void:
	if Rewind.is_rewinding:
		return
	var v := _make(Vector2.ZERO, Vfx.Kind.CRESCENT, 0.13, color, [], radius)
	v.angle = dir.angle() + tilt
	v.sweep *= sweep_sign
	v.scale = Vector2(1.0, squash)
	node.add_child(v)


## An enemy takes a hit: dark ink streaks and goo blobs in its own colour fly
## off along the blow, over a small white flash where the blade connected.
func enemy_hit(pos: Vector2, dir: Vector2, color: Color, strength := 1.0) -> void:
	var aim := dir.angle() if dir != Vector2.ZERO else -PI / 2
	var ink: Array = []
	for i in int(5 * strength):
		ink.append([aim + randf_range(-0.5, 0.5), randf_range(26.0, 54.0) * strength, randf_range(2.0, 4.0), randf_range(0.0, 0.1)])
	_spawn(pos, Vfx.Kind.STREAKS, 0.24, INK, ink, 20.0, false)
	_spawn(pos, Vfx.Kind.SPLAT, 0.45, color, _splat_parts(int(7 * strength), aim, 0.7, 220.0, 2.5), 20.0, false)
	_spawn(pos, Vfx.Kind.BLOOM, 0.16, color, [], 16.0 * strength)
	_spawn(pos, Vfx.Kind.STREAKS, 0.14, Color.WHITE, [[aim, 30.0 * strength, 3.0, 0.0], [aim + 0.3, 18.0, 2.0, 0.0],
		[aim - 0.3, 18.0, 2.0, 0.0]])
	# A slash mark across the body, roughly across the blow, and a flare.
	var cut := aim + PI / 2 + randf_range(-0.6, 0.6)
	_spawn(pos, Vfx.Kind.CUT, 0.16, Color.WHITE, [[cut, 46.0 * strength]])
	_spawn(pos, Vfx.Kind.STAR, 0.14, Color.WHITE, [], 16.0 * strength)


## An enemy dies: a big soft glow in its colour, a splatter of goo, ink
## streaks everywhere, its body flung away, and embers drifting up after.
func enemy_kill(pos: Vector2, dir: Vector2, color: Color, size := Vector2(16, 20), floor_y := -1.0) -> void:
	var aim := dir.angle() if dir != Vector2.ZERO else -PI / 2
	slow_mo(0.12)
	kick(dir, 6.0)
	_spawn(pos, Vfx.Kind.CUT, 0.22, Color.WHITE, [[aim + PI / 2 + randf_range(-0.4, 0.4), 80.0]])
	_spawn(pos, Vfx.Kind.STAR, 0.2, Color.WHITE, [], 28.0)
	if floor_y >= 0.0:
		var blobs: Array = []
		for i in 6:
			blobs.append([randf_range(-18.0, 18.0) + dir.x * 10.0, randf_range(4.0, 10.0)])
		var stain := _make(Vector2(pos.x, floor_y), Vfx.Kind.STAIN, 10.0, color.darkened(0.45), blobs, 20.0)
		stain.additive = false
		stain.z_index = -1
		if get_tree().current_scene and not Rewind.is_rewinding:
			get_tree().current_scene.add_child(stain)
	_spawn(pos, Vfx.Kind.BLOOM, 0.5, color, [], 56.0)
	var ink: Array = []
	for i in 10:
		ink.append([aim + randf_range(-PI, PI), randf_range(30.0, 70.0), randf_range(2.5, 4.5), randf_range(0.0, 0.15)])
	_spawn(pos, Vfx.Kind.STREAKS, 0.32, INK, ink, 20.0, false)
	_spawn(pos, Vfx.Kind.SPLAT, 0.75, color, _splat_parts(18, aim, PI, 260.0, 3.5), 20.0, false)
	_spawn(pos, Vfx.Kind.SPARKLES, 1.4, color, _sparkle_parts(12, -PI / 2, 1.4, 60.0))
	_spawn(pos, Vfx.Kind.STREAKS, 0.2, Color.WHITE, [[aim, 70.0, 4.0, 0.0], [aim + 0.25, 46.0, 3.0, 0.0],
		[aim - 0.25, 46.0, 3.0, 0.0]])
	var fling := Vector2(cos(aim) * 140.0, -180.0) if absf(cos(aim)) > 0.3 else Vector2(randf_range(-80, 80), -220.0)
	_spawn(pos, Vfx.Kind.CORPSE, 0.9, color.darkened(0.55), [[fling, size, randf_range(-9.0, 9.0)]], 20.0, false)


func lunge(pos: Vector2, dir: Vector2) -> void:
	var streaks: Array = []
	for i in 4:
		streaks.append([(-dir).angle() + randf_range(-0.12, 0.12), randf_range(60.0, 110.0), randf_range(2.0, 3.5), 0.0])
	_spawn(pos, Vfx.Kind.STREAKS, 0.22, Color(0.75, 0.97, 1.0), streaks)


func telegraph(pos: Vector2, size := 10.0, color := Color(1.0, 0.35, 0.4)) -> void:
	_spawn(pos, Vfx.Kind.STAR, 0.3, color, [], size)
	_spawn(pos, Vfx.Kind.BLOOM, 0.25, color, [], size * 1.2)


func deflect(pos: Vector2, color: Color) -> void:
	_spawn(pos, Vfx.Kind.RING, 0.25, color, [], 30.0)
	_spawn(pos, Vfx.Kind.STAR, 0.18, Color.WHITE, [], 18.0)


func spawn_in(pos: Vector2, color: Color) -> void:
	_spawn(pos, Vfx.Kind.RING, 0.4, color, [], 34.0)
	_spawn(pos, Vfx.Kind.BLOOM, 0.4, color, [], 26.0)
	_spawn(pos, Vfx.Kind.SPARKLES, 0.6, color, _sparkle_parts(10, -PI / 2, PI, 90.0))


func ground_crack(pos: Vector2, color: Color) -> void:
	var streaks: Array = []
	for side in [0.0, PI]:
		for i in 4:
			streaks.append([side + randf_range(-0.07, 0.07), randf_range(50.0, 110.0), randf_range(2.0, 3.5), i * 0.06])
	_spawn(pos, Vfx.Kind.STREAKS, 0.4, color, streaks)


func _splat_parts(count: int, aim: float, spread: float, speed: float, size: float) -> Array:
	var parts: Array = []
	for i in count:
		var v := Vector2.from_angle(aim + randf_range(-spread, spread)) * randf_range(speed * 0.35, speed)
		parts.append([v + Vector2(0, -60.0), randf_range(size * 0.5, size)])
	return parts


func _sparkle_parts(count: int, aim: float, spread: float, speed: float) -> Array:
	var parts: Array = []
	for i in count:
		parts.append([Vector2.from_angle(aim + randf_range(-spread, spread)) * randf_range(speed * 0.4, speed),
			randf_range(0.8, 1.6)])
	return parts


func _spawn(pos: Vector2, kind: Vfx.Kind, life: float, color: Color, parts: Array, radius := 20.0,
		additive := true) -> void:
	var scene := get_tree().current_scene
	if scene == null or Rewind.is_rewinding:
		return
	var v := _make(pos, kind, life, color, parts, radius)
	v.additive = additive
	scene.add_child(v)


func _make(pos: Vector2, kind: Vfx.Kind, life: float, color: Color, parts: Array, radius: float) -> Vfx:
	var v := Vfx.new()
	v.position = pos
	v.kind = kind
	v.life = life
	v.color = color
	v.parts = parts
	v.radius = radius
	return v
