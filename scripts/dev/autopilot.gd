extends Node
## Autoload "Autopilot" for playtesting without a human. Does nothing unless
## the game is launched with user args, e.g.
##   godot --path . --fixed-fps 60 -- --autopilot=fight --shots=/tmp/shots
## It presses inputs on fixed physics frames, saves screenshots and prints a
## state line at each shot, then quits. --checkpoint=1 starts at the shrine.
## Plans: fight, arena (waves, rewind undo, gates), boss, win, retrace,
## inverted (only the ghost can hurt inverted enemies), boss2 (enraged boss
## flipping between normal and inverted; use with --checkpoint=1), reversal
## (burst the boss until it rewinds itself; --checkpoint=1), thorns (a full
## jump in the tunnel hits the thorny ceiling: 1 HP and back to safe ground;
## at 1 HP it's a real death),
## shade (die with time left, collect it after the reload; die again first
## and it's replaced), echo (charged slash: the swing bounces off an inverted
## grunt, its echo lands), pogo (down-slash bounce still works), wall (climb
## the shrine chimney by wall-jumping and grab its shard), showcase (a guided
## tour of every feature with captions; run it without --fixed-fps to watch
## at normal speed, and it stays open at the end).

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
var _caption := Label.new()


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
	# Autoloads survive scene reloads, so the caption stays up through them.
	var layer := CanvasLayer.new()
	layer.layer = 30
	_caption.position = Vector2(0, 52)
	_caption.size = Vector2(640, 40)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size", 10)
	_caption.add_theme_color_override("font_outline_color", Color.BLACK)
	_caption.add_theme_constant_override("outline_size", 4)
	layer.add_child(_caption)
	add_child(layer)


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
			plan = [[1, "god", ""], [280, "warp", 2680], [292, "shot", "1_boss_intro"]]
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
			plan = [[1, "god", ""], [280, "warp", 2680], [291, "boss_half", ""], [700, "quit", ""]]
			for f in range(300, 690, 20):
				plan.append([f, "face_boss", ""])
				plan.append([f + 1, "tap", "attack"])
			for f in range(300, 700, 30):
				plan.append([f, "boss_trace", ""])
			plan.append([420, "shot", "boss2"])
		"reversal":
			# Burst 4 damage, let it rewind; burst again and interrupt the second
			# reversal with a (fake) ghost hit.
			plan = [[1, "god", ""], [280, "warp", 2680],
				[500, "burst_boss", 4], [530, "shot", "1_reversing"],
				[700, "burst_boss", 4], [720, "ghost_hit_boss", ""], [800, "quit", ""]]
			for f in range(480, 800, 10):
				plan.append([f, "boss_trace", ""])
		"thorns":
			# Full jump into the tunnel ceiling twice (second time at 1 HP), plus
			# a short hop in between that must stay clear of the thorns.
			plan = [[1, "warp", 760], [10, "press", "jump"], [30, "release", "jump"], [45, "shot", "1_hit"],
				[80, "tap", "jump"], [100, "set_hp", 1], [110, "press", "jump"], [130, "release", "jump"],
				[150, "shot", "2_dead"], [160, "quit", ""]]
			for f in [9, 20, 40, 79, 84, 99, 140]:
				plan.append([f, "trace", ""])
		"shade":
			# Die at x=600 with time on the bar, reboot, warp back and slash the
			# shade to collect it; then die again to leave a new one.
			plan = [[1, "warp", 600], [3, "set_hp", 1], [4, "spike_self", ""], [30, "shade_trace", ""],
				[40, "tap", "jump"], [45, "shade_trace", ""]]
			# The scene reloads at 40 and Autopilot keeps counting frames.
			plan += [[50, "shade_trace", ""], [51, "warp", 570], [60, "shot", "1_at_shade"],
				[62, "tap", "attack"], [80, "shade_trace", ""]]
			# A second death before collecting replaces the shade.
			plan += [[310, "shade_trace", ""], [315, "warp", 760], [320, "set_hp", 1], [321, "spike_self", ""],
				[340, "tap", "jump"], [350, "shade_trace", ""], [360, "quit", ""]]
		"echo":
			# Timed so the inverted grunt walks into range just as the echo lands.
			# Grunts now notice and charge you, so hold this one in range.
			plan = [[1, "god", ""], [1, "stage_inverted", 470], [15, "press", "attack"], [55, "shot", "1_charged"],
				[60, "release", "attack"], [75, "shot", "2_echo_waiting"], [91, "shot", "3_echo_hit"], [120, "quit", ""]]
			for f in [14, 59, 61, 89, 92, 118]:
				plan.append([f, "trace", ""])
		"pogo":
			plan = [[1, "god", ""], [1, "warp_xy", Vector2(99, 230)], [2, "press", "move_down"],
				[8, "tap", "attack"], [40, "release", "move_down"], [60, "quit", ""]]
			for f in range(4, 40, 3):
				plan.append([f, "trace", ""])
		"wall":
			plan = [[1, "god", ""], [1, "warp_xy", Vector2(2220, 268)], [3, "press", "move_left"],
				[5, "press", "jump"], [15, "release", "jump"]]
			var dirs := ["move_right", "move_left"]
			for k in 9:
				var f := 30 + k * 22
				plan += [[f, "release", dirs[(k + 1) % 2]], [f, "press", dirs[k % 2]], [f, "press", "jump"],
					[f + 12, "release", "jump"]]
			plan += [[200, "release", "move_left"], [200, "release", "move_right"], [235, "quit", ""],
				[90, "shot", "1_climbing"]]
			for f in range(4, 235, 8):
				plan.append([f, "wall_trace", ""])
		"wall_dash":
			# Air-dash into the chimney wall: the cling should give the dash back.
			plan = [[1, "god", ""], [1, "warp_xy", Vector2(2220, 268)], [3, "press", "move_left"],
				[5, "press", "jump"], [8, "tap", "dash"], [15, "release", "jump"], [40, "quit", ""]]
			for f in [7, 10, 14, 18, 24, 30]:
				plan.append([f, "wall_trace", ""])
		"showcase":
			plan = _showcase()
		"overview":
			# One screenshot per screen of the level, for checking the layout.
			plan = [[1, "god", ""]]
			for i in 10:
				plan += [[1 + i * 50, "warp_xy", Vector2(160 + i * 320, 200)], [40 + i * 50, "shot", "screen_%02d" % i]]
			plan.append([510, "quit", ""])
		"husk":
			# Stand near the first grunt: it should notice, wind up, charge, recover.
			plan = [[1, "god", ""], [1, "warp_xy", Vector2(170, 316)], [200, "quit", ""]]
			for f in range(2, 200, 8):
				plan.append([f, "grunt_trace", ""])
		"zoomtest":
			# --zoom=N previews a closer camera at a few spots.
			plan = [[1, "god", ""], [2, "zoom", ""]]
			var spots := [Vector2(480, 316), Vector2(1100, 316), Vector2(1600, 316), Vector2(2220, 120), Vector2(2800, 316)]
			for i in spots.size():
				plan += [[5 + i * 60, "warp_xy", spots[i]], [50 + i * 60, "shot", "zoom_%d" % i]]
			plan.append([5 + spots.size() * 60, "quit", ""])
		"arts":
			# Dash Slash into a held grunt (3 -> 1), then a Cyclone Slash on a
			# fresh one right beside you (3 hits: 3 -> dead).
			plan = [[1, "god", ""], [1, "warp_xy", Vector2(40, 316)], [2, "stage_grunt", Vector2(140, 316)],
				[5, "press", "attack"], [50, "tap", "dash"], [60, "release", "attack"],
				[80, "warp_xy", Vector2(40, 316)], [81, "stage_grunt", Vector2(70, 316)],
				[85, "press", "attack"], [120, "press", "move_up"], [125, "stage_grunt", Vector2(66, 316)],
				[131, "release", "attack"],
				[140, "release", "move_up"], [180, "quit", ""], [134, "shot", "cyclone"], [53, "shot", "dash_slash"]]
			for f in [49, 70, 130, 141, 165]:
				plan.append([f, "grunt_trace", ""])
		"parry":
			# A held grunt is released to charge you; slash just before it
			# connects. --tap=N picks the frame of the slash.
			var tap := 47
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--tap="):
					tap = int(arg.get_slice("=", 1))
			plan = [[1, "warp_xy", Vector2(40, 316)], [2, "stage_grunt", Vector2(100, 316)],
				[3, "grunt_speed", 40.0], [tap, "tap", "attack"], [90, "quit", ""]]
			for f in range(40, 90, 4):
				plan.append([f, "parry_trace", ""])
		"reflect":
			# Boss arena: a shockwave is sent at you; slash it back into the boss.
			plan = [[1, "god", ""], [1, "warp", 2680], [60, "boss_wave", 80.0], [76, "tap", "attack"],
				[260, "quit", ""]]
			for f in range(58, 260, 12):
				plan.append([f, "reflect_trace", ""])
		"win":
			plan = [[1, "god", ""], [250, "warp", 2680], [255, "press", "move_right"], [260, "kill_boss", ""],
				[300, "shot", "1_portal_open"], [600, "shot", "2_won"], [620, "quit", ""]]
	return plan


