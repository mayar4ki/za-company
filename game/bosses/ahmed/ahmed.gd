extends "res://game/bosses/boss_base.gd"
## Ahmed, F4's boss. 144 HP solo - six heavies, six full combos - and a burning
## axe with five attacks, chosen by where you are and what you have been doing.
## Each one asks for a different move, because he is the first boss and the
## fight is where the player learns to read one:
##
## - **chop** and **sweep** alternate when you are in reach. Same reach, same
##   cycle, different telegraphs: the axe up behind his head, or dragged low
##   behind him. 16 and 12 damage.
##   - The chop is a FISSURE: the blade bites the floor and a crack runs on
##     ahead of it, bursting into a row of fire pillars (fissure.gd, 8 more).
##     Backing straight off is the wrong answer; step to the side.
##   - The sweep SHOVES: whoever it hits is pushed away along the line from his
##     feet (player.gd's `shove()`, at its cap) - out of his reach and in front
##     of him, which is exactly where the wave goes. A combo you can see coming.
## - **slam** is the AREA attack and now a LEAP: he crouches, jumps, and lands
##   on the spot you were standing on when he left the ground, up to 100 px
##   away. A ring on the floor marks where (leap_mark.gd), and he lands with 20
##   to EVERYONE in the r 40 Ring - the player and any office boy alike. In
##   reach it comes every third swing, or sooner if you hit him twice inside
##   two seconds, and is a hop onto you; out of reach it is how he follows
##   someone who will not come to him. Get out of the ring.
## - **wave** is the RANGED one: in front of him and out of reach, three waves
##   of fire go out in a fan (fan_wave.gd), 14 each. The safe ground is between
##   two of them - sidestep a little, not a lot. Then a cooldown.
## - **chair** is THE ENORMOUS CHAIR, for whoever keeps away longest: three
##   seconds out of his reach and he sits down in it, spins it up for a second,
##   and rolls straight at you until he hits something - 18 if it is you - then
##   sits there dizzy for a second and a half. Sidestep, then punish.
##
## Each attack's wind-up and recover come from its frames in poses.gd, so the
## picture and the timer are one thing - the leap's crouch and flight and the
## chair's longest run are frames too. Every hit is metered by the player's
## grace window like any blow; nothing here drains. And every impact lands with
## WEIGHT: a hit-stop, a shake and a white star (`_jolt`), the first two asked
## of game.gd by signal like his health bar.
##
## Reach is two Area2Ds - `Touch` (r 24, the axe's melee reach, the chair's
## bumper, and what the base uses to decide he has arrived) and `Ring` (r 40,
## the slam) - plus geometry for the fan and the fissure, which carry their
## own lanes in their own nodes. Everything thrown off an attack is a child of
## his pinned to the floor it fell on (fx_node.gd), so it draws in his place in
## the room the way the fire on his axe does.

const Poses := preload("res://game/bosses/ahmed/poses.gd")
const Fissure := preload("res://game/bosses/ahmed/fissure.gd")
const FanWave := preload("res://game/bosses/ahmed/fan_wave.gd")
const LeapMark := preload("res://game/bosses/ahmed/leap_mark.gd")
const SlamLand := preload("res://game/bosses/ahmed/slam_land.gd")
const ShoveDust := preload("res://game/bosses/ahmed/shove_dust.gd")
const ImpactStar := preload("res://game/bosses/ahmed/impact_star.gd")
const ChairRun := preload("res://game/bosses/ahmed/chair_run.gd")

## MEDIUM numbers; the difficulty scale is applied by the base when chosen.
const DAMAGE := {"chop": 16, "sweep": 12, "slam": 20, "wave": 14, "chair": 18}
## The fissure's pillars, on top of the chop's own 16.
const FISSURE_DAMAGE := 8
## Melee attacks between slams.
const SWINGS_PER_SLAM := 2
## Two hits inside this window bring the slam forward.
const HIT_WINDOW := 2.0

