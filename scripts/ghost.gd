class_name Ghost
extends Node2D
## The timeline you rewound keeps happening: replays the player's undone
## frames forward as a red echo whose slashes still damage enemies.

const COLOR := Color("#ff3b3b")
const FADE_TIME := 0.3

static var _serial := 0

var _frames: Array[Dictionary] = []
var _index := 0
var _id := 0
var _fade := FADE_TIME
var _sprite := RoninSprite.new()


func setup(frames: Array[Dictionary]) -> void:
	_frames = frames
	_serial += 1
	_id = _serial
	modulate = Color(1, 1, 1, 0.6)
	_sprite.modulate = Color(1.0, 0.35, 0.35)
	add_child(_sprite)
	_show_frame(0)


func _physics_process(delta: float) -> void:
	if Rewind.is_rewinding:
		return
	if _index >= _frames.size():
		_fade -= delta
		modulate.a = 0.6 * maxf(_fade / FADE_TIME, 0.0)
		if _fade <= 0.0:
			queue_free()
		return
	_show_frame(_index)
	var frame := _frames[_index]
	if frame.attack_t > 0.0 and not frame.dead:
		var rect := Player.attack_rect(frame.position, frame.attack_dir)
		for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
			if rect.intersects(enemy.hurt_rect()):
				if enemy.take_hit("g%d_%d" % [_id, frame.attack_id], frame.attack_dir):
					Fx.sparks(rect.intersection(enemy.hurt_rect()).get_center(), COLOR, 8, frame.attack_dir)
					Fx.shake(0.15)
					Sfx.play("hit", -6.0, 0.15)
	_index += 1


func _show_frame(i: int) -> void:
	var frame := _frames[mini(i, _frames.size() - 1)]
	position = frame.position
	_sprite.show_state(frame)


