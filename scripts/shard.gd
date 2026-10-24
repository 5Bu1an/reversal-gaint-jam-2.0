class_name Shard
extends Node2D
## Time shard pickup: refills part of the time bar. Not rewindable on
## purpose, so you can't rewind and grab the same shard twice.

const MS := 1000.0
const RADIUS := 10.0
const COLOR := Color("#05d9e8")

var _t := 0.0


func _physics_process(delta: float) -> void:
	_t += delta
	queue_redraw()
	var player: Player = get_tree().get_first_node_in_group("player")
	if player and not player.dead and player.position.distance_to(position) < RADIUS + 8.0:
		Rewind.add_time(MS)
		Fx.burst(position, COLOR, 8, 90.0)
		Fx.sprite_fx("harvest_seal", position, 0.6)
		Sfx.play("shard")
		queue_free()


func _draw() -> void:
	var y := sin(_t * 3.0) * 3.0
	var points := PackedVector2Array([
		Vector2(0, y - 7), Vector2(5, y), Vector2(0, y + 7), Vector2(-5, y),
	])
	draw_colored_polygon(points, Color(COLOR, 0.35))
	points.append(points[0])
	draw_polyline(points, COLOR, 1.0)
