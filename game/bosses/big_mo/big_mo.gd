extends "res://game/bosses/boss_base.gd"
## Big Mo, F7's boss. 216 HP solo - nine heavies, nine full combos - and a
## rhythm rather than a menu. Where Ahmed picks an attack to suit the range,
## Big Mo runs a COMBINATION and makes you learn its shape:
##
## - **jab, jab, then the big one**, then a breath. The jabs are 0.25 s and 6
##   damage and are effectively uninterruptible - they are swings, so step out
##   and they whiff rather than being staggered out of him. The big one is the
##   READ: a **hook** or an **uppercut**, both 0.7 s, both 22, both
##   interruptible, and they want opposite answers. The hook is wide and short
##   (his whole `Touch` circle), so you step BACK; the uppercut is narrow and
##   long (a lane straight out in front of him), so you step ASIDE. What tells
##   them apart is the rear glove - up and out, or down to the hip - and the
##   Bell drawing a ring under one and a lane under the other. He never throws
##   the same one three times running, so the read never becomes a habit.
## - **corner rush** breaks the pattern for a player who kites. If you are out
##   of reach and in front of him he crouches where he stands, then closes the
##   gap in one dash along his line, and the combination starts again from the
##   top. The crouch is the tell and it outlasts a reaction, and like the
##   uppercut the answer is to step ASIDE: the dash runs straight along his
##   line, while backing off outruns it only from the far end of his reach.
##
## Three things answer what the PLAYER does rather than where they stand, and
## each one is the punishment for a kind of greed:
##
## - **Shell Up**, for mashing. Land SHELL_HITS on him inside SHELL_WINDOW and
##   he covers up for SHELL_SECONDS. A hit on the shell is BLOCKED - no damage
##   - and he counters at once with a hook cut to a 0.15 s wind-up; wait it out
##   and his guard drops for OPEN_SECONDS, which is a bigger window than the
##   mashing would have bought. It is a stance and not an attack, so the
##   interrupt economy never sees it.
## - **Clinch & Throw**, for standing on him. Stay pressed against him -
##   closer than his punches need - for CLINCH_AFTER and he throws his arms
##   wide, wraps you up and heaves you off: 8 damage and a carried shove.
## - **Burning Flurry**, raging only. Every other string becomes five straight
##   punches while he marches, each one shoving you back, then the big one with
##   no breath between. Get off his line before the first punch and he walks
##   past you. The rage also shortens his breath to RAGE_BREATH - the lever
##   the rage note below always named - and changes no damage number.
##
## The interrupt economy is enemy_base's, unchanged - `commit_fraction` and
## `interrupt_cooldown` mean what they always meant. The only thing this script
## does with them is set commit per attack when the attack begins, which is
## what makes the jab uninterruptible and the hook not.
##
## Each attack's wind-up and recover come from its frames in poses.gd, so the
## picture and the timer are one thing. Every hit is a blow, metered by the
## player's grace window; nothing here drains.
##
## He is drawn FRONT ON at 2x density - see poses.gd for why both of those are
## deliberate, and why the base's side-only facing still works on him.

const Poses := preload("res://game/bosses/big_mo/poses.gd")

## MEDIUM numbers; the difficulty scale is applied by the base when chosen.
## The flurry's 4 is per punch, and the grace window eats most of the five:
## what the flurry takes is your position, not your health.
##
## Measured against the office boy's 15, as Ahmed's are. Drawn when a guard hit
## for 10 and raised on 2026-10-04 once it hit for 15: the finishers 18 -> 22,
## so his heaviest sits between Ahmed's 20 and Silverman's 24, and the rush and
## the counter 10 / 12 -> 15, so neither lands softer than the office boys on
## his floor. The jab, the clinch and the flurry stay under the unit on
## purpose - they are the rhythm and the footwork, not the blows.
const DAMAGE := {"jab": 6, "hook": 22, "uppercut": 22, "rush": 15,
	"counter": 15, "clinch": 8, "flurry": 4}

