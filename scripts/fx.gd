extends Node
## Autoload "Fx". Game-feel effects anyone can trigger: hit-stop, camera
## shake, spark bursts and screen flashes. Skipped while rewinding, so a
## rewind never replays them.

const MAX_SHAKE := 7.0
const SHAKE_DECAY := 2.2

var _trauma := 0.0
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
	_trauma = maxf(_trauma - delta * SHAKE_DECAY, 0.0)
	var camera := get_viewport().get_camera_2d()
	if camera:
		var amount := _trauma * _trauma * MAX_SHAKE
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * amount
	_flash.color.a = move_toward(_flash.color.a, 0.0, delta * 2.5)


## amount 0-1; stacks up to a cap.
func shake(amount: float) -> void:
	if Rewind.is_rewinding:
		return
	_trauma = minf(_trauma + amount, 1.0)


func flash(color: Color, alpha := 0.3) -> void:
	_flash.color = Color(color, alpha)


## Near-freeze the game for a few real-time milliseconds so hits land hard.
func hit_stop(seconds: float) -> void:
	if Rewind.is_rewinding or Engine.time_scale < 1.0:
		return
	Engine.time_scale = 0.05
	await get_tree().create_timer(seconds, true, false, true).timeout
	Engine.time_scale = 1.0


## Burst of sparks at a world position. dir biases them (zero = all around).
func sparks(pos: Vector2, color: Color, count := 10, dir := Vector2.ZERO) -> void:
	if Rewind.is_rewinding:
		return
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = count
	p.lifetime = 0.4
	p.position = pos
	p.direction = dir if dir != Vector2.ZERO else Vector2.UP
	p.spread = 180.0 if dir == Vector2.ZERO else 55.0
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 220.0
	p.damping_min = 200.0
	p.damping_max = 300.0
	p.gravity = Vector2(0, 250)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.5
	p.color = color
	p.color_ramp = _spark_ramp
	p.z_index = 10
	p.finished.connect(p.queue_free)
	get_tree().current_scene.add_child(p)
	p.emitting = true
