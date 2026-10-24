extends Control
## Chrono vessel (time orb + ms counter), power cells, sector title cards, the
## boss intro card and bar, and state messages. Reads the Game autoload.

const COLOR_TIME := Color("#05d9e8")
const COLOR_HP := Color("#ff2a6d")
const COLOR_DIM := Color(1, 1, 1, 0.15)
const COLOR_INK := Color("#0b0b14")

const VESSEL := Rect2(12, 10, 44, 44)
const CELL_ORIGIN := Vector2(70, 24)
const CELL_RADIUS := 6.0
const CELL_STEP := 16.0
const CRACK_TIME := 0.35

const CARD_IN := 0.6
const CARD_HOLD := 2.2
const CARD_OUT := 0.9

var _vessel := ColorRect.new()
var _prev_hp := Player.MAX_HP
var _crack_t: Array[float] = []
var _zones_seen := {}
## Active title card: {"top", "title", "accent", "t", "big"} or empty.
var _card := {}
var _boss_card_shown := false


static func format_ms(ms: float) -> String:
	var digits := str(int(round(ms)))
	var grouped := ""
	while digits.length() > 3:
		grouped = "," + digits.right(3) + grouped
		digits = digits.left(digits.length() - 3)
	return digits + grouped + " ms"


## Letter-spaced caps for titles.
static func spaced(text: String) -> String:
	return " ".join(text.split(""))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vessel.position = VESSEL.position
	_vessel.size = VESSEL.size
	_vessel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vessel.material = ShaderMaterial.new()
	_vessel.material.shader = preload("res://shaders/chrono_vessel.gdshader")
	add_child(_vessel)
	_crack_t.resize(Player.MAX_HP)
	_crack_t.fill(0.0)


func _process(delta: float) -> void:
	queue_redraw()
	var player: Player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	_vessel.material.set_shader_parameter("fill", Rewind.time_ms / Rewind.MAX_MS)
	_vessel.material.set_shader_parameter("rewinding", 1.0 if Rewind.is_rewinding else 0.0)

	if player.hp < _prev_hp:
		for i in range(maxi(player.hp, 0), mini(_prev_hp, Player.MAX_HP)):
			_crack_t[i] = CRACK_TIME
	_prev_hp = player.hp
	for i in _crack_t.size():
		_crack_t[i] = maxf(_crack_t[i] - delta, 0.0)

	var zone := Sectors.index_at(player.position.x)
	if not _zones_seen.has(zone):
		_zones_seen[zone] = true
		var sector: Dictionary = Sectors.LIST[zone]
		_show_card(sector.code, sector.name, sector.accent, false)

	var boss := Game.boss
	if not _boss_card_shown and boss and is_instance_valid(boss) and not boss.dormant:
		_boss_card_shown = true
		_show_card("CEO OF CHRONOS CORP", Boss.NAME, COLOR_HP, true)

	if not _card.is_empty():
		_card.t += delta
		if _card.t > CARD_IN + CARD_HOLD + CARD_OUT:
			_card = {}


func _show_card(top: String, title: String, accent: Color, big: bool) -> void:
	_card = {"top": top, "title": title, "accent": accent, "t": 0.0, "big": big}


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var player: Player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	_draw_vessel_frame(font)
	_draw_cells(player)
	_draw_boss_bar(font)
	_draw_card(font)
	_draw_message(font, player)


func _draw_vessel_frame(font: Font) -> void:
	var center := VESSEL.get_center()
	var radius := VESSEL.size.x / 2.0
	var accent := Color.WHITE if Rewind.is_rewinding else COLOR_TIME
	# Clock ticks round the orb, and a hand that spins backwards on rewind.
	for i in 12:
		var a := TAU * i / 12.0
		var inner := radius + (3.0 if i % 3 == 0 else 4.5)
		draw_line(center + Vector2.from_angle(a) * inner, center + Vector2.from_angle(a) * (radius + 6.0), Color(accent, 0.6), 1.0)
	var spin := -Time.get_ticks_msec() / 90.0 if Rewind.is_rewinding else Time.get_ticks_msec() / 2000.0
	draw_line(center, center + Vector2.from_angle(spin - PI / 2) * (radius - 6.0), Color(1, 1, 1, 0.45), 1.0)
	# Horn-like flourish linking the orb to the cell row.
	draw_line(Vector2(VESSEL.end.x + 4, CELL_ORIGIN.y + 10), Vector2(CELL_ORIGIN.x + CELL_STEP * Player.MAX_HP, CELL_ORIGIN.y + 10), Color(accent, 0.35), 1.0)
	draw_string(font, Vector2(CELL_ORIGIN.x - 6, CELL_ORIGIN.y + 24), format_ms(Rewind.time_ms),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, accent)
	if Rewind.is_rewinding and int(Time.get_ticks_msec() / 250) % 2 == 0:
		draw_string(font, Vector2(CELL_ORIGIN.x + 54, CELL_ORIGIN.y + 24), "<< REWIND", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)