## The combination, run in order and then repeated. The last beat is a slot
## rather than a punch: `_finisher()` fills it with one of FINISHERS.
const COMBO := ["jab", "jab", "hook"]
const FINISHERS := ["hook", "uppercut"]
## The longest run of one finisher he will throw before he must switch.
const FINISHER_RUN := 2

## Per-attack commit. The jabs are swings you step out of, not blows you
## stagger him out of; the hook and the uppercut are the ones that can be
## interrupted early. The counter, the clinch and the flurry are answers to
## something you did, and an answer you can mash out of is not one - so they
## are 0.0, which in enemy_base's terms is committed from the first frame.
## (1.0 is the OTHER end of that dial: interruptible the whole way through.)
const COMMIT := {"jab": 1.0, "hook": 0.45, "uppercut": 0.45, "rush": 1.0,
	"counter": 0.0, "clinch": 0.0, "flurry": 0.0}

## The uppercut's reach: a lane from his feet straight out the way he faces.
## Long enough that stepping back the hook's distance still gets you hit, and
## narrow enough that one step to the side does not.
const UPPERCUT_REACH := 44.0
const UPPERCUT_HALF_WIDTH := 8.0
## How far behind his own feet the lane starts, so a body standing ON him is
## still in front of him.
const UPPERCUT_BACK := 4.0

## Shell Up. Hits counted inside the window, how long he holds the shell, and
## how long his guard stays down if nobody hits it.
const SHELL_HITS := 3
const SHELL_WINDOW := 1.2
const SHELL_SECONDS := 0.8
const OPEN_SECONDS := 0.8
const SHELL_COOLDOWN := 6.0
## Brightens him while he holds the shell, blinking, so a blocked hit is
## something the player was warned about rather than a bug.
const SHELL_TINT := Color(1.45, 1.45, 1.45)
const BlockSpark := preload("res://game/bosses/big_mo/block_spark.gd")
## The block spark sits on his chest, where the shell is.
const CHEST := Vector2(0.0, -13.0)

## Clinch & Throw. "Pressed against him" is closer than any punch needs - the
## bodies are 6 px each, so this is all but touching - and held for this long.
const CLINCH_RANGE := 14.0
const CLINCH_AFTER := 0.8
const CLINCH_COOLDOWN := 5.0
## The throw is a shove HELD at full strength through the heave, rather than
## one shove: player.gd caps a single push at 70, which is 17 px, and refreshes
## rather than stacks, so holding it is the honest way to throw someone.
const THROW_SECONDS := 0.35
const THROW_FORCE := 70.0

## Burning Flurry. Five punches FLURRY_GAP apart - the frame boundaries in
## poses.gd - each shoving whoever is in front of him, while he marches.
const FLURRY_PUNCHES := 5
const FLURRY_GAP := 0.2
const FLURRY_REACH := 26.0
const FLURRY_HALF_WIDTH := 10.0
const FLURRY_SHOVE := 70.0
## Faster than his walk on purpose: each punch shoves you about 11 px, and a
## march slower than that would punch himself out of reach by the third.
const FLURRY_MARCH := 55.0
## His breath once he is burning.
const RAGE_BREATH := 0.4

## How hard the room takes each blow - world pixels of camera throw, decaying
## over SHAKE_SECONDS. Applied by game.gd off `shook`; see boss_base. It is on
## every blow, the jab included - it is 3 px where the hook is 4.65, which is
## what keeps the hook the big one. Zero an entry to take the throw off that
## attack without touching the rest.
const SHAKE := {"jab": 3.0, "hook": 4.65, "uppercut": 4.65, "rush": 3.6,
	"counter": 4.0, "clinch": 3.6, "flurry": 1.5}
const SHAKE_SECONDS := 0.12

