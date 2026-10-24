class_name Hint
extends Node2D
## A quiet inscription in the world, like a lore tablet: pale sentence-case
## text that only shows when you stand right by it, and fades as you leave.

const NEAR := 50.0
const FAR := 100.0
const LINE_HEIGHT := 10.0
const COLOR := Color("#dcdcf0")

var lines: PackedStringArray = []


func setup(text_lines: PackedStringArray) -> Hint:
	lines = text_lines
	return self


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var player: Player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var dist := absf(player.position.x - position.x)
	var alpha := clampf(remap(dist, FAR, NEAR, 0.0, 1.0), 0.0, 1.0)
	if alpha <= 0.0:
		return
	var font := ThemeDB.fallback_font
	for i in lines.size():
		var color := Color(COLOR, alpha * (0.9 if i == 0 else 0.6))
		draw_string(font, Vector2(-120, i * LINE_HEIGHT), lines[i], HORIZONTAL_ALIGNMENT_CENTER, 240, 8, color)
