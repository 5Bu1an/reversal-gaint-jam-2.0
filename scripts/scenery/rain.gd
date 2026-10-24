extends CPUParticles2D
## Rain that follows the camera. While time rewinds it falls upward.

const FALL_GRAVITY := Vector2(-60, 700)
const REWIND_GRAVITY := Vector2(60, -2600)


func _ready() -> void:
	var image := Image.create(1, 7, false, Image.FORMAT_RGBA8)
	for y in 7:
		image.set_pixel(0, y, Color(1, 1, 1, (y + 1) / 7.0))
	texture = ImageTexture.create_from_image(image)
	amount = 260
	lifetime = 0.9
	preprocess = 1.0
	local_coords = false
	position = Vector2(0, -200)
	emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	emission_rect_extents = Vector2(400, 4)
	direction = Vector2(-0.12, 1)
	spread = 2.0
	initial_velocity_min = 380.0
	initial_velocity_max = 460.0
	gravity = FALL_GRAVITY
	particle_flag_align_y = true
	color = Color(0.65, 0.8, 1.0, 0.3)
	z_index = 6


func _process(_delta: float) -> void:
	gravity = REWIND_GRAVITY if Rewind.is_rewinding else FALL_GRAVITY