## Hit-stop: the sprite holds still for this long on the frame the blow lands,
## which is most of what tells a player the attack is OVER. The hook gets half
## again, being the one worth stopping for - and so do the uppercut and the
## counter, which are the same size of blow. The flurry gets none: five holds
## in one second would slide the punches off the frames that throw them.
##
## It pauses the SPRITE only - `_phase_time` runs on untouched, so his wind-up,
## his recover and the window you can punish him in are all exactly what
## poses.gd says. The cost is that the last 0.08 s of the recover animation is
## clipped when the phase moves on before the picture has finished, which is
## the right way round: the timings are load-bearing and the tail of a
## return-to-guard is not. Set to 0.0 to switch it off.
const HIT_STOP := 0.08
const HIT_STOP_HOOK := 1.3

## THE RAGE. At half health he goes up, once, and never comes back down -
## `rage.gd` draws it, this decides when. Half of him is already a
## moment: his floor cues a reinforcement beat at `at_boss_fraction: 0.5`, so the
## fire and the south door open together.
##
## One flip rather than a ladder. DESIGN.md gives the ladder to Silverman, and
## two bosses making the same argument is one boss too many.
##
## He does NOT get stronger here. Every number in this file is still the
## number it was, because 24 / 17 / 36 and the heavy's 24 are exact combo
## breakpoints and the fight was tuned around them. If the rage should bite as
## well as burn, the cheapest honest lever is `breath_seconds`: the combination
## he taught you, arriving with less room to answer it.
const RAGE_AT := 0.5
## Seconds into the animation that the blast lands - the same number rage.gd
## draws it on, and the frame boundary in poses.gd both come off.
const RAGE_BLAST := 0.51
## He holds still on the blast, and the whole room takes it.
const RAGE_HOLD := 0.12
const RAGE_SHAKE := 6.0
const RAGE_SHAKE_SECONDS := 0.20

## Public, because the fire he KEEPS has to outlive the animation that started
## it: rage.gd reads this rather than trying to see a rage in an idle sprite.
var is_raging := false

## After a full combination he holds for this long before starting again -
## the window the fight is built around.
@export var breath_seconds := 0.7
## Closer than this and he just punches; the rush is for the gap.
@export var rush_min_distance := 46.0
@export var rush_cooldown := 3.5
## How fast the dash carries him once the crouch is over. Over the 0.30 s of
## running frames that is about 68 px - the whole of his lane, so a player who
## stays on his line is reached from anywhere in it.
@export var rush_speed := 225.0

@onready var _lane: Area2D = $Lane
@onready var _lane_reach: float = absf(_lane.position.x)

var _step := 0
var _breath := 0.0
var _rush_timer := 0.0
var _stop := 0.0
## Seconds into the eruption, and -1 when he is not having one.
var _rage_time := -1.0
var _blown := false

## The finishers thrown so far, newest last - only the tail is ever read.
var _finished: Array[String] = []
## Seconds left in the shell, and in the open guard after it; -1 when not.
var _shell := -1.0
var _open := -1.0
var _shell_cooldown := 0.0
## When each recent hit landed, on `_clock`, for the shell's count.
var _hits: Array[float] = []
var _clock := 0.0
## How long the player has been pressed against him, and the throw in flight.
var _pressed := 0.0
var _clinch_cooldown := 0.0
var _throwing := 0.0
## Who the heave caught and which way each of them is going: everybody standing
## in the clinch when it lands, so a party pressed against him goes flying too.
var _throws := {}
## Raging: the next string is a flurry; and after a flurry, the big one at once.
var _flurry_due := false
var _flurry_left := 0
var _after_flurry := false


## The building calls him Big Mo, and so does his bar. The base's scene-name
## rule would announce BIG_MO, underscore and all, off `big_mo.tscn`.
func title() -> String:
	return "BIG MO"


