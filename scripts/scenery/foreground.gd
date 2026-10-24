extends Node2D
## Near-black silhouettes in front of the action, scrolling faster than the
## camera for depth: hanging cables and pipes up top, railings and rubble at
## the bottom. Kept to the screen edges so they never hide a fight.

const COLOR := Color("#05050a")

var scroll_scale := 1.25
var level_w := 3200.0

var _cables: Array[PackedVector2Array] = []
var _pipes: Array[Rect2] = []
var _rubble: Array[PackedVector2Array] = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var span := (level_w - 640.0) * scroll_scale + 640.0
	var x := 40.0
	while x < span:
		match rng.randi() % 3:
			0:
				_cables.append(_catenary(x, x + rng.randf_range(120, 220), rng.randf_range(40, 75)))
			1:
				_pipes.append(Rect2(x, 0, rng.randf_range(8, 14), rng.randf_range(30, 60)))
			2:
				_rubble.append(_lump(x, rng))
		x += rng.randf_range(140, 260)


func _catenary(x0: float, x1: float, sag: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 17:
		var u := i / 16.0
		points.append(Vector2(lerpf(x0, x1, u), 6.0 + sag * 4.0 * u * (1.0 - u)))
	return points


func _lump(x: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var w := rng.randf_range(50, 110)
	var points := PackedVector2Array([Vector2(x, 360)])
	for i in 6:
		points.append(Vector2(x + w * (i + 1) / 7.0, 360 - rng.randf_range(10, 28)))
	points.append(Vector2(x + w, 360))
	return points


func _draw() -> void:
	for cable in _cables:
		draw_polyline(cable, COLOR, 2.0)
	for pipe in _pipes:
		draw_rect(pipe, COLOR)
		draw_rect(Rect2(pipe.position.x - 3, pipe.end.y - 6, pipe.size.x + 6, 6), COLOR)
	for lump in _rubble:
		draw_colored_polygon(lump, COLOR)
