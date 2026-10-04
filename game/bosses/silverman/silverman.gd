extends "res://game/bosses/boss_base.gd"
## SILVERMAN. The last man in the building, and the first one in it who is not
## pretending to be a person: no suit, no face, no seams - a humanoid poured
## out of the same metal the penthouse is specified in.
##
## **His body never changes shape**, and every attack below obeys that rather
## than working around it. A row in his poses is the same eighteen columns of
## ASCII as his idle, at a different height and a different rung of the ramp;
## everything that makes an attack legible is drawn live beside him. So the
## whole fight cost two rows of art, and neither of them is a picture of a
## weapon.
##
## ## The ladder
##
## Three phases, DESIGN.md's own, and each one ADDS without removing - the
## fight gets more crowded rather than faster, which is the only escalation
## available to a man who never hurries:
##
## - **The Handshake** (288 -> 192 solo): the crossing and the glare. Standard
##   interrupts. The fair phase.
## - **The Meeting** (192 -> 96): the split arrives. One interrupt, then a long
##   lockout - you get one.
## - **The Performance Review** (96 -> 0): the room goes cold, standing near
##   him costs health on its own, and the prism arrives. Fully
##   uninterruptible.
##
## A phase is announced by `herald`, which is his version of adjusting his
## cuffs: he has no cuffs, so what he does instead is spend a rung of his own
## shine on the room (glare.gd draws it) and shake it. Crossing a threshold
## also clears both cooldowns, so an escalation ARRIVES rather than being
## something you notice a few seconds later.
##
## ## The five things he does
##
## - **the crossing** (`DASH`) - locomotion that now hurts. He passes THROUGH
##   you, once per crossing, and it is the only thing he has that is not on the
##   attack cycle at all.
## - **the glare** - the room whites out and the light leaves him as a CROSS:
##   a band left and right along the floor, and two shorter arms straight up
##   and down, all travelling through his recover. You step off both lines -
##   diagonal to him is the only safe place near him; you cannot outrun it.
## - **the split** - he divides, and the copy walks at you while he stands
##   still. See copy.gd; it is drawn from a sheet row he never plays.
## - **the prism** - he draws the city's light in off the window behind him and
##   sweeps it across the room as a white beam, 140 degrees of it. A fan on the
##   floor shows the whole arc for the full second before it fires, and the
##   side it does not cover is the answer. See prism.gd.
## - **the cold room** - an aura, not an attack. No telegraph, nothing to
##   interrupt, and it sits OUTSIDE the grace window because a drain is not a
##   blow.
##
## What he deliberately has NOT got is a melee swing. Nothing here is thrown
## with a hand: he glides through you, blinds you, divides, and freezes the air
## near him. A player standing on him is answered by the glare, whose band
## starts inside its own reach.

const Poses := preload("res://game/bosses/silverman/poses.gd")
const Copy := preload("res://game/bosses/silverman/copy.gd")

## MEDIUM numbers. The base scales an attack's damage when it is chosen; the
## crossing and the cold room are not on the cycle, so they scale their own
## (see `_ready`).
##
## Raised by about half on the 2026-10-03 playtest, which found the last fight in
## the building the easiest of the three (was glare 16, split 12, prism 16,
## crossing 18). Every big blow he has is now a heavy's worth - 24 - and the
## copy, the one that homes, stays the smaller number.
const DAMAGE := {"glare": 24, "split": 18, "prism": 24}
const DASH_DAMAGE := 24

## How much of a wind-up can still be interrupted, by phase, and how long an
## interrupt then locks him out for. This IS the ladder: the base has one dial
## for each, and setting them per phase as an attack begins is the only way to
## have the same attack narrow over the fight.
##
## 0.0 is never interruptible, not always: `_interruptible()` asks whether the
## wind-up's progress is still BELOW this, so a lower number is a more
## committed boss. The third phase is 0.0, which is DESIGN.md's "fully
## uninterruptible" with no special case anywhere to make it so.
const COMMIT := {1: 0.65, 2: 0.40, 3: 0.0}
const LOCKOUT := {1: 1.2, 2: 3.0, 3: 3.0}

