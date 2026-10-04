extends "res://game/bosses/big_mo/brush.gd"
## THE BELL - Big Mo's punches, announced at the scale of the room.
##
## He is the one boss drawn FRONT ON, and that costs him the thing every other
## attack in this game reads by: travel. A jab front on is the glove growing
## from `gs 5` to `gs 9` and back - four source pixels, two world pixels - so
## the wind-up, the blow and the recover all look like a man standing still.
## This supplies the travel the camera angle takes away, and it does it at
## arena scale rather than on his fist, because the fist is the one part that
## cannot move on screen.
##
## Three parts, one script, chosen by `part` the way axe_fire.gd does it - and
## the split is by SPACE, not by taste:
##
## - **ground** sits under the body: the ring tightening on the floor beneath
##   him while he loads. World pixels.
## - **burst** sits over the body: the ring and twelve spokes that leave the
##   glove on impact. World pixels too, so they grow with the zoom he is being
##   watched at instead of shrinking into a 640x360 screen.
## - **screen** hangs off a CanvasLayer: the vignette, the chevrons that arrive
##   from the edges of the screen, and the flash. VIEWPORT pixels, because the
##   edge of the screen is not a place in the room. That layer sits BELOW the
##   HUD (see game.tscn) - a flash that washes out his own health bar hides
##   the one number the player is watching while it lands.
##
## Nothing tells any of them anything. Like Ahmed's fire, each reads the
## sprite's animation, frame and flip and draws from `poses.gd`. It reads the
## frame's PROGRESS as well, which is the one thing the fire never needed: a
## chevron crossing the screen and a ring leaving a glove want something
## smoother to move on than ten frames a second. Time into the attack is
## summed from the same `dur` list the boss script derives `windup_seconds`
## from, so an effect here cannot disagree with the telegraph it is drawing -
## and no `dur` had to move to fit it.
##
## The jab is deliberately almost nothing: a bar at the foot of the screen and
## one small ring. Three hooks per combination is nine of these a fight, and
## the hook is only enormous if the two jabs before it were not.

## Which glove each attack is thrown with. The rush is a shoulder rather than a
## punch, so it has no glove to hang anything on and anchors on his chest, and
## so does the clinch, which is both arms at once. The flurry alternates, so its
## anchor is whichever glove the current frame has thrown (`_anchor`).
const ARM := {"jab": "L", "hook": "R", "uppercut": "R", "rush": "",
	"counter": "R", "clinch": "", "flurry": "L"}
const CHEST := Vector2(0.0, -13.0)

## The two that get the jab's small treatment rather than the full one: the jab
## because there are two of them before every big one, the flurry because
## there are five of them in a second.
const LIGHT := ["jab", "flurry"]

## The uppercut's floor lane, which IS its reach - big_mo.gd's UPPERCUT_REACH
## and UPPERCUT_HALF_WIDTH, read off the boss rather than restated.
const LANE_ALPHA := 0.55

## How long each piece runs after the blow lands.
const FLASH_SECONDS := 0.11
const BURST_SECONDS := 0.40
const JAB_RING_SECONDS := 0.08
const STREAK_SECONDS := 0.12

## The rush's speed lines: ONE fixed pattern rather than a fresh roll every
## frame, so the dash reads as a held streak instead of television static.
## World pixels above his feet, and alpha.
const RUSH_STREAKS := [
	[25.61, 0.0135], [17.69, 0.0262], [26.89, 0.1684], [18.60, 0.0566],
	[11.90, 0.1934], [9.85, 0.0293], [25.41, 0.1669],
]

## What the screen layer is built out of: one CHUNKth of the frame's width, so
## roughly 7 px at the 640x360 base viewport.
##
## This is the one number that cannot come from the room. Furniture of the
## frame sized in world pixels does two wrong things at once: a chevron nine
## world pixels across is nine pixels on a 640-pixel screen, which is a
## telegraph nobody can see, and it would change size with the zoom - the one
## thing something pinned to the edge of the screen must never do. A fraction
## of the frame holds the shape at every zoom and every window size.
const CHUNK := 96.0


