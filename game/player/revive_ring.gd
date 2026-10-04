extends Node2D
## STEADY HANDS: the green ring on the floor round a body that is down, filling
## clockwise from the top while a teammate holds interact over it - picked from
## the Revive Lab preview (option A, 2026-10-04) and drawn the way the page drew
## it, line for line: `healRing` for the ring, `Ring` for the flare, and the
## page's own pixel stepping (`arc`, `line`) rather than Godot's draw_arc, so
## the pixels are the ones that were picked.
##
## - **The ring**: the whole ellipse in dark green, the filled part in green
##   with a pale head, red for a moment when a blow knocks some off, and dimmer
##   while nobody is holding (it runs back down then).
## - **The plus signs**: one every PLUS_EVERY while somebody holds, off the part
##   already filled (heal_plus.gd).
## - **The flare**: when the body gets up the ring is thrown outward, white to
##   green, and frees itself; game/revive.gd adds the crown of plus signs.
##
## Green is the colour of health and of nothing else in the game, which is why
## the ring does not take the reviver's spark colour as the charge ring does.
##
## It is `top_level` and draws in WORLD pixels, rounded the way the page
## rounded them, from a node parked at the world's origin - which is also what
## puts it on the floor and under every body: the room is y-sorted, so a node at
## y 0 draws after the floor (the level comes first in the tree) and before
## anything standing. NOT at `z_index` -1 like the charge ring: a top-level node
## there drew under the floor tiles and was never seen. It follows the body's
## PICTURE (`drawn_at()`), which on a remote body is a beat behind where it
## stands. game/revive.gd owns its life and writes `progress`, `live` and `lost`
## every frame.

const HealPlus := preload("res://game/player/heal_plus.gd")

const HEAL := Color(95 / 255.0, 209 / 255.0, 122 / 255.0)
const HEAL_DARK := Color(34 / 255.0, 104 / 255.0, 58 / 255.0)
const HEAL_LIGHT := Color(196 / 255.0, 248 / 255.0, 206 / 255.0)
const LOST := Color(1.0, 92 / 255.0, 92 / 255.0)
## The ellipse lying on the floor, and its centre above the feet.
const RX := 14.0
const RY := 6.0
const LIFT := 2.0
## One plus sign this often while somebody holds; one in four is a big one.
const PLUS_EVERY := 0.12
const BIG_SHARE := 0.25
const LIGHT_SHARE := 0.35
## The flare: thrown from the ring's own size out to FLARE_TO, white to green.
const FLARE_SECONDS := 0.32
const FLARE_TO := 26.0
const FLARE_SQUASH := 0.45
## Found by tests through this group; nothing in the game looks a ring up.
const GROUP := &"revive_ring"

## 0..1, how much of the revive is done. Written by game/revive.gd.
var progress := 0.0
## Whether somebody is holding interact over the body right now.
var live := false
## Seconds of red left, after a blow knocked some off.
var lost := 0.0

var _body: Node2D
var _plus_clock := 0.0
## Seconds into the flare, or -1 while it is still a ring.
var _flare := -1.0
var _centre := Vector2.ZERO


func setup(body: Node2D) -> void:
	_body = body
	top_level = true
	add_to_group(GROUP)
	_follow()


## The body got up: the ring is thrown outward and gone.
func flare() -> void:
	_flare = 0.0
	live = false


func flaring() -> bool:
	return _flare >= 0.0


func _process(delta: float) -> void:
	if _flare >= 0.0:
		_flare += delta
		if _flare >= FLARE_SECONDS:
			queue_free()
			return
	else:
		_follow()
		lost = maxf(lost - delta, 0.0)
		if live:
			_plus_clock -= delta
			if _plus_clock <= 0.0:
				_plus_clock = PLUS_EVERY
				var a := -PI / 2.0 + randf() * progress * TAU
				HealPlus.spawn(_body, _centre + Vector2(cos(a) * RX, sin(a) * RY),
					randf() < BIG_SHARE, HEAL_LIGHT if randf() < LIGHT_SHARE else HEAL,
					HealPlus.drift())
	queue_redraw()


## World pixels from here on: the node sits at the origin of the world.
func _follow() -> void:
	global_position = Vector2.ZERO
	if is_instance_valid(_body):
		_centre = (_body.call("drawn_at") as Vector2) - Vector2(0.0, LIFT)


func _draw() -> void:
	if _flare >= 0.0:
		var t := _flare / FLARE_SECONDS
		var e := 1.0 - pow(1.0 - t, 2.0)
		var r := lerpf(RX, FLARE_TO, e)
		_arc(_centre.x, _centre.y, r, r * FLARE_SQUASH, 0.0, TAU,
			Color.WHITE.lerp(HEAL, t), 1.0 - t)
		return
	var top := -PI / 2.0
	_arc(_centre.x, _centre.y, RX, RY, 0.0, TAU, HEAL_DARK, 0.7 if live else 0.4)
	if progress <= 0.0:
		return
	var end := top + progress * TAU
	_arc(_centre.x, _centre.y, RX, RY, top, end, LOST if lost > 0.0 else HEAL,
		1.0 if live else 0.5)
	_px(_centre.x + cos(end) * RX, _centre.y + sin(end) * RY, HEAL_LIGHT,
		1.0 if live else 0.5)


# --- the page's pixel stepping ------------------------------------------------------


## JavaScript's Math.round: halves go up.
static func _jr(v: float) -> int:
	return floori(v + 0.5)


func _px(x: float, y: float, c: Color, a: float) -> void:
	draw_rect(Rect2(_jr(x), _jr(y), 1, 1), Color(c, a))


## An arc of the floor ellipse round (cx, cy), from a0 to a1, as one pixel
## line between each pair of its points - forty to a full turn.
func _arc(cx: float, cy: float, rx: float, ry: float, a0: float, a1: float,
		c: Color, a: float) -> void:
	var n := maxi(2, ceili(absf(a1 - a0) / TAU * 40.0))
	var last := Vector2(cx + cos(a0) * rx, cy + sin(a0) * ry)
	for i in range(1, n + 1):
		var t := a0 + (a1 - a0) * i / n
		var next := Vector2(cx + cos(t) * rx, cy + sin(t) * ry)
		_line(last, next, Color(c, a))
		last = next


## Bresenham between two rounded points, both ends drawn.
func _line(from: Vector2, to: Vector2, c: Color) -> void:
	var x0 := _jr(from.x)
	var y0 := _jr(from.y)
	var x1 := _jr(to.x)
	var y1 := _jr(to.y)
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	while true:
		draw_rect(Rect2(x0, y0, 1, 1), c)
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy
