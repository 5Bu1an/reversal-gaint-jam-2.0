class_name MenuList
extends Control
## A vertical menu of buttons, sliders and toggles in the game's techno style
## (chamfered dark glass, neon edges, a pink marker on the selected row).
## Works with keys (W/S or arrows to move, A/D or arrows to adjust, Enter /
## Space / J to choose, Esc to go back) and the mouse (hover, click, drag).
## Hide it (visible = false) to stop it reacting.
##
##   menu.set_items([
##       {"id": "start", "label": "START"},
##       {"id": "music", "label": "MUSIC", "kind": "slider", "value": 0.7},
##       {"id": "full", "label": "FULLSCREEN", "kind": "toggle", "value": false},
##   ])
##   menu.chosen.connect(func(id): ...)      # a button was pressed
##   menu.changed.connect(func(id, value): ...)  # a slider or toggle moved
##   menu.back.connect(...)                  # Esc

signal chosen(id: String)
signal changed(id: String, value: Variant)
signal back

const CYAN := Color("#30e8ff")
const PINK := Color("#ff3d8b")
const GLASS := Color(0.04, 0.03, 0.08, 0.72)
const INK := Color("#eae6ff")
const ROW_H := 24.0
const CHAMFER := 7.0
const SLIDER_STEP := 0.1

var row_width := 170.0
var gap := 7.0
var selected := 0

var _items: Array[Dictionary] = []
var _press_t := 0.0
var _dragging := -1
var _font: Font
## The frame this menu last appeared on; the key press that opened it is
## ignored so it doesn't also act on the new menu.
var _shown_frame := -1


func _ready() -> void:
	_font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_ALL
	visibility_changed.connect(func() -> void: _shown_frame = Engine.get_process_frames())


func set_items(items: Array) -> void:
	_items.clear()
	for item: Dictionary in items:
		var copy := item.duplicate()
		copy.kind = copy.get("kind", "button")
		_items.append(copy)
	selected = clampi(selected, 0, _items.size() - 1)
	size = Vector2(row_width, _items.size() * (ROW_H + gap))
	queue_redraw()


func value_of(id: String) -> Variant:
	for item in _items:
		if item.id == id:
			return item.get("value")
	return null


func _process(delta: float) -> void:
	_press_t = maxf(_press_t - delta, 0.0)
	queue_redraw()
	if is_visible_in_tree() and not _items.is_empty():
		_poll_keys()