func _physics_process(delta: float) -> void:
	# A guest's copy is the host's, drawn (enemy_base.gd's *Online*).
	if not _in_charge():
		super(delta)
		return
	_rush_timer = maxf(_rush_timer - delta, 0.0)
	_breath = maxf(_breath - delta, 0.0)
	# Hit-stop, and the one thing that must always let go of it: a boss who
	# conceded mid-hold still has a concede animation to play.
	if _stop > 0.0:
		_stop = 0.0 if has_conceded else maxf(_stop - delta, 0.0)
		_sprite.speed_scale = 0.0 if _stop > 0.0 else 1.0
	_burn(delta)
	_tick_reactions(delta)
	super(delta)
	if has_conceded:
		return
	_lane.position.x = -_lane_reach if _facing_left else _lane_reach
	_watch_pressed(delta)
	_carry_throw(delta)
	_run_flurry()
	# The dash is the back of the rush's wind-up: he crouches, runs, and the
	# blow lands on the last running frame, so he connects when he arrives
	# rather than swinging at the air halfway there. There is no STRIKE phase
	# to hang this on - enemy_base fires the blow at the end of WINDUP and goes
	# straight to RECOVER - so the travel lives inside the wind-up. Not the
	# crouch, though: that is the tell, and he holds it where he stands.
	if attack == "rush" and phase == Phase.WINDUP \
			and _phase_time >= Poses.tell_of("rush"):
		var dir := -1.0 if _facing_left else 1.0
		velocity.x = dir * rush_speed
		move_and_slide()


## The eruption's own clock. It follows the SPRITE rather than the wall: while
## the blast holds him still, this holds too, so the fire rage.gd draws off the
## animation and the blast this fires cannot come apart.
func _burn(delta: float) -> void:
	if _rage_time < 0.0 or has_conceded:
		return
	if _stop > 0.0:
		return
	var was := _rage_time
	_rage_time += delta
	if not _blown and was < RAGE_BLAST and _rage_time >= RAGE_BLAST:
		_blown = true
		_stop = RAGE_HOLD
		_sprite.speed_scale = 0.0
		shook.emit(RAGE_SHAKE, RAGE_SHAKE_SECONDS)
	if _rage_time >= Poses.length_of("rage"):
		_rage_time = -1.0


## True only while the eruption is playing. He is rooted, silent and
## un-staggerable for its 0.95 s; `is_raging` is the thing that stays true.
func _erupting() -> bool:
	return _rage_time >= 0.0


func _attack_spec(id: String) -> Dictionary:
	return {
		"windup": Poses.windup_of(id),
		"recover": Poses.recover_of(id),
		"damage": DAMAGE[id],
	}


## Commit is per attack here, which the base does not do for itself.
func _begin_attack(id: String) -> void:
	commit_fraction = COMMIT.get(id, 0.6)
	super(id)


## The blow. The base decides whether it FINDS anybody; the room takes it
## either way, because a punch that misses still landed somewhere - and because
## the effect drawing it keys off the animation, which does not know either.
func _strike() -> void:
	var id := attack
	# The blow, before `super()` - which can clear `attack` - and paired with
	# the telegraph boss_base already fires on the wind-up. Said here rather
	# than in the base for the same reason as Ahmed's: a boss lands a blow his
	# own way. It plays whether or not the punch found anybody, exactly like
	# the shake below, because a punch that misses still landed somewhere.
	_sfx(id + "_hit")
	match id:
		# A lane rather than his reach circle - see UPPERCUT_REACH.
		"uppercut":
			for body in _in_lane(UPPERCUT_REACH, UPPERCUT_HALF_WIDTH):
				_touch_strike(body)
		# The first of five; `_run_flurry` throws the rest through the recover.
		"flurry":
			_flurry_left = FLURRY_PUNCHES - 1
			_flurry_punch()
			return
		_:
			super()
	var heavy: bool = id in ["hook", "uppercut", "counter"]
	_stop = HIT_STOP * (HIT_STOP_HOOK if heavy else 1.0)
	var throw: float = SHAKE.get(id, 0.0)
	if throw > 0.0:
		shook.emit(throw, SHAKE_SECONDS)


## The clinch's blow is a heave: hurt, then carried away from him. The shove is
## HELD by `_carry_throw` - one is 17 px, which is a nudge and not a throw. A
## heave the roll made miss carries nobody: the throw is part of the blow.
func _touch_strike(player: Node2D) -> void:
	super(player)
	if attack == "clinch" and player.has_method("shove") and not _untouchable(player):
		var away := player.global_position - global_position
		if away.length() < 0.5:
			away = Vector2(_dir(), 0.0)
		if _throwing <= 0.0:
			_throws.clear()
		_throws[player] = away
		_throwing = THROW_SECONDS
		player.call("shove", away, THROW_FORCE)


