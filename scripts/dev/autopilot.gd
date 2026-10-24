extends Node
## Autoload "Autopilot" for playtesting without a human. Does nothing unless
## the game is launched with user args, e.g.
##   godot --path . --fixed-fps 60 -- --autopilot=fight --shots=/tmp/shots
## It presses inputs on fixed physics frames, saves screenshots and prints a
## state line at each shot, then quits.

const PLANS := {
	"fight": [
		[10, "press", "move_right"], [40, "release", "move_right"],
		[66, "tap", "attack"], [86, "tap", "attack"], [106, "tap", "attack"],
		[115, "press", "move_left"], [130, "tap", "jump"], [160, "release", "move_left"],
		[165, "shot", "1_fight"],
		[166, "press", "rewind"], [196, "shot", "2_rewinding"], [226, "release", "rewind"],
		[236, "shot", "3_ghost"], [256, "shot", "4_ghost_late"],
		[300, "quit", ""],
	],
}

var _plan: Array = []
var _shots_dir := ""
var _frame := 0
var _taps: Array[String] = []


func _ready() -> void:
	process_physics_priority = -100
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--autopilot="):
			_plan = PLANS.get(arg.get_slice("=", 1), [])
		elif arg.begins_with("--shots="):
			_shots_dir = arg.get_slice("=", 1)
	set_physics_process(not _plan.is_empty())


func _physics_process(_delta: float) -> void:
	for action in _taps:
		Input.action_release(action)
	_taps.clear()
	for step in _plan:
		if step[0] != _frame:
			continue
		match step[1]:
			"press":
				Input.action_press(step[2])
			"release":
				Input.action_release(step[2])
			"tap":
				Input.action_press(step[2])
				_taps.append(step[2])
			"shot":
				_shot(step[2])
			"quit":
				get_tree().quit()
	_frame += 1


func _shot(shot_name: String) -> void:
	var player: Player = get_tree().get_first_node_in_group("player")
	var enemies := get_tree().get_nodes_in_group("enemies").map(func(e: Enemy) -> String:
		return "%d%s@%d" % [e.hp, "x" if e.dead else "", int(e.position.x)])
	print("[shot %s] frame=%d player=(%d,%d) hp=%d time=%d rewinding=%s ghosts=%d enemies=%s" % [
		shot_name, _frame, player.position.x, player.position.y, player.hp, Rewind.time_ms,
		Rewind.is_rewinding, get_tree().current_scene.get_node("Ghosts").get_child_count(), enemies,
	])
	if _shots_dir != "":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_shots_dir.path_join(shot_name + ".png"))