## The leap: the furthest he will jump, how high, and how high a hop onto
## somebody already in his reach is. Closer than LEAP_MIN and out of reach is
## a walk, not a jump.
const LEAP_RANGE := 100.0
const LEAP_HEIGHT := 34.0
const LEAP_LOW := 16.0
const LEAP_MIN := 40.0
## The fan: how far its waves run, and how wide a cone in front of him counts
## as being in front of him.
const FAN_REACH := 96.0
const FAN_CONE := 0.5
## The sweep's push, which player.gd caps at exactly this.
const SHOVE_FORCE := 70.0
## The chair: how fast it rolls, and the least distance worth rolling.
const CHAIR_SPEED := 255.0
const CHAIR_MIN := 60.0

## Every impact's weight, from the preview: [hit-stop seconds, shake px].
const JOLT := {
	"chop": [0.08, 2.0], "sweep": [0.08, 2.0], "slam": [0.08, 3.0],
	"wave": [0.08, 2.0], "crash": [0.08, 3.0],
}
const SHAKE_SECONDS := 0.25
## Where each impact's star goes, in his local pixels facing right: the blade
## where it lands, the floor under the slam, the front of the chair.
const STAR_AT := {
	"chop": Vector2(17, -3), "sweep": Vector2(22, -8), "slam": Vector2(0, -4),
	"wave": Vector2(13, -4), "crash": Vector2(8, -10),
}

## Beaten, and getting his breath back - see `_settle()`. Long enough to read
## as a man who has just lost a fight (the loop is 1.57 s, so it is about six
## gasps), short enough that it is over before the floor's own quiet is his
## panting. The row keeps looping at BREATH_CALM afterwards, silently.
const BREATH_HARD := 9.0
const BREATH_FADE := 6.0
const BREATH_CALM := 0.45

@export var wave_cooldown := 3.0
## Closer than this and the axe would do; the wave is for the gap.
@export var wave_min_distance := 34.0
@export var leap_cooldown := 4.0
## How long the player must keep out of his reach before the chair comes out,
## and how long before it can come out again.
@export var chair_after := 3.0
@export var chair_cooldown := 10.0
## Anything thrown across the gap - wave, leap, chair - holds the other two
## off this long, so keeping away is a fight and not a barrage.
@export var ranged_gap := 1.5

@onready var _ring: Area2D = $Ring
@onready var _air: Node2D = $AirFire

var _swings := 0
var _last_melee := "sweep"
var _slam_due := false
var _hits := 0
var _hit_window := 0.0
var _wave_timer := 0.0
var _leap_timer := 0.0
var _chair_timer := 0.0
var _ranged_timer := 0.0
var _kept_away := 0.0

var _leaping := false
var _leap_from := Vector2.ZERO
var _leap_to := Vector2.ZERO
var _leap_peak := 0.0
var _z := 0.0

var _charging := false
var _charge_t := 0.0
var _chair_dir := Vector2.RIGHT
var _chair_hit := {}
var _chair_fx: Node2D


## The concede ends him kneeling but not dead, so it hands off to a looping
## row: he is still breathing when you walk back out. It has to be a second
## row because one animation cannot loop only its last two frames.
func _ready() -> void:
	super()
	_sprite.animation_finished.connect(_on_animation_finished)
	# The axe burns for as long as he holds it, so its fire is not an event -
	# it starts with him and is only ever taken away. hurt, stagger and
	# concede are the base's; these two are his, for the same reason the fire
	# on the blade is.
	_sfx_loop("axe")


func _on_animation_finished() -> void:
	if has_conceded and _sprite.animation == &"concede_side":
		_sprite.play("beaten_side")
		_sfx_loop("breath")
		_settle()