## In reach: the next beat of the combination, unless he is still breathing
## after finishing one. Raging, every other string is the flurry, and the big
## one follows the flurry with no breath between - the flurry walks you back,
## the finisher is what it was walking you into.
func _pick_attack() -> String:
	if _breath > 0.0:
		return ""
	if _after_flurry:
		_after_flurry = false
		_breath = _breath_length()
		return _finisher()
	if is_raging and _flurry_due and _step == 0:
		_flurry_due = false
		_after_flurry = true
		return "flurry"
	var id: String = COMBO[_step]
	_step += 1
	if _step >= COMBO.size():
		_step = 0
		_breath = _breath_length()
		_flurry_due = is_raging
		id = _finisher()
	return id


func _breath_length() -> float:
	return RAGE_BREATH if is_raging else breath_seconds


## Hook or uppercut, at random, but never more than FINISHER_RUN of one in a
## row - a read the dice turn into a habit is not a read.
func _finisher() -> String:
	var id: String = FINISHERS[randi() % FINISHERS.size()]
	var run := _finished.slice(-FINISHER_RUN)
	if run.size() == FINISHER_RUN and run.count(run[0]) == FINISHER_RUN \
			and id == run[0]:
		id = FINISHERS[(FINISHERS.find(id) + 1) % FINISHERS.size()]
	_finished.append(id)
	if _finished.size() > FINISHER_RUN:
		_finished.pop_front()
	return id


## Half health, once. Checked after the base has taken the hit, so a blow that
## finishes him concedes instead of setting him on fire on the way down.
##
## And the shell, which is in front of all of it: a hit on the shell never
## reaches the base, so it costs nothing, flashes nothing and staggers nothing.
func take_damage(amount: int) -> void:
	if _shell >= 0.0 and not has_conceded and health > 0:
		_block()
		return
	super(amount)
	if has_conceded or health <= 0:
		return
	if not is_raging and health <= roundi(float(max_health) * RAGE_AT):
		_begin_rage()
		return
	_count_hit()


## He drops whatever he was swinging. Being interrupted by your own temper is
## the point: the combination stops mid-count and starts again from the top.
func _begin_rage() -> void:
	# Both halves of the noise, on the one frame he goes up. The eruption is a
	# one-shot cut to land its loudest moment on RAGE_BLAST, so the blast, the
	# camera shake and the sound are one event rather than three. The fire
	# underneath it is a LOOP with no stop anywhere - he catches fire once and
	# never comes back down, and he is still burning when he kneels, which is
	# why nothing fades it on concede the way Ahmed's axe fades: Ahmed drops
	# the axe, and Big Mo is the fire.
	_sfx("rage")
	_sfx_loop("fire")
	# And the line. His alone - the base fires spot/taunt/hurt/stagger/concede
	# and one cue per attack, and none of those is "the moment the process
	# stops". It is said BEFORE `is_raging` goes true only for readability;
	# `_say` neither reads nor cares about that flag.
	_say("rage")
	is_raging = true
	_rage_time = 0.0
	_blown = false
	attack = ""
	_step = 0
	_breath = 0.0
	_stop = 0.0
	_sprite.speed_scale = 1.0
	# The temper wipes the slate along with the combination: whatever the
	# player was mashing when he went up is not counted towards a shell, and
	# whatever stance he was in is gone.
	_hits.clear()
	_shell = -1.0
	_open = -1.0
	_flurry_due = false
	_after_flurry = false
	_enter(Phase.CHASE)


