extends Node2D
## Street of buildings just behind the play area, assembled from Warped City
## facade pieces, with rooftop clutter and animated neon signs. Each sector
## has its own mix. Lives in a Parallax2D, so x is in that layer's space.

const FLOOR_Y := 328.0
const ROW_H := 64.0

## Per sector (same order as Sectors.LIST).
const STYLES := [
	{ # LOWER RING: shops and food signs
		"rows": [1, 3], "ground": ["shop", "door", "shop", "panel"], "upper": ["window", "window", "panel", "shutter"],
		"signs": ["banner-sushi", "banner-coke", "banner-neon", "banner-big", "hotel-sign", "banner-open"],
		"roof": ["antenna", "ac", "fan"],
	},
	{ # THE GRINDER: shuttered industry, machinery
		"rows": [1, 3], "ground": ["shutter", "panel2", "door", "panel"], "upper": ["panel", "pipe", "panel2", "shutter"],
		"signs": ["banner-arrow", "banner-scroll", "control-box-1", "control-box-3", "banners"],
		"roof": ["ac", "fan", "ac"],
	},
	{ # KILLBOX: security block, screens
		"rows": [2, 3], "ground": ["door", "panel", "shutter"], "upper": ["window", "panel", "panel2"],
		"signs": ["monitor", "monitor", "banner-side", "banner-neon"],
		"roof": ["antenna", "fan"],
	},
	{ # STILL SHRINE: low, quiet, lanterns
		"rows": [1, 2], "ground": ["shop", "panel", "door"], "upper": ["window", "panel"],
		"signs": ["lights", "banner-scroll", "banner-e"],
		"roof": ["antenna"],
	},
	{ # KURO'S THRONE: corporate towers, big billboards
		"rows": [2, 3], "ground": ["door", "panel2", "shutter"], "upper": ["window", "window", "panel2"],
		"signs": ["banner-a", "banner-b", "banner-c", "banner-d"],
		"roof": ["antenna", "ac"],
	},
]

var scroll_scale := 0.85
var level_w := 3200.0

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 42
	var span := (level_w - 640.0) * scroll_scale + 640.0
	var x := -16.0
	while x < span:
		var sector := Sectors.index_at(x / scroll_scale)
		x += _building(x, sector) + _rng.randf_range(12, 72)


## Builds one building at x and returns its width.
func _building(x0: float, sector: int) -> float:
	var style: Dictionary = STYLES[sector]
	var tint := Color(0.52, 0.52, 0.62).lerp(Sectors.LIST[sector].accent, 0.1)
	var rows: int = _rng.randi_range(style.rows[0], style.rows[1])
	var columns := _rng.randi_range(2, 4)
	var x := x0
	for c in columns:
		var width := 0.0
		for row in rows:
			var names: Array = style.ground if row == 0 else style.upper
			var region: Rect2 = Warped.FACADE[names[_rng.randi() % names.size()]]
			# Keep each column one width so rows stack cleanly.
			if row > 0:
				region = _match_width(names, width)
			var sprite := Warped.piece(Warped.WC1_TILES, region)
			sprite.position = Vector2(x, FLOOR_Y - ROW_H * (row + 1))
			sprite.modulate = tint
			add_child(sprite)
			if row == 0:
				width = region.size.x
		x += width
	var top := FLOOR_Y - ROW_H * rows
	var width_total := x - x0
	_roof(style, x0, width_total, top, tint)
	_signs(style, x0, width_total, top, rows)
	return width_total


## A piece from names with the given width, or any upper piece if none match.
func _match_width(names: Array, width: float) -> Rect2:
	var options: Array[Rect2] = []
	for piece_name: String in names:
		var region: Rect2 = Warped.FACADE[piece_name]
		if is_equal_approx(region.size.x, width):
			options.append(region)
	for piece_name: String in Warped.FACADE:
		var region: Rect2 = Warped.FACADE[piece_name]
		if options.is_empty() and is_equal_approx(region.size.x, width) and piece_name != "shop" and piece_name != "door":
			options.append(region)
	return options[_rng.randi() % options.size()] if not options.is_empty() else Warped.FACADE.panel


func _roof(style: Dictionary, x0: float, width: float, top: float, tint: Color) -> void:
	var count := _rng.randi_range(0, 2)
	for i in count:
		var item: String = style.roof[_rng.randi() % style.roof.size()]
		var node: Node2D
		if Warped.CLUTTER.has(item):
			node = Warped.piece(Warped.WC1_TILES, Warped.CLUTTER[item])
		else:
			node = Warped.prop(item)
		var size := Warped.prop_size(node)
		node.position = Vector2(x0 + _rng.randf_range(0, maxf(width - size.x, 0)), top - size.y)
		node.modulate = tint
		add_child(node)


func _signs(style: Dictionary, x0: float, width: float, top: float, rows: int) -> void:
	var count := _rng.randi_range(1, 2)
	for i in count:
		var sign_name: String = style.signs[_rng.randi() % style.signs.size()]
		var node := Warped.prop(sign_name)
		var size := Warped.prop_size(node)
		var on_side := _rng.randf() < 0.5
		var x := x0 - size.x * 0.5 if on_side else x0 + _rng.randf_range(0, maxf(width - size.x, 0))
		if on_side and _rng.randf() < 0.5:
			x = x0 + width - size.x * 0.5
		var y := _rng.randf_range(top + 6, FLOOR_Y - ROW_H * 0.5 - size.y) if rows > 1 else top - size.y
		node.position = Vector2(x, y).round()
		add_child(node)