## Phase boundaries as fractions of his own max, so retuning his health in the
## scene moves the phases with it instead of stranding them at 128 and 64.
const PHASE_TWO := 2.0 / 3.0
const PHASE_THREE := 1.0 / 3.0

## The dash, beat by beat: seconds held, and where he is along the crossing in
## world px from where he started. It is a POSITION CURVE and nothing else -
## the sprite holds one unchanging frame for all 0.5 s of it, because a liquid
## that deforms while it travels was drawn, looked at and dropped.
##
## `moving` is what smear.gd draws on. The first and last two beats are the
## coil and the arrival, where he is standing still: three pixels back before
## he goes and two past the mark on the way in are the only anticipation this
## boss has, and they are position, so his shape is still never touched.
##
## `hit` is the pass-through. All three travel beats carry it and a flag keeps
## it to ONE blow per crossing, so where the player is standing along the
## crossing decides when it lands rather than whether it does. The coil and the
## arrival are harmless, which is what keeps it a pass-through and not a
## 0.5 s hitbox parked on top of you.
const DASH := [
	{"dur": 0.12, "x": -3.0, "moving": false},
	{"dur": 0.06, "x": 8.0, "moving": true, "hit": true},
	{"dur": 0.06, "x": 36.0, "moving": true, "hit": true},
	{"dur": 0.06, "x": 60.0, "moving": true, "hit": true},
	{"dur": 0.08, "x": 74.0, "moving": false},
	{"dur": 0.12, "x": 72.0, "moving": false},
]

## Closer than this and he answers with the room instead - the crossing is for
## a player who has made ground.
##
## **It has to be well inside the crossing's own 72 px**, and this is the one
## number the pass-through turned into a bug: at the 96 it was while the dash
## was pure locomotion, he triggered at 96 and travelled 72, so he ALWAYS
## stopped 24 px short and could never once pass through anybody. A gap-closer
## may stop short. A blow may not.
##
## At 40 the bands are: inside 40 he glares, 40 to ~86 he crosses THROUGH you,
## and past that he crosses and lands short - which is the old locomotion,
## still there, for a player who has backed off further than he can reach.
@export var dash_range := 40.0
## Short enough that backing off buys a breath and not a rest: a kiting player
## is crossed again before they have made their ground back. Was 2.4.
@export var dash_cooldown := 1.4
## How close the crossing passes to count as passing THROUGH. His own body
## radius plus a little, so clipping his shoulder is a hit and standing a step
## off the line is not.
@export var dash_reach := 12.0

## The glare's band: where its front is on the frame the light lands, how far
## it crosses, and the slack that puts a body on the edge of it inside it.
const GLARE_START := 16.0
const GLARE_REACH := 140.0
const GLARE_SLACK := 6.0
## THE CROSSFIRE: the arms straight up and down, picked off the glare preview
## and shipped as previewed. Shorter than the band because the room is less
## deep than it is wide, and fired on the same frame, over the same travel, as
## part of the same glare - one glare is still one hit, whichever arm finds
## you. Each arm is a 20 px lane, the band's own width turned on its side.
const GLARE_ARM := 80.0
## Where every lane is centred: his chest's height, the Band node's own y.
const GLARE_LANE_Y := -10.0
## A body is measured along an arm at its own centre, 4 px over its origin.
const GLARE_BODY_Y := -4.0

## The cooldowns are what made him weak, more than the damage: each starts on
## the blow, so the glare's old 3.2 s left him hovering, doing nothing, for 2.5
## of every 4 s you stood on him. At 1.6 he glares every 2.4 s and the gap is
## the length of his own recover again. Was glare 3.2, split 5.0, prism 6.0.
##
## His wind-ups did NOT get shorter, and that is deliberate: they are on the
## sheet (poses.gd), every effect is drawn against them, and a boss who hits
## harder and more often owes you the same time to read each blow coming.
@export var glare_cooldown := 1.6
@export var split_cooldown := 3.0
## Closer than this and the copy would arrive before it has walked anywhere,
## so he glares instead. The split is the mid-range answer.
@export var split_min_distance := 34.0