func _draw_cells(player: Player) -> void:
	var low := player.hp == 1 and not player.dead
	var pulse := 0.65 + 0.35 * sin(Time.get_ticks_msec() / 110.0) if low else 1.0
	for i in Player.MAX_HP:
		var center := CELL_ORIGIN + Vector2(i * CELL_STEP, 0)
		var hex := _hexagon(center, CELL_RADIUS)
		if i < player.hp:
			draw_colored_polygon(hex, Color(COLOR_HP, pulse))
			draw_colored_polygon(_hexagon(center + Vector2(-1, -1), CELL_RADIUS * 0.45), Color(1, 1, 1, 0.5 * pulse))
		else:
			draw_colored_polygon(hex, COLOR_INK)
		var outline := hex.duplicate()
		outline.append(hex[0])
		draw_polyline(outline, COLOR_HP if i < player.hp else COLOR_DIM, 1.0)
		if _crack_t[i] > 0.0:
			var k := _crack_t[i] / CRACK_TIME
			draw_polyline(_hexagon(center, CELL_RADIUS + (1.0 - k) * 8.0), Color(1, 1, 1, k), 1.0)
			draw_line(center + Vector2(-3, -4), center + Vector2(1, 0), Color(1, 1, 1, k), 1.0)
			draw_line(center + Vector2(1, 0), center + Vector2(-1, 4), Color(1, 1, 1, k), 1.0)


func _hexagon(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 6:
		points.append(center + Vector2.from_angle(TAU * i / 6.0 - PI / 2) * radius)
	return points


## Hollow Knight-style area title: small code line, large spaced name, thin
## rules with diamonds either side.
func _draw_card(font: Font) -> void:
	if _card.is_empty():
		return
	var t: float = _card.t
	var alpha := clampf(t / CARD_IN, 0.0, 1.0)
	if t > CARD_IN + CARD_HOLD:
		alpha = 1.0 - clampf((t - CARD_IN - CARD_HOLD) / CARD_OUT, 0.0, 1.0)
	var accent: Color = _card.accent
	var big: bool = _card.big
	var y := 150.0 if big else 96.0
	var title_size := 28 if big else 20
	var title := spaced(_card.title)
	var w := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	if big:
		draw_rect(Rect2(0, y - 34, size.x, 62), Color(0, 0, 0, 0.45 * alpha))
	var top_y := y - 30 if big else y - 14
	draw_string(font, Vector2(0, top_y), spaced(_card.top), HORIZONTAL_ALIGNMENT_CENTER, size.x, 8, Color(accent, 0.8 * alpha))
	draw_string(font, Vector2(0, y + 6 + 1), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, title_size, Color(accent, 0.35 * alpha))
	draw_string(font, Vector2(0, y + 6), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, title_size, Color(1, 1, 1, alpha))
	var half := w / 2.0 + 14.0
	var reach := 70.0 * clampf(t / CARD_IN, 0.0, 1.0)
	var cx := size.x / 2.0
	var line_y := y - 2 if big else y
	for side in [-1, 1]:
		var a := Vector2(cx + side * half, line_y - title_size * 0.3)
		var b := a + Vector2(side * reach, 0)
		draw_line(a, b, Color(accent, alpha), 1.0)
		draw_colored_polygon(_diamond(b, 3.0), Color(accent, alpha))


func _diamond(center: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([center + Vector2(0, -r), center + Vector2(r, 0), center + Vector2(0, r), center + Vector2(-r, 0)])


func _draw_message(font: Font, player: Player) -> void:
	var msg := ""
	match Game.state:
		Game.State.DOWN:
			msg = "SYSTEM FAILURE  -  hold REWIND"
		Game.State.GAME_OVER:
			msg = "SYSTEM FAILURE  -  press JUMP to reboot"
		Game.State.PAUSED:
			msg = "PAUSED  -  ESC to resume"
		Game.State.WON:
			msg = "TIMELINE SECURED  -  press JUMP to play again"
	if msg != "":
		var color := COLOR_TIME if Game.state == Game.State.WON else COLOR_HP
		draw_rect(Rect2(0, 160, size.x, 30), Color(0, 0, 0, 0.6))
		draw_line(Vector2(0, 160), Vector2(size.x, 160), Color(color, 0.6), 1.0)
		draw_line(Vector2(0, 190), Vector2(size.x, 190), Color(color, 0.6), 1.0)
		draw_string(font, Vector2(0, 180), msg, HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, color)
	elif Game.checkpoint == 0 and player.position.x < 600:
		draw_string(font, Vector2(16, 348), "A/D move  SPACE jump  J slash  K dash  hold L rewind  ESC pause",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, COLOR_DIM)


func _draw_boss_bar(font: Font) -> void:
	var boss := Game.boss
	if boss == null or not is_instance_valid(boss) or boss.dormant or boss.dead:
		return
	var bar := Rect2(170, 338, 300, 4)
	draw_string(font, Vector2(0, bar.position.y - 5), spaced(Boss.NAME), HORIZONTAL_ALIGNMENT_CENTER, size.x, 8, COLOR_HP)
	draw_rect(bar.grow(1), COLOR_INK)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(boss.hp) / boss.max_hp, bar.size.y)), COLOR_HP)
	draw_rect(bar.grow(1), Color(COLOR_HP, 0.5), false, 1.0)
	draw_colored_polygon(_diamond(Vector2(bar.position.x - 6, bar.get_center().y), 3.0), COLOR_HP)
	draw_colored_polygon(_diamond(Vector2(bar.end.x + 6, bar.get_center().y), 3.0), COLOR_HP)
