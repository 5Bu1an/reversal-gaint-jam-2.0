extends Control
## Time bar in milliseconds, health pips, boss bar and state messages.
## Placeholder look; the real UI can replace this using the Game autoload.

const COLOR_TIME := Color("#05d9e8")
const COLOR_HP := Color("#ff2a6d")
const COLOR_DIM := Color(1, 1, 1, 0.15)
const BAR := Rect2(16, 24, 160, 6)


static func format_ms(ms: float) -> String:
	var digits := str(int(round(ms)))
	var grouped := ""
	while digits.length() > 3:
		grouped = "," + digits.right(3) + grouped
		digits = digits.left(digits.length() - 3)
	return digits + grouped + " ms"


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var player: Player = get_tree().get_first_node_in_group("player")
	if player == null:
		return

	var fill := Rewind.time_ms / Rewind.MAX_MS
	draw_rect(BAR, COLOR_DIM)
	draw_rect(Rect2(BAR.position, Vector2(BAR.size.x * fill, BAR.size.y)), COLOR_TIME)
	var label_color := Color.WHITE if Rewind.is_rewinding else COLOR_TIME
	draw_string(font, Vector2(BAR.end.x + 8, BAR.end.y + 1), format_ms(Rewind.time_ms),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, label_color)
	if Rewind.is_rewinding:
		draw_string(font, Vector2(16, 18), "<< REWINDING", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)

	for i in Player.MAX_HP:
		var pip := Rect2(16 + i * 12, 38, 8, 8)
		draw_rect(pip, COLOR_HP if i < player.hp else COLOR_DIM)

	_draw_boss_bar(font)

	var msg := ""
	match Game.state:
		Game.State.DOWN:
			msg = "SYSTEM FAILURE - hold REWIND or press JUMP to reboot"
		Game.State.GAME_OVER:
			msg = "SYSTEM FAILURE - press JUMP to reboot"
		Game.State.PAUSED:
			msg = "PAUSED - ESC to resume"
		Game.State.WON:
			msg = "TIMELINE SECURED - press JUMP to play again"
	if msg != "":
		var color := COLOR_TIME if Game.state == Game.State.WON else COLOR_HP
		draw_rect(Rect2(0, 160, size.x, 30), Color(0, 0, 0, 0.6))
		draw_string(font, Vector2(0, 180), msg, HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, color)
	elif Game.checkpoint == 0 and player.position.x < 600:
		draw_string(font, Vector2(16, 348), "A/D move  SPACE jump  J slash  K dash  hold L rewind  ESC pause",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, COLOR_DIM)


func _draw_boss_bar(font: Font) -> void:
	var boss := Game.boss
	if boss == null or not is_instance_valid(boss) or boss.dormant or boss.dead:
		return
	var bar := Rect2(170, 336, 300, 5)
	draw_string(font, Vector2(bar.position.x, bar.position.y - 4), Boss.NAME,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, COLOR_HP)
	draw_rect(bar, COLOR_DIM)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(boss.hp) / boss.max_hp, bar.size.y)), COLOR_HP)
