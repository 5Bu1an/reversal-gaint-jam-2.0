extends Node
## Autoload "Autopilot" for playtesting without a human. Does nothing unless
## the game is launched with user args, e.g.
##   godot --path . --fixed-fps 60 -- --autopilot=fight --shots=/tmp/shots
## It presses inputs on fixed physics frames, saves screenshots and prints a
## state line at each shot, then quits. --checkpoint=1 starts at the shrine.
## Plans: fight, arena (waves, rewind undo, gates), boss, win, retrace,
## inverted (only the ghost can hurt inverted enemies), boss2 (enraged boss
## flipping between normal and inverted; use with --checkpoint=1).

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
	process_mode = Node.PROCESS_MODE_ALWAYS # keep going on the pause/win screens
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--autopilot="):
			_plan = _make_plan(arg.get_slice("=", 1))
		elif arg.begins_with("--shots="):
			_shots_dir = arg.get_slice("=", 1)
		elif arg.begins_with("--checkpoint="):
			Game.checkpoint = int(arg.get_slice("=", 1))
	set_physics_process(not _plan.is_empty())


func _make_plan(plan_name: String) -> Array:
	if PLANS.has(plan_name):
		return PLANS[plan_name]
	var plan: Array = []
	match plan_name:
		"arena":
			plan = [[1, "god", ""], [1, "warp", 1300], [5, "press", "move_right"], [30, "release", "move_right"],
				[40, "shot", "1_locked"], [80, "shot", "2_wave1"],
				[100, "press", "rewind"], [195, "release", "rewind"], [197, "shot", "3_rewound"],
				[200, "press", "move_right"], [220, "release", "move_right"],
				[240, "kill_active", ""], [290, "kill_active", ""], [292, "shot", "4_wave3"],
				[340, "kill_active", ""], [380, "shot", "5_cleared"],
				[390, "press", "move_right"], [640, "shot", "6_past_gate"], [650, "quit", ""]]
		"boss":
			plan = [[1, "god", ""], [5, "press", "move_right"], [290, "release", "move_right"],
				[292, "shot", "1_boss_intro"]]
			for f in range(300, 690, 20):
				plan.append([f, "face_boss", ""])
				plan.append([f + 1, "tap", "attack"])
			plan += [[420, "shot", "2_boss_mid"], [600, "shot", "3_boss_late"],
				[700, "press", "rewind"], [740, "shot", "4_boss_rewind"], [760, "release", "rewind"],
				[766, "shot", "5_boss_ghost"], [900, "quit", ""]]
		"moves":
			plan = [[1, "god", ""], [20, "shot", "1_idle"],
				[30, "press", "move_right"], [40, "shot", "2_run"], [50, "release", "move_right"],
				[60, "press", "jump"], [66, "shot", "3_jump"], [75, "release", "jump"], [88, "shot", "4_fall"],
				[110, "tap", "dash"], [113, "shot", "5_dash"],
				[140, "tap", "attack"], [143, "shot", "6_slash"],
				[170, "press", "move_up"], [171, "tap", "attack"], [174, "shot", "7_slash_up"], [180, "release", "move_up"],
				[200, "press", "jump"], [214, "release", "jump"], [216, "press", "move_down"], [217, "tap", "attack"],
				[220, "shot", "8_slash_down"], [226, "release", "move_down"], [260, "quit", ""]]
		"tour":
			plan = [[1, "god", ""]]
			var stops := [[300, "1_lower_ring"], [930, "2_grinder"], [1580, "3_killbox"], [2240, "4_shrine"], [2900, "5_throne"]]
			for i in stops.size():
				plan.append([10 + i * 60, "warp", stops[i][0]])
				plan.append([55 + i * 60, "shot", stops[i][1]])
			plan.append([10 + stops.size() * 60, "quit", ""])
		"title":
			plan = [[40, "shot", "1_title"], [50, "tap", "move_down"], [60, "tap", "jump"], [80, "shot", "2_controls"],
				[90, "tap", "jump"], [100, "tap", "move_up"], [110, "tap", "jump"], [150, "shot", "3_level"],
				[200, "quit", ""]]
		"retrace":
			# Run, jump and slash for 2 s, then hold rewind for 1 s; the trace
			# while rewinding should mirror the forward trace frame for frame.
			plan = [[5, "press", "move_right"], [40, "tap", "jump"], [70, "tap", "attack"],
				[90, "release", "move_right"], [91, "press", "move_left"], [125, "release", "move_left"],
				[125, "press", "rewind"], [185, "release", "rewind"], [200, "quit", ""]]
			for f in range(65, 186, 5):
				plan.append([f, "trace", ""])
		"inverted":
			# Slash the intro's inverted grunt (should bounce off), then rewind
			# so the ghost replays those slashes (should land).
			plan = [[1, "god", ""], [1, "warp", 500], [80, "press", "rewind"], [150, "release", "rewind"],
				[152, "shot", "2_ghost"], [260, "quit", ""]]
			for f in [30, 50, 70]:
				plan.append([f, "tap", "attack"])
			for f in [29, 76, 152, 200, 255]:
				plan.append([f, "trace", ""])
			plan.append([76, "shot", "1_deflected"])
		"boss2":
			plan = [[1, "god", ""], [5, "press", "move_right"], [290, "release", "move_right"],
				[291, "boss_half", ""], [700, "quit", ""]]
			for f in range(300, 690, 20):
				plan.append([f, "face_boss", ""])
				plan.append([f + 1, "tap", "attack"])
			for f in range(300, 700, 30):
				plan.append([f, "boss_trace", ""])
			plan.append([420, "shot", "boss2"])
		"win":
			plan = [[1, "god", ""], [5, "press", "move_right"], [260, "kill_boss", ""],
				[300, "shot", "1_portal_open"], [600, "shot", "2_won"], [620, "quit", ""]]
	return plan


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
			"god":
				get_tree().get_first_node_in_group("player").hp = 999
			"trace":
				var p: Player = get_tree().get_first_node_in_group("player")
				var inverted := get_tree().get_nodes_in_group("enemies").filter(func(e: Enemy) -> bool:
					return e.inverted and not e.dormant).map(func(e: Enemy) -> String:
					return "%d@%d" % [e.hp, int(e.position.x)])
				print("[trace] frame=%d rewinding=%s pos=(%.1f,%.1f) facing=%d attack_t=%.2f inverted=%s" % [
					_frame, Rewind.is_rewinding, p.position.x, p.position.y, p.facing, p.attack_t, inverted])
			"warp":
				get_tree().get_first_node_in_group("player").position.x = step[2]
			"face_boss":
				var player: Player = get_tree().get_first_node_in_group("player")
				player.facing = 1 if Game.boss.position.x > player.position.x else -1
			"kill_active":
				for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
					if enemy.is_active():
						enemy.hp = 0
						enemy.dead = true
			"boss_half":
				Game.boss.hp = Game.boss.max_hp / 2
			"boss_trace":
				print("[boss] frame=%d hp=%d inverted=%s invert_t=%.1f mode=%s" % [_frame, Game.boss.hp,
					Game.boss.inverted, Game.boss.invert_t, Boss.Mode.keys()[Game.boss.mode]])
			"kill_boss":
				Game.boss.hp = 0
				Game.boss.dead = true
	_frame += 1


