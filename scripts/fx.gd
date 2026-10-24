extends Node
## Autoload "Fx". Game feel: screen shake, hit-stop and particle bursts.
## All cosmetic, so none of it is recorded by Rewind.
##
##   Fx.shake(4.0)                   # pixels of trauma, decays on its own
##   Fx.hit_stop(0.05)               # freeze the game for a moment
##   Fx.burst(pos, Color.CYAN, 12)   # one-shot spark burst in world space

const SHAKE_DECAY := 30.0 # pixels per second
const MAX_SHAKE := 10.0

var _shake := 0.0
var _stop_until := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if Engine.time_scale < 1.0 and Time.get_ticks_msec() >= _stop_until:
		Engine.time_scale = 1.0
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	if get_tree().paused:
		camera.offset = Vector2.ZERO
		return
	_shake = maxf(_shake - SHAKE_DECAY * delta, 0.0)
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake


func shake(amount: float) -> void:
	_shake = minf(maxf(_shake, amount), MAX_SHAKE)


## Uses real time, so stacking stops never freezes the game for long.
func hit_stop(seconds: float) -> void:
	Engine.time_scale = 0.05
	_stop_until = maxi(_stop_until, Time.get_ticks_msec() + int(seconds * 1000.0))


func burst(pos: Vector2, color: Color, amount := 10, speed := 120.0, spread := 180.0, dir := Vector2.UP) -> void:
	var scene := get_tree().current_scene
	if scene == null:
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
	p.finished.connect(p.queue_free)
	scene.add_child(p)
	p.emitting = true


## Small puff of dust at someone's feet.
func dust(feet: Vector2, amount := 6) -> void:
	burst(feet, Color(1, 1, 1, 0.35), amount, 60.0, 70.0)