## Rooted through the eruption and through the shell and the open guard: no
## attack starts, and the rush cannot open. A player pressed against him long
## enough is clinched before the combination gets its next beat.
func _advance_phase() -> void:
	if _erupting() or _guarding():
		return
	if phase == Phase.CHASE and _pressed >= CLINCH_AFTER and _clinch_cooldown <= 0.0:
		_pressed = 0.0
		_clinch_cooldown = CLINCH_COOLDOWN
		_begin_attack("clinch")
		return
	if phase == Phase.CHASE and not touching_player and _rush_timer <= 0.0 \
			and _breath <= 0.0 and _player_in_lane():
		_rush_timer = rush_cooldown
		_begin_attack("rush")
		return
	super()


## The eruption is the whole animation, so it owns the sprite while it runs;
## so do the shell and the open guard, which are stances rather than attacks.
func _animation_state(advancing: bool) -> String:
	if _erupting():
		return "rage"
	if _shell >= 0.0:
		return "shell"
	if _open >= 0.0:
		return "open"
	return super(advancing)


## He does not walk through it, and he cannot be staggered out of it. Damage
## still lands - a 0.95 s window of free hits is the reward for being close.
## The shell and the open guard root him the same way.
func _can_advance() -> bool:
	if _erupting() or _guarding():
		return false
	return super()


func _interruptible() -> bool:
	if _erupting() or _guarding():
		return false
	return super()


## The shell blinks bright, so a hit that does nothing was a hit you were told
## would do nothing.
func _resting_tint() -> Color:
	if _shell >= 0.0 and fmod(_shell, 0.2) >= 0.1:
		return SHELL_TINT
	return super()


## In the shell or standing open after it.
func _guarding() -> bool:
	return _shell >= 0.0 or _open >= 0.0


## Public for tests and for anything that wants to know a hit will be wasted.
func is_shelled() -> bool:
	return _shell >= 0.0


func is_open() -> bool:
	return _open >= 0.0


# --- the reactions -----------------------------------------------------------


## The clocks the three reactions run on, ticked before the base's step so a
## stance that ends this frame has handed the sprite back by the time the base
## picks an animation.
func _tick_reactions(delta: float) -> void:
	_clock += delta
	_shell_cooldown = maxf(_shell_cooldown - delta, 0.0)
	_clinch_cooldown = maxf(_clinch_cooldown - delta, 0.0)
	if has_conceded:
		_shell = -1.0
		_open = -1.0
		return
	if _shell >= 0.0:
		_shell -= delta
		if _shell < 0.0:
			# Nobody hit it. The guard drops, and that is the reward for waiting.
			_shell = -1.0
			_open = OPEN_SECONDS
	elif _open >= 0.0:
		_open -= delta
		if _open < 0.0:
			_open = -1.0
			_step = 0


## A hit that landed, for the shell's count. Not while he erupts, and he only
## covers up between punches: mid-wind-up he is committed to the swing, and the
## hit still counts towards the next chance he gets.
func _count_hit() -> void:
	if _erupting():
		return
	_hits.append(_clock)
	while not _hits.is_empty() and _clock - _hits[0] > SHELL_WINDOW:
		_hits.pop_front()
	if _hits.size() >= SHELL_HITS and _shell_cooldown <= 0.0 \
			and phase != Phase.WINDUP and not _guarding():
		_begin_shell()


func _begin_shell() -> void:
	_hits.clear()
	_shell = SHELL_SECONDS
	_shell_cooldown = SHELL_COOLDOWN
	attack = ""
	_step = 0
	_breath = 0.0
	_after_flurry = false
	_stop = 0.0
	_sprite.speed_scale = 1.0
	_enter(Phase.CHASE)
	_sfx("shell")
	# "Noted." His hurt lines were always this man's way of not being hurt, so
	# a shell with no lines of its own borrows them.
	if not _say("shell"):
		_say("hurt")


## A hit on the shell. Nothing lands, and he answers it straight away.
func _block() -> void:
	_sfx("block")
	_spark(global_position + CHEST)
	_tell("spark", [global_position + CHEST])
	_shell = -1.0
	_open = -1.0
	_begin_attack("counter")


