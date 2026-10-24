extends CanvasLayer
## Pause menu, shown while Game.state is PAUSED: resume, settings, quit to
## title. Esc steps back out of settings, or resumes from the main list.

const VIEW := Vector2(640, 360)

var _main := MenuList.new()
var _settings := MenuList.new()
var _backdrop := Control.new()


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.draw.connect(_draw_backdrop)
	add_child(_backdrop)

	_main.set_items([{"id": "resume", "label": "RESUME"}, {"id": "settings", "label": "SETTINGS"},
		{"id": "title", "label": "QUIT TO TITLE"}])
	_main.position = Vector2((VIEW.x - _main.row_width) / 2, 150)
	_main.chosen.connect(_on_main)
	_main.back.connect(_resume)
	add_child(_main)

	_settings.row_width = 260.0
	_settings.gap = 4.0
	_settings.position = Vector2((VIEW.x - _settings.row_width) / 2, 120)
	_settings.changed.connect(func(id: String, value: Variant) -> void: Settings.set_option(id, value))
	_settings.chosen.connect(func(_id: String) -> void: _show_settings(false))
	_settings.back.connect(func() -> void: _show_settings(false))
	add_child(_settings)
	_sync()


func _process(_delta: float) -> void:
	_sync()
	_backdrop.queue_redraw()


func _sync() -> void:
	var paused := Game.state == Game.State.PAUSED
	visible = paused
	if not paused:
		_main.visible = true
		_settings.visible = false
	_main.process_mode = Node.PROCESS_MODE_ALWAYS if paused and _main.visible else Node.PROCESS_MODE_DISABLED
	_settings.process_mode = Node.PROCESS_MODE_ALWAYS if paused and _settings.visible else Node.PROCESS_MODE_DISABLED


func _on_main(id: String) -> void:
	match id:
		"resume":
			_resume()
		"settings":
			_show_settings(true)
		"title":
			Game.quit_to_title()


func _resume() -> void:
	if Engine.get_process_frames() == Game.paused_frame:
		return # the Esc press that just opened the menu
	Game.set_paused(false)


func _show_settings(on: bool) -> void:
	_settings.set_items(Settings.menu_items())
	_settings.selected = 0
	_settings.visible = on
	_main.visible = not on


func _draw_backdrop() -> void:
	_backdrop.draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.02, 0.01, 0.05, 0.6))
	if _settings.visible:
		MenuList.draw_panel(_backdrop, Rect2(170, 90, 300, 210), "SETTINGS")
	else:
		MenuList.draw_panel(_backdrop, Rect2(210, 100, 220, 160), "PAUSED")
