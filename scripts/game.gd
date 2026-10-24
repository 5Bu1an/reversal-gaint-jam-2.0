extends Node
## Autoload "Game". Run state, pause and the checkpoint, which survives scene
## reloads. UI hooks in here:
##
##   Game.state_changed.connect(func(state): ...)   # show/hide screens
##   Game.checkpoint_reached.connect(...)           # "checkpoint" toast
##   Game.boss                                      # Boss node or null; read .hp / .max_hp
##   Game.restart() / Game.new_game() / Game.set_paused(bool)

enum State { PLAYING, PAUSED, DOWN, GAME_OVER, WON }

signal state_changed(state: State)
signal checkpoint_reached(index: int)

## 0 = level start, 1 = shrine before the boss.
var checkpoint := 0
var state := State.PLAYING
var boss: Boss


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		if state == State.PLAYING:
			set_paused(true)
		elif state == State.PAUSED:
			set_paused(false)
	elif Input.is_action_just_pressed("jump"):
		if state == State.GAME_OVER:
			restart()
		elif state == State.WON:
			new_game()


func set_state(new_state: State) -> void:
	if new_state == state:
		return
	state = new_state
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


## Retry from the last checkpoint.
func restart() -> void:
	get_tree().paused = false
	set_state(State.PLAYING)
	get_tree().reload_current_scene()


func new_game() -> void:
	checkpoint = 0
	restart()
