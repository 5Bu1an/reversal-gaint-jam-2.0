extends Node
## Autoload "Rewind". Records every node in the "rewindable" group once per
## physics frame and, while the rewind action is held, plays those frames back
## in reverse. Each rewound frame drains the time bar.
##
## Rewindable nodes implement capture_state() -> Dictionary and
## apply_state(state: Dictionary), and skip their own physics while
## Rewind.is_rewinding is true.

signal rewind_started
## undone_frames is the timeline that was rewound, in chronological order.
signal rewind_ended(undone_frames: Array)

const MAX_MS := 5000.0
const START_MS := 2000.0
const MAX_FRAMES := 300 # 5 s of history at 60 Hz
const MS_PER_FRAME := 1000.0 / 60.0

var time_ms := START_MS
var is_rewinding := false
## Set false to pause history (e.g. while the player lies dead).
var recording := true

var _history: Array[Dictionary] = []
var _undone: Array[Dictionary] = []


func _ready() -> void:
	# Run after gameplay nodes so each recorded frame is the settled result.
	process_physics_priority = 100


func _physics_process(_delta: float) -> void:
	var wants_rewind := Input.is_action_pressed("rewind") and time_ms > 0.0 and not _history.is_empty()
	if wants_rewind:
		if not is_rewinding:
			is_rewinding = true
			_undone.clear()
			rewind_started.emit()
		var frame: Dictionary = _history.pop_back()
		_apply(frame)
		_undone.push_front(frame)
		time_ms = maxf(time_ms - MS_PER_FRAME, 0.0)
		return

	if is_rewinding:
		is_rewinding = false
		rewind_ended.emit(_undone.duplicate())
		_undone.clear()
	_record()


func add_time(ms: float) -> void:
	time_ms = minf(time_ms + ms, MAX_MS)


func can_rewind() -> bool:
	return time_ms > 0.0 and not _history.is_empty()


func reset() -> void:
	_history.clear()
	_undone.clear()
	is_rewinding = false
	recording = true
	time_ms = START_MS


func _record() -> void:
	if not recording:
		return
	var frame := {}
	for node in get_tree().get_nodes_in_group("rewindable"):
		frame[node] = node.capture_state()
	_history.push_back(frame)
	if _history.size() > MAX_FRAMES:
		_history.pop_front()


func _apply(frame: Dictionary) -> void:
	for node in frame:
		if is_instance_valid(node):
			node.apply_state(frame[node])