func _shot(shot_name: String) -> void:
	var player: Player = get_tree().get_first_node_in_group("player")
	if player == null:
		print("[shot %s] frame=%d state=%s scene=%s" % [shot_name, _frame, Game.State.keys()[Game.state], get_tree().current_scene.name])
		await _save_shot(shot_name)
		return
	var alive := get_tree().get_nodes_in_group("enemies").filter(func(e: Enemy) -> bool:
		return e.is_active())
	var boss := Game.boss
	var arenas := get_tree().get_nodes_in_group("rewindable").filter(func(n: Node) -> bool: return n is Arena).map(
		func(a: Arena) -> String: return "%s/%d" % [Arena.Phase.keys()[a.phase], a.wave])
	print("[shot %s] frame=%d state=%s player=(%d,%d) hp=%d time=%d rewinding=%s ghosts=%d alive=%d boss=%d%s arenas=%s" % [
		shot_name, _frame, Game.State.keys()[Game.state], player.position.x, player.position.y, player.hp,
		Rewind.time_ms, Rewind.is_rewinding, get_tree().current_scene.get_node("Ghosts").get_child_count(),
		alive.size(), boss.hp, "x" if boss.dead else "", arenas,
	])
	await _save_shot(shot_name)


func _save_shot(shot_name: String) -> void:
	if _shots_dir != "":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_shots_dir.path_join(shot_name + ".png"))
