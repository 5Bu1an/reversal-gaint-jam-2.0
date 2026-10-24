extends Node2D
## Placeholder entry scene. Replaced by the first level once the player exists.


func _ready() -> void:
	var actions := ["move_left", "move_right", "move_up", "move_down", "jump", "attack", "dash", "rewind"]
	for action in actions:
		assert(InputMap.has_action(action), "Missing input action: %s" % action)
	print("Tenet booted. Inputs OK: ", actions.size())