## THE PRISM, picked off the attack preview and shipped as previewed. The beam
## opens PRISM_LEAD behind the player on the side it sweeps from - so it comes
## ONTO you rather than opening on top of you - and turns PRISM_SPREAD in
## PRISM_SWEEP seconds, alternating direction every cast.
##
## At 100 degrees a second it crosses a body 50 px out at about the player's
## own walking speed, so running ahead of it at range fails and the answer is
## the other side of him: the 220 degrees the fan never covers.
const PRISM_SPREAD := deg_to_rad(140.0)
const PRISM_LEAD := 0.35
const PRISM_SWEEP := 1.4
## Where the light leaves him, and how far a beam reaches if the room does not
## stop it first. It starts a few pixels off his chest so it never draws across
## his own body.
const PRISM_CHEST := Vector2(0.0, -20.0)
const PRISM_FROM := 6.0
const PRISM_REACH := 190.0
## Half the beam's width as a hitbox - the five white lanes in the middle of
## the nine prism.gd draws. A body is measured at its chest, 5 px up.
const PRISM_HALF := 4.0
const PRISM_BODY := Vector2(0.0, -5.0)
## How finely the arc is measured against the walls when a cast begins. The
## beam's length at any angle is read off these, so the fan, the beam and the
## hitbox all stop at one wall rather than three.
const PRISM_SAMPLES := 48

@export var prism_cooldown := 4.0

## The cold room, third phase only. A drain, so it knows its own rate and is
## metered by nothing: the grace window neither blocks it nor is opened by it.
## Was 3.0 a second.
@export var chill_radius := 34.0
@export var chill_per_second := 5.0

## World pixels of camera throw. The glare is the big one because it is the
## whole room; a phase arriving is worth more than either.
const SHAKE := {"glare": 5.0, "dash": 3.4, "prism": 3.0}
const SHAKE_SECONDS := 0.14
## The prism's, as previewed: a 3 px kick as it fires, then a 1 px hum under
## the rest of the sweep once the kick has decayed below it.
const PRISM_SHAKE_SECONDS := 0.18
const PRISM_HUM := 1.0
const PRISM_HUM_SECONDS := 0.05
const HERALD_SECONDS := 0.9
const HERALD_SHAKE := 6.0

## What he SAYS as a phase arrives, by the phase that arrived. His alone - the
## base fires spot/taunt/hurt/stagger/concede and one cue per attack, and none
## of those is "the ladder just moved".
##
## A cue per phase rather than one `herald` cue holding both lines, which is
## the same call `_begin_attack` makes with an attack id: which rung just
## arrived is the ONLY information in the line, and a cue with two lines in it
## picks between them at random and throws that away. The names are DESIGN.md's
## own for the phases. Phase one needs none - `spot` is already the line for
## the fight starting.
const PHASE_CUE := {2: "meeting", 3: "review"}

## True for the whole crossing; `dash_moving` only for the three beats he is
## actually travelling. Both public because smear.gd reads the second one and
## the tests read the first - neither is told anything.
var dashing := false
var dash_moving := false
## Seconds left of a phase announcement, counting down. Public for the same
## reason: glare.gd draws it and is told nothing.
var herald := 0.0
## The current prism's arc: where it starts and how far it turns (signed). Set
## as the cast begins and read by prism.gd, which is told nothing else.
var prism_from := 0.0
var prism_span := 0.0
## Bumped once per cast, so prism.gd can tell a new one from the last.
var prism_casts := 0

var _dash_time := 0.0
var _dash_from := Vector2.ZERO
var _dash_dir := 1.0
var _dash_cool := 0.0
## Whom this crossing has already gone through, so each is struck once.
var _dash_hits := {}
## The bodies he is crossing through, while he is crossing them - every player
## standing when he set off, since a party can be anywhere on the line. Held so
## the exceptions can be dropped again from either end - the arrival or a
## concede.
var _dash_excepted: Array[Node2D] = []
var _dash_damage := DASH_DAMAGE

var _glare_timer := 0.0
var _glare_hit := {}
var _split_timer := 0.0
var _prism_timer := 0.0
var _prism_dir := 1.0
var _prism_lengths := PackedFloat32Array()
var _chill_rate := 0.0
var _owed := 0.0
var _tier := 1

