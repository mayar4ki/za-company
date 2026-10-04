extends RefCounted
## THE TUMBLE ROLL - the dodge's three rows, built from the body's own pixels.
##
## Picked from the Dodge Lab preview (option A, 2026-10-04) and built by the
## preview's own generator, ported line for line: `DodgeFrames` in the page's
## first script. Nothing here is drawn. Every pixel written is a pixel the idle
## frame already had, moved - the legs, the shirt and the head lifted out by
## row and set down lower, or the head-and-shirt ball turned over inside its
## box - so a roll is whatever the character standing there looks like.
##
## Four frames per facing, 0.08 s each: a crouch, then the ball going over.
## Side-on the ball turns a quarter at a time inside its 12 x 12 box. Toward
## or away from the camera it cannot turn round, so it turns OVER: the crown
## (the back of the head, off the up row), the crown upside down, then the face
## coming up (down) or the crown again (up).
##
## build_characters.gd calls `paint()` on each character's RECOLOURED sheet,
## never on the source, and that order is the one the preview used. The
## recolour reshapes as well as recolours (curls grow from the top of the hair,
## a beard is found through the eyes), so a ball turned before the recolour is
## not the ball the preview showed.

const Art := preload("res://tools/character_art.gd")

const FRAME := Art.FRAME
## Where the three facings land, and the height the sheet grows to.
const ROWS := {"down": 24, "up": 25, "side": 26}
const ROWS_NEEDED := 27
## The idle row each facing's body is lifted from.
const IDLE := {"down": 0, "up": 2, "side": 4}
## The square the ball fills and turns over inside: x 10-21, y 12-23, its
## bottom on the ground line every 32 px cell stands on.
const BOX_X := 10
const BOX_Y := 12
const BOX := 12


## A copy of `sheet` grown to ROWS_NEEDED rows, with the roll painted into rows
## 24-26 from its own idle rows. Rows 0-23 are copied untouched.
static func paint(sheet: Image) -> Image:
	var out := Image.create(sheet.get_width(), ROWS_NEEDED * FRAME, false, Image.FORMAT_RGBA8)
	out.blit_rect(sheet, Rect2i(0, 0, sheet.get_width(), mini(sheet.get_height(), ROWS["down"] * FRAME)),
		Vector2i.ZERO)
	for dir in ROWS:
		var cells := frames(sheet, dir)
		for k in cells.size():
			out.blit_rect(cells[k], Rect2i(0, 0, FRAME, FRAME), Vector2i(k * FRAME, ROWS[dir] * FRAME))
	return out


## The four frames of one facing, each a 32 x 32 cell.
static func frames(sheet: Image, dir: String) -> Array[Image]:
	var idle := _cell(sheet, IDLE[dir])
	var ball := _ball(idle)
	if dir == "side":
		return [_crouch(idle), _turn(ball, 1), _turn(ball, 2), _turn(ball, 3)]
	var crown := _ball(_cell(sheet, IDLE["up"]))
	var last := ball if dir == "down" else crown
	return [_crouch(idle), crown, _flip(crown), last]


static func _cell(sheet: Image, row: int) -> Image:
	return sheet.get_region(Rect2i(0, row * FRAME, FRAME, FRAME))


static func _blank() -> Image:
	return Image.create(FRAME, FRAME, false, Image.FORMAT_RGBA8)


## Rows y0..y1 of `src` into `dst`, moved by (dx, dy); opaque pixels only, and
## a later part lands over an earlier one.
static func _part(dst: Image, src: Image, y0: int, y1: int, dx := 0, dy := 0) -> void:
	for y in range(y0, y1 + 1):
		for x in FRAME:
			var c := src.get_pixel(x, y)
			if c.a == 0.0:
				continue
			var tx := x + dx
			var ty := y + dy
			if tx < 0 or ty < 0 or tx >= FRAME or ty >= FRAME:
				continue
			dst.set_pixel(tx, ty, c)


## The body in an idle cell is a head (rows 8-16), a shirt (17-20) and legs
## (21-23). A crouch keeps the legs, drops the shirt one and the head two.
static func _crouch(idle: Image) -> Image:
	var c := _blank()
	_part(c, idle, 21, 23)
	_part(c, idle, 17, 20, 0, 1)
	_part(c, idle, 8, 16, 0, 2)
	return c


## The ball: legs tucked away, the shirt under the head, sitting on the ground.
static func _ball(idle: Image) -> Image:
	var c := _blank()
	_part(c, idle, 17, 20, 0, 3)
	_part(c, idle, 8, 16, 0, 4)
	return c


## The ball's box turned `quarters` quarter turns clockwise. Only the box is
## carried over, and the ball is all inside it.
static func _turn(src: Image, quarters: int) -> Image:
	var out := _blank()
	for y in BOX:
		for x in BOX:
			var sx := x
			var sy := y
			for _k in quarters & 3:
				var t := sx
				sx = sy
				sy = BOX - 1 - t
			out.set_pixel(BOX_X + x, BOX_Y + y, src.get_pixel(BOX_X + sx, BOX_Y + sy))
	return out


## The ball's rows mirrored top to bottom: upside down, still on the ground.
static func _flip(src: Image) -> Image:
	var out := _blank()
	var y1 := BOX_Y + BOX - 1
	for y in range(BOX_Y, y1 + 1):
		for x in FRAME:
			out.set_pixel(x, BOX_Y + y1 - y, src.get_pixel(x, y))
	return out
