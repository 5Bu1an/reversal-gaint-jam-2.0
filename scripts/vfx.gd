class_name Vfx
extends Node2D
## One short-lived, procedurally drawn effect in the style of Hollow Knight's
## nail hits: long white streaks that shoot out and thin away, a soft bloom
## of light, drifting sparkles, a crescent swipe or an expanding ring. Drawn
## additively, so the level's glow makes the bright parts bloom. Spawn them
## through the Fx autoload rather than directly. They run on real time, so a
## hit-stop freezes the fight while the burst still flies out.
##
## Enemy-side effects (SPLAT goo, ink streaks, a flung CORPSE) draw normally
## rather than additively, so dark ink stays dark.

enum Kind { STREAKS, BLOOM, SPARKLES, CRESCENT, RING, SPLAT, CORPSE, CUT, STAR, STAIN }

const GRAVITY := 520.0

const BLEND := preload("res://scripts/vfx_blend.tres")

var kind := Kind.STREAKS
var life := 0.2
var color := Color.WHITE
var additive := true
## Streaks: [angle, length, width, delay] each. Sparkles and splats:
## [velocity, size]. Corpse: [velocity, size (Vector2), spin]. Cut: [angle,
## length]. Stain: [x offset, radius] blobs flattened onto the floor.
var parts: Array = []
var radius := 20.0
## Crescent: facing angle and sweep.
var angle := 0.0
var sweep := 2.4

var _t := 0.0


func _ready() -> void:
	if additive:
		material = BLEND
	z_index = 6


func _process(delta: float) -> void:
	_t += delta / maxf(Engine.time_scale, 0.01)
	if _t >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / life
	match kind:
		Kind.STREAKS:
			_draw_streaks(k)
		Kind.BLOOM:
			_draw_bloom(k)
		Kind.SPARKLES:
			_draw_sparkles(k)
		Kind.CRESCENT:
			_draw_crescent(k)
		Kind.RING:
			_draw_ring(k)
		Kind.SPLAT:
			_draw_splat()
		Kind.CORPSE:
			_draw_corpse(k)
		Kind.CUT:
			_draw_cut(k)
		Kind.STAR:
			_draw_star(k)
		Kind.STAIN:
			_draw_stain(k)


## Each streak shoots out from the centre fast, then its tail catches up so
## it thins into a sliver and vanishes.
func _draw_streaks(k: float) -> void:
	for p: Array in parts:
		var delay: float = p[3]
		var length: float = p[1]
		var width: float = p[2]
		var local := clampf((k - delay) / (1.0 - delay), 0.0, 1.0)
		if local <= 0.0 or local >= 1.0:
			continue
		var dir := Vector2.from_angle(p[0])
		var head := ease(local, 0.25) * length
		var tail := ease(local, 2.2) * length
		var side := dir.orthogonal() * width * (1.0 - local)
		var a := dir * tail
		var b := dir * head
		var mid := (a + b) / 2
		draw_colored_polygon(PackedVector2Array([a, mid + side, b, mid - side]),
			Color(color, 1.0 - local * local))


func _draw_bloom(k: float) -> void:
	var r := radius * (0.6 + 0.6 * ease(k, 0.3))
	for i in 4:
		var f := 1.0 - i / 4.0
		draw_circle(Vector2.ZERO, r * f, Color(color, 0.18 * (1.0 - k)))


func _draw_sparkles(k: float) -> void:
	for p: Array in parts:
		var vel: Vector2 = p[0]
		# Fast at first, then drifting, with a little lift like glowing dust.
		var pos := vel * ease(k, 0.35) * life + Vector2(0, -12.0 * k)
		var size: float = p[1] * (1.0 - k)
		draw_circle(pos, size, Color(color, 1.0 - k))
		draw_circle(pos, size * 2.5, Color(color, 0.15 * (1.0 - k)))