var _dash_total := _total_of(DASH)

@onready var _band: Area2D = $Band
@onready var _band_up: Area2D = $BandUp
@onready var _band_down: Area2D = $BandDown


func _ready() -> void:
	super()
	# The two things that are not on the attack cycle scale themselves, where
	# the base scales an attack's damage as it is chosen. Read once at spawn
	# like every other consumer: the mode cannot change mid-fight.
	_dash_damage = roundi(DASH_DAMAGE * Difficulty.damage_scale())
	_chill_rate = chill_per_second * Difficulty.damage_scale()
	_sprite.animation_finished.connect(_on_animation_finished)


## Which phase he is in - 1, 2 or 3. Public because the tests read it and
## because his effects want to know how bad it has got without being told.
func tier() -> int:
	var left := float(health) / float(maxi(max_health, 1))
	if left > PHASE_TWO:
		return 1
	return 2 if left > PHASE_THREE else 3


## Rooted against the base's own walking while he is crossing: the dash moves
## him itself, and two things pushing one body fight each other.
func _can_advance() -> bool:
	return not dashing


## His wind-up is DRAWN, not tinted. The base fades the sprite towards an amber
## WINDUP_TINT as a swing fills, which is exactly wrong on a body whose whole
## look is six exact greyscale values: a multiply lands between two rungs of
## his ramp, and there is no hue anywhere in him to tint. The `dull` steps in
## poses.gd are the telegraph instead - see the `glare` row.
func _windup_tint() -> Color:
	return Color.WHITE


func _physics_process(delta: float) -> void:
	# A guest's copy is the host's, drawn (enemy_base.gd's *Online*).
	if has_conceded or not _in_charge():
		super(delta)
		return
	_glare_timer = maxf(_glare_timer - delta, 0.0)
	_split_timer = maxf(_split_timer - delta, 0.0)
	_prism_timer = maxf(_prism_timer - delta, 0.0)
	herald = maxf(herald - delta, 0.0)
	if dashing:
		_dash_step(delta)
		_chill(delta)
		return
	super(delta)
	# The band runs on through the recover: each frame it has crossed further
	# hits whoever it has reached and not yet blinded.
	if attack == "glare" and phase == Phase.RECOVER:
		_glare_reach(glare_front(_phase_time))
		_glare_reach_arm(_band_up, -1.0, glare_arm_front(_phase_time))
		_glare_reach_arm(_band_down, 1.0, glare_arm_front(_phase_time))
	if attack == "prism" and phase == Phase.RECOVER and _phase_time < PRISM_SWEEP:
		_prism_reach(_phase_time)
	_chill(delta)
	_dash_cool = maxf(_dash_cool - delta, 0.0)
	_consider_dash()


# --- the attack cycle --------------------------------------------------------


func _attack_spec(id: String) -> Dictionary:
	return {
		"windup": Poses.windup_of(id),
		"recover": Poses.recover_of(id),
		"damage": DAMAGE[id],
	}


## Per-phase commit and lockout, set as the attack begins. The base has one
## dial for each and this is the only place they can narrow over a fight.
func _begin_attack(id: String) -> void:
	commit_fraction = COMMIT[tier()]
	interrupt_cooldown = LOCKOUT[tier()]
	if id == "prism":
		_aim_prism()
	super(id)


## The prism the moment his last phase allows it, then the split while it is
## available and there is ground for the copy to cover, the glare otherwise. "" holds him where he is, which is a perfectly good
## thing for this boss to be doing.
func _pick_attack() -> String:
	if tier() >= 3 and _prism_timer <= 0.0:
		return "prism"
	if tier() >= 2 and _split_timer <= 0.0 and _distance_to_player() >= split_min_distance:
		return "split"
	if _glare_timer <= 0.0:
		return "glare"
	return ""


## Neither of his attacks needs to reach you, so neither waits for contact -
## the glare is the whole room and the copy does the walking. Ahmed's wave
## opens from CHASE the same way and for the same reason.
func _advance_phase() -> void:
	if phase == Phase.CHASE and not touching_player and not dashing:
		var player := target()
		if player != null and _distance_to_player() <= sight_radius:
			var id := _pick_attack()
			if id != "":
				_begin_attack(id)
				return
	super()


