extends Node2D
## Kuro's finale. Time stalls on the killing blow; he sinks to his knees in
## slow motion while cracks of golden light split out of him; then he bursts
## into gold and sakura with a shockwave, and a banner names the victory.
## Sets boss.death_shown at the end so the portal opens. It pauses while time
## rewinds, and removes itself if a rewind brings Kuro back to life.

const JP_FONT := preload("res://assets/fonts/NotoSansJP-subset.ttf")
const GOLD := Color("#ffcf5a")
const PALE := Color("#fff4c8")
const PINK := Color("#ff7aae")
const CRIMSON := Color("#ff2a6d")
const FALL_TIME := 1.8 # kneeling, cracking with light
const LENGTH := 4.6
const VIEW := Vector2(640, 360)

var _boss: Boss
var _corpse := AnimatedSprite2D.new()
var _t := 0.0
var _burst := false
var _spark_t := 0.0
var _rays: Array[float] = []
var _banner := Control.new()
var _jp := FontVariation.new()
var _rng := RandomNumberGenerator.new()


func setup(boss: Boss, art: AnimatedSprite2D) -> void:
	_boss = boss
	position = boss.position + Vector2(0, boss.size.y / 2)
	if art:
		_corpse.sprite_frames = art.sprite_frames
		_corpse.centered = false
		_corpse.offset = art.offset
		_corpse.scale = Vector2(absf(art.scale.x) * signf(art.scale.x), absf(art.scale.x))
		_corpse.material = art.material.duplicate()


func _ready() -> void:
	z_index = 20
	_jp.base_font = JP_FONT
	_jp.variation_opentype = {"weight": 800}
	if _corpse.sprite_frames:
		add_child(_corpse)
		_corpse.play("death")
		_corpse.speed_scale = 0.45
	var layer := CanvasLayer.new()
	layer.layer = 22
	_banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.draw.connect(_draw_banner)
	layer.add_child(_banner)
	add_child(layer)
	# The killing blow: freeze, flash, then a long beat of slow motion.
	Fx.hit_stop(0.45)
	Fx.slow_mo(1.6)
	Fx.flash(Color.WHITE, 0.85)
	Fx.shake(8.0)
	Sfx.play("kill", 0.0, 0.0)
	Sfx.play("boss_slam", -2.0, 0.0)


func _process(delta: float) -> void:
	if not is_instance_valid(_boss) or not _boss.dead:
		queue_free() # rewound to before the killing blow
		return
	if Rewind.is_rewinding:
		return
	_t += delta
	if not _burst:
		# Cracks of light: more of them as he falls.
		var want := int(lerpf(2.0, 14.0, clampf(_t / FALL_TIME, 0.0, 1.0)))
		while _rays.size() < want:
			_rays.append(_rng.randf_range(-PI, 0.0) if _rng.randf() < 0.7 else _rng.randf_range(0.0, PI))
		_spark_t -= delta
		if _spark_t <= 0.0:
			_spark_t = 0.12
			Fx.burst(_chest(), GOLD, 6, 160.0)
			Fx.shake(2.0 + 4.0 * _t / FALL_TIME)
		_corpse.position = Vector2(_rng.randf_range(-1, 1), 0) * (_t / FALL_TIME) * 2.0
		var mat := _corpse.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("flash", clampf(_t / FALL_TIME, 0.0, 1.0) * (0.6 + 0.4 * sin(_t * 30.0)))
		if _t >= FALL_TIME:
			_explode()
	if _t >= LENGTH and is_instance_valid(_boss):
		_boss.death_shown = true
		set_process(false)
	queue_redraw()
	_banner.queue_redraw()


func _chest() -> Vector2:
	return position + Vector2(0, -34)


func _explode() -> void:
	_burst = true
	_corpse.visible = false
	Fx.flash(Color(1, 0.95, 0.85), 0.9)
	Fx.hit_stop(0.12)
	Fx.shake(10.0)
	Fx.kill(_chest(), Vector2.UP, GOLD)
	Fx.burst(_chest(), GOLD, 40, 260.0)
	Fx.burst(_chest(), Color.WHITE, 24, 320.0)
	Sfx.play("boss_slam", 0.0, 0.0)
	Sfx.play("kill", 0.0, 0.0)
	Sfx.play("rewind_end", 0.0, 0.0)
	_petals()