## He gets his breath back. The `beaten` row loops for good - that is the whole
## point of it, he is still there and still alive when you walk back out - but
## the PANTING is an event with an end, and left running it was the only sound
## in the room for as long as the player stayed on the floor. His floor is
## quiet by then: the theme fades on his concede, and Ivan walks in to talk
## over the top of it.
##
## So both halves of it wind down together rather than one of them being cut.
## The sound fades out over `BREATH_FADE` after `BREATH_HARD` seconds of
## actually gasping, and the row slows to `BREATH_CALM` across the same span,
## so the picture and the sound are telling the same story at every moment -
## the one thing his fire already taught (see `_concede`). What is left is a
## man kneeling and breathing slowly, which is what the row was drawn for.
func _settle() -> void:
	# Parallel, not sequential: the sound going quiet while the chest was still
	# heaving would read as the audio having broken rather than as him calming
	# down. The slowing runs the whole span; the fade joins it at BREATH_HARD.
	var settle := create_tween().set_parallel()
	settle.tween_property(_sprite, "speed_scale", BREATH_CALM,
		BREATH_HARD + BREATH_FADE).set_trans(Tween.TRANS_SINE)
	settle.tween_callback(
		func() -> void: _sfx_fade("breath", BREATH_FADE)).set_delay(BREATH_HARD)


## The fire goes out the moment the axe leaves his hand, and `glow` says how
## long that takes: 0.6, 0.45, 0.2, 0.05 over the concede's first four frames.
## Fading across exactly that span is what keeps the sound on the picture -
## cutting it on frame one would put the room in silence while the blade is
## still lit - so it is read off the poses rather than typed here.
##
## And he comes down out of the air, or off the chair, wherever he was.
func _concede() -> void:
	_charging = false
	_leaping = false
	_set_height(0.0)
	super()
	_sfx_fade("axe", Poses.glow_out_of("concede"))


func _physics_process(delta: float) -> void:
	# A guest's copy is the host's, drawn (enemy_base.gd's *Online*) - and
	# the chair's spin, which flips fourteen times a second and would only
	# alias against twenty snapshots, is spun here off the host's own clock.
	if not _in_charge():
		super(delta)
		if attack == "chair" and phase == Phase.WINDUP:
			_sprite.flip_h = int(floorf(_phase_time * 14.0)) % 2 == 1
		return
	_wave_timer = maxf(_wave_timer - delta, 0.0)
	_leap_timer = maxf(_leap_timer - delta, 0.0)
	_chair_timer = maxf(_chair_timer - delta, 0.0)
	_ranged_timer = maxf(_ranged_timer - delta, 0.0)
	_hit_window = maxf(_hit_window - delta, 0.0)
	super(delta)
	if has_conceded:
		return
	_watch_distance(delta)
	match attack:
		"slam":
			_leap_step()
		"chair":
			_chair_step(delta)
	# Knocked out of the air by an interrupt, or the attack simply over: on
	# the floor wherever that left him.
	if attack != "slam" and (_leaping or _z != 0.0):
		_leaping = false
		_set_height(0.0)
	if attack != "chair":
		_charging = false


## How long the player has been keeping out of his reach - the chair's cue.
## Counted only while he can see them and is not busy, and wiped the moment
## they come close, so it measures somebody avoiding him rather than the walk
## in.
func _watch_distance(delta: float) -> void:
	var player := target()
	if player == null or touching_player \
			or global_position.distance_to(player.global_position) > sight_radius:
		_kept_away = 0.0
		return
	if attack == "":
		_kept_away += delta


func _attack_spec(id: String) -> Dictionary:
	if id == "chair":
		# The run between the wind-up and the dizzy spell is as long as it
		# takes to hit something, so the recover the base counts is the dizzy
		# spell alone, and `_chair_step` holds the clock while he rolls.
		return {
			"windup": Poses.windup_of(id),
			"recover": Poses.chair_dizzy_seconds(),
			"damage": DAMAGE[id],
		}
	return {
		"windup": Poses.windup_of(id),
		"recover": Poses.recover_of(id),
		"damage": DAMAGE[id],
	}


## In reach: slam when it is owed, otherwise the other of chop and sweep.
func _pick_attack() -> String:
	if _slam_due or _swings >= SWINGS_PER_SLAM:
		_slam_due = false
		_swings = 0
		return "slam"
	_swings += 1
	_last_melee = "sweep" if _last_melee == "chop" else "chop"
	return _last_melee