## The blow, per attack. There is no `super()` branch here because he has no
## melee: nothing he does lands merely on whoever is inside `Touch`.
func _strike() -> void:
	match attack:
		"glare":
			_glare_timer = glare_cooldown
			_glare_hit.clear()
			# The burst BEFORE the travel - see below. It shares `_glare_hit`
			# with the band, so nobody is caught twice by one glare.
			_flash_at_source()
			_glare_reach(GLARE_START)
			_glare_reach_arm(_band_up, -1.0, GLARE_START)
			_glare_reach_arm(_band_down, 1.0, GLARE_START)
			shook.emit(SHAKE["glare"], SHAKE_SECONDS)
		"split":
			_split_timer = split_cooldown
			_cast_copy()
		"prism":
			# The light leaving him. The flash is prism.gd's, off the same
			# frame; the beam itself is _prism_reach, every frame of the sweep.
			_prism_timer = prism_cooldown
			shook.emit(SHAKE["prism"], PRISM_SHAKE_SECONDS)


## The glare bursts off HIM before it sets out, and anyone inside his own reach
## when he spends his shine takes it whatever line they are standing on.
##
## **This is what stops him being free to hug**, and without it he had a hole
## you could win the last fight in the game through. Every reach he owns points
## along x or is too far out: the band is a 20 px lane through his chest, the
## crossing only travels along x, and the split will not fire closer than 34.
## So a player standing directly north or south of him at arm's length was
## missed by the lane on BOTH axes, slid past by the crossing, and not worth a
## split - phases one and two landed nothing at all on them.
##
## It needs no new number and no new shape: `Touch` is the reach the base
## already gives him, and standing in the source of the glare being the worst
## place to be is the obvious reading of it.
func _flash_at_source() -> void:
	for body in _touch_area.get_overlapping_bodies():
		if body == self or _glare_hit.has(body) or not body.has_method("take_damage"):
			continue
		_glare_hit[body] = true
		body.call("take_damage", contact_damage)


# --- the glare ---------------------------------------------------------------


## How far the band's front has crossed, `since` seconds after the light
## landed. glare.gd draws the band off this very function, so the picture and
## the hitbox are one number and cannot drift apart.
func glare_front(since: float) -> float:
	var travel := maxf(Poses.recover_of("glare"), 0.001)
	return GLARE_START + (GLARE_REACH - GLARE_START) * clampf(since / travel, 0.0, 1.0)


## Everything the band has reached and not yet caught, once each. The area is
## swung to his facing and moved to the front before it is asked.
func _glare_reach(front: float) -> void:
	_band.position.x = -front if _facing_left else front
	for body in _band.get_overlapping_bodies():
		if body == self or _glare_hit.has(body) or not body.has_method("take_damage"):
			continue
		if _forward_of(body) <= front + GLARE_SLACK:
			_glare_hit[body] = true
			body.call("take_damage", contact_damage)


## How far the up and down arms' fronts have crossed, `since` seconds after
## the light landed - the band's travel over the arms' shorter reach.
func glare_arm_front(since: float) -> float:
	var travel := maxf(Poses.recover_of("glare"), 0.001)
	return GLARE_START + (GLARE_ARM - GLARE_START) * clampf(since / travel, 0.0, 1.0)


## One vertical arm, `dy` -1 up and 1 down: the band's rule turned on its side.
## The area is moved to the front and asked who it overlaps, and a body counts
## once the front has reached it, sharing `_glare_hit` with the band so one
## glare still lands once.
func _glare_reach_arm(area: Area2D, dy: float, front: float) -> void:
	area.position.y = GLARE_LANE_Y + dy * front
	for body in area.get_overlapping_bodies():
		if body == self or _glare_hit.has(body) or not body.has_method("take_damage"):
			continue
		var along: float = (body.global_position.y + GLARE_BODY_Y
			- (global_position.y + GLARE_LANE_Y)) * dy
		if along <= front + GLARE_SLACK:
			_glare_hit[body] = true
			body.call("take_damage", contact_damage)


