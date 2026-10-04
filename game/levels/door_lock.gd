extends Node2D
## A door's sign that its room is sealed: a lamp on each jamb and a padlock hung
## in the doorway between them. Red and shut while the room is sealed; when it
## is beaten the lamps blink white and go green, the padlock springs open green
## and fades, and the lamps stay green. Picked as D1 from the Sealed Doors
## preview and drawn from its numbers, so the pixels are the preview's.
##
## ## Why a lock AND lamps
##
## Before it, nothing said a door was shut: you walked into one and nothing
## happened, which reads as a door that is broken (door_count.gd's reason for
## saying "1/2"). The lamps carry the colour, and the pulse draws the eye from
## across the room; the padlock carries the meaning in a SHAPE, so the door says
## locked without anybody having to tell red from green.
##
## ## On the door, and turned with it
##
## A child of the door, drawn in its own pixels like door_count.gd. At 150% the
## north door sits on the top edge of the screen - the camera stops at the wall
## - so nothing can go above a door, and the doorway itself is the one place
## always in view with it. It turns with the door, so the lamps sit on the
## jambs either way, and the padlock is mirrored inside its own box on the
## south door, which is the north one turned half a turn, so it comes out
## upright. Being part of the door, a player standing in the north doorway is
## drawn in front of it, as they are in front of the door.
##
## ## Whose answer
##
## It shows the door's `sealed()`, which is the host's to decide: a guest's
## room cannot work out "beaten" for itself, because the beats only run on the
## host, so the door takes the host's word from the snapshot (door_base.gd).
##
## A room that is open when it is entered - the lobby - is simply open: the
## lamps green from the first frame and no unlock played, since nothing was won
## there.

## The lamps: one on each jamb, 2 x 3 world pixels, in a 4 x 5 glow.
const LAMP_XS := [-14, 12]
const LAMP := Rect2(0, -4, 2, 3)
const GLOW := Rect2(-1, -5, 4, 5)
## Sealed, they pulse: lit for PULSE_ON of every PULSE seconds, dim between.
const PULSE := 1.1
const PULSE_ON := 0.65
const RED := Color8(255, 75, 75)
const RED_DIM := Color8(140, 42, 42)
const RED_GLOW := Color(1.0, 75.0 / 255.0, 75.0 / 255.0, 0.38)
const BLINK := Color8(255, 248, 225)
const BLINK_GLOW := Color(1.0, 248.0 / 255.0, 225.0 / 255.0, 0.45)
const GREEN := Color8(126, 224, 176)
const GREEN_GLOW := Color(110.0 / 255.0, 179.0 / 255.0, 157.0 / 255.0, 0.42)

## The unlock, from the frame the room is beaten: the lamps blink white for
## BLINK_FOR and the padlock holds shut through it, then springs open; it fades
## from FADE_FROM of the way through and is gone at the end.
const UNLOCK := 1.0
const BLINK_FOR := 0.14
const FADE_FROM := 0.5

## The padlock, 7 x 8, its top-left at PAD_AT in the door's own pixels - in the
## doorway between the lamps. Shut, the shackle sits in the body; open, it lifts
## a row and its right leg comes free.
const PAD_AT := Vector2i(-4, -7)
const PAD_SHUT := [".......", "..###..", ".#...#.", ".#...#.", "#######", "###.###", "###.###", "#######"]
const PAD_OPEN := ["..###..", ".#...#.", ".#.....", ".#.....", "#######", "###.###", "###.###", "#######"]
## Outlined the way door_count.gd outlines: every ink cell's four neighbours
## that are not ink themselves, drawn first.
const EDGE := Color8(7, 8, 12)

## Painted into an image in world pixels and drawn as ONE texture, never as a
## rect per pixel, and the reason is the camera: at a fractional zoom like 150%
## a texture's pixels are sampled nearest, exactly as the doorway art under it
## is, while a 1 x 1 rect has its corners snapped to whole screen pixels and
## lands a row off. LAYER is big enough for the lamps' glow and the padlock's
## outline either side of the door's origin, which sits at ORIGIN in it.
const LAYER := Vector2i(48, 64)
const ORIGIN := Vector2i(24, 16)

