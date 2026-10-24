class_name UiArt
## The painted Edo-cyberpunk UI pack in assets/ui. Textures are large paintings
## on transparent canvases; draw_painted() draws only the painted part so
## layouts don't have to account for the empty margins.

const SOUL_FRAME := preload("res://assets/ui/hud/soul-frame.png")
const SOUL_FILL := preload("res://assets/ui/hud/soul-fill.png")
const MASK_FULL := preload("res://assets/ui/hud/health-full.png")
const MASK_DAMAGED := preload("res://assets/ui/hud/health-damaged.png")
const MASK_EMPTY := preload("res://assets/ui/hud/health-empty.png")
const BUTTON := preload("res://assets/ui/buttons/normal.png")
const BUTTON_HOVER := preload("res://assets/ui/buttons/hover.png")
const BUTTON_PRESSED := preload("res://assets/ui/buttons/pressed.png")
const HEADER := preload("res://assets/ui/ornaments/header.png")
const FOOTER := preload("res://assets/ui/ornaments/footer.png")
const DIVIDER := preload("res://assets/ui/ornaments/divider.png")
const MODAL := preload("res://assets/ui/panels/modal.png")
const MENU_BACKGROUND := preload("res://assets/ui/artwork/menu-background.png")

const INK := Color("#e8dcc0") # ivory, matches the carved inlay

static var _painted_cache := {}


## The non-transparent part of a texture, cached.
static func painted_rect(texture: Texture2D) -> Rect2:
	if not _painted_cache.has(texture):
		_painted_cache[texture] = Rect2(texture.get_image().get_used_rect())
	return _painted_cache[texture]


## Draws the painted part of texture at height h, centred on center,
## preserving its aspect ratio. Returns the rect it drew into.
static func draw_painted(canvas: CanvasItem, texture: Texture2D, center: Vector2, h: float, modulate := Color.WHITE) -> Rect2:
	var src := painted_rect(texture)
	var size := Vector2(src.size.x / src.size.y * h, h)
	var dest := Rect2(center - size / 2.0, size)
	canvas.draw_texture_rect_region(texture, dest, src, modulate)
	return dest