## How far ahead of him a body stands, along the way he faces.
func _forward_of(body: Node2D) -> float:
	var dx := body.global_position.x - global_position.x
	return -dx if _facing_left else dx


# --- the split ---------------------------------------------------------------


## One copy, in the room rather than under him - a thing parented to the boss
## would drift with him, and the whole point is that he stands still while it
## goes. It is handed the damage the base already scaled for this attack.
##
## Cast on every machine alike - only the host's copy can hurt anybody, by
## player.gd's rule - so a guest sees it set off the moment he casts it.
func _cast_copy() -> void:
	_copy(global_position, contact_damage, -1.0 if _facing_left else 1.0)
	_tell("copy", [global_position, contact_damage, -1.0 if _facing_left else 1.0])


func _copy(at: Vector2, damage: int, facing: float) -> void:
	var copy := Copy.new()
	get_parent().add_child(copy)
	copy.global_position = at
	copy.cast(self, damage, facing)


# --- the prism ---------------------------------------------------------------


## The arc for this cast, fixed the moment it begins: the fan has to show
## exactly what will sweep, so nothing about it may move once it is drawn.
func _aim_prism() -> void:
	var dir := _prism_dir
	_prism_dir = -dir
	var to_player := Vector2.LEFT if _facing_left else Vector2.RIGHT
	var player := target()
	if player != null:
		to_player = (player.global_position + PRISM_BODY) - prism_chest()
	prism_from = to_player.angle() - dir * PRISM_LEAD
	prism_span = dir * PRISM_SPREAD
	_prism_lengths.resize(PRISM_SAMPLES)
	for i in PRISM_SAMPLES:
		var a := prism_from + prism_span * float(i) / float(PRISM_SAMPLES - 1)
		_prism_lengths[i] = _wall_distance(prism_chest(), Vector2.from_angle(a), PRISM_REACH)
	prism_casts += 1
	# The fan a guest draws is this one, measured here: walls and all.
	_tell("prism", [prism_from, prism_span, prism_casts, _prism_lengths])


## Where the light comes out of him, in the world.
func prism_chest() -> Vector2:
	return global_position + PRISM_CHEST


## The beam's angle `since` seconds into the recover. The sweep is linear and
## holds at the end of its arc once the 1.4 s are up.
func prism_angle(since: float) -> float:
	return prism_from + prism_span * clampf(since / PRISM_SWEEP, 0.0, 1.0)


## How far the beam reaches at `angle` before a wall stops it, read off the
## arc measured when the cast began. prism.gd draws with this and
## `_prism_reach` hurts with it, so the light you see is the light that hits.
func prism_length(angle: float) -> float:
	if _prism_lengths.size() < 2 or is_zero_approx(prism_span):
		return PRISM_REACH
	var f := clampf((angle - prism_from) / prism_span, 0.0, 1.0) * float(PRISM_SAMPLES - 1)
	var i := mini(int(f), PRISM_SAMPLES - 2)
	return lerpf(_prism_lengths[i], _prism_lengths[i + 1], f - float(i))


## The beam as a segment in the world, from just off his chest to the wall.
func prism_beam(angle: float) -> PackedVector2Array:
	var dir := Vector2.from_angle(angle)
	return PackedVector2Array([prism_chest() + dir * PRISM_FROM,
		prism_chest() + dir * prism_length(angle)])


## One frame of the sweep. A blow like any other, so the grace window is what
## meters it, as in the preview: the beam crosses a body in about a tenth of a
## second, which is one hit, and a player who runs WITH it at close range pays
## again once the window has closed.
func _prism_reach(since: float) -> void:
	var beam := prism_beam(prism_angle(since))
	for body in get_tree().get_nodes_in_group("player"):
		var node := body as Node2D
		if node == null or not node.has_method("take_damage"):
			continue
		var at := node.global_position + PRISM_BODY
		var on := Geometry2D.get_closest_point_to_segment(at, beam[0], beam[1])
		if at.distance_to(on) < PRISM_HALF:
			node.call("take_damage", contact_damage)
	# The hum, once the kick has decayed under it - game.gd keeps one shake at
	# a time, so asking for 1 px any earlier would cut the 3 px short.
	if since > PRISM_SHAKE_SECONDS * (1.0 - PRISM_HUM / SHAKE["prism"]):
		shook.emit(PRISM_HUM, PRISM_HUM_SECONDS)