## Every feature in one run, ~35 s. Uses god mode and warps between sections
## so the scripted inputs always land.
func _showcase() -> Array:
	# Only grow this array in place: the say() closure holds on to it.
	var plan: Array = [[1, "god", ""]]
	var say := func(f: int, text: String) -> void: plan.append([f, "caption", text])

	say.call(2, "1/10  SLASH, RUN, JUMP  (J, A/D, hold Space)")
	for f in [20, 40, 60, 80]:
		plan.append([f, "tap", "attack"])
	plan.append_array([[90, "press", "move_right"], [98, "press", "jump"], [112, "release", "jump"],
		[124, "press", "jump"], [138, "release", "jump"], [150, "release", "move_right"]])

	say.call(150, "2/10  HOLD L: REWIND TIME\nthe timeline you undo keeps fighting as a red ghost")
	plan.append_array([[160, "press", "rewind"], [220, "release", "rewind"]])

	say.call(320, "3/10  PURPLE = INVERTED: your slashes bounce off")
	plan.append_array([[324, "clear_near", ""], [325, "stage_inverted", 470], [335, "tap", "attack"], [360, "tap", "attack"]])
	say.call(385, "ECHO SLASH: hold J, release\nthe echo strikes again a moment later, as a ghost - and it lands")
	plan.append_array([[390, "press", "attack"], [432, "release", "attack"], [500, "unstage_inverted", ""]])

	say.call(510, "6/10  THORNS: lose 1 HP, back to the last safe ground")
	plan.append_array([[512, "warp", 760], [520, "press", "jump"], [540, "release", "jump"]])
	say.call(570, "tap jump for a short hop under them")
	plan.append_array([[575, "tap", "jump"], [590, "tap", "jump"]])

	say.call(610, "7/10  POGO: S + J in the air to bounce off enemies")
	plan.append_array([[612, "stage_pogo", Vector2(600, 316)], [613, "warp_xy", Vector2(600, 220)],
		[614, "press", "move_down"], [624, "tap", "attack"], [662, "tap", "attack"], [700, "release", "move_down"]])

	say.call(720, "8/10  WALL CLING + WALL JUMP\nhold toward a wall, Jump to kick off - a shard waits up the chimney")
	var w := 725
	plan.append_array([[w - 6, "release", "move_down"], [w, "warp_xy", Vector2(2220, 268)], [w + 4, "press", "jump"],
		[w + 6, "press", "move_left"], [w + 16, "release", "jump"]])
	var dirs := ["move_right", "move_left"]
	for k in 7:
		var f := w + 30 + k * 22
		plan.append_array([[f, "release", dirs[(k + 1) % 2]], [f, "press", dirs[k % 2]], [f, "press", "jump"],
			[f + 12, "release", "jump"]])
	plan.append_array([[w + 200, "release", "move_left"], [w + 200, "release", "move_right"]])

	say.call(990, "9/10  DEATH SHADE: die, and your time stays behind")
	plan.append_array([[992, "warp_xy", Vector2(2310, 316)], [993, "clear_near", ""], [995, "set_hp", 1], [1010, "spike_self", ""],
		[1050, "tap", "jump"], [1060, "god", ""]])
	say.call(1062, "reboot at the shrine... slash your shade to take the time back")
	plan.append_array([[1070, "warp", 2282], [1071, "clear_near", ""], [1075, "press", "move_right"],
		[1080, "release", "move_right"], [1110, "tap", "attack"], [1130, "tap", "attack"]])

	say.call(1240, "10/10  BOSS: THE KURO SHOGUN")
	plan.append([1242, "warp", 2680])
	say.call(1275, "parry a quake and it rolls back into the Shogun")
	plan.append_array([[1280, "boss_wave", 80.0], [1296, "tap", "attack"], [1300, "reflect_trace", ""],
		[1380, "reflect_trace", ""]])
	for f in range(1330, 1640, 20):
		plan.append_array([[f, "face_boss", ""], [f + 1, "tap", "attack"]])
	# It needs 2 s of its own history before it can rewind.
	say.call(1415, "hit it too fast and it REWINDS ITSELF\nonly a ghost hit can interrupt it")
	plan.append([1420, "burst_boss", 4])
	say.call(1515, "below half health it turns INVERTED - only ghost hits land")
	plan.append([1520, "boss_half", ""])
	say.call(1650, "beat it, step into the portal...")
	plan.append_array([[1655, "kill_boss", ""], [1660, "warp", 3060], [1665, "press", "move_right"],
		[1720, "release", "move_right"]])
	say.call(1725, "...and see how you did.  (close the window when you're done)")
	# With --shots these save a checkpoint picture of each feature, then quit.
	for shot in [[140, "01_slash"], [200, "02_rewinding"], [270, "03_ghost"], [345, "04_deflect"],
			[428, "05_charged"], [470, "06_echo_hit"], [545, "07_spike"], [645, "08_pogo"], [840, "09_climb"],
			[1040, "10_down"], [1072, "11_shade"], [1140, "12_shade_taken"], [1440, "13_boss_reversal"],
			[1560, "14_boss_inverted"], [1800, "15_results"]]:
		plan.append([shot[0], "shot", shot[1]])
	for f in [330, 470]:
		plan.append([f, "trace", ""])
	for f in [1419, 1440, 1500, 1530, 1560, 1600]:
		plan.append([f, "boss_trace", ""])
	plan.append_array([[1072, "shade_trace", ""], [1140, "shade_trace", ""], [1820, "quit_if_shots", ""]])
	if "--trace_showcase" in OS.get_cmdline_user_args():
		for f in range(500, 860, 15):
			plan.append([f, "respawn_trace", ""])

	# Nail arts and the parry slot in after the echo slash; everything from
	# there on (steps, captions, shots, traces) moves back to make room.
	const ARTS_AT := 505
	const ARTS_LEN := 300
	for step: Array in plan:
		if step[0] >= ARTS_AT:
			step[0] += ARTS_LEN
	var a := ARTS_AT
	say.call(a, "4/10  NAIL ARTS: hold J until the ring pulses, then...")
	plan.append_array([[a + 4, "clear_near", ""], [a + 5, "warp_xy", Vector2(40, 316)],
		[a + 6, "stage_grunt", Vector2(150, 316)], [a + 10, "press", "attack"]])
	say.call(a + 45, "...press Dash: DASH SLASH")
	plan.append_array([[a + 55, "tap", "dash"], [a + 60, "release", "attack"]])
	say.call(a + 100, "...or let go holding up: CYCLONE SLASH")
	plan.append_array([[a + 100, "warp_xy", Vector2(40, 316)], [a + 101, "stage_grunt", Vector2(66, 316)],
		[a + 105, "press", "attack"], [a + 140, "press", "move_up"], [a + 145, "stage_grunt", Vector2(66, 316)],
		[a + 151, "release", "attack"], [a + 160, "release", "move_up"]])
	say.call(a + 195, "5/10  TIME-PARRY: strike just as a blow lands, and turn it back")
	plan.append_array([[a + 200, "warp_xy", Vector2(40, 316)], [a + 201, "stage_grunt", Vector2(100, 316)],
		[a + 202, "grunt_speed", 40.0], [a + 252, "tap", "attack"]])
	plan.append_array([[a + 58, "shot", "05a_dash_slash"], [a + 156, "shot", "05b_cyclone"],
		[a + 256, "shot", "05c_parry"], [a + 70, "grunt_trace", ""], [a + 170, "grunt_trace", ""],
		[a + 251, "parry_trace", ""], [a + 262, "parry_trace", ""]])
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
				print("[trace] frame=%d rewinding=%s pos=(%.1f,%.1f) vy=%.0f hp=%d dead=%s attack_t=%.2f charge=%.2f echoes=%d inverted=%s" % [
					_frame, Rewind.is_rewinding, p.position.x, p.position.y, p.velocity.y, p.hp, p.dead, p.attack_t,
					p.charge_t, p.echoes.size(), inverted])
			"spike_self":
				var p: Player = get_tree().get_first_node_in_group("player")
				p._spike_hit()
			"shade_trace":
				var p: Player = get_tree().get_first_node_in_group("player")
				var shades := get_tree().get_nodes_in_group("enemies").filter(func(e: Enemy) -> bool:
					return e is Shade and not e.dead).map(func(e: Shade) -> String:
					return "%d@%d" % [e.ms, int(e.position.x)])
				print("[shade] frame=%d state=%s player_x=%d time=%d Game.shade=%s nodes=%s" % [
					_frame, Game.State.keys()[Game.state], p.position.x if p else -1, Rewind.time_ms, Game.shade, shades])
			"set_hp":
				get_tree().get_first_node_in_group("player").hp = step[2]
			"wall_trace":
				var p: Player = get_tree().get_first_node_in_group("player")
				print("[wall] frame=%d pos=(%.0f,%.0f) vy=%.0f sliding=%s wall_t=%.2f dir=%d time=%d air_dash_used=%s" % [
					_frame, p.position.x, p.position.y, p.velocity.y, p.wall_sliding, p.wall_t, p.wall_dir,
					Rewind.time_ms, p.air_dash_used])
			"quit_if_shots":
				if _shots_dir != "":
					get_tree().quit()
			"caption":
				_caption.text = step[2]
			"clear_near":
				# Demo staging: drop ordinary enemies that would wander into the shot.
				var p: Player = get_tree().get_first_node_in_group("player")
				for e: Enemy in get_tree().get_nodes_in_group("enemies"):
					if e is Shade or e is Boss or e.inverted or not e.is_active():
						continue
					if absf(e.position.x - p.position.x) < 400.0:
						e.dead = true
			"stage_inverted":
				# Park the intro's inverted grunt in slash range and hold it still.
				var p: Player = get_tree().get_first_node_in_group("player")
				p.position = Vector2(step[2], 316)
				p.velocity = Vector2.ZERO
				p.hurt_t = 0.0
				p.facing = 1
				for e: Enemy in get_tree().get_nodes_in_group("enemies"):
					if e.inverted and not e.dormant:
						e.position = Vector2(step[2] + 30, 316)
						e.speed = 0.0
						break
			"unstage_inverted":
				for e: Enemy in get_tree().get_nodes_in_group("enemies"):
					if e.inverted:
						e.speed = 40.0
			"stage_grunt":
				for e: Enemy in get_tree().get_nodes_in_group("enemies"):
					if e.get_script() == Enemy and not e.inverted and not e.dormant:
						e.dead = false
						e.hp = e.max_hp
						e.position = step[2]
						e.speed = 0.0
						e.last_hit = ""
						e.velocity = Vector2.ZERO
						e.hurt_t = 0.0
						e.ai = Enemy.Ai.WANDER
						e.ai_t = Enemy.WANDER_TIME
						break
			"grunt_speed":
				for e: Enemy in get_tree().get_nodes_in_group("enemies"):
					if e.get_script() == Enemy and not e.inverted and not e.dormant:
						e.speed = step[2]
						break
			"parry_trace":
				var p: Player = get_tree().get_first_node_in_group("player")
				var g: Enemy = null
				for e: Enemy in get_tree().get_nodes_in_group("enemies"):
					if e.get_script() == Enemy and not e.inverted and not e.dormant:
						g = e
						break
				print("[parry] frame=%d player_hp=%d time=%d attack_t=%.2f parry_t=%.2f grunt_x=%d grunt_vx=%.0f ai=%s" % [
					_frame, p.hp, Rewind.time_ms, p.attack_t, p.parry_t, g.position.x, g.velocity.x, Enemy.Ai.keys()[g.ai]])
			"boss_wave":
				var p: Player = get_tree().get_first_node_in_group("player")
				Game.boss.waves.append(Vector3(p.position.x + step[2], 328.0, -1))
			"reflect_trace":
				var p: Player = get_tree().get_first_node_in_group("player")
				print("[reflect] frame=%d player_hp=%d time=%d boss_hp=%d boss_x=%d waves=%s reflected=%s" % [
					_frame, p.hp, Rewind.time_ms, Game.boss.hp, Game.boss.position.x, Game.boss.waves, Game.boss.reflected])
			"stage_pogo":
				var grunt: Enemy = null
				for e: Enemy in get_tree().get_nodes_in_group("enemies"):
					if e.get_script() == Enemy and not e.inverted and not e.dormant:
						grunt = e
						break
				if grunt:
					grunt.dead = false
					grunt.hp = grunt.max_hp
					grunt.position = step[2]
					grunt.speed = 0.0
			"respawn_trace":
				var p: Player = get_tree().get_first_node_in_group("player")
				print("[rs] frame=%d pos=(%d,%d) hp=%d respawn_t=%.2f safe=%s invuln=%.2f scale=%.2f" % [
					_frame, p.position.x, p.position.y, p.hp, p.respawn_t, p.safe_pos, p.invuln_t, Engine.time_scale])
			"zoom":
				var z := 1.0
				for arg in OS.get_cmdline_user_args():
					if arg.begins_with("--zoom="):
						z = float(arg.get_slice("=", 1))
				get_viewport().get_camera_2d().zoom = Vector2(z, z)
			"grunt_trace":
				for e: Enemy in get_tree().get_nodes_in_group("enemies"):
					if e.get_script() == Enemy and not e.inverted:
						print("[grunt] frame=%d x=%d vx=%.0f hp=%d dead=%s ai=%s ai_t=%.2f dir=%d" % [
							_frame, e.position.x, e.velocity.x, e.hp, e.dead, Enemy.Ai.keys()[e.ai], e.ai_t, e.dir])
						break
			"warp_xy":
				var p: Player = get_tree().get_first_node_in_group("player")
				p.position = step[2]
				p.velocity = Vector2.ZERO
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
				Game.boss.invert_t = 0.0 # flip to inverted right away
			"boss_trace":
				print("[boss] frame=%d hp=%d inverted=%s invert_t=%.1f mode=%s x=%d reversals_left=%d" % [
					_frame, Game.boss.hp, Game.boss.inverted, Game.boss.invert_t, Boss.Mode.keys()[Game.boss.mode],
					Game.boss.position.x, Game.boss.reversals_left])
			"burst_boss":
				for i in step[2]:
					Game.boss.take_hit("burst%d_%d" % [_frame, i], Vector2.RIGHT)
			"ghost_hit_boss":
				Game.boss.take_hit("g_test_%d" % _frame, Vector2.RIGHT)
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
