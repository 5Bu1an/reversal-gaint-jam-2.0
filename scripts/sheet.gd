class_name Sheet
## Builds SpriteFrames from sprite sheets and caches them, so every enemy of a
## kind (and every one-shot effect) shares one set of frames.
##
##   Sheet.grid(path, Vector2i(96, 96), {"fly": [row, frames, fps, loop]})
##   Sheet.strips(Vector2i(200, 200), {"run": [path, frames, fps, loop]})
##   Sheet.effect("crescent_slash")   # a PVFX Foundry effect, 20 fps

## PVFX Foundry effects: 96 px cells in five columns, 20 fps, one shot.
const EFFECT_DIR := "res://assets/fx/pvfx/"
const EFFECT_FRAMES := {
	"crescent_slash": 10, "electric_impact": 14, "warm_explosion": 15, "arcane_parry": 16,
	"focus_charge": 14, "earth_rupture": 20, "landing_dust": 14, "void_implosion": 14,
	"spectral_bloom": 16, "rift_portal": 16, "smoke_puff": 14, "harvest_seal": 36,
}

static var _cache := {}


## One animation per row of a grid of equal cells.
static func grid(path: String, cell: Vector2i, rows: Dictionary) -> SpriteFrames:
	if _cache.has(path):
		return _cache[path]
	var texture: Texture2D = load(path)
	var frames := _new_frames()
	for anim: String in rows:
		var spec: Array = rows[anim]
		var row: int = spec[0]
		var first: int = spec[4] if spec.size() > 4 else 0
		_add(frames, anim, spec[2], spec[3])
		for i in range(first, first + int(spec[1])):
			frames.add_frame(anim, _cut(texture, Rect2(i * cell.x, row * cell.y, cell.x, cell.y)))
	_cache[path] = frames
	return frames


## One horizontal strip file per animation.
static func strips(cell: Vector2i, files: Dictionary) -> SpriteFrames:
	var key := str(files.values()[0][0])
	if _cache.has(key):
		return _cache[key]
	var frames := _new_frames()
	for anim: String in files:
		var spec: Array = files[anim]
		var texture: Texture2D = load(spec[0])
		_add(frames, anim, spec[2], spec[3])
		for i in int(spec[1]):
			frames.add_frame(anim, _cut(texture, Rect2(i * cell.x, 0, cell.x, cell.y)))
	_cache[key] = frames
	return frames


## A PVFX effect, read left to right, top to bottom, as the "play" animation.
static func effect(effect_name: String, loop := false) -> SpriteFrames:
	var key := effect_name + ("@loop" if loop else "")
	if _cache.has(key):
		return _cache[key]
	var texture: Texture2D = load(EFFECT_DIR + effect_name + ".png")
	var frames := _new_frames()
	_add(frames, "play", 20.0, loop)
	for i in int(EFFECT_FRAMES[effect_name]):
		frames.add_frame("play", _cut(texture, Rect2((i % 5) * 96, (i / 5) * 96, 96, 96)))
	_cache[key] = frames
	return frames


static func _new_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	return frames


static func _add(frames: SpriteFrames, anim: String, fps: float, loop: bool) -> void:
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, loop)


static func _cut(texture: Texture2D, region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = region
	return atlas