## Sakura and gold leaves thrown out, then drifting down.
func _petals() -> void:
	for spec: Array in [[PINK, 90], [GOLD, 50]]:
		var image := Image.create(3, 2, false, Image.FORMAT_RGBA8)
		image.fill(spec[0])
		var p := CPUParticles2D.new()
		p.texture = ImageTexture.create_from_image(image)
		p.one_shot = true
		p.explosiveness = 0.95
		p.amount = spec[1]
		p.lifetime = 3.2
		p.position = _chest() - position
		p.direction = Vector2.UP
		p.spread = 180.0
		p.initial_velocity_min = 60.0
		p.initial_velocity_max = 220.0
		p.damping_min = 80.0
		p.damping_max = 140.0
		p.gravity = Vector2(-8, 40)
		p.angular_velocity_min = -200.0
		p.angular_velocity_max = 200.0
		p.angle_max = 360.0
		p.scale_amount_min = 1.0
		p.scale_amount_max = 2.2
		var fade := Gradient.new()
		fade.set_color(0, Color.WHITE)
		fade.set_color(1, Color(1, 1, 1, 0))
		p.color_ramp = fade
		add_child(p)
		p.emitting = true


func _draw() -> void:
	var chest := _chest() - position
	if not _burst:
		var grow := clampf(_t / FALL_TIME, 0.0, 1.0)
		draw_circle(chest, 20.0 + 30.0 * grow, Color(GOLD, 0.12 + 0.25 * grow))
		for a in _rays:
			var length := 40.0 + 260.0 * grow
			var width := 0.05 + 0.04 * grow
			var tip := chest + Vector2.from_angle(a) * length
			draw_colored_polygon(PackedVector2Array([chest, chest + Vector2.from_angle(a - width) * length, tip,
				chest + Vector2.from_angle(a + width) * length]), Color(PALE, 0.35 + 0.4 * grow))
		return
	var k := _t - FALL_TIME
	# Shockwave rings and a fading core.
	for i in 3:
		var ring := k * (320.0 + i * 120.0)
		var alpha := clampf(1.0 - k * (1.2 + i * 0.3), 0.0, 1.0)
		if alpha > 0.0:
			draw_arc(chest, ring, 0.0, TAU, 72, Color(GOLD if i == 0 else CRIMSON, alpha * 0.8), 6.0 * alpha + 1.0)
	var core := clampf(1.0 - k * 1.5, 0.0, 1.0)
	if core > 0.0:
		draw_circle(chest, 40.0 * core + 10.0, Color(PALE, core))
	# A pillar of light where he stood, fading.
	var pillar := clampf(1.0 - k / 2.5, 0.0, 1.0)
	if pillar > 0.0:
		draw_rect(Rect2(chest.x - 14 * pillar, -400, 28 * pillar, 434), Color(GOLD, 0.25 * pillar))
		draw_rect(Rect2(chest.x - 4 * pillar, -400, 8 * pillar, 434), Color(PALE, 0.6 * pillar))


func _draw_banner() -> void:
	var k := _t - FALL_TIME - 0.6
	if k <= 0.0:
		return
	var alpha := clampf(k / 0.5, 0.0, 1.0) * clampf((LENGTH + 0.5 - _t) / 0.8, 0.0, 1.0)
	var font := ThemeDB.fallback_font
	var y := 120.0
	_banner.draw_rect(Rect2(0, y - 40, VIEW.x, 74), Color(0, 0, 0, 0.5 * alpha))
	_banner.draw_line(Vector2(0, y - 40), Vector2(VIEW.x, y - 40), Color(GOLD, 0.6 * alpha), 1.0)
	_banner.draw_line(Vector2(0, y + 34), Vector2(VIEW.x, y + 34), Color(GOLD, 0.6 * alpha), 1.0)
	var scale_in := lerpf(1.4, 1.0, clampf(k / 0.35, 0.0, 1.0))
	var size := int(30 * scale_in)
	var text := "クロ、討ち取ったり"
	for glow in [Vector2(0, 2), Vector2(0, -2), Vector2(2, 0), Vector2(-2, 0)]:
		_banner.draw_string(_jp, Vector2(0, y + 4) + glow, text, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, size, Color(CRIMSON, 0.35 * alpha))
	_banner.draw_string(_jp, Vector2(0, y + 4), text, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, size, Color(PALE, alpha))
	_banner.draw_string(font, Vector2(0, y + 26), "K U R O   H A S   F A L L E N", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 11, Color(GOLD, alpha))
