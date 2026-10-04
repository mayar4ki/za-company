extends RefCounted
## DOWN AND UP - the fall and the getting-up, two rows built from the body's own
## pixels.
##
## Picked from the Revive Lab preview (option A, Steady hands, 2026-10-04) and
## built by the preview's own generator, ported line for line: `ReviveFrames` in
## the page's first script, the `fall` and `rise` it builds. Nothing here is
## drawn. Every pixel written is a pixel the side idle frame already had, moved:
## lying is that frame's body turned a quarter anticlockwise, so the head goes
## left and the face up, centred and set down on the ground line; the crouch
## and the sitting ball are the dodge's own (tools/roll_pose.gd), so getting up
## reads in the roll's body language.
##
## One row each, side-on only, facing right like the sheet - a body lying on the
## floor has no "towards the camera", and the sprite's flip turns it round:
##
## - `fall` (row 27): the crouch, lying lifted a pixel, lying, lying.
## - `rise` (row 28): lying, sitting, the crouch, standing.
##
## build_characters.gd calls `paint()` on each character's RECOLOURED sheet,
## after the roll, the order the preview used.

const Art := preload("res://tools/character_art.gd")

const FRAME := Art.FRAME
## Where the two rows land, and the height the sheet grows to.
const ROWS := {"fall": 27, "rise": 28}
const ROWS_NEEDED := 29
## The side idle row every frame is made from.
const IDLE_SIDE := 4


## A copy of `sheet` grown to ROWS_NEEDED rows, with the fall and the rise in
## rows 27-28. Everything above is copied untouched.
static func paint(sheet: Image) -> Image:
	var out := Image.create(sheet.get_width(), ROWS_NEEDED * FRAME, false, Image.FORMAT_RGBA8)
	out.blit_rect(sheet, Rect2i(0, 0, sheet.get_width(), mini(sheet.get_height(), ROWS["fall"] * FRAME)),
		Vector2i.ZERO)
	var rows := frames(sheet)
	for name in ROWS:
		var cells: Array = rows[name]
		for k in cells.size():
			out.blit_rect(cells[k], Rect2i(0, 0, FRAME, FRAME), Vector2i(k * FRAME, ROWS[name] * FRAME))
	return out


## {fall: [4 cells], rise: [4 cells]}, each a 32 x 32 image.
static func frames(sheet: Image) -> Dictionary:
	var side := sheet.get_region(Rect2i(0, IDLE_SIDE * FRAME, FRAME, FRAME))
	var lie := _lying(side, 0)
	return {
		"fall": [_crouch(side), _lying(side, 1), lie, lie],
		"rise": [lie, _sit(side), _crouch(side), side],
	}


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
## (21-23). The roll's crouch: legs kept, shirt down one, head down two.
static func _crouch(idle: Image) -> Image:
	var c := _blank()
	_part(c, idle, 21, 23)
	_part(c, idle, 17, 20, 0, 1)
	_part(c, idle, 8, 16, 0, 2)
	return c


## The roll's ball, which sitting on the floor is: legs gone under, the shirt
## down three, the head down four.
static func _sit(idle: Image) -> Image:
	var c := _blank()
	_part(c, idle, 17, 20, 0, 3)
	_part(c, idle, 8, 16, 0, 4)
	return c


## Lying on the back: every opaque pixel of the frame turned a quarter
## anticlockwise inside its own bounding box - the top goes left, the right
## goes up - then centred on x 16 with its bottom on the ground line (y 23),
## `lift` pixels higher.
static func _lying(idle: Image, lift: int) -> Image:
	var x0 := FRAME
	var x1 := -1
	var y0 := FRAME
	var y1 := -1
	for y in FRAME:
		for x in FRAME:
			if idle.get_pixel(x, y).a > 0.0:
				x0 = mini(x0, x)
				x1 = maxi(x1, x)
				y0 = mini(y0, y)
				y1 = maxi(y1, y)
	var c := _blank()
	if x1 < 0:
		return c
	var w := x1 - x0 + 1
	var h := y1 - y0 + 1
	# JavaScript's Math.round, which the preview used: halves go up.
	var left := floori(16.0 - h / 2.0 + 0.5)
	var top := 23 - w + 1 - lift
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var px := idle.get_pixel(x, y)
			if px.a == 0.0:
				continue
			var tx := left + (y - y0)
			var ty := top + (x1 - x)
			if tx < 0 or ty < 0 or tx >= FRAME or ty >= FRAME:
				continue
			c.set_pixel(tx, ty, px)
	return c