## A sword swipe: a soft glow, a bright crescent that sweeps on and thins
## out, and two fainter arcs trailing behind it like afterimages.
func _draw_crescent(k: float) -> void:
	var reach := ease(minf(k * 2.5, 1.0), 0.4)
	var thickness := radius * 0.34 * (1.0 - k)
	_crescent_band(radius + 3.0, thickness * 1.9, reach, Color(color, 0.22 * (1.0 - k)))
	_crescent_band(radius, thickness, reach, Color(color, 0.92 * (1.0 - k)))
	for i in 2:
		# Trails lag a little behind the leading edge and sit further in.
		var lag := clampf(reach - 0.18 * (i + 1), 0.0, 1.0)
		var trail := _arc_points(radius - 4.0 - i * 4.0, lag)
		if trail.size() >= 2:
			draw_polyline(trail, Color(color, (0.5 - i * 0.2) * (1.0 - k)), 1.0)
	var edge := _arc_points(radius, reach)
	if edge.size() >= 2:
		draw_polyline(edge, Color(Color.WHITE, 1.0 - k), 1.0)


func _arc_points(r: float, reach: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var steps := 16
	for i in steps + 1:
		var f := i / float(steps)
		if f > reach:
			break
		points.append(Vector2.from_angle(angle - sweep / 2 + sweep * f) * r)
	return points


## One crescent-shaped band, thickest mid-arc and tapering to points.
func _crescent_band(r: float, thickness: float, reach: float, band_color: Color) -> void:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var steps := 16
	for i in steps + 1:
		var f := i / float(steps)
		if f > reach:
			break
		var a := angle - sweep / 2 + sweep * f
		var w := thickness * sin(f * PI)
		outer.append(Vector2.from_angle(a) * r)
		inner.append(Vector2.from_angle(a) * (r - w))
	if outer.size() < 2:
		return
	inner.reverse()
	draw_colored_polygon(outer + inner, band_color)


func _draw_ring(k: float) -> void:
	var r := radius * ease(k, 0.3)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(color, 1.0 - k), 3.0 * (1.0 - k) + 1.0)


## Goo blobs that fly out, fall under gravity and shrink away.
func _draw_splat() -> void:
	var t := _t
	for p: Array in parts:
		var vel: Vector2 = p[0]
		var size: float = p[1]
		var pos := vel * t + Vector2(0, 0.5 * GRAVITY * t * t)
		var k := t / life
		var r := size * (1.0 - k * k)
		draw_circle(pos, r, Color(color, 1.0 - k * k * k))
		# A smaller highlight blob keeps them from reading as flat dots.
		draw_circle(pos + Vector2(-r * 0.3, -r * 0.3), r * 0.4, Color(color.lightened(0.5), 0.8 * (1.0 - k)))


## The enemy's body, flung away spinning and fading out.
func _draw_corpse(k: float) -> void:
	var p: Array = parts[0]
	var vel: Vector2 = p[0]
	var size: Vector2 = p[1]
	var spin: float = p[2]
	var pos := vel * _t + Vector2(0, 0.5 * GRAVITY * _t * _t)
	draw_set_transform(pos, spin * _t, Vector2.ONE)
	draw_rect(Rect2(-size / 2, size), Color(color, 1.0 - k))
	draw_set_transform(Vector2.ZERO)


## A bright slash mark across the target: grows long fast and thins away.
func _draw_cut(k: float) -> void:
	for p: Array in parts:
		var dir := Vector2.from_angle(p[0])
		var length: float = p[1] * ease(minf(k * 3.0, 1.0), 0.3)
		var width := 3.5 * (1.0 - k)
		var side := dir.orthogonal() * width
		draw_colored_polygon(PackedVector2Array([-dir * length / 2, side, dir * length / 2, -side]),
			Color(color, 1.0 - k * k))


## A four-pointed flare that pops and shrinks.
func _draw_star(k: float) -> void:
	var r := radius * (1.0 - k) * ease(minf(k * 6.0, 1.0), 0.4)
	for i in 2:
		var dir := Vector2.from_angle(PI / 4 + i * PI / 2)
		var side := dir.orthogonal() * r * 0.12
		draw_colored_polygon(PackedVector2Array([-dir * r, side, dir * r, -side]), Color(color, 1.0 - k))
	draw_circle(Vector2.ZERO, r * 0.2, Color(color, 1.0 - k))


## Goo left on the floor after a kill; lingers, then fades.
func _draw_stain(k: float) -> void:
	var alpha := 0.7 * clampf((1.0 - k) * 4.0, 0.0, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.28))
	for p: Array in parts:
		draw_circle(Vector2(p[0], 0), p[1], Color(color, alpha))
	draw_set_transform(Vector2.ZERO)
