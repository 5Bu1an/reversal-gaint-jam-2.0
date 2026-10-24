class_name Warped
## Warped City 1 & 2 environment art (CC0, ansimuz) in assets/env/warped:
## atlas regions for facade and deck pieces, and a builder for the animated
## neon props. See assets/env/warped/CREDITS.md.

const DIR := "res://assets/env/warped/"
const WC1_TILES := preload("res://assets/env/warped/wc1/tileset.png")
const WC2_TILES := preload("res://assets/env/warped/wc2/tileset.png")

## 64-tall facade columns from the Warped City 1 tileset.
const FACADE := {
	"window": Rect2(48, 16, 48, 64),
	"panel": Rect2(144, 16, 32, 64),
	"pipe": Rect2(192, 16, 16, 64),
	"shutter": Rect2(224, 16, 48, 64),
	"panel2": Rect2(288, 16, 32, 64),
	"shop": Rect2(224, 96, 48, 64),
	"door": Rect2(224, 176, 48, 64),
}
## Rooftop and street clutter from the same sheet.
const CLUTTER := {
	"ac": Rect2(160, 96, 48, 32),
	"fan": Rect2(176, 144, 32, 32),
	"lamp": Rect2(112, 100, 32, 60),
	"cables": Rect2(64, 96, 16, 48),
	"vent": Rect2(336, 16, 16, 16),
}
## Repeating 64 px walkway deck and a solid block, Warped City 2 tileset.
const DECK := Rect2(16, 16, 64, 41)
const BLOCK := Rect2(361, 16, 32, 96)

## Animated props: folder, file prefix, frame count.
const ANIMATED := {
	"banner-big": ["wc1/props/banner-big/", "banner-big-", 4],
	"banner-side": ["wc1/props/banner-side/", "banner-side-", 4],
	"banner-coke": ["wc1/props/banner-coke/", "banner-coke-", 3],
	"banner-neon": ["wc1/props/banner-neon/", "banner-neon-", 4],
	"banner-scroll": ["wc1/props/banner-scroll/", "banner-scroll-", 4],
	"banner-sushi": ["wc1/props/banner-sushi/", "banner-sushi-", 3],
	"monitor": ["wc1/props/monitorface/", "monitor-face-", 4],
	"banner-a": ["wc2/props/banner-a/", "banner-a", 4],
	"banner-b": ["wc2/props/banner-b/", "banner-b", 4],
	"banner-c": ["wc2/props/banner-c/", "banner-c", 4],
	"banner-d": ["wc2/props/banner-d/", "banner-d", 4],
	"banner-e": ["wc2/props/banner-e/", "banner-e", 4],
	"lights": ["wc2/props/lights/", "lights", 4],
}
## Static props: file in wc1/props.
const STATIC := ["antenna", "hotel-sign", "banners", "banner-open", "banner-small", "banner-arrow", "control-box-1", "control-box-3"]

static var _frames_cache := {}


static func piece(texture: Texture2D, region: Rect2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.region_rect = region
	sprite.centered = false
	return sprite


static func prop(prop_name: String) -> Node2D:
	if ANIMATED.has(prop_name):
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = _frames(prop_name)
		sprite.centered = false
		sprite.frame = randi() % sprite.sprite_frames.get_frame_count("default")
		sprite.play()
		return sprite
	var still := Sprite2D.new()
	still.texture = load(DIR + "wc1/props/" + prop_name + ".png")
	still.centered = false
	return still


static func prop_size(node: Node2D) -> Vector2:
	if node is AnimatedSprite2D:
		return node.sprite_frames.get_frame_texture("default", 0).get_size()
	var sprite := node as Sprite2D
	return sprite.region_rect.size if sprite.region_enabled else sprite.texture.get_size()


static func _frames(prop_name: String) -> SpriteFrames:
	if not _frames_cache.has(prop_name):
		var spec: Array = ANIMATED[prop_name]
		var frames := SpriteFrames.new()
		frames.set_animation_speed("default", 6.0)
		for i in range(1, spec[2] + 1):
			frames.add_frame("default", load("%s%s%s%d.png" % [DIR, spec[0], spec[1], i]))
		_frames_cache[prop_name] = frames
	return _frames_cache[prop_name]
