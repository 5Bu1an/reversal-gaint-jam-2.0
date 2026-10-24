extends Control
## End-of-run panel shown by Game.win(): time, deaths, rewinds and a rank.
## Placeholder look; reads everything from Game.stats.

const COLOR_TIME := Color("#05d9e8")
const COLOR_GOLD := Color("#f5c542")
## Sits under the HUD's win banner, which also says how to play again.
const PANEL := Rect2(200, 200, 240, 120)


static func format_time(seconds: float) -> String:
	var ms := int(seconds * 1000.0) % 1000
	var s := int(seconds) % 60
	var m := int(seconds) / 60
	return "%d:%02d.%03d" % [m, s, ms]


static func rank(stats: Dictionary) -> String:
	if stats.deaths == 0 and stats.time < 240.0:
		return "S"
	if stats.deaths <= 1 and stats.time < 360.0:
		return "A"
	if stats.time < 600.0:
		return "B"
	return "C"


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var stats := Game.stats
	draw_rect(PANEL, Color(0.02, 0.02, 0.05, 0.92))
	draw_rect(PANEL, COLOR_TIME, false, 1.0)
	var x := PANEL.position.x + 16
	var y := PANEL.position.y + 22
	draw_string(font, Vector2(x, y), "RUN COMPLETE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COLOR_TIME)
	var rows := [
		["TIME", format_time(stats.time)],
		["DEATHS", str(stats.deaths)],
		["REWINDS", str(stats.rewinds)],
		["TIME UNDONE", "%.1f s" % (stats.rewound_ms / 1000.0)],
	]
	for row: Array in rows:
		y += 18
		draw_string(font, Vector2(x, y), row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1, 0.6))
		draw_string(font, Vector2(x + 90, y), row[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)
	draw_string(font, Vector2(PANEL.end.x - 60, PANEL.position.y + 70), rank(stats),
		HORIZONTAL_ALIGNMENT_CENTER, 44, 36, COLOR_GOLD)
