extends Node
## Autoload "Game". Run state, pause and the checkpoint, which survives scene
## reloads. UI hooks in here:
##
##   Game.state_changed.connect(func(state): ...)   # show/hide screens
##   Game.checkpoint_reached.connect(...)           # "checkpoint" toast
##   Game.boss                                      # Boss node or null; read .hp / .max_hp
##   Game.stats                                     # time, deaths, rewinds, rewound_ms
##   Game.shade                                     # {pos, ms} of lost time, or {}
##   Game.restart() / Game.new_game() / Game.set_paused(bool)

enum State { PLAYING, PAUSED, DOWN, GAME_OVER, WON }

signal state_changed(state: State)
signal checkpoint_reached(index: int)

## 0 = level start, 1 = shrine before the boss.
var checkpoint := 0
var state := State.PLAYING
var boss: Boss
## This run's numbers, kept across checkpoint retries, cleared by new_game().
var stats := {}
## Time lost at the last real death, waiting at {pos, ms}; {} when none.
## Lives here so it survives the scene reload.
var shade := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_reset_stats()
	# Rewind is the next autoload, so it isn't in the tree yet.
	_connect_rewind.call_deferred()


func _connect_rewind() -> void:
	Rewind.rewind_started.connect(func() -> void: stats.rewinds += 1)
	Rewind.rewind_ended.connect(func(undone: Array) -> void:
		stats.rewound_ms += undone.size() * Rewind.MS_PER_FRAME)


func _physics_process(delta: float) -> void:
	if state == State.PLAYING or state == State.DOWN:
		stats.time += delta


func _reset_stats() -> void:
	stats = {"time": 0.0, "deaths": 0, "rewinds": 0, "rewound_ms": 0.0}


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		if state == State.PLAYING:
			set_paused(true)
		elif state == State.PAUSED:
			set_paused(false)
	elif Input.is_action_just_pressed("jump"):
		# While down you can still rewind, or give up and reboot.
		if state == State.GAME_OVER or state == State.DOWN:
			restart()
		elif state == State.WON:
			new_game()


func set_state(new_state: State) -> void:
	if new_state == state:
		return
	# Dying with no time left skips DOWN, so count whichever comes first.
	var was_alive := state != State.DOWN and state != State.GAME_OVER
	state = new_state
	if was_alive and (state == State.DOWN or state == State.GAME_OVER):
		stats.deaths += 1
	state_changed.emit(state)


func set_paused(paused: bool) -> void:
	get_tree().paused = paused
	set_state(State.PAUSED if paused else State.PLAYING)


func reach_checkpoint(index: int) -> void:
	if index <= checkpoint:
		return
	checkpoint = index
	checkpoint_reached.emit(index)


func win() -> void:
	set_state(State.WON)
	get_tree().paused = true
	var layer := CanvasLayer.new()
	layer.layer = 25
	layer.add_child(preload("res://scripts/results.gd").new())
	get_tree().current_scene.add_child(layer)


## Retry from the last checkpoint. After a real death, the time left on the
## bar stays behind as the shade (replacing any older one).
func restart() -> void:
	if state == State.DOWN or state == State.GAME_OVER:
		var player: Player = get_tree().get_first_node_in_group("player")
		shade = {"pos": player.shade_spot(), "ms": Rewind.time_ms} if player and Rewind.time_ms >= 1.0 else {}
	get_tree().paused = false
	Engine.time_scale = 1.0
	set_state(State.PLAYING)
	get_tree().reload_current_scene()


func new_game() -> void:
	checkpoint = 0
	shade = {}
	_reset_stats()
	restart()
