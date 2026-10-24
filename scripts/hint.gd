class_name Hint
extends Node2D
## Tutorial sign painted into the world. Fades in as the player gets close
## and stays dim otherwise, so it never clutters the screen.

const NEAR := 90.0
const FAR := 220.0
const LINE_HEIGHT := 11.0
const COLOR := Color("#05d9e8")

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
	var alpha := clampf(remap(dist, FAR, NEAR, 0.12, 1.0), 0.12, 1.0)
	var font := ThemeDB.fallback_font
	for i in lines.size():
		var size := 9 if i == 0 else 7
		var color := COLOR if i == 0 else Color.WHITE
		draw_string(font, Vector2(-100, i * LINE_HEIGHT), lines[i], HORIZONTAL_ALIGNMENT_CENTER, 200, size,
			Color(color, alpha * (1.0 if i == 0 else 0.7)))
