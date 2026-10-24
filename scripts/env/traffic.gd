extends Node2D
## Flying cars crossing the sky in two lanes. They fly backwards while time
## rewinds. Lives in a Parallax2D; wraps around the visible span.

const CARS := ["v-police", "v-red", "v-yellow"]
const LANES := [
	{"y": 48.0, "speed": 60.0, "scale": 0.26, "shade": 0.45},
	{"y": 82.0, "speed": -95.0, "scale": 0.3, "shade": 0.6},
]

var scroll_scale := 0.3
var level_w := 3200.0

var _span := 0.0
var _cars: Array[Dictionary] = []


func _ready() -> void:
	_span = (level_w - 640.0) * scroll_scale + 640.0 + 300.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for lane: Dictionary in LANES:
		var x := rng.randf_range(0, 200)
		while x < _span:
			var sprite := Sprite2D.new()
			sprite.texture = load(Warped.DIR + "wc1/vehicles/%s.png" % CARS[rng.randi() % CARS.size()])
			sprite.scale = Vector2.ONE * lane.scale
			sprite.flip_h = lane.speed < 0
			sprite.modulate = Color(lane.shade, lane.shade, lane.shade + 0.1)
			sprite.position = Vector2(x, lane.y + rng.randf_range(-8, 8))
			add_child(sprite)
			_cars.append({"node": sprite, "speed": lane.speed * rng.randf_range(0.8, 1.2)})
			x += rng.randf_range(260, 520)


func _process(delta: float) -> void:
	var direction := -2.0 if Rewind.is_rewinding else 1.0
	for car in _cars:
		var sprite: Sprite2D = car.node
		sprite.position.x = wrapf(sprite.position.x + car.speed * direction * delta, -150.0, _span)
