extends Node
## Autoload "Settings". Player options, saved to user://settings.cfg and
## applied at startup: master / music / effects volume (on the Music and SFX
## buses), fullscreen, and whether the screen shakes.

const PATH := "user://settings.cfg"
const OPTIONS := ["master", "music", "sfx", "fullscreen", "shake"]

var master := 0.8
var music := 0.7
var sfx := 0.9
var fullscreen := false
var shake := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		for option in OPTIONS:
			set(option, config.get_value("options", option, get(option)))
	apply()


## Rows for a MenuList options screen (title and pause menus).
func menu_items() -> Array:
	return [
		{"id": "master", "label": "MASTER", "kind": "slider", "value": master},
		{"id": "music", "label": "MUSIC", "kind": "slider", "value": music},
		{"id": "sfx", "label": "EFFECTS", "kind": "slider", "value": sfx},
		{"id": "fullscreen", "label": "FULLSCREEN", "kind": "toggle", "value": fullscreen},
		{"id": "shake", "label": "SCREEN SHAKE", "kind": "toggle", "value": shake},
		{"id": "back", "label": "BACK"},
	]


func set_option(option: String, value: Variant) -> void:
	set(option, value)
	apply()
	var config := ConfigFile.new()
	for key in OPTIONS:
		config.set_value("options", key, get(key))
	config.save(PATH)


func apply() -> void:
	_set_volume("Master", master)
	_set_volume("Music", music)
	_set_volume("SFX", sfx)
	if not OS.has_feature("web"):
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)


func _set_volume(bus_name: String, value: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_mute(bus, value <= 0.001)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(value, 0.001)))
