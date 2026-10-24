extends Node2D
## Parallax city backdrop. Warped City 1's sky, skyline and near buildings for
## most of the tower; it crossfades into Warped City 2's red rooftops as the
## camera reaches the boss sector.

const SCALE_WC1 := 1.5 # 3 screen pixels per art pixel at 1280x720
const SCALE_WC2 := 2.0
const FADE_FROM := 2380.0
const FADE_TO := 2640.0

var _city: Array[Parallax2D] = []
var _rooftops: Array[Parallax2D] = []
var _sky_fill := ColorRect.new()
var _sky_city := Color.BLACK
var _sky_rooftops := Color.BLACK


func _ready() -> void:
	var sky: Texture2D = load(Warped.DIR + "wc1/bg/sky.png")
	var back: Texture2D = load(Warped.DIR + "wc2/bg/back.png")
	_sky_city = sky.get_image().get_pixel(0, 0)
	_sky_rooftops = back.get_image().get_pixel(0, 0)
	_sky_fill.size = Vector2(640, 360)
	var fixed := Parallax2D.new()
	fixed.scroll_scale = Vector2.ZERO
	fixed.z_index = -20
	fixed.add_child(_sky_fill)
	add_child(fixed)

	_city.append(_layer(sky, 0.05, SCALE_WC1, 360.0, -19))
	_city.append(_layer(load(Warped.DIR + "wc1/bg/skyline.png"), 0.18, SCALE_WC1, 344.0, -18))
	_city.append(_layer(load(Warped.DIR + "wc1/bg/near.png"), 0.4, SCALE_WC1, 350.0, -17))
	_rooftops.append(_layer(back, 0.05, SCALE_WC2, 360.0, -19))
	_rooftops.append(_layer(load(Warped.DIR + "wc2/bg/middle.png"), 0.18, SCALE_WC2, 350.0, -18))
	_rooftops.append(_layer(load(Warped.DIR + "wc2/bg/front.png"), 0.4, SCALE_WC2, 366.0, -17))
	_apply_fade(0.0)


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera:
		var t := smoothstep(FADE_FROM, FADE_TO, camera.get_screen_center_position().x)
		_apply_fade(t)


func _apply_fade(t: float) -> void:
	for layer in _city:
		layer.modulate.a = 1.0 - t
	for layer in _rooftops:
		layer.modulate.a = t
	_sky_fill.color = _sky_city.lerp(_sky_rooftops, t)


## One repeating layer whose bottom edge sits at bottom_y.
func _layer(texture: Texture2D, scroll: float, scale_by: float, bottom_y: float, z: int) -> Parallax2D:
	var parallax := Parallax2D.new()
	parallax.scroll_scale = Vector2(scroll, 1.0)
	var width := texture.get_width() * scale_by
	parallax.repeat_size = Vector2(width, 0)
	parallax.repeat_times = int(ceil(640.0 / width)) + 2
	parallax.z_index = z
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.scale = Vector2(scale_by, scale_by)
	sprite.position = Vector2(0, bottom_y - texture.get_height() * scale_by)
	parallax.add_child(sprite)
	add_child(parallax)
	return parallax