## Out of reach, CHASE can open an attack without contact - that is the whole
## of what his three ranged answers share. Everything else is the base.
func _advance_phase() -> void:
	if phase == Phase.CHASE and not touching_player:
		var id := _ranged_pick()
		if id != "":
			_begin_attack(id)
			return
	super()


## Which of the three to throw across the gap, if any. The chair is for the
## player who has kept away longest, the fan for one standing in front of him,
## the leap for anyone else in range; the gap between any two of them is what
## keeps him from doing nothing else.
func _ranged_pick() -> String:
	if _ranged_timer > 0.0:
		return ""
	var player := target()
	if player == null:
		return ""
	var rel := player.global_position - global_position
	var d := rel.length()
	if d > sight_radius:
		return ""
	if _chair_timer <= 0.0 and _kept_away >= chair_after and d >= CHAIR_MIN:
		return "chair"
	if _wave_timer <= 0.0 and _in_fan(rel):
		return "wave"
	if _leap_timer <= 0.0 and d >= LEAP_MIN and d <= LEAP_RANGE:
		return "slam"
	return ""


func _in_fan(rel: Vector2) -> bool:
	var fwd := rel.x * _dir()
	return fwd >= wave_min_distance and rel.length() <= FAN_REACH \
		and absf(atan2(rel.y, fwd)) <= FAN_CONE


## +1 facing right, -1 facing left.
func _dir() -> float:
	return -1.0 if _facing_left else 1.0


func _begin_attack(id: String) -> void:
	_leaping = false
	_charging = false
	match id:
		"slam":
			# However it came - owed in reach, or across the gap - it is the
			# slam, and the count to the next one starts again.
			_slam_due = false
			_swings = 0
			_leap_timer = leap_cooldown
			if not touching_player:
				_ranged_timer = ranged_gap
		"wave":
			_ranged_timer = ranged_gap
		"chair":
			_chair_timer = chair_cooldown
			_ranged_timer = ranged_gap
			_kept_away = 0.0
	super(id)
	if id == "chair":
		_chair_fx = _spawn_fx(ChairRun, global_position, true)
		# The chair is the taunt, acted out: it comes for whoever kept away,
		# which is the moment `taunt` was written for and now arrives half a
		# second before boss_base's own clock would have said it. So it says
		# the taunt - "Get over here!" as he sits down - rather than waiting
		# for chair lines nobody has recorded.
		_say("taunt")


## The blow, per attack. The base's own strike is the axe on whoever is in
## Touch - the chop and the sweep - and the rest read their own shapes.
func _strike() -> void:
	# The blow landing, paired with the telegraph boss_base fires on the
	# wind-up. It is said HERE rather than in the base, unlike the telegraph,
	# because a boss applies damage his own way per attack - the slam sweeps a
	# ring and the wave walks a lane, and neither calls `super()` - so the base
	# never sees most of Ahmed's blows land. The chair's is the crash, which
	# comes later.
	if attack != "chair":
		_sfx(attack + "_hit")
	match attack:
		"slam":
			if _leaping:
				global_position = _leap_to
			_leaping = false
			_set_height(0.0)
			for body in _ring.get_overlapping_bodies():
				if body != self and body.has_method("take_damage"):
					body.call("take_damage", contact_damage)
			_spawn_fx(SlamLand, global_position, false)
		"wave":
			_wave_timer = wave_cooldown
			_spawn_fx(FanWave, global_position, false, {"damage": contact_damage})
		"chair":
			_launch_chair()
			return
		"chop":
			super()
			_spawn_fx(Fissure, global_position, false,
				{"damage": roundi(FISSURE_DAMAGE * _damage_scale)})
		_:
			super()
	_jolt(attack, _dir())


## The sweep is the one blow that moves you: hurt, then pushed away from his
## feet, with the dust kicked up where you skid.
func _touch_strike(player: Node2D) -> void:
	super(player)
	# A sweep the roll made miss pushes nobody: the push is part of the blow.
	if attack == "sweep" and player.has_method("shove") and not _untouchable(player):
		player.call("shove", player.global_position - global_position, SHOVE_FORCE)
		_spawn_fx(ShoveDust, global_position, true, {"victim": player})