func _draw() -> void:
	if _sprite == null or _boss == null:
		return
	var anim := _anim()
	# Only the attacks draw anything. Idle, walk, the concede and the two
	# stances - shell and open - are the same early return, which is what keeps
	# a beaten boss dark and a guarding one quiet.
	if not ARM.has(anim):
		return
	_flip = _sprite.flip_h
	var frames: Array = Poses.ANIMS[anim]
	var idx := clampi(_sprite.frame, 0, frames.size() - 1)
	var frame: Dictionary = frames[idx]
	var windup: float = Poses.windup_of(anim)
	var into := _into(frames, idx)
	# Negative until the blow lands, then seconds since. Every piece below is
	# written against this one number.
	var since := into - windup
	var loading := clampf(into / maxf(windup, 0.001), 0.0, 1.0)
	match part:
		"ground":
			_draw_ground(anim, since, loading)
		"burst":
			_draw_burst(anim, frame, since)
		"screen":
			_draw_screen(anim, since, loading)


## Where the blow comes from. The rush is a shoulder rather than a punch, so it
## has no glove to hang anything on and anchors on his chest.
func _anchor(anim: String, frame: Dictionary) -> Vector2:
	var key: String = ARM[anim]
	if anim == "flurry":
		key = "R" if float(frame.get("R", {}).get("gs", 0)) > \
			float(frame.get("L", {}).get("gs", 0)) else "L"
	if key == "" or frame.get(key, {}).is_empty():
		return CHEST
	return _glove(frame, key)


# --- ground: under the body --------------------------------------------------


## The floor tightening under him as he loads. The jab does not get one; see
## the header for why it gets so little. The uppercut gets a LANE instead of a
## ring, and that is half its tell: the ring says "get out of the circle" and
## the lane says "get off the line", which are the two opposite answers.
func _draw_ground(anim: String, since: float, loading: float) -> void:
	if since >= 0.0 or anim in LIGHT:
		return
	if anim == "uppercut":
		_lane(loading)
		return
	_ring(0.0, 0.0, 12.0 + 6.0 * loading, 0.4, Color(HOT, 0.2 + 0.5 * loading))


## The uppercut's reach drawn on the floor, filling from his feet outwards as
## he loads - edges first, so it reads as a lane from the first frame.
func _lane(loading: float) -> void:
	var k: Dictionary = (_boss.get_script() as GDScript).get_script_constant_map()
	var reach: float = k["UPPERCUT_REACH"]
	var half: float = k["UPPERCUT_HALF_WIDTH"]
	var back: float = k["UPPERCUT_BACK"]
	var col := Color(HOT, 0.15 + LANE_ALPHA * loading)
	var tip := -back + (reach + back) * loading
	var x := -back
	while x <= tip:
		_put(x, -half, col)
		_put(x, half, col)
		if int(x) % 4 == 0:
			_put(x, 0.0, Color(col, col.a * 0.5))
		x += 1.0
	for y in range(int(-half), int(half) + 1):
		_put(tip, float(y), col)


# --- burst: over the body ----------------------------------------------------


## What leaves the glove on impact. Anchored on the glove the CURRENT frame
## draws, so the ring follows his fist back in through the recover rather than
## hanging in the air where the blow was.
func _draw_burst(anim: String, frame: Dictionary, since: float) -> void:
	if since < 0.0:
		return
	var at := _anchor(anim, frame)
	if anim in LIGHT:
		# The flurry rings once per punch: time since the latest one, on the
		# same 0.2 s grid poses.gd throws them on.
		var s := fmod(since, 0.2) if anim == "flurry" else since
		if s < JAB_RING_SECONDS:
			var jk := s / JAB_RING_SECONDS
			_ring(at.x, at.y, 4.0 + 40.0 * jk, 1.0, Color(BONE, 1.0 - jk))
		return
	if since >= BURST_SECONDS:
		return
	var k := since / BURST_SECONDS
	var col := HOT.lerp(GLOVE, k)
	for i in 12:
		var th := TAU * float(i) / 12.0
		var r0 := 5.0 + 46.0 * (1.0 - pow(1.0 - k, 2.0))
		var r1 := r0 + 12.0 * (1.0 - k)
		_seg(at.x + cos(th) * r0, at.y + sin(th) * r0,
			at.x + cos(th) * r1, at.y + sin(th) * r1, Color(col, (1.0 - k) * 0.9))
	_ring(at.x, at.y, 4.0 + 50.0 * (1.0 - pow(1.0 - k, 2.5)), 1.0,
		Color(col, (1.0 - k) * 0.95))


# --- screen: the room itself -------------------------------------------------