## How far a ray from `from` gets before it meets the ROOM. Furniture and
## bodies share the walls' collision layer, and the light goes over a desk the
## way the glare's band does, so anything that is not the walls' tilemap is
## excluded and the ray cast again.
func _wall_distance(from: Vector2, dir: Vector2, reach: float) -> float:
	var space := get_world_2d().direct_space_state
	var exclude: Array[RID] = [get_rid()]
	for _try in 12:
		var query := PhysicsRayQueryParameters2D.create(from, from + dir * reach, 1, exclude)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return reach
		if hit["collider"] is TileMapLayer:
			return from.distance_to(hit["position"])
		exclude.append(hit["rid"])
	return reach


# --- the cold room -----------------------------------------------------------


## Third phase only, and outside the cycle entirely. Health is an integer, so
## the rate is banked and spent in whole points with the remainder carried -
## the wraith's arrangement, because it is the same idea. A ROOM, so it reaches
## everybody standing in it rather than only the one he is after; the bank is
## his, and each of them pays the same point when it is spent.
func _chill(delta: float) -> void:
	if tier() < 3:
		return
	var cold: Array[Node2D] = []
	for node in get_tree().get_nodes_in_group("player"):
		var player := node as Node2D
		if player != null and player.has_method("drain") 				and player.global_position.distance_to(global_position) <= chill_radius:
			cold.append(player)
	if cold.is_empty():
		return
	_owed += delta * _chill_rate
	var points := int(_owed)
	if points > 0:
		_owed -= points
		for player in cold:
			player.call("drain", points)


# --- the crossing ------------------------------------------------------------


## Start one if he is watching a player he cannot reach. Distance alone, which
## is the whole cue: the crossing is how he keeps a kiting player in the same
## room as him, and now that it hurts it is also what that player pays.
func _consider_dash() -> void:
	if _dash_cool > 0.0 or phase != Phase.CHASE:
		return
	var player := target()
	if player == null:
		return
	var to_player := player.global_position - global_position
	var distance := to_player.length()
	if distance > sight_radius or distance <= dash_range:
		return
	dashing = true
	dash_moving = false
	_dash_hits.clear()
	_dash_time = 0.0
	_dash_from = global_position
	_dash_dir = signf(to_player.x) if absf(to_player.x) > 0.01 else 1.0
	# THROUGH, which is a thing two solid bodies do not do on their own: his
	# own move_and_slide() collided with the player and stopped him dead 11 px
	# short, so the pass-through was a boss walking into you and halting. An
	# exception for the bodies he is crossing, dropped the moment he arrives -
	# the arena's walls still stop him, which is the whole reason this is an
	# exception and not a collision mask. Every player rather than the one he
	# is after, or a second one standing on the line stops him dead instead.
	for node in get_tree().get_nodes_in_group("player"):
		var body := node as Node2D
		if body != null:
			_dash_excepted.append(body)
			add_collision_exception_with(body)
	# The picture, on the frame the crossing starts rather than the frame
	# after. `_dash_step` does not run until the next physics step, so without
	# this he spends one frame crossing the room in his idle pose.
	_apply_animation("dash")


