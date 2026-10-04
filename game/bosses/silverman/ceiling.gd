extends Node2D
## THE GLASS CEILING - his sixth thing, picked off the second attack preview.
## He looks up, and the shadows of the panes overhead spread across the floor
## round you in a checkerboard. Half of them come down, then the other half:
## you wait for the first wave and step into a square it has just emptied.
##
## Shipped as previewed. Every number and every drawing call below is the
## preview's, in the preview's order, because the picture that was picked is
## the spec; the floor and the panes were diffed against it pixel for pixel.
##
## **It lives in the room, not on him.** The grid is where you stood when he
## looked up, and it stays there whatever he does next - copy.gd's reason for
## being parented to the room.
##
## **And its floor is drawn as one-pixel rows, each in the room's depth sort at
## its own height**, because the penthouse rug is pinned at its top edge so
## that everyone standing on it draws after it - and so does anything else
## sorted below that edge. One floor node sorted at the grid's top edge was
## tried in the running game and the rug painted straight over it. A row at its
## own y draws after the rug where the row is on the rug, and before anybody
## whose feet are on or below it, since nothing of a body is drawn below its
## own feet: checked with three bodies standing in the grid, on and off the
## rug. This node is y-sorted, so its rows join the room's sort as if they were
## props. Each frame the floor is recorded once, in the preview's drawing
## order, and every row draws only its own runs of it.
##
## Three layers, split by space like glare.gd and prism.gd. The rows draw the
## floor: the shadows, then the white of a pane landing and the cracks it
## leaves. `Air`, at z 1, draws what is above everybody: the panes falling, the
## grit off the ceiling and the shards. `Screen`, on CanvasLayer 1 under the
## HUD, draws the faint flash as each wave lands.
##
## It is not a body - no group, no health, no collision - and it hurts nobody.
## The blow is the boss's, dealt on his own cycle off the same `cells()` and
## the same `falls()`, so the squares you see come down are the squares that
## hit, at the moment they hit.

const Poses := preload("res://game/bosses/silverman/poses.gd")
const Px := preload("res://game/bosses/silverman/pixels.gd")

## The preview's own numbers. Five panes by three, each 40 x 28, centred on you
## as he looks up (silverman.gd moves the grid off a wall rather than cut it).
const CELL := Vector2(40, 28)
const COLS := 5
const ROWS := 3
## A shadow darkens for this long before its pane lands, and the pane is seen
## for the last FALL of it, dropping from LIFT px up.
const SHADOW := 0.8
const FALL := 0.12
const LIFT := 70.0
## Grit stops falling off the ceiling this long before the pane does.
const GRIT_STOPS := 0.15
## What a landed pane leaves on the floor: a white flash, then cracks and
## glitter fading out.
const LANDED := 0.9
const WHITE := 0.15
## The flash on the frame as each wave lands.
const FLASH := 0.1
const FLASH_SECONDS := 0.08

## His ramp, and the outline's near-black for the shadows. No hue: the panes
## are the penthouse's own glass.
const O := Color("07080c")
const M := Color("545d6e")
const S := Color("8c97a8")
const L := Color("c3ccd8")
const W := Color("eef4fb")

## Fields of one particle, by index: grit falls straight down onto its square,
## shards jump off a landed pane and settle on the floor.
enum { PX, PY, PZ, VX, VY, VZ, GRAV, LIFE, MAX, STAY, COL, LANDS }

var _boss: Node2D
var _has_boss := false
var _cells: Array[Dictionary] = []
var _falls: Array[float] = []
## Seconds since he looked up.
var _t := 0.0
## When he gave in, if he did before every pane was down: nothing due after it
## falls, and its shadows go with him.
var _cut := INF
var _fallen := [false, false]
var _flash := 0.0
var _parts: Array = []
var _air: Node2D
var _screen: Node2D
var _checkers := {}
## The floor, one row of world pixels per node, and what each row draws this
## frame: row y -> [[SOLID, x, width, colour] or [DOTS, x, width, colour, kind]].
var _strips: Array[Node2D] = []
var _rows := {}

enum { SOLID, DOTS }