func _spark(at: Vector2) -> void:
	var spark := BlockSpark.new()
	get_parent().add_child(spark)
	spark.global_position = at


## His snapshot: a boss's, and the two things his own effects read off him -
## the fire he keeps, and his hit-stop, which is his sprite's speed.
func net_state() -> Array:
	var state := super()
	state.append_array([is_raging, _sprite.speed_scale])
	return state


func apply_net_state(state: Array) -> void:
	super(state)
	if has_conceded or state.size() < NET_OWN + 2:
		return
	is_raging = bool(state[NET_OWN])
	_sprite.speed_scale = float(state[NET_OWN + 1])


func net_event(what: String, args: Array) -> void:
	if what == "spark" and not args.is_empty():
		_spark(args[0])
	else:
		super(what, args)


## Pressed against him, measured from feet to feet - the clinch's whole trigger.
## It keeps counting through his punches, because his breath alone is shorter
## than CLINCH_AFTER and a hug that only counted between strings could never be
## caught; but the clinch itself only opens between punches (`_advance_phase`).
## His punches stop at `stop_distance`, so nobody is this close by accident.
func _watch_pressed(delta: float) -> void:
	var player := target()
	if player == null or _erupting() or _guarding() or attack == "clinch" \
			or global_position.distance_to(player.global_position) > CLINCH_RANGE:
		_pressed = 0.0
		return
	_pressed += delta


## The heave, held: see THROW_SECONDS.
func _carry_throw(delta: float) -> void:
	if _throwing <= 0.0:
		return
	_throwing = maxf(_throwing - delta, 0.0)
	for player in _throws:
		if is_instance_valid(player) and (player as Node).is_in_group("player"):
			player.call("shove", _throws[player], THROW_FORCE)


## The flurry's other four punches, each on the frame that throws it, and the
## march that carries him after you while they land.
func _run_flurry() -> void:
	if attack != "flurry" or phase != Phase.RECOVER:
		return
	var thrown := FLURRY_PUNCHES - 1 - _flurry_left
	if _flurry_left > 0 and _phase_time >= float(thrown + 1) * FLURRY_GAP:
		_flurry_left -= 1
		_flurry_punch()
	if _phase_time < float(FLURRY_PUNCHES - 1) * FLURRY_GAP:
		velocity = Vector2(_dir() * FLURRY_MARCH, 0.0)
		move_and_slide()


## One straight punch: whoever stands in front of him, inside a jab's reach,
## is hit and shoved back. The grace window decides how many of the five hurt;
## every one that reaches you pushes, and one a roll made miss neither hurts
## nor pushes.
func _flurry_punch() -> void:
	_sfx("flurry_hit")
	for body in _in_lane(FLURRY_REACH, FLURRY_HALF_WIDTH):
		if _untouchable(body):
			continue
		if body.has_method("take_damage"):
			body.call("take_damage", contact_damage)
		if body.has_method("shove"):
			body.call("shove", Vector2(_dir(), 0.0), FLURRY_SHOVE)
	shook.emit(SHAKE["flurry"], SHAKE_SECONDS)


## The player, if they stand in a lane straight out in front of him.
func _in_lane(reach: float, half_width: float) -> Array[Node2D]:
	var out: Array[Node2D] = []
	for body in get_tree().get_nodes_in_group("player"):
		var b := body as Node2D
		if b == null:
			continue
		var rel := b.global_position - global_position
		var fwd := rel.x * _dir()
		if fwd >= -UPPERCUT_BACK and fwd <= reach and absf(rel.y) <= half_width:
			out.append(b)
	return out


## +1 facing right, -1 facing left.
func _dir() -> float:
	return -1.0 if _facing_left else 1.0


func _player_in_lane() -> bool:
	for body in _lane.get_overlapping_bodies():
		if body.is_in_group("player") and _forward_of(body) >= rush_min_distance:
			return true
	return false

## How far ahead of him a body stands, along the way he faces.
func _forward_of(body: Node2D) -> float:
	var dx := body.global_position.x - global_position.x
	return -dx if _facing_left else dx