## A blow landing hard: the world stops for a moment, the room shakes, and a
## white star marks where. The first two are asked of game.gd - he never
## learns who is listening - and a test that builds him by hand with no game
## around him simply gets the star.
func _jolt(kind: String, facing: float) -> void:
	var weight: Array = JOLT[kind]
	froze.emit(weight[0])
	shook.emit(weight[1], SHAKE_SECONDS)
	var at: Vector2 = STAR_AT[kind]
	var x := at.x if facing > 0.0 else -1.0 - at.x
	_spawn_fx(ImpactStar, global_position + Vector2(x, at.y), true, {"seconds": weight[0]})


## One thrown-off effect, pinned to `anchor` on the floor. Under his body
## (just after FloorFire) unless `over`, in which case on top of everything
## he draws.
##
## Every effect he has comes through here, which is what makes them one moment
## to tell the guests rather than seven: the same script, anchor, facing and
## props, thrown on their copy of him too. It carries the attack it belongs to,
## because an effect that ends with its attack (the chair, the leap's mark)
## must not find a guest still a snapshot behind and end on its first frame.
func _spawn_fx(script: GDScript, anchor: Vector2, over: bool, props := {}) -> Node2D:
	var node := _throw_fx(script, anchor, over, _dir(), props)
	_tell("fx", [script.resource_path, anchor, over, _dir(), props, attack, int(phase), _leaping])
	return node


func _throw_fx(script: GDScript, anchor: Vector2, over: bool, dir: float,
		props: Dictionary) -> Node2D:
	var node: Node2D = script.new()
	node.set("boss", self)
	node.set("anchor", anchor)
	node.set("dir", dir)
	for key in props:
		node.set(key, props[key])
	add_child(node)
	if not over:
		move_child(node, 1)
	return node


## His snapshot: a boss's, and the four things his effects read off him that
## nothing else carries - how high he is, whether he is in the air, and the
## chair: rolling, and which way.
func net_state() -> Array:
	var state := super()
	state.append_array([_z, _leaping, _charging, _chair_dir])
	return state


func apply_net_state(state: Array) -> void:
	super(state)
	if has_conceded or state.size() < NET_OWN + 4:
		return
	_leaping = bool(state[NET_OWN + 1])
	_charging = bool(state[NET_OWN + 2])
	_chair_dir = state[NET_OWN + 3]
	_set_height(float(state[NET_OWN]))


## And his height with him, so a leap arcs on a guest rather than climbing in
## twentieths of a second.
func net_between(a: Array, b: Array, weight: float) -> void:
	super(a, b, weight)
	if not has_conceded and a.size() > NET_OWN and b.size() > NET_OWN:
		_set_height(lerpf(float(a[NET_OWN]), float(b[NET_OWN]), weight))


## His moments, on a guest: an effect thrown, and the chair going and crashing.
func net_event(what: String, args: Array) -> void:
	match what:
		"fx":
			if args.size() < 8 or has_conceded:
				return
			attack = String(args[5])
			phase = int(args[6]) as Phase
			_leaping = bool(args[7])
			var node := _throw_fx(load(String(args[0])) as GDScript, args[1],
				bool(args[2]), float(args[3]), args[4])
			if node.get_script() == ChairRun:
				_chair_fx = node
		"chair_launch":
			_chair_dir = args[0]
			_charging = true
			if is_instance_valid(_chair_fx):
				_chair_fx.call("launch", _chair_dir)
		"chair_crash":
			_charging = false
			if is_instance_valid(_chair_fx):
				_chair_fx.call("crash")
		_:
			super(what, args)


# --- the leap ----------------------------------------------------------------