## The grid, square by square: each one's rect in the world and which wave it
## falls in. A checkerboard, so every square of the first wave has the second
## wave on all four sides of it. silverman.gd hits with this very list.
static func cells(origin: Vector2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for j in ROWS:
		for i in COLS:
			out.append({
				"rect": Rect2(origin + Vector2(i * CELL.x, j * CELL.y), CELL),
				"wave": (i + j) % 2,
			})
	return out


## When each wave lands, in seconds after he looks up: the first on his impact
## frame, the second as that held frame ends. Off his sheet's own row, so the
## picture, the panes and the blows cannot drift apart.
static func falls() -> Array[float]:
	var first := Poses.windup_of("ceiling")
	var hold := 0.0
	for frame in Poses.ANIMS["ceiling"]:
		if frame.get("impact", false):
			hold = frame["dur"]
	return [first, first + hold]


func _ready() -> void:
	# The rows below join the room's depth sort one by one.
	y_sort_enabled = true
	# The dither is a 2 x 2 texture repeated over the world's own pixel grid;
	# every row inherits both settings.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_air = Node2D.new()
	_air.name = "Air"
	_air.z_index = 1
	_air.draw.connect(_draw_air)
	add_child(_air)
	var layer := CanvasLayer.new()
	layer.name = "Flash"
	layer.layer = 1
	add_child(layer)
	_screen = Node2D.new()
	_screen.draw.connect(_draw_screen)
	layer.add_child(_screen)


## Everything it is ever told, once, after it is in the room: who looked up (or
## nobody, for a picture with no fight behind it) and where the grid's corner is.
func cast(boss: Node2D, origin: Vector2) -> void:
	_boss = boss
	_has_boss = boss != null
	_cells = cells(origin)
	_falls = falls()
	global_position = Vector2.ZERO
	# A row at its own y: after the rug where the row is on the rug (a tie goes
	# to whatever was in the room first), and before anybody whose feet are on
	# or below it - nothing of a body is drawn below its own feet.
	var top := int(origin.y)
	for row in int(CELL.y) * ROWS:
		var strip := Node2D.new()
		strip.position = Vector2(0.0, top + row)
		strip.draw.connect(_draw_row.bind(strip, top + row))
		add_child(strip)
		_strips.append(strip)


func _process(delta: float) -> void:
	_t += delta
	if _cut == INF and _gave_in():
		_cut = _t
	for wave in 2:
		var at := _falls[wave]
		if at > _cut:
			continue
		if _t > at - SHADOW and _t < at - GRIT_STOPS and randf() < 0.5:
			_grit(wave)
		if not _fallen[wave] and _t >= at:
			_fallen[wave] = true
			_land(wave)
	_tick(delta)
	_flash = maxf(_flash - delta, 0.0)
	if _done():
		queue_free()
		return
	_record()
	for strip in _strips:
		strip.queue_redraw()
	_air.queue_redraw()
	_screen.queue_redraw()


func _gave_in() -> bool:
	if not _has_boss:
		return false
	return not is_instance_valid(_boss) or bool(_boss.get("has_conceded"))


## Over once the last pane due has landed and settled, and the last shard with it.
func _done() -> bool:
	if not _parts.is_empty():
		return false
	var last := 0.0
	for wave in 2:
		if _falls[wave] <= _cut:
			last = _falls[wave] + LANDED
	return _t >= maxf(last, minf(_cut, _falls[1]))


# --- the particles ---------------------------------------------------------------


func _grit(wave: int) -> void:
	var mine := _cells.filter(func(c: Dictionary) -> bool: return c["wave"] == wave)
	var r: Rect2 = mine.pick_random()["rect"]
	_spawn(r.position.x + randf_range(3, r.size.x - 3), r.position.y + randf_range(3, r.size.y - 3),
		randf_range(40, 80), 0.0, 0.0, -randf_range(90, 140), 0.0, 1.0, 1.0, 0.06,
		[L, S].pick_random())


func _land(wave: int) -> void:
	_flash = FLASH_SECONDS
	for c in _cells:
		if c["wave"] != wave:
			continue
		var r: Rect2 = c["rect"]
		for _k in 9:
			var life := randf_range(0.9, 1.4)
			_spawn(r.position.x + randf_range(2, r.size.x - 2), r.position.y + randf_range(2, r.size.y - 2),
				randf_range(1, 8), randf_range(-55, 55), randf_range(-25, 25), randf_range(40, 110),
				330.0, life, 1.4, 0.5, [W, L, L, S].pick_random())


func _spawn(x: float, y: float, z: float, vx: float, vy: float, vz: float, grav: float,
		life: float, most: float, stay: float, col: Color) -> void:
	_parts.append([x, y, z, vx, vy, vz, grav, life, most, stay, col, false])


## The preview's particle step, field for field: a body in the air falls under
## its own gravity and, on reaching the floor, stops and lingers `STAY`.
func _tick(delta: float) -> void:
	for p in _parts:
		p[PX] += p[VX] * delta
		p[PY] += p[VY] * delta
		if p[GRAV] != 0.0 or p[VZ] != 0.0 or p[PZ] != 0.0:
			p[VZ] -= p[GRAV] * delta
			p[PZ] += p[VZ] * delta
			if p[PZ] <= 0.0 and not p[LANDS]:
				p[PZ] = 0.0
				p[LANDS] = true
				p[LIFE] = minf(p[LIFE], p[STAY])
				p[VX] = 0.0
				p[VY] = 0.0
				p[VZ] = 0.0
				p[GRAV] = 0.0
		p[LIFE] -= delta
	_parts = _parts.filter(func(p: Array) -> bool: return p[LIFE] > 0.0)


# --- floor: the shadows, and what a pane leaves ---------------------------------


## The whole floor for this frame, in the preview's order, filed by row.
func _record() -> void:
	_rows.clear()
	for c in _cells:
		var at: float = _falls[c["wave"]]
		if _t >= at or at > _cut:
			continue
		var k := _ramp(_t, at - SHADOW, at)
		if k <= 0.0:
			continue
		var r: Rect2 = c["rect"]
		_dots(r.position + Vector2.ONE, r.size - Vector2(2, 2), O, 0.3 + 0.5 * k, 25 if k < 0.55 else 50)
		var a := 0.3 + 0.55 * k
		var x0 := r.position.x + 1.0
		var y0 := r.position.y + 1.0
		var x1 := r.end.x - 2.0
		var y1 := r.end.y - 2.0
		_line(Vector2(x0, y0), Vector2(x1, y0), O, a)
		_line(Vector2(x0, y1), Vector2(x1, y1), O, a)
		_line(Vector2(x0, y0), Vector2(x0, y1), O, a)
		_line(Vector2(x1, y0), Vector2(x1, y1), O, a)
		if k > 0.75:
			_line(r.position + Vector2(2, 2), Vector2(r.end.x - 3.0, r.position.y + 2.0), L,
				0.35 + 0.25 * sin(_t * 50.0))
	for wave in 2:
		if not _fallen[wave]:
			continue
		var age := _t - _falls[wave]
		if age >= LANDED:
			continue
		for c in _cells:
			if c["wave"] == wave:
				_landed(c["rect"], age)


## A pane on the floor: white for an instant, then a crack and seven glints
## fading out over LANDED.
func _landed(r: Rect2, age: float) -> void:
	var x := r.position.x
	var y := r.position.y
	var w := int(r.size.x)
	var h := int(r.size.y)
	if age < WHITE:
		_fill(Vector2(x + 1, y + 1), Vector2(w - 2, h - 2), W, 0.85 * (1.0 - age / WHITE))
	var k := 1.0 - age / LANDED
	for i in 7:
		var at := Vector2(x + 4 + ((i * 13 + 5) % (w - 8)), y + 3 + ((i * 7 + 3) % (h - 6)))
		_px(at, L if i % 2 else W, 0.8 * k * (0.6 + 0.4 * sin(age * 30.0 + i)))
	_line(Vector2(x + 6, y + 4), Vector2(x + 17, y + 13), S, 0.5 * k)
	_line(Vector2(x + 17, y + 13), Vector2(x + 31, y + 9), S, 0.5 * k)
	_line(Vector2(x + 17, y + 13), Vector2(x + 22, y + h - 4), S, 0.45 * k)


## One row of the floor: its own runs, in the order they were recorded.
func _draw_row(strip: Node2D, y: int) -> void:
	for op in _rows.get(y, []):
		var area := Rect2(op[1], 0.0, op[2], 1.0)
		if op[0] == SOLID:
			strip.draw_rect(area, op[3])
		else:
			# The texture's region is the WORLD row, so the dither lines up on
			# the room's own pixel grid whatever row draws it.
			strip.draw_texture_rect_region(_checker(op[4]), area, Rect2(op[1], y, op[2], 1.0),
				op[3], false, false)


# --- air: the panes coming down, the grit and the shards ------------------------


func _draw_air() -> void:
	_air.draw_set_transform(-_air.global_position)
	for c in _cells:
		var at: float = _falls[c["wave"]]
		if at > _cut:
			continue
		var f := _ramp(_t, at - FALL, at)
		if f <= 0.0 or f >= 1.0:
			continue
		var r: Rect2 = c["rect"]
		var lift := roundf(LIFT * (1.0 - f) * (1.0 - f))
		var x := r.position.x + 1.0
		var y := r.position.y + 1.0 - lift
		var w := r.size.x - 2.0
		var h := r.size.y - 2.0
		_rect_on(_air, Vector2(x, y), Vector2(w, h), M, 0.88)
		_rect_on(_air, Vector2(x, y), Vector2(w, roundf(h * 0.35)), S, 0.5)
		Px.line(_air, Vector2(x + 5, y + h - 2), Vector2(x + 15, y + 1), W, 0.75)
		Px.line(_air, Vector2(x + 9, y + h - 2), Vector2(x + 19, y + 1), L, 0.55)
		Px.line(_air, Vector2(x + 26, y + h - 2), Vector2(x + 32, y + 6), W, 0.4)
		Px.line(_air, Vector2(x, y), Vector2(x + w - 1, y), L, 0.9)
		Px.line(_air, Vector2(x - 1, y - 1), Vector2(x + w, y - 1), O, 1.0)
		Px.line(_air, Vector2(x - 1, y + h), Vector2(x + w, y + h), O, 1.0)
		Px.line(_air, Vector2(x - 1, y - 1), Vector2(x - 1, y + h), O, 1.0)
		Px.line(_air, Vector2(x + w, y - 1), Vector2(x + w, y + h), O, 1.0)
	for p in _parts:
		Px.px(_air, Vector2(p[PX], p[PY] - p[PZ]), p[COL], minf(1.0, p[LIFE] / p[MAX] * 1.5))


# --- the frame ---------------------------------------------------------------------


func _draw_screen() -> void:
	if _flash > 0.0:
		_screen.draw_rect(Rect2(Vector2.ZERO, _screen.get_viewport_rect().size),
			Color(W, FLASH * _flash / FLASH_SECONDS))


# --- drawing ---------------------------------------------------------------------


func _rect_on(ci: CanvasItem, at: Vector2, size: Vector2, col: Color, alpha: float) -> void:
	if alpha <= Px.FAINT:
		return
	ci.draw_rect(Rect2(at.round(), size.round()), Color(col, minf(alpha, 1.0)))


# --- recording the floor -------------------------------------------------------
# pixels.gd's dot, line and rect, filed by row instead of drawn. A line is the
# same Bresenham, so the same pixels; a level one is one run, which is the
# same pixels drawn once each.


func _run(y: int, op: Array) -> void:
	if not _rows.has(y):
		_rows[y] = []
	_rows[y].append(op)


func _px(at: Vector2, col: Color, alpha: float) -> void:
	if alpha <= Px.FAINT:
		return
	var p := at.round()
	_run(int(p.y), [SOLID, p.x, 1.0, Color(col, minf(alpha, 1.0))])


func _fill(at: Vector2, size: Vector2, col: Color, alpha: float) -> void:
	if alpha <= Px.FAINT:
		return
	var r := Rect2(at.round(), size.round())
	for y in range(int(r.position.y), int(r.end.y)):
		_run(y, [SOLID, r.position.x, r.size.x, Color(col, minf(alpha, 1.0))])


## A dithered fill on the room's own pixel grid: 50 is a checker, 25 one pixel
## in four.
func _dots(at: Vector2, size: Vector2, col: Color, alpha: float, kind: int) -> void:
	if alpha <= Px.FAINT or size.x <= 0.0 or size.y <= 0.0:
		return
	var r := Rect2(at.round(), size.round())
	for y in range(int(r.position.y), int(r.end.y)):
		_run(y, [DOTS, r.position.x, r.size.x, Color(col, minf(alpha, 1.0)), kind])


func _line(a: Vector2, b: Vector2, col: Color, alpha: float) -> void:
	if alpha <= Px.FAINT:
		return
	var c := Color(col, minf(alpha, 1.0))
	var x0 := roundi(a.x)
	var y0 := roundi(a.y)
	var x1 := roundi(b.x)
	var y1 := roundi(b.y)
	if y0 == y1:
		_run(y0, [SOLID, float(mini(x0, x1)), float(absi(x1 - x0) + 1), c])
		return
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	for _guard in 2000:
		_run(y0, [SOLID, float(x0), 1.0, c])
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy


func _checker(kind: int) -> ImageTexture:
	if not _checkers.has(kind):
		var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		img.set_pixel(0, 0, Color.WHITE)
		if kind == 50:
			img.set_pixel(1, 1, Color.WHITE)
		_checkers[kind] = ImageTexture.create_from_image(img)
	return _checkers[kind]


## The preview's `ramp`, in its own arithmetic, so a fade crosses a threshold
## on the same frame here as it did there.
static func _ramp(t: float, a: float, b: float) -> float:
	return clampf((t - a) / (b - a), 0.0, 1.0)
