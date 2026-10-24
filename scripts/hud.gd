extends Control
## Chrono vessel (painted orb + ms counter), oni-mask health, sector title
## cards, the boss intro card and bar, and state messages. Art comes from the
## painted UI pack (UiArt); reads the Game autoload.

const COLOR_TIME := Color("#05d9e8")
const COLOR_HP := Color("#ff2a6d")
const COLOR_DIM := Color(1, 1, 1, 0.15)
const COLOR_INK := Color("#0b0b14")

const VESSEL := Rect2(4, 2, 60, 60)
const MASK_ORIGIN := Vector2(78, 20)
const MASK_HEIGHT := 17.0
const MASK_STEP := 27.0
const CRACK_TIME := 0.35

const CARD_IN := 0.6
const CARD_HOLD := 2.2
const CARD_OUT := 0.9

var _vessel_fill := TextureRect.new()
var _vessel_frame := TextureRect.new()
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
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for rect: TextureRect in [_vessel_fill, _vessel_frame]:
		rect.position = VESSEL.position
		rect.size = VESSEL.size
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_SCALE
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rect)
	_vessel_fill.texture = UiArt.SOUL_FILL
	_vessel_fill.material = ShaderMaterial.new()
	_vessel_fill.material.shader = preload("res://shaders/vessel_fill.gdshader")
	_vessel_frame.texture = UiArt.SOUL_FRAME
	_crack_t.resize(Player.MAX_HP)
	_crack_t.fill(0.0)


func _process(delta: float) -> void:
	queue_redraw()
	var player: Player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	_vessel_fill.material.set_shader_parameter("fill", Rewind.time_ms / Rewind.MAX_MS)
	_vessel_fill.material.set_shader_parameter("rewinding", 1.0 if Rewind.is_rewinding else 0.0)

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
	_draw_time(font)
	_draw_masks(player)
	_draw_boss_bar(font)
	_draw_card(font)
	_draw_message(font, player)


func _draw_time(font: Font) -> void:
	var accent := Color.WHITE if Rewind.is_rewinding else COLOR_TIME
	var text_pos := Vector2(MASK_ORIGIN.x - 10, MASK_ORIGIN.y + 24)
	draw_string(font, text_pos + Vector2(1, 1), format_ms(Rewind.time_ms), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0, 0, 0, 0.7))
	draw_string(font, text_pos, format_ms(Rewind.time_ms), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, accent)
	if Rewind.is_rewinding and int(Time.get_ticks_msec() / 250) % 2 == 0:
		draw_string(font, text_pos + Vector2(62, 0), "<< REWIND", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)


## One painted oni mask per hit point. A lost mask flashes its cracked
## version, then goes dark; the last one pulses.
func _draw_masks(player: Player) -> void:
	var low := player.hp == 1 and not player.dead
	var pulse := 0.7 + 0.3 * sin(Time.get_ticks_msec() / 110.0) if low else 1.0
	for i in Player.MAX_HP:
		var center := MASK_ORIGIN + Vector2(i * MASK_STEP, 0)
		if i < player.hp:
			UiArt.draw_painted(self, UiArt.MASK_FULL, center, MASK_HEIGHT, Color(1, 1, 1, pulse))
		elif _crack_t[i] > 0.0:
			var k := _crack_t[i] / CRACK_TIME
			UiArt.draw_painted(self, UiArt.MASK_EMPTY, center, MASK_HEIGHT)
			UiArt.draw_painted(self, UiArt.MASK_DAMAGED, center, MASK_HEIGHT * (1.0 + (1.0 - k) * 0.3), Color(1, 1, 1, k))
		else:
			UiArt.draw_painted(self, UiArt.MASK_EMPTY, center, MASK_HEIGHT, Color(1, 1, 1, 0.75))


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
	if big:
		draw_rect(Rect2(0, y - 34, size.x, 62), Color(0, 0, 0, 0.45 * alpha))
	var top_y := y - 30 if big else y - 14
	draw_string(font, Vector2(0, top_y), spaced(_card.top), HORIZONTAL_ALIGNMENT_CENTER, size.x, 8, Color(accent, 0.8 * alpha))
	draw_string(font, Vector2(0, y + 6 + 1), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, title_size, Color(accent, 0.35 * alpha))
	draw_string(font, Vector2(0, y + 6), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, title_size, Color(1, 1, 1, alpha))
	var grow := clampf(t / CARD_IN, 0.0, 1.0)
	var divider_h := 18.0 if big else 14.0
	UiArt.draw_painted(self, UiArt.DIVIDER, Vector2(size.x / 2.0, y + 18), divider_h * (0.6 + 0.4 * grow), Color(1, 1, 1, alpha))


func _diamond(center: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([center + Vector2(0, -r), center + Vector2(r, 0), center + Vector2(0, r), center + Vector2(-r, 0)])


func _draw_message(font: Font, player: Player) -> void:
	var msg := ""
	match Game.state:
		Game.State.DOWN:
			msg = "SYSTEM FAILURE  -  hold REWIND or press JUMP to reboot"
		Game.State.GAME_OVER:
			msg = "SYSTEM FAILURE  -  press JUMP to reboot"
		Game.State.PAUSED:
			msg = "PAUSED  -  ESC to resume"
		Game.State.WON:
			msg = "TIMELINE SECURED  -  press JUMP to play again"
	if Game.god_mode:
		draw_string(font, Vector2(0, 16), "GOD MODE  (F1)   ", HORIZONTAL_ALIGNMENT_RIGHT, size.x, 9, Color(1, 0.85, 0.3))
	if msg != "":
		var color := COLOR_TIME if Game.state == Game.State.WON else COLOR_HP
		draw_rect(Rect2(0, 160, size.x, 30), Color(0, 0, 0, 0.6))
		UiArt.draw_painted(self, UiArt.HEADER, Vector2(size.x / 2.0, 150), 22.0)
		UiArt.draw_painted(self, UiArt.FOOTER, Vector2(size.x / 2.0, 200), 22.0)
		draw_string(font, Vector2(0, 180), msg, HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, color)


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
