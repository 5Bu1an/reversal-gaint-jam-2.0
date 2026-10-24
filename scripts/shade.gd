class_name Shade
extends Enemy
## What's left of your last timeline: when you die, the time on your bar is
## lost and waits at the death spot as a red shade. Slash it to take that
## time back. Die again first and it's gone for good. Game.shade keeps it
## across the scene reload.
##
## Not rewindable on purpose (like shards), so you can't rewind and collect
## the same time twice. Harmless to touch.

const BOB := 3.0

var ms := 0.0
var _t := 0.0


func _init() -> void:
	size = Vector2(12, 24)
	max_hp = 1
	knockback = 0.0


func _ready() -> void:
	super()
	remove_from_group("rewindable")


func _act(delta: float) -> void:
	_t += delta


func damage_rects() -> Array[Rect2]:
	return []


## Any slash (yours or a ghost's) collects it. Returns false so the hit
## doesn't also pay out MS_PER_HIT or pogo you.
func take_hit(key: String, _from_dir: Vector2) -> bool:
	if not is_active() or key == last_hit:
		return false
	last_hit = key
	dead = true
	Rewind.add_time(ms)
	Game.shade = {}
	Fx.burst(position, Ghost.COLOR, 30, 180.0)
	Fx.shake(4.0)
	Sfx.play("pickup")
	return false


func _draw() -> void:
	if dead:
		return
	var y := sin(_t * 2.0) * BOB
	draw_set_transform(Vector2(0, y))
	modulate.a = 0.55 + 0.15 * sin(_t * 5.0)
	Player.draw_body(self, -1, Ghost.COLOR, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(-40, -24), "%d ms" % ms,
		HORIZONTAL_ALIGNMENT_CENTER, 80, 8, Ghost.COLOR)