## One frame of the crossing. It keeps the base's bookkeeping that still
## matters mid-dash - the hurt flash and the interrupt lock both tick - and
## drives position through `velocity` rather than by assignment, so the arena's
## walls still stop him.
func _dash_step(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
	if _interrupt_locked > 0.0:
		_interrupt_locked = maxf(_interrupt_locked - delta, 0.0)
	touching_player = false
	_dash_time += delta

	var beat := _beat_at(_dash_time)
	dash_moving = beat["moving"]
	_facing_left = _dash_dir < 0.0
	var target := _dash_from + Vector2(beat["x"] * _dash_dir, 0.0)
	velocity = (target - global_position) / maxf(delta, 0.0001)
	move_and_slide()
	if beat.get("hit", false):
		_pass_through()

	_apply_animation("dash")
	_sprite.modulate = HURT_TINT if _flash > 0.0 else _resting_tint()

	if _dash_time >= _dash_total:
		dashing = false
		dash_moving = false
		_dash_cool = dash_cooldown
		_solid_again()


## He passes through whoever is on the line, each of them once per crossing.
## Metered by the player's grace window like any blow - it goes in through
## take_damage() and is nothing special on the way.
func _pass_through() -> void:
	for node in get_tree().get_nodes_in_group("player"):
		var player := node as Node2D
		if player == null or _dash_hits.has(player) or not player.has_method("take_damage"):
			continue
		if player.global_position.distance_to(global_position) > dash_reach:
			continue
		_dash_hits[player] = true
		player.call("take_damage", _dash_damage)
		shook.emit(SHAKE["dash"], SHAKE_SECONDS)


func _beat_at(seconds: float) -> Dictionary:
	var acc := 0.0
	for beat in DASH:
		acc += beat["dur"]
		if seconds < acc:
			return beat
	return DASH[DASH.size() - 1]


static func _total_of(beats: Array) -> float:
	var total := 0.0
	for beat in beats:
		total += beat["dur"]
	return total


func _distance_to_player() -> float:
	var player := target()
	if player == null:
		return INF
	return player.global_position.distance_to(global_position)


# --- phases and the end ------------------------------------------------------


## A phase arriving is announced and it arrives AT ONCE: both cooldowns clear,
## so the new thing he does is the next thing he does. He has no cuffs to
## adjust, so what he spends on the announcement is a rung of his own shine.
func take_damage(amount: int) -> void:
	var before := tier()
	super(amount)
	if has_conceded:
		return
	var now := tier()
	if now == before:
		return
	_tier = now
	herald = HERALD_SECONDS
	_glare_timer = 0.0
	_split_timer = 0.0
	_prism_timer = 0.0
	shook.emit(HERALD_SHAKE, SHAKE_SECONDS)
	# And the line, on the cue named after the phase that arrived. A boss with
	# nothing to say here has no `Lines` child and this does nothing, which is
	# the deal every other cue in the fight is on.
	_say(PHASE_CUE.get(now, ""))


## Losing flight is the defeat, so the crossing stops wherever it had got to -
## a boss who concedes mid-dash must not keep sliding while he sinks.
func _concede() -> void:
	dashing = false
	dash_moving = false
	herald = 0.0
	velocity = Vector2.ZERO
	_solid_again()
	super()


## He is only allowed through the party for the half second he is crossing.
## Called from both ends - the arrival and a concede mid-flight - because a
## boss left permanently able to walk through the player is a boss you can
## never corner.
func _solid_again() -> void:
	for body in _dash_excepted:
		if is_instance_valid(body):
			remove_collision_exception_with(body)
	_dash_excepted.clear()


## His snapshot: a boss's, and the three his effects read off him - the
## crossing, the travel inside it, and a phase being announced.
func net_state() -> Array:
	var state := super()
	state.append_array([dashing, dash_moving, herald])
	return state


## On a guest he crosses THROUGH the party exactly as he does on the host, or
## his drawn body, moved there twenty times a second, would shoulder this
## machine's player out of the way.
func apply_net_state(state: Array) -> void:
	super(state)
	if has_conceded or state.size() < NET_OWN + 3:
		return
	var was := dashing
	dashing = bool(state[NET_OWN])
	dash_moving = bool(state[NET_OWN + 1])
	herald = float(state[NET_OWN + 2])
	if dashing and not was:
		for node in get_tree().get_nodes_in_group("player"):
			var body := node as Node2D
			if body != null:
				_dash_excepted.append(body)
				add_collision_exception_with(body)
	elif was and not dashing:
		_solid_again()


func net_event(what: String, args: Array) -> void:
	match what:
		"copy":
			if args.size() >= 3:
				_copy(args[0], int(args[1]), float(args[2]))
		"prism":
			if args.size() >= 4:
				prism_from = float(args[0])
				prism_span = float(args[1])
				_prism_lengths = args[3]
				prism_casts = int(args[2])
		_:
			super(what, args)


func _on_animation_finished() -> void:
	if has_conceded and _sprite.animation == &"concede_side":
		_sprite.play("beaten_side")