## The slam's wind-up, carried: the crouch roots him like any wind-up, then the
## frame marked `air` in poses.gd is the jump, and he travels the whole of it
## from where he stood to where the player stood as he left the ground.
func _leap_step() -> void:
	if phase != Phase.WINDUP:
		return
	var crouch := Poses.leap_crouch_seconds()
	if _phase_time < crouch:
		return
	var leaving := not _leaping
	if leaving:
		_take_off()
	var u := clampf((_phase_time - crouch) / Poses.leap_air_seconds(), 0.0, 1.0)
	global_position = _leap_from.lerp(_leap_to, u)
	_set_height(_leap_peak * sin(PI * u))
	# After he has moved, not before: a child pinned to the floor is only
	# re-pinned on its own next frame, so one spawned and then carried along
	# by this frame's step would sit a step off the target for a frame.
	if leaving:
		_spawn_fx(LeapMark, _leap_to, false)


func _take_off() -> void:
	_leaping = true
	_leap_from = global_position
	var to := Vector2.ZERO
	var player := target()
	if player != null:
		to = (player.global_position - global_position).limit_length(LEAP_RANGE)
	_leap_to = global_position + to
	_leap_peak = lerpf(LEAP_LOW, LEAP_HEIGHT, clampf(to.length() / LEAP_RANGE, 0.0, 1.0))


## How high off the floor he is drawn. The body stays on the ground - his
## shadow, his Ring, his collision - and the picture and the fire on the axe
## rise together.
func _set_height(z: float) -> void:
	_z = z
	var lift := -roundf(z)
	_sprite.position.y = lift
	_air.position.y = lift


## For leap_mark.gd: whether he is in the air, and his shadow's size, 0 at
## the top of the jump and 1 on the ground.
func is_leaping() -> bool:
	return _leaping and attack == "slam" and phase == Phase.WINDUP


func leap_shadow() -> float:
	return 1.0 - _z / LEAP_HEIGHT


# --- the chair ---------------------------------------------------------------


## The chair goes the way the player was when it went, and keeps going.
func _launch_chair() -> void:
	var player := target()
	_chair_dir = Vector2(_dir(), 0.0)
	if player != null and player.global_position != global_position:
		_chair_dir = (player.global_position - global_position).normalized()
	_charging = true
	_charge_t = 0.0
	_chair_hit.clear()
	if is_instance_valid(_chair_fx):
		_chair_fx.call("launch", _chair_dir)
	_tell("chair_launch", [_chair_dir])


## Spun up on the wind-up - the picture flipping fourteen times a second - then
## rolled until it hits something or runs out of `chair_charge_seconds()`,
## facing the way it rolls rather than the way the player went.
func _chair_step(delta: float) -> void:
	if phase == Phase.WINDUP:
		_sprite.flip_h = int(floorf(_phase_time * 14.0)) % 2 == 1
		return
	if phase != Phase.RECOVER:
		return
	_sprite.flip_h = _chair_dir.x < 0.0
	if not _charging:
		return
	# The recover is the dizzy spell; it does not start until he stops.
	_phase_time = 0.0
	_charge_t += delta
	var bump := move_and_collide(_chair_dir * CHAIR_SPEED * delta)
	for body in _touch_area.get_overlapping_bodies():
		# A body rolling clear is not counted as hit, so a roll has to carry it
		# out of the chair's way rather than merely be rolling as it arrives.
		if body != self and body.has_method("take_damage") and not _chair_hit.has(body) \
				and not _untouchable(body):
			_chair_hit[body] = true
			body.call("take_damage", contact_damage)
	if bump != null or _charge_t >= Poses.chair_charge_seconds():
		_crash()


func _crash() -> void:
	_charging = false
	_sfx("chair_hit")
	if is_instance_valid(_chair_fx):
		_chair_fx.call("crash")
	_tell("chair_crash")
	_jolt("crash", signf(_chair_dir.x) if _chair_dir.x != 0.0 else _dir())


## For tests and effects: whether the chair is still rolling.
func is_charging() -> bool:
	return _charging


func take_damage(amount: int) -> void:
	super(amount)
	if has_conceded:
		return
	_hits = _hits + 1 if _hit_window > 0.0 else 1
	_hit_window = HIT_WINDOW
	if _hits >= 2:
		_slam_due = true