## How long the room has been sealed, for the pulse.
var _clock := 0.0
## Seconds since the room was beaten, or -1 while it is sealed. Starts as a
## finished unlock if the room is open when the door first asks.
var _since := -1.0
var _asked := false
var _image := Image.create_empty(LAYER.x, LAYER.y, false, Image.FORMAT_RGBA8)
var _texture := ImageTexture.create_from_image(_image)
## What the image was last painted for, so it is only painted again on a change.
var _painted := []


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	var sealed := bool(get_parent().call("sealed"))
	if not _asked:
		_asked = true
		_since = -1.0 if sealed else UNLOCK
	elif sealed:
		_since = -1.0
		_clock += delta
	elif _since < 0.0:
		_since = 0.0
	elif _since < UNLOCK:
		_since += delta
	queue_redraw()


func _draw() -> void:
	var look := _look()
	if look != _painted:
		_painted = look
		_paint(look)
	draw_texture(_texture, -Vector2(ORIGIN))


## Everything the picture depends on: the lamps' core and glow, then whether
## the padlock is drawn, open, and how strongly.
func _look() -> Array:
	var core := GREEN
	var glow := GREEN_GLOW
	if _since < 0.0:
		var lit := fmod(_clock, PULSE) < PULSE_ON
		core = RED if lit else RED_DIM
		glow = RED_GLOW if lit else Color.TRANSPARENT
	elif _since < BLINK_FOR:
		core = BLINK
		glow = BLINK_GLOW
	# Shut and red while sealed; through the unlock it holds shut for the
	# blink, springs open green and fades. Gone once the room is open.
	var pad := _since < UNLOCK
	var open := _since >= BLINK_FOR
	var alpha := 1.0
	if _since >= 0.0 and _since / UNLOCK >= FADE_FROM:
		alpha = 1.0 - (_since / UNLOCK - FADE_FROM) / (1.0 - FADE_FROM)
	return [core, glow, pad, open, alpha, absf(get_parent().rotation) > 1.0]


func _paint(look: Array) -> void:
	_image.fill(Color.TRANSPARENT)
	var core: Color = look[0]
	var glow: Color = look[1]
	for x: int in LAMP_XS:
		if glow.a > 0.0:
			_fill(Rect2i(Vector2i(GLOW.position) + Vector2i(x, 0), Vector2i(GLOW.size)), glow)
		_fill(Rect2i(Vector2i(LAMP.position) + Vector2i(x, 0), Vector2i(LAMP.size)), core)
	if look[2]:
		_paint_pad(look[3], look[4], look[5])
	_texture.update(_image)


func _paint_pad(open: bool, alpha: float, flip: bool) -> void:
	var rows: Array = PAD_OPEN if open else PAD_SHUT
	var ink := []
	for y in rows.size():
		for x in String(rows[y]).length():
			if String(rows[y])[x] == "#":
				ink.append(Vector2i(x, y))
	# An outline cell next to two ink cells is laid twice, as the preview lays
	# it - which only shows while the padlock is fading.
	var edge := Color(EDGE, alpha)
	for cell: Vector2i in ink:
		for step: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			if not ink.has(cell + step):
				_fill(Rect2i(_place(cell + step, flip), Vector2i.ONE), edge)
	var colour := Color(GREEN if open else RED, alpha)
	for cell: Vector2i in ink:
		_fill(Rect2i(_place(cell, flip), Vector2i.ONE), colour)


## A padlock cell in the door's own pixels. On the turned south door it is
## mirrored inside its box, so the half turn brings it back upright.
func _place(cell: Vector2i, flip: bool) -> Vector2i:
	if flip:
		return Vector2i(PAD_AT.x + 6 - cell.x, PAD_AT.y + 7 - cell.y)
	return PAD_AT + cell


## `colour` laid over what the image already holds there ("over", straight
## alpha), in the door's own pixels.
func _fill(area: Rect2i, colour: Color) -> void:
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var at := Vector2i(x, y) + ORIGIN
			var under := _image.get_pixelv(at)
			var a := colour.a + under.a * (1.0 - colour.a)
			if a <= 0.0:
				continue
			var mixed := (colour * colour.a + under * under.a * (1.0 - colour.a)) / a
			mixed.a = a
			_image.set_pixelv(at, mixed)
