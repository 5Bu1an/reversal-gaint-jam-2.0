class_name RoninSprite
extends AnimatedSprite2D
## The Cyber Ronin sprite (assets/art/player/samurai.png, made by
## tools/gen_player.py). Picks its animation from a player state dictionary,
## so the player and the ghost replaying a recorded timeline share it. Plays
## backwards while time rewinds.

const SHEET := preload("res://assets/art/player/samurai.png")
const META := preload("res://assets/art/player/samurai.json")

static var _frames: SpriteFrames

var _attack_id := -1
var _landing := false


static func frames() -> SpriteFrames:
	if _frames == null:
		_frames = SpriteFrames.new()
		_frames.remove_animation("default")
		var meta: Dictionary = META.data
		var cell: int = meta.cell
		for anim_name: String in meta.anims:
			var info: Dictionary = meta.anims[anim_name]
			_frames.add_animation(anim_name)
			_frames.set_animation_speed(anim_name, info.fps)
			_frames.set_animation_loop(anim_name, info.loop)
			for i in int(info.frames):
				var atlas := AtlasTexture.new()
				atlas.atlas = SHEET
				atlas.region = Rect2(i * cell, int(info.row) * cell, cell, cell)
				_frames.add_frame(anim_name, atlas)
	return _frames


## The animation a player state should show.
static func pick(state: Dictionary) -> String:
	if state.dead:
		return "dead"
	if state.attack_t > 0.0:
		if state.attack_dir == Vector2.UP:
			return "slash_up"
		return "slash_down" if state.attack_dir == Vector2.DOWN else "slash_side"
	if state.hurt_t > 0.0:
		return "hurt"
	if state.dash_t > 0.0:
		return "dash"
	if not state.get("grounded", true):
		return "jump" if state.velocity.y < 0.0 else "fall"
	return "run" if absf(state.velocity.x) > 10.0 else "idle"


func _ready() -> void:
	sprite_frames = frames()
	centered = false
	# Line the sheet's feet up with the bottom of the player's collision box.
	var meta: Dictionary = META.data
	position = Vector2(-int(meta.cell) / 2, Player.SIZE.y / 2 - int(meta.feet_y))
	animation_finished.connect(func() -> void: _landing = false)
	play("idle")


func show_state(state: Dictionary) -> void:
	var anim := pick(state)
	if anim == "idle" and (animation == "jump" or animation == "fall"):
		_landing = true
		play("land")
	elif _landing and anim == "idle":
		pass # let the landing squash finish
	elif anim != animation or (anim.begins_with("slash") and state.attack_id != _attack_id):
		_landing = false
		play(anim)
	_attack_id = state.attack_id
	flip_h = state.facing < 0
	speed_scale = -1.0 if Rewind.is_rewinding else 1.0