## Keys are polled rather than read from input events so the autopilot (which
## presses actions directly) can drive menus too.
func _poll_keys() -> void:
	if Engine.get_process_frames() <= _shown_frame + 1:
		return
	if Input.is_action_just_pressed("ui_cancel"):
		back.emit()
	elif Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("move_up"):
		_select(wrapi(selected - 1, 0, _items.size()))
	elif Input.is_action_just_pressed("ui_down") or Input.is_action_just_pressed("move_down"):
		_select(wrapi(selected + 1, 0, _items.size()))
	elif Input.is_action_just_pressed("ui_left") or Input.is_action_just_pressed("move_left"):
		_adjust(-1)
	elif Input.is_action_just_pressed("ui_right") or Input.is_action_just_pressed("move_right"):
		_adjust(1)
	elif Input.is_action_just_pressed("ui_accept") or (Input.is_action_just_pressed("attack")
			and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		_activate(selected)


func _row_rect(i: int) -> Rect2:
	return Rect2(0, i * (ROW_H + gap), row_width, ROW_H)


func _row_at(pos: Vector2) -> int:
	for i in _items.size():
		if _row_rect(i).has_point(pos):
			return i
	return -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var row := _row_at(event.position)
		if row >= 0 and row != selected:
			_select(row)
		if _dragging >= 0:
			_set_slider_from_mouse(_dragging, event.position.x)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var row := _row_at(event.position)
		if event.pressed and row >= 0:
			_select(row)
			if _items[row].kind == "slider":
				_dragging = row
				_set_slider_from_mouse(row, event.position.x)
			else:
				_activate(row)
			accept_event()
		elif not event.pressed:
			_dragging = -1


func _select(i: int) -> void:
	if i == selected:
		return
	selected = i
	Sfx.play("ui_move", -4.0, 0.0)


func _adjust(step: int) -> void:
	var item := _items[selected]
	match item.kind:
		"slider":
			_set_value(selected, clampf(snappedf(item.value + step * SLIDER_STEP, SLIDER_STEP), 0.0, 1.0))
		"toggle":
			_set_value(selected, not item.value)


func _activate(i: int) -> void:
	var item := _items[i]
	_press_t = 0.12
	match item.kind:
		"button":
			Sfx.play("ui_select", 0.0, 0.0)
			chosen.emit(item.id)
		"toggle":
			_set_value(i, not item.value)
		"slider":
			_set_value(i, 0.0 if item.value >= 1.0 else clampf(item.value + SLIDER_STEP, 0.0, 1.0))


func _set_slider_from_mouse(i: int, x: float) -> void:
	var track := _slider_track(_row_rect(i))
	_set_value(i, snappedf(clampf((x - track.position.x) / track.size.x, 0.0, 1.0), 0.05))


func _set_value(i: int, value: Variant) -> void:
	if _items[i].value == value:
		return
	_items[i].value = value
	Sfx.play("ui_move", -2.0, 0.0)
	changed.emit(_items[i].id, value)


func _slider_track(rect: Rect2) -> Rect2:
	return Rect2(rect.position.x + rect.size.x * 0.55, rect.get_center().y - 2, rect.size.x * 0.38, 4)


func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for i in _items.size():
		var item := _items[i]
		var rect := _row_rect(i)
		var on := i == selected
		var pressed := on and _press_t > 0.0
		var shape := chamfer(rect, CHAMFER)
		draw_colored_polygon(shape, Color(CYAN, 0.22) if pressed else (Color(0.1, 0.12, 0.2, 0.85) if on else GLASS))
		var edge := shape.duplicate()
		edge.append(shape[0])
		draw_polyline(edge, CYAN if on else Color(CYAN, 0.28), 1.0)
		if on:
			var pulse := 0.6 + 0.4 * sin(t * 6.0)
			draw_rect(Rect2(rect.position.x + 3, rect.position.y + 5, 3, rect.size.y - 10), Color(PINK, pulse))
			draw_polyline(edge, Color(CYAN, 0.18), 4.0)
		var label := " ".join(String(item.label).split(""))
		var color := INK if on else Color(INK, 0.6)
		if item.kind == "button":
			var jitter := Vector2(1, 0) if on and int(t * 12.0) % 17 == 0 else Vector2.ZERO
			if on:
				draw_string(_font, Vector2(rect.position.x + 1, rect.get_center().y + 4) + jitter, label,
					HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 10, Color(PINK, 0.6))
			draw_string(_font, Vector2(rect.position.x, rect.get_center().y + 4) - jitter, label,
				HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 10, color)
		else:
			draw_string(_font, Vector2(rect.position.x + 14, rect.get_center().y + 4), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 9, color)
			if item.kind == "slider":
				_draw_slider(rect, item.value, on)
			else:
				_draw_toggle(rect, item.value, on)


func _draw_slider(rect: Rect2, value: float, on: bool) -> void:
	var track := _slider_track(rect)
	draw_rect(track, Color(1, 1, 1, 0.12))
	draw_rect(Rect2(track.position, Vector2(track.size.x * value, track.size.y)), CYAN if on else Color(CYAN, 0.6))
	var knob := Vector2(track.position.x + track.size.x * value, track.get_center().y)
	draw_colored_polygon(diamond(knob, 5.0), PINK if on else INK)
	draw_string(_font, Vector2(track.end.x + 4, rect.get_center().y + 3), str(int(round(value * 100))),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(INK, 0.7))


func _draw_toggle(rect: Rect2, value: bool, on: bool) -> void:
	var box := Rect2(rect.end.x - 40, rect.get_center().y - 5, 26, 10)
	draw_colored_polygon(chamfer(box, 3.0), Color(CYAN, 0.35) if value else Color(1, 1, 1, 0.1))
	var knob := Rect2(box.position.x + (14 if value else 2), box.position.y + 2, 10, 6)
	draw_rect(knob, PINK if on else INK)
	draw_string(_font, Vector2(box.position.x - 26, rect.get_center().y + 3), "ON" if value else "OFF",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(INK, 0.7))


## Rectangle with its top-left and bottom-right corners cut off.
static func chamfer(rect: Rect2, cut: float) -> PackedVector2Array:
	return PackedVector2Array([
		rect.position + Vector2(cut, 0), Vector2(rect.end.x, rect.position.y),
		Vector2(rect.end.x, rect.end.y - cut), rect.end - Vector2(cut, 0),
		Vector2(rect.position.x, rect.end.y), rect.position + Vector2(0, cut),
	])


static func diamond(center: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([center + Vector2(0, -r), center + Vector2(r, 0), center + Vector2(0, r), center + Vector2(-r, 0)])


## A techno glass panel with corner brackets, for sub-screens.
static func draw_panel(canvas: CanvasItem, rect: Rect2, title: String) -> void:
	var shape := chamfer(rect, 12.0)
	canvas.draw_colored_polygon(shape, Color(0.03, 0.02, 0.07, 0.86))
	var edge := shape.duplicate()
	edge.append(shape[0])
	canvas.draw_polyline(edge, Color(CYAN, 0.35), 1.0)
	for corner: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var sx := 1.0 if corner.x == rect.position.x else -1.0
		var sy := 1.0 if corner.y == rect.position.y else -1.0
		canvas.draw_line(corner + Vector2(sx * 4, sy * 4), corner + Vector2(sx * 18, sy * 4), CYAN, 2.0)
		canvas.draw_line(corner + Vector2(sx * 4, sy * 4), corner + Vector2(sx * 4, sy * 18), CYAN, 2.0)
	if title != "":
		var font := ThemeDB.fallback_font
		var label := " ".join(title.split(""))
		canvas.draw_string(font, Vector2(rect.position.x, rect.position.y + 20), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 11, PINK)
		canvas.draw_line(Vector2(rect.get_center().x - 50, rect.position.y + 26), Vector2(rect.get_center().x + 50, rect.position.y + 26), Color(CYAN, 0.5), 1.0)
