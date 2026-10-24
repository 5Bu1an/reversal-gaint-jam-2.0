class_name Drone
extends Enemy
## Flying security drone. Hovers around its post, flashes when it spots the
## player, then dives at where the player was standing and flies back.

enum Mode { HOVER, AIM, DIVE, RETURN }

const SIGHT := 170.0
const AIM_TIME := 0.7
const DIVE_SPEED := 200.0
const DIVE_TIME := 0.8
const REST_TIME := 2.0

var home := Vector2.ZERO
var mode := Mode.HOVER
var mode_t := 0.0
var target := Vector2.ZERO
var bob := 0.0


func _init() -> void:
	size = Vector2(16, 10)
	speed = 90.0
	max_hp = 2
	knockback = 140.0


func _ready() -> void:
	super()
	home = position


func _act(delta: float) -> void:
	mode_t = maxf(mode_t - delta, 0.0)
	if hurt_t > 0.0:
		if mode == Mode.DIVE:
			mode = Mode.RETURN
		velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
		move_and_slide()
		return

	var player: Player = get_tree().get_first_node_in_group("player")
	match mode:
		Mode.HOVER:
			bob += delta
			var goal := home + Vector2(sin(bob * 1.3) * 24.0, sin(bob * 2.6) * 6.0)
			velocity = (goal - position) * 3.0
			if player and not player.dead and mode_t <= 0.0 and position.distance_to(player.position) < SIGHT:
				mode = Mode.AIM
				mode_t = AIM_TIME
		Mode.AIM:
			velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
			if player:
				target = player.position
			if mode_t <= 0.0:
				mode = Mode.DIVE
				mode_t = DIVE_TIME
				velocity = position.direction_to(target) * DIVE_SPEED
		Mode.DIVE:
			if mode_t <= 0.0 or get_slide_collision_count() > 0:
				mode = Mode.RETURN
		Mode.RETURN:
			velocity = position.direction_to(home) * speed
			if position.distance_to(home) < 6.0:
				mode = Mode.HOVER
				mode_t = REST_TIME
	if absf(velocity.x) > 1.0:
		dir = int(signf(velocity.x))
	move_and_slide()


func _draw_body(body: Color) -> void:
	draw_rect(Rect2(-size / 2, size), body)
	# Rotor struts.
	draw_line(Vector2(-11, -7), Vector2(-3, -5), body, 1.0)
	draw_line(Vector2(11, -7), Vector2(3, -5), body, 1.0)
	var eye := COLOR_EYE
	if mode == Mode.AIM and int(mode_t * 20.0) % 2 == 0:
		eye = Color.WHITE
	var eye_x := 1.0 if dir > 0 else -5.0
	draw_rect(Rect2(eye_x, -2, 4, 3), eye)


func capture_state() -> Dictionary:
	var state := super()
	state.merge({"mode": mode, "mode_t": mode_t, "target": target, "bob": bob})
	return state