func _draw_screen(anim: String, since: float, loading: float) -> void:
	var view := get_viewport_rect().size
	var xf := get_viewport().get_canvas_transform()
	# His feet in viewport pixels, and the two scales this layer draws at.
	# `chunk` is a piece of the frame - see CHUNK. `world` is a world pixel as
	# seen at the current zoom, which the rush's speed lines want instead:
	# they span the whole frame but they are drawn across HIM, so their spacing
	# belongs to the room even though their length does not.
	var at := xf * _boss.global_position
	var chunk := maxf(1.0, roundf(view.x / CHUNK))
	var world := maxf(1.0, xf.get_scale().x)

	if since < 0.0:
		if anim in LIGHT:
			# The jab's entire announcement, and the flurry's.
			draw_rect(Rect2(roundf(at.x - chunk * 10.0), roundf(view.y - chunk * 2.0),
				chunk * 20.0 * loading, chunk), Color(GLOVE, 0.25 + 0.4 * loading))
			return
		_vignette(view, chunk, 0.06 + 0.3 * loading)
		if anim == "uppercut":
			_rising(at, view, chunk, world, loading)
		else:
			_chevrons(at, view, chunk, world, loading)
	else:
		# The jab's impact is the small ring in `burst`, and nothing else.
		if anim in LIGHT:
			return
		if since < FLASH_SECONDS:
			draw_rect(Rect2(Vector2.ZERO, view),
				Color(HOT, 0.55 * (1.0 - since / FLASH_SECONDS)))

	# The dash's speed lines run from the first RUNNING frame through to just
	# after he arrives - one continuous streak across the whole charge. Not
	# through the crouch before it: he stands still for that, and streaks on a
	# body that is not moving would say he had already gone.
	if anim == "rush" and since < STREAK_SECONDS \
			and since >= Poses.tell_of("rush") - Poses.windup_of("rush"):
		for streak in RUSH_STREAKS:
			draw_rect(Rect2(0.0, roundf(at.y - world * float(streak[0])), view.x, world),
				Color(BONE, float(streak[1])))


## Red pulled in at both edges. Drawn as columns a world pixel wide rather than
## as a gradient, so it bands WITH the room's pixels instead of across them.
func _vignette(view: Vector2, chunk: float, alpha: float) -> void:
	var span := view.x * 0.3
	var x := 0.0
	while x < span:
		var col := Color(GLOVE_LO, alpha * (1.0 - x / span))
		if col.a > FAINT:
			draw_rect(Rect2(x, 0.0, chunk, view.y), col)
			draw_rect(Rect2(view.x - x - chunk, 0.0, chunk, view.y), col)
		x += chunk


## Two of them, crossing the screen through the wind-up and meeting at his
## chest as the blow lands. This IS the telegraph: the hook's is 0.70 s wide,
## and its first 0.32 s is the punish window.
func _chevrons(at: Vector2, view: Vector2, chunk: float, world: float,
		loading: float) -> void:
	for side: float in [-1.0, 1.0]:
		var x0 := at.x + side * view.x * 0.52 * (1.0 - loading)
		# They MEET at his chest, which is a place in the room - 13 world pixels
		# up - even though the arrows themselves are cut from the frame.
		var y0 := at.y - world * 13.0
		for i in 9:
			var alpha := (0.5 - float(i) * 0.045) * loading
			if alpha <= FAINT:
				continue
			var d := float(i) * chunk
			var col := Color(HOT, alpha)
			var x := roundf(x0 - side * d)
			draw_rect(Rect2(x, roundf(y0 - d * 0.85), chunk, chunk), col)
			draw_rect(Rect2(x, roundf(y0 + d * 0.85), chunk, chunk), col)


## The uppercut's chevrons: the hook's two, turned on end. They arrive from the
## top and bottom of the frame instead of the sides, and in BONE instead of HOT,
## so the two 0.70 s wind-ups never share a telegraph - the direction the arrows
## travel is the direction the punch does, and the direction you step is across
## it.
func _rising(at: Vector2, view: Vector2, chunk: float, world: float,
		loading: float) -> void:
	var cx := at.x
	var cy := at.y - world * 13.0
	for side: float in [-1.0, 1.0]:
		var y0 := cy + side * view.y * 0.55 * (1.0 - loading)
		for i in 9:
			var alpha := (0.5 - float(i) * 0.045) * loading
			if alpha <= FAINT:
				continue
			var d := float(i) * chunk
			var col := Color(BONE, alpha)
			var y := roundf(y0 + side * d)
			draw_rect(Rect2(roundf(cx - d * 0.85), y, chunk, chunk), col)
			draw_rect(Rect2(roundf(cx + d * 0.85), y, chunk, chunk), col)
