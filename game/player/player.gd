extends CharacterBody2D
## Top-down player. Moves in 8 directions but animates in 3 (down / up / side),
## because the sheet only draws a right-facing profile - left is that, flipped.

const SPEED := 90.0
const ACCELERATION := 900.0
## How much of walking speed the two light attacks keep. They used to root the
## body; a third lets a swing step in or drift back without letting the player
## dance out of a guard's finish, which the grace window and the interrupt
## tuning both assume. The stick also steers: facing follows it mid-attack and
## the hitbox re-parks (see _turn_attack). The charge stance and the heavy stay
## rooted - the heavy's ~1.9 rooted seconds are part of its damage maths.
const ATTACK_SLIDE := 0.35
const FRICTION := 1100.0
const MAX_HEALTH := 100
## Damage one swing deals to each enemy it reaches. A constant for now; when
## characters grow their own stats this moves into the roster recipe the same
## way looks did.
const ATTACK_POWER := 5
## Damage the thrust - the combo's second hit - deals. Reached only through a
## swing (a press during one, or just after), so it can never be spammed alone,
## which is what lets it outhit the swing without upsetting any balance.
const THRUST_POWER := 7
## Damage the arc - the combo's third and last hit - deals to everything the
## blade reaches, and what its lightning then deals to each body it jumps to.
## 5 + 7 + 12 is 24: one full cycle is exactly a guard and exactly the heavy,
## so every enemy HP in the game still dies on a whole hit (guard 3, wraith 3,
## warden 5, security 6). The jump is a SWING's worth so a body the bolt reached
## stays on the same 5 / 7 / 12 lattice as one the blade did - retune it and
## the breakpoints walk.
const ARC_POWER := 12
const ARC_JUMP_POWER := 5
## How far the lightning looks for its next body, from the one it just left,
## and how many times it may jump. World pixels; two jumps is three bodies, and
## it is the combo's whole answer to a crowd that does not cost the heavy's
## rooted seconds.
const ARC_JUMP_RANGE := 40.0
const ARC_JUMPS := 2
## Which light attack follows which: swing, rising slash, arc. The arc ends the
## chain, so the press after it is a fresh swing - see _on_animation_finished.
const LIGHT_NEXT := {"attack": "attack2", "attack2": "attack3", "attack3": "attack"}
## After a swing or a rising slash ends, a press within this window still
## chains the next hit, so deliberate timing combos as reliably as mashing does.
const COMBO_GRACE_SECONDS := 0.2
## Damage the heavy attack - the charged spin plus its wildfire - deals to
## EVERY enemy inside the Spinbox circle. Exactly a regular's health on purpose:
## an AoE that does not KILL the basic enemy thins no crowd and so never repays
## the ~1.9 rooted seconds it costs - at 15 it was strictly the wrong button.
## At 24 it one-shots a guard and a wraith while its single-target rate
## (~15.6/s counting the entry swing) stays below the light combo's 21, so the
## combo is still right against one enemy and the heavy right against a crowd.
const HEAVY_POWER := 24
## How long the attack button must be HELD before the heavy goes off - counted
## from the press, not from the swing's end, and it fires itself the moment it
## lands rather than waiting for a release.
##
## Both halves of that sentence are fixes for the same complaint: the hold was
## hard to do. It was 1.0s that only STARTED when the press's swing finished,
## so the real cost was 1.3s of standing in a room with four enemies in it,
## and it then asked for a release timed against a cue (the charge animation
## doubling speed) that nobody watching the enemies could see. Releasing a
## fraction early threw the whole hold away with no sign it had been close.
##
## So the swing is now INSIDE the charge instead of a tax before it, the total
## is 0.75 rather than 1.0, and the release is gone: hold, and it happens. What
## a player has to do is hold the button down, which is the one input nobody
## can get wrong. The cue moved off the eyes and onto the floor - see
## game/player/charge_ring.gd.
##
## The number is bounded by the same arithmetic the heavy has always been
## bounded by, and it still holds. Press to wildfire is now 0.75 + 0.29 + 0.29
## = 1.32s, so the heavy's single-target rate with its entry swing is
## (5 + 24) / 1.32 = 21.9/s against the light combo's (5 + 7 + 12) / 0.86 =
## 28/s. The combo stays the right answer to one enemy and the heavy to a
## crowd, which is the invariant - not the 1.0 itself.
const CHARGE_SECONDS := 0.75
## Grace period after a hit - set per difficulty mode from Difficulty at spawn.
## It meters ALL blows: hazards and enemies push damage with no timers of their
## own and this window is what turns that pressure into discrete hits. It is
## also the crowd dial, which is why difficulty owns it: a guard's attack cycle
## is 0.8s, so grace at 0.8 (EASY) means extra guards' strikes are swallowed and
## N enemies hit like one, while 0.5 (HARD) lets a crowd interleave.
var _grace_window := 0.8
## Floor on how far a slow may go. Below roughly this the player is not really
## playing any more, and no combination of sources should get there.
const MIN_SLOW_FACTOR := 0.2
## How a slowed character reads. Cold, and deliberately a tint rather than the
## blink the grace window owns, so being hurt and being slowed never look alike.
const SLOW_TINT := Color(0.6, 0.75, 1.0)
## How a body that is DOWN reads (knock_down): lying on the floor (the `fall`
## rows), a little darker than it stands and still solid - a body a teammate can
## find to revive, and plainly not in the fight. It used to be the standing
## frame faded to almost nothing; the Revive Lab preview put it on the floor.
const DOWN_TINT := Color(190 / 255.0, 190 / 255.0, 210 / 255.0)
## How close a teammate stands to revive a body that is down, centre to centre
## (game/revive.gd).
const REVIVE_RANGE := 16.0
## Getting up from a revive: rooted while the four frames of `rise` play.
const RISE_SECONDS := 0.36
## Every body that is down, which is how a player holding interact finds one to
## revive - by group, like everything that reaches a body.
const FALLEN_GROUP := &"fallen"
## How a body whose machine has gone silent reads (`away`): its own colours,
## frozen where it last was, see-through - somebody who is not here, rather
## than somebody who fell.
const AWAY_TINT := Color(1.0, 1.0, 1.0, 0.4)

## Ceiling on a single shove, in pixels per second. Below the walking speed of
## 90 on purpose: a push has to be something you feel and then walk out of, not
## something that takes the character away from you. It is also the guarantee
## that a shove can never post anybody through a wall - it is applied through
## `move_and_collide()`, and at this speed one physics frame moves about 1.2 px,
## nowhere near a 16 px tile.
const MAX_SHOVE := 70.0
## How long a shove takes to decay away, ramping linearly to nothing. The two
## numbers together are the whole feel: half a second off a 70 ceiling is about
## 17 px, which is a tile - far enough to read as being moved, near enough that
## a push you are still fighting a second later never happens.
const SHOVE_SECONDS := 0.5

## THE DODGE: the tumble roll, picked from the Dodge Lab preview (option A,
## https://claude.ai/artifact/2ucqkdtJrk4VmSgKE3gLU6) and shipped as previewed -
## its frames are tools/roll_pose.gd's, its dust roll_dust.gd's, and these are
## its numbers. A roll is a real move, DODGE_DISTANCE in a straight line over
## DODGE_SECONDS, the way the stick points - or straight back, away from the
## facing, with the stick at rest - so a desk or a body in the way stops it.
const DODGE_SECONDS := 0.32
const DODGE_DISTANCE := 48.0
## The stretch of the roll no blow can land in, in seconds from the press:
## most of it, which is what made the roll the forgiving one of the three.
## Blows only - a drain, a slow and a shove still reach a rolling body.
const DODGE_SAFE_FROM := 0.04
const DODGE_SAFE_UNTIL := 0.26
## How long after a roll ENDS before the next can start. Without it rolls chain
## into lasting safety, which is a second grace window nobody tuned - and the
## grace window is the crowd dial.
const DODGE_COOLDOWN := 0.45
## The share of walking speed a held stick has on the frame a roll ends, so it
## runs on into the walk instead of starting from a standstill.
const DODGE_EXIT := 0.8
## The dust left under the tumble: one puff this often, each lasting this long.
const DUST_EVERY := 0.09
const DUST_TRAIL_LIFE := 0.28

## How close the player has to get to a scripted destination before it counts
## as arrived. Six pixels rather than one: the escort's destination MOVES (it
## trails whoever is being followed), and a tighter ring makes the walk stutter
## between walking and idle every time the guide slows down.
const LEAD_STOP := 6.0

signal health_changed(health: int, max_health: int)
## Health hit zero. What that MEANS is game.gd's: lives are the party's pool,
## not this body's, so the body only says it fell.
signal died
## The hit feel, asked of game.gd on exactly a boss's terms: the player says a
## blow landed and how hard, and whatever owns the clock and the camera holds
## the room still or throws it about. A player that nothing is listening to -
## one instanced alone in a test - simply never pauses anything.
signal froze(seconds: float)
signal shook(strength: float, seconds: float)
## The host's: the world reached this body, and the rest of the party has to
## hear (game/sync/bodies.gd). `struck` and `drained` are seen by everybody -
## the owner blinks for them too - while `slowed` and `shoved` are only ever
## said of a REMOTE body, and only to its owner, who is the one moving it.
## Health itself travels on `health_changed`, which the host sends to everybody.
signal reached(what: String, args: Array)

## Preloaded by path rather than via `class_name`, like the rest of the project.
const Roster := preload("res://game/player/characters/roster.gd")
const InputSource := preload("res://game/player/input_source.gd")
const PlayerAudio := preload("res://game/player/player_audio.gd")
const Arc := preload("res://game/player/arc.gd")
const ChargeRing := preload("res://game/player/charge_ring.gd")
const DamageNumber := preload("res://game/player/damage_number.gd")
const StaticCharge := preload("res://game/player/static_charge.gd")
const Shock := preload("res://game/player/shock.gd")
const KillBurst := preload("res://game/player/kill_burst.gd")
const ScreenFlash := preload("res://game/player/screen_flash.gd")
const Supernova := preload("res://game/player/supernova.gd")
const RollDust := preload("res://game/player/roll_dust.gd")

## THE HIT FEEL, picked from the Combo Lab preview with one option per attack
## and shipped as previewed. None of it touches a damage number.
##
## How long the room holds still when an attack lands, by attack: a swing's
## worth is a flicker, the heavy is a beat. Asked once per FRAME something was
## struck, like the `hit` sound, and stops extend rather than stack (game.gd).
const HIT_STOP := {
	"attack": 0.04, "attack2": 0.05, "attack3": 0.07, "heavy": 0.1, "wildfire": 0.1,
}
## [strength, seconds] of camera shake: the arc's THUNDERCLAP, the heavy's
## SUPERNOVA going off, and a body dying.
const ARC_SHAKE := [2.0, 0.15]
const NOVA_SHAKE := [3.0, 0.22]
const KILL_SHAKE := [1.0, 0.08]
## The screen flash (screen_flash.gd) for the same two, and the supernova's own
## stop, which is asked on the frame the heavy FIRES rather than when it lands.
const ARC_FLASH := 0.1
const NOVA_FLASH := 0.06
const NOVA_STOP := 0.1
## A number over an enemy: white for the blade, the spark colour for a bolt's
## jump, double size and spark-darkened outline for the heavy.
const DEALT_INK := Color.WHITE
const DEALT_EDGE := Color(24 / 255.0, 18 / 255.0, 32 / 255.0)
const HEAVY_EDGE_DARKEN := 0.55

## Attack animation -> the cue it opens with. The two lights are named for the
## MOVEMENT rather than for the animation because that is what they are: air,
## not impact. Nothing has been struck on the frame a swing starts, so `hit`
## belongs to `_strike()` and to the frame something is actually reached - the
## enemies' rule (game/enemies/CLAUDE.md, The noise) pointed the other way.
const ATTACK_SOUNDS := {
	"attack": "swing",
	"attack2": "swing2",
	# The arc opens on the swing's own air until it has a cue of its own: a
	# `swing3` entry in tools/sfx/player.py, its stream in player.tscn, and
	# this line. Reusing a real cue rather than naming a missing one, because a
	# body that declares a cue with no file behind it is what test_player_sfx
	# exists to catch.
	"attack3": "swing",
	"heavy": "heavy",
}

enum Facing { DOWN, UP, SIDE }

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _hitbox: Area2D = $Hitbox
@onready var _spinbox: Area2D = $Spinbox
## The noise this body makes, or null. Optional on exactly an enemy's terms: a
## cue with no `Audio` child, or with no file behind it, is silence with no
## branch anywhere - so a fresh checkout runs before anybody has imported a WAV.
@onready var _audio: PlayerAudio = get_node_or_null("Audio")

## What drives this body: the stick and the attack button are asked of it and
## never of `Input` directly (input_source.gd). The keyboard unless whoever
## spawns the body hands it other hands before it enters the tree.
var input_source: InputSource = InputSource.new()
## Which of the cast this body is, by roster id. Empty means the one the player
## picked and saved - every solo run - and game.gd fills it in for the rest of
## a party, who did their own picking.
var character := ""
## Online, whose machine this body belongs to: its owner's peer id. 1 offline,
## where every body - a party on one machine included - is this machine's.
var peer := 1
## Whether ANOTHER machine moves this body (DESIGN.md's Multiplayer, M3). A
## remote body runs none of the player below: it stands where its owner last
## said (`apply_net_state()`), its picture plays what its owner played a beat
## ago (`net_draw()`), and the owner's machine is the only one that reads its
## hands. Set before the body enters the tree.
var remote := false
## Online, a remote body whose machine has gone SILENT - nothing heard from it
## for a second (game/sync/bodies.gd). It is out of the fight while it lasts,
## by the same group `knock_down` uses, but it is not down: no life is spent and
## nothing waits to get it up. It comes back the moment its owner is heard
## again, or goes with them when the line is given up on (M6's *The cracks*).
var away := false

var health := MAX_HEALTH
## Whether this body is DOWN - see knock_down(). Kept apart from being in the
## `player` group, which `away` takes a body out of too.
var _down := false
## The movement multiplier currently in force and how long is left of it. Public
## because they are a readout: the sprite tint reads them now and a HUD status
## icon would read the same pair.
var slow_factor := 1.0
var slow_seconds := 0.0

## The shove the player is currently carrying, and how long is left of it.
## Private where the slow pair is public because nothing reads this but the
## movement below - a push has no tint and no HUD row: you find out about it by
## ending up somewhere else.
var _shove := Vector2.ZERO
var _shove_seconds := 0.0

## Cutscene control. While the world has the wheel the stick and the attack
## button are ignored outright - not merely unread: an attack in progress is
## cancelled on the way in, so a conversation cannot start with a sword already
## swinging through it. Deliberately NOT `set_physics_process(false)`, which is
## what a door transition uses: a frozen body cannot walk, and being led on a
## tour is the one time the player moves without touching the keyboard.
var _scripted := false
## Where the world is currently walking the player to, or null to stand still.
## Re-set every frame by whoever is leading, so following a moving guide is the
## same mechanism as walking to a fixed mark.
var _lead = null
var _facing: Facing = Facing.DOWN
var _facing_left := false
## The attack animation currently playing ("" when none), the one buffered to
## chain after it, and how long a late press can still chain a thrust. A press
## mid-attack is buffered rather than dropped - dropped inputs read as the game
## eating the button, and combos live or die on that feel.
var _attack := ""
var _buffered := ""
var _combo_grace := 0.0
## Which light attack a press inside the grace window chains into - the next
## link after whichever one just ended. Only read while _combo_grace > 0.
var _combo_next := ""
## The colour this character's weapon effects are drawn in, off the roster
## recipe at spawn: the bolt the arc throws between enemies has to match the
## sparks baked into the sheet, and Roster.spark_hex is the one rule both read.
var _spark := Color(Roster.SPARK_BALD)
## How long the attack button has been down, counted from the PRESS. It needs
## no reset of its own: a press can only follow a release, and a release zeroes
## it, so the frame `just_pressed` fires is already a fresh count. This is what
## makes the opening swing part of the charge rather than a tax before it.
var _hold := 0.0
## Charge stance: entered by still holding the button when an attack ends, and
## rooted while it lasts. It starts at whatever `_hold` has already reached, so
## the swing counts; at CHARGE_SECONDS the heavy fires ITSELF. Letting go before
## then just returns to idle - the press's swing already happened, so an early
## release loses nothing.
var _charging := false
var _charge := 0.0
## The ring drawn at the feet while charging, or null. Owned here rather than
## placed in player.tscn because it exists only for the length of a stance.
var _ring: Node2D = null
var _grace := 0.0
## The newest number a drain put up, which later ticks add to while it lasts -
## see damage_number.gd. A blow never touches it: a blow is its own number.
var _drain_number: Node2D = null
## Enemies already struck by the current swing, so a swing lands once per enemy
## rather than once per physics frame it overlaps them.
var _swing_hits := {}
## The thunderclap's and the supernova's white, at CanvasLayer 1.
var _screen_flash: CanvasLayer = null
## A remote body's: which move its picture is in - the animation without its
## facing - so a move is announced once as it starts and never again as the
## body turns inside it (see net_draw).
var _drawn_move := ""
## The physics frame a remote body last made its `hit` on - see net_event.
var _heard_hit := -1
## The roll in progress: how far into it (negative while not rolling) and which
## way, the cooldown left after the last one, and whether the attack button
## went down during it - owed, and swung the moment it ends.
var _dodge_t := -1.0
var _dodge_dir := Vector2.ZERO
var _dodge_cooldown := 0.0
var _dodge_swing := false
## Counts down to the next puff of a roll's trail: this body's own roll, or on a
## remote body the roll its picture is in.
var _dust_clock := 0.0
## A remote body's: whether its owner says it is in the untouchable stretch of a
## roll, as of the newest step. The host trusts it - see take_damage().
var _net_untouchable := false
## A remote body's: which way the roll its picture is in is going.
var _drawn_roll := Vector2.ZERO
## The teammate this body is reviving - holding interact over them - or null.
## Asked of the hands every physics frame on the machine that moves the body;
## a remote body's is its owner's word, as a peer id (`_net_reviving`).
var _reviving: Node2D = null
var _net_reviving := 0
## Seconds left of getting up from a revive, rooted (get_up).
var _rise := 0.0


func _ready() -> void:
	_apply_character()
	# Read once at spawn, like every difficulty number: the mode can only change
	# at the main menu, and a new run builds a fresh player.
	_grace_window = Difficulty.grace_seconds()
	_sprite.animation_finished.connect(_on_animation_finished)
	_apply_animation("idle")
	_screen_flash = ScreenFlash.new()
	add_child(_screen_flash)


## Every character shares the same animation set, so becoming one is a frames
## swap. An unknown saved id keeps the scene's default look rather than crashing.
func _apply_character() -> void:
	var id := character
	if id == "":
		id = Settings.get_value(&"player", &"character", Roster.DEFAULT_ID)
	# Kept, so whoever puts a name to this body (the HUD's party rows) reads
	# the same answer the frames were picked by.
	character = id
	var path := Roster.frames_path(id)
	if path != "" and path != _sprite.sprite_frames.resource_path:
		_sprite.sprite_frames = load(path)
	var entry := Roster.find(id)
	if entry.has("recipe"):
		_spark = Color(Roster.spark_hex(entry["recipe"]))


func _physics_process(delta: float) -> void:
	if remote:
		# The one clock a remote body keeps is the grace window, and only on
		# the host, where blows on it are decided. Its blink is the owner's,
		# and arrives with everything else it draws.
		_grace = maxf(_grace - delta, 0.0)
		return
	# First, so a press is dated to this frame whichever branch below asks.
	input_source.tick()
	if _grace > 0.0:
		_grace = maxf(_grace - delta, 0.0)
		# Blink for as long as the grace lasts, so a hit reads on the character
		# and not only on the HUD bar.
		_sprite.visible = _grace == 0.0 or fmod(_grace, 0.2) >= 0.1

	if slow_seconds > 0.0:
		slow_seconds = maxf(slow_seconds - delta, 0.0)
		if slow_seconds == 0.0:
			slow_factor = 1.0
		_sprite.modulate = SLOW_TINT if slow_seconds > 0.0 else Color.WHITE

	if _combo_grace > 0.0:
		_combo_grace = maxf(_combo_grace - delta, 0.0)

	# A shove decays on its own clock, up here with the other things the player
	# is CARRYING rather than down in the movement - so it runs out at the same
	# rate whether the player is walking out of it, swinging, or stood still.
	if _shove_seconds > 0.0:
		_shove_seconds = maxf(_shove_seconds - delta, 0.0)
		_shove = _shove.move_toward(Vector2.ZERO,
			MAX_SHOVE / SHOVE_SECONDS * delta)

	# Getting up from a revive: rooted for the four frames of `rise`, which the
	# sprite plays by itself, and standing at the end of them.
	if _rise > 0.0:
		_rise = maxf(_rise - delta, 0.0)
		velocity = Vector2.ZERO
		if _rise == 0.0:
			_apply_animation("idle")
		return

	# Scripted movement short-circuits everything below: no stick, no attack,
	# no combo. The timers above still run, because a blow landed during a
	# conversation still has its grace window to spend.
	if _scripted:
		_scripted_step(delta)
		return

	var direction := input_source.move()

	# Holding interact over a teammate who is down is a revive (game/revive.gd):
	# standing, turned to them, the stick and the attack button both ignored for
	# as long as it is held. Letting go - or a roll, which takes the hands - is
	# how it stops.
	_reviving = _fallen_in_reach()
	if _reviving != null:
		direction = Vector2.ZERO
		_face(_reviving.global_position - global_position)

	if input_source.attack_held():
		_hold += delta
	else:
		_hold = 0.0

	if _dodge_cooldown > 0.0 and not _dodging():
		_dodge_cooldown = maxf(_dodge_cooldown - delta, 0.0)
	if input_source.dodge_pressed():
		_start_dodge(direction)

	if _dodging():
		# A press mid-roll is owed rather than dropped - a dropped press reads as
		# the game eating the button - and swings as the roll ends.
		if input_source.attack_pressed():
			_dodge_swing = true
	elif not _charging and _reviving == null and input_source.attack_pressed():
		if _attack == "":
			_start_attack(_combo_next if _combo_grace > 0.0 else "attack")
		else:
			# Mid-attack queues the next link of the chain; mid-heavy queues a
			# fresh swing.
			_buffered = LIGHT_NEXT.get(_attack, "attack")

	if _dodging():
		_roll(delta)
	elif _charging:
		_charge += delta
		var filled := clampf(_charge / CHARGE_SECONDS, 0.0, 1.0)
		# Progress, twice, because a fight gives the player nowhere to look: the
		# ring on the floor fills, and the stance winds up towards double speed
		# as it goes. The old cue SNAPPED to double at the ready point and said
		# nothing before it, which is a cue that only helps somebody already
		# counting.
		_sprite.speed_scale = lerpf(1.0, 2.0, filled)
		if _ring != null:
			_ring.progress = filled
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
		if _charge >= CHARGE_SECONDS:
			# It fires ITSELF. There is no release to time and no way to hold
			# past it into nothing - the stance ends the only way it can end
			# well, and the ring flares on the frame it does.
			_end_charge(true)
			_start_attack("heavy")
		elif not input_source.attack_held():
			# Let go early and nothing happened, so nothing flashes: the ring
			# is dropped rather than flared. The hum is faded rather than cut,
			# because an early release loses nothing (the press's swing already
			# happened) and so must not sound like something broke.
			_end_charge(false)
			_apply_animation("idle")
	elif _attack != "":
		if LIGHT_NEXT.has(_attack) and direction != Vector2.ZERO:
			# Light attacks steer and slide at a fraction of walking speed.
			_turn_attack(direction)
			velocity = velocity.move_toward(
				direction * SPEED * slow_factor * ATTACK_SLIDE, ACCELERATION * delta)
		else:
			# The heavy, its wildfire, and a light attack with no stick held
			# brake to a stop.
			velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
		_strike()
	elif direction != Vector2.ZERO:
		_face(direction)
		velocity = velocity.move_toward(direction * SPEED * slow_factor,
			ACCELERATION * delta)
		_apply_animation("walk")
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
		_apply_animation("idle")

	move_and_slide()
	if _dodging():
		_rolled(delta)

	# The shove rides ON TOP of whatever the player was doing rather than
	# replacing it: a stumble you can still walk against is a stumble, and one
	# that takes the stick away for half a second is a cutscene. Applied after
	# the ordinary move and to every branch above alike - walking, sliding
	# through a light attack, rooted in the heavy - because being rooted is not
	# being bolted down.
	#
	# It is a SEPARATE displacement and deliberately never added to `velocity`.
	# Velocity is carried between frames and only bled off at FRICTION, so
	# adding the push to it every frame compounds: a 70 px/s shove held for a
	# third of a second reaches several hundred, then coasts the player across
	# the room long after the shove itself is over. `move_and_collide` keeps the
	# one guarantee that matters - the room's own walls stop it - without
	# touching the state the stick owns.
	if _shove_seconds > 0.0:
		move_and_collide(_shove * delta)


## What this body looks like now, for the other machines (game/sync/): where it
## stands and what its sprite is drawing - the frame, the facing, the tint a
## slow or a fall gives it, the grace window's blink - and how full a charge
## is, for the ring at its feet. The owner's machine sends it; every other
## stands the body where it says (apply_net_state) and draws its picture a beat
## later (net_draw). Plain values, because it crosses the wire thirty times a
## second.
func net_state() -> Array:
	return [global_position, _sprite.animation, _sprite.frame, _sprite.flip_h,
		_sprite.modulate.to_rgba32(), _sprite.visible,
		clampf(_charge / CHARGE_SECONDS, 0.0, 1.0) if _charging else 0.0,
		_dodge_dir if _dodging() else Vector2.ZERO, _untouchable(),
		int(_reviving.get("peer")) if _reviving != null else 0]


## The newest word on a remote body: where it IS. Only the body moves here - the
## picture is net_draw's, a beat behind (game/sync/bodies.gd's header says why
## the two are apart).
##
## And the picture stays exactly where it was. A step arrives with the network
## poll, after the physics frame that drew the picture and before the screen
## is drawn, so a sprite left riding on the body would be put on screen a whole
## step ahead and pulled back on the next physics frame - a twitch thirty times
## a second, and an idle picture shuffling before its walk has begun.
func apply_net_state(state: Array) -> void:
	if state.size() >= 7:
		var was := global_position
		global_position = state[0]
		_sprite.position -= global_position - was
	# The newest word, not the picture's: a blow on this body is decided on the
	# host NOW, and whether it is mid-roll now is what its owner said last.
	_net_untouchable = state.size() >= 9 and bool(state[8])
	# And who it is reviving, on the same terms: the host counts a revive from
	# the newest word (game/revive.gd).
	_net_reviving = int(state[9]) if state.size() >= 10 else 0


## A remote body's picture: what its owner drew `DELAY` ago, standing at
## `where`, which is on its way between two steps (game/sync/bodies.gd). The
## body itself is at the newest step, so the picture is the sprite's offset
## from it, nothing at all once it stands still.
##
## The sprite keeps PLAYING between two steps, so its frame is only corrected
## when it has drifted, and a frame that fits the picture is never yanked back
## to the one the message was sent on.
func net_draw(state: Array, where: Vector2) -> void:
	if state.size() < 7:
		return
	_sprite.position = where - global_position
	# Down is decided on this machine (game.gd's net_down), and so is the picture
	# of it: the fall knock_down started here, held on its last frame where it
	# lies. A picture still a beat behind must neither stand the body back up nor
	# play its owner's copy of the fall over this one.
	if is_down():
		return
	var anim := StringName(state[1])
	var frame := int(state[2])
	if _sprite.animation != anim and _sprite.sprite_frames.has_animation(anim):
		_drawn(String(anim).get_slice("_", 0), state[7] if state.size() >= 9 else Vector2.ZERO)
		_sprite.play(anim)
		_sprite.frame = frame
	elif absi(_sprite.frame - frame) > 1:
		_sprite.frame = frame
	if not _sprite.is_playing():
		_sprite.play()
	_sprite.flip_h = bool(state[3])
	if away:
		_sprite.modulate = AWAY_TINT
		_sprite.visible = true
	else:
		_sprite.modulate = Color.hex(int(state[4]))
		_sprite.visible = bool(state[5])
	if _ring != null:
		_ring.progress = float(state[6])
	# A roll's trail, under the picture rather than the body, on the owner's
	# clock: one puff every DUST_EVERY while the picture tumbles.
	if _drawn_move == "dodge":
		_dust_clock -= get_physics_process_delta_time()
		if _dust_clock <= 0.0:
			_dust_clock = DUST_EVERY
			RollDust.kick(self, global_position + _sprite.position,
				Vector2(-_drawn_roll.x * 12.0, 0.0), DUST_TRAIL_LIFE)


## A remote body's picture going into another move: the moments its owner's
## machine had there, read off what it draws - the air of a swing, the heavy's
## supernova, the charge's hum and its ring, a roll's dust. Not the stop, the
## shake or the flash: those are the attacker's to feel, on the attacker's
## screen. `roll` is the way a roll the picture goes into is heading.
func _drawn(move: String, roll := Vector2.ZERO) -> void:
	if move == _drawn_move:
		return
	var was := _drawn_move
	_drawn_move = move
	if was == "dodge":
		_stand_dust(global_position + _sprite.position, _drawn_roll)
	if was == "charge":
		if _ring != null:
			if move == "heavy":
				_ring.fire()
			else:
				_ring.queue_free()
			_ring = null
		_sfx_fade("charge", 0.08)
	match move:
		"charge":
			_ring = ChargeRing.new()
			_ring.setup(_spark)
			# Under the SPRITE, which is where the picture is.
			_sprite.add_child(_ring)
			_sfx_loop("charge")
		"heavy":
			_sfx(ATTACK_SOUNDS["heavy"])
			var nova := Supernova.new()
			add_child(nova)
			nova.setup(global_position + _sprite.position, _spark)
		"wildfire":
			_sfx("wildfire")
		"dodge":
			_drawn_roll = roll
			_dust_clock = 0.0
			_kick_dust(global_position + _sprite.position, roll)
		_:
			_sfx(ATTACK_SOUNDS.get(move, ""))


## The world takes the wheel. Any swing, thrust, charge or heavy in flight is
## dropped here rather than allowed to finish: a cutscene that begins on frame
## two of a combo would otherwise play out over the top of it, hitbox and all.
##
## Health, grace and slows are untouched - being talked at is not a safe room.
func take_control() -> void:
	_scripted = true
	_lead = null
	_reviving = null
	_drop_dodge()
	_attack = ""
	_buffered = ""
	_combo_grace = 0.0
	_hold = 0.0
	# Dropped, never fired: a conversation must not open with a heavy going off
	# in it, however full the charge was on the frame the world took over.
	_end_charge(false)
	_swing_hits.clear()
	velocity = Vector2.ZERO
	_apply_animation("idle", true)
	# Cut, not faded: a hum trailing into the first line of a conversation is
	# the cutscene starting on top of the combat it just cancelled.
	_sfx_stop("charge")


func release_control() -> void:
	_scripted = false
	_lead = null


func scripted() -> bool:
	return _scripted


## Walk here, under the player's own legs and at the player's own speed. Only
## obeyed while the world has the wheel, so nothing can drag a player who is
## still playing. Call again to redirect - an escort re-calls it every frame
## with a point that trails the guide - and `null` to stand still.
func lead_to(point) -> void:
	_lead = point


## Turn to look at something without moving. Used at the start of a
## conversation, so the player is not delivering their half of it to a wall.
func face_towards(point: Vector2) -> void:
	var to_point := point - global_position
	if to_point == Vector2.ZERO:
		return
	_face(to_point)
	_apply_animation("idle")


## One frame of being led. The same walk the stick produces - same speed, same
## acceleration, same animation - with the direction coming from a destination
## instead of the keyboard, so being escorted looks exactly like walking.
func _scripted_step(delta: float) -> void:
	var direction := Vector2.ZERO
	if _lead != null:
		var to_lead: Vector2 = _lead - global_position
		if to_lead.length() > LEAD_STOP:
			direction = to_lead.normalized()
	if direction != Vector2.ZERO:
		_face(direction)
		velocity = velocity.move_toward(direction * SPEED * slow_factor,
			ACCELERATION * delta)
		_apply_animation("walk")
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
		_apply_animation("idle")
	move_and_slide()


func _face(direction: Vector2) -> void:
	# Horizontal wins ties, so a diagonal reads as the side profile.
	if absf(direction.x) >= absf(direction.y):
		_facing = Facing.SIDE
		_facing_left = direction.x < 0.0
	else:
		_facing = Facing.UP if direction.y < 0.0 else Facing.DOWN


func _facing_suffix() -> String:
	match _facing:
		Facing.UP:
			return "up"
		Facing.SIDE:
			return "side"
		_:
			return "down"


## Mid-attack the stick steers: facing follows it, the hitbox re-parks, and the
## sprite switches to the new facing's row of the SAME attack at the SAME frame
## and progress, so a swing that turns keeps its timing and its telegraph. The
## hit ledger is untouched - turning cannot land one swing twice on one enemy.
func _turn_attack(direction: Vector2) -> void:
	var before := _facing
	var before_left := _facing_left
	_face(direction)
	if _facing == before and _facing_left == before_left:
		return
	_hitbox.position = _hitbox_offset()
	var frame := _sprite.frame
	var progress := _sprite.frame_progress
	_apply_animation(_attack)
	_sprite.set_frame_and_progress(frame, progress)


func _apply_animation(state: String, restart := false) -> void:
	_sprite.flip_h = _facing == Facing.SIDE and _facing_left
	# A slowed walk played at full rate reads as skating across the floor. The
	# swing keeps its own timing - a slow takes your legs, not your sword.
	_sprite.speed_scale = slow_factor if state == "walk" else 1.0
	var anim := "%s_%s" % [state, _facing_suffix()]
	if restart:
		_sprite.animation = anim
		_sprite.frame = 0
		_sprite.play(anim)
	elif _sprite.animation != anim or not _sprite.is_playing():
		_sprite.play(anim)


func _start_attack(anim: String) -> void:
	_attack = anim
	_buffered = ""
	_combo_grace = 0.0
	_swing_hits.clear()
	if anim != "heavy":
		_hitbox.position = _hitbox_offset()
	_apply_animation(anim, true)
	_sfx(ATTACK_SOUNDS.get(anim, ""))
	if anim == "heavy":
		_supernova()


## The heavy going off: the room freezes, two shockwaves roll out and the
## floor cracks round the feet. The embers that fed it were the ring's.
func _supernova() -> void:
	froze.emit(NOVA_STOP)
	shook.emit(NOVA_SHAKE[0], NOVA_SHAKE[1])
	_screen_flash.flash(NOVA_FLASH)
	var nova := Supernova.new()
	add_child(nova)
	nova.setup(global_position, _spark)


## The hitbox sits one step ahead of the body in whatever direction the attack
## faces, and stays live for the whole animation. Both light attacks share it:
## the second hit (attack2) is a rising slash on the spot - a launcher, not a
## thrust - whose arc covers the same reach as the swing's, and it no longer
## lunges, since the jump is its movement.
func _hitbox_offset() -> Vector2:
	match _facing:
		Facing.UP:
			return Vector2(0, -14)
		Facing.SIDE:
			return Vector2(-11 if _facing_left else 11, -4)
		_:
			return Vector2(0, 6)


## Group + method rather than type, like every cross-feature touch in this
## project: the player never names an enemy script. The heavy hits through the
## Spinbox circle - all around, as the spin and its fire ring promise - and its
## ledger spans the spin AND the wildfire, so it lands once per enemy total.
func _strike() -> void:
	var heavy := _attack == "heavy" or _attack == "wildfire"
	var area := _spinbox if heavy else _hitbox
	var power := ATTACK_POWER
	if heavy:
		power = HEAVY_POWER
	elif _attack == "attack2":
		power = THRUST_POWER
	elif _attack == "attack3":
		power = ARC_POWER
	var struck: Array[Node2D] = []
	for body in area.get_overlapping_bodies():
		if _swing_hits.has(body) or not body.is_in_group("enemies"):
			continue
		if body.has_method("take_damage"):
			_swing_hits[body] = true
			_land(body, power, "heavy" if heavy else "blade")
			struck.append(body)
			if body.is_queued_for_deletion():
				continue
			# STATIC CHARGE: the two light hits tag what they reach, for the
			# arc to set off. JUGGLE: the rising slash launches what it reaches.
			if _attack == "attack" or _attack == "attack2":
				StaticCharge.add_to(body, _spark, self)
			if _attack == "attack2" and body.has_method("launch"):
				body.call("launch")
	if struck.is_empty():
		return
	if _attack == "attack3":
		_arc(struck)
	# Once for the frame, not once per enemy: a heavy landing on four bodies is
	# one impact, and four copies of one clip started together is a click. The
	# hit-stop is the same, for the same reason - four stops on one frame are
	# one stop.
	_sfx("hit")
	froze.emit(HIT_STOP.get(_attack, 0.0))


## One blow the player lands, and everything a blow that lands now does: the
## damage, the number over the body, the recoil, and - if it killed - the body
## breaking apart and a knock of the camera. `kind` is "blade", "jump" or
## "heavy", which only decides how the number is drawn. The number shows only
## when health actually moved, so a conceded boss standing in the swing says
## nothing.
func _land(body: Node2D, power: int, kind: String) -> void:
	var away := body.global_position - global_position
	if not _world_reaches():
		_land_for_host(body, power, kind, away)
		return
	var before: Variant = body.get("health")
	body.call("take_damage", power)
	var after: Variant = body.get("health")
	var moved := before == null or after == null or int(after) < int(before)
	var killed := body.is_queued_for_deletion()
	_show_blow(body, power, kind, moved, killed, away)
	if killed:
		# Not on the heavy: game.gd's newest shake REPLACES the last, and the
		# supernova's bigger one went out the frame the heavy fired. The arc
		# is safe the other way round - its own shake is asked after its kills.
		if kind != "heavy":
			shook.emit(KILL_SHAKE[0], KILL_SHAKE[1])
	# Online, everybody else sees it land too (net_event's "blow"). Only a blow
	# that DID something: one a conceded boss took for nothing is nothing.
	if moved:
		_tell("blow", [body, power, kind, _attack, killed])


## A blow this body landed, drawn: the number over what it hit, and its pieces
## if it killed it or the jolt if it did not. Everything a blow is but the damage
## - which is why a machine that only SEES somebody else's blow draws it with
## this too (net_event), and gets the same blow.
func _show_blow(body: Node2D, power: int, kind: String, moved: bool, killed: bool,
		away: Vector2) -> void:
	if moved:
		var ink := _spark if kind == "jump" else DEALT_INK
		var edge := _spark.darkened(HEAVY_EDGE_DARKEN) if kind == "heavy" else DEALT_EDGE
		DamageNumber.spawn_dealt(body, power, ink, edge, 2 if kind == "heavy" else 1)
	if killed:
		KillBurst.shatter(body, away, _spark)
	elif body.has_method("recoil"):
		body.call("recoil", away)


## A blow on a guest: the host deals it, and this screen shows it at once -
## the benefit of the doubt the attacker gets, since waiting a round trip to
## see your own hit land is the one lag a player feels in their hands. The
## number and the jolt, then; the white flash is the enemy's own (net_flash),
## and whether it died is the host's to say, and comes back (net_event).
func _land_for_host(body: Node2D, power: int, kind: String, away: Vector2) -> void:
	if body.get("has_conceded") == true or int(body.get("health")) <= 0:
		return
	_tell("blow", [body, power, kind, _attack])
	_show_blow(body, power, kind, true, false, away)
	if body.has_method("net_flash"):
		body.call("net_flash")


## A moment of this body's - a blow it landed, a bolt it threw - for the rest
## of the party (game/sync/world.gd's *A player's moment*). Through the `sync`
## group like a boss's `_tell`, so offline nobody is in it to hear.
func _tell(what: String, args: Array) -> void:
	if is_inside_tree():
		get_tree().call_group(&"sync", &"from_player", self, what, args)


## Somebody else's moment on this machine, or this body's own told back. A blow
## shows what it did; on the attacker's own machine it was shown at once, and
## only whether it KILLED is news (the host's to say). A bolt is drawn where it
## went, and leaves what it touched crackling.
func net_event(what: String, args: Array) -> void:
	match what:
		"blow":
			if args.size() < 5 or not is_instance_valid(args[0]):
				return
			var body: Node2D = args[0]
			var attack := String(args[3])
			var killed := bool(args[4])
			var away := body.global_position - global_position
			if not remote:
				if killed:
					KillBurst.shatter(body, away, _spark)
					if String(args[2]) != "heavy":
						shook.emit(KILL_SHAKE[0], KILL_SHAKE[1])
				return
			# The host flashed it dealing it; a guest's copy is drawn.
			if not _world_reaches() and not killed and body.has_method("net_flash"):
				body.call("net_flash")
			_show_blow(body, int(args[1]), String(args[2]), true, killed, away)
			if not killed:
				if attack == "attack" or attack == "attack2":
					StaticCharge.add_to(body, _spark, self)
				if attack == "attack2" and body.has_method("launch"):
					body.call("launch")
			# Once for the frame, as on the attacker's own: four bodies under
			# one heavy are one impact.
			if _heard_hit != Engine.get_physics_frames():
				_heard_hit = Engine.get_physics_frames()
				_sfx("hit")
		"bolt":
			if args.size() < 2 or not remote:
				return
			var chains: Array[PackedVector2Array] = []
			for chain in args[0]:
				chains.append(PackedVector2Array(chain))
			var bolt := Arc.new()
			bolt.setup(chains, _spark)
			get_parent().add_child(bolt)
			_thunder(args[1])


## Every body a bolt went through: its charge set off, and crackling.
func _thunder(touched: Array) -> void:
	for body in touched:
		if not is_instance_valid(body) or not body is Node2D:
			continue
		var charge := StaticCharge.of(body, self)
		if charge != null:
			charge.discharge()
		if not body.is_queued_for_deletion():
			Shock.apply(body, _spark)


## The arc's lightning. From each body the blade reached it jumps to the
## nearest enemy within ARC_JUMP_RANGE that nothing in this attack has touched
## yet, and once more from there, ARC_JUMPS times. The ledger is the same
## `_swing_hits`, which buys two things at once: the bolt can never double back
## onto the body it left, and the hitbox cannot land a second 12 on a body the
## bolt already reached for 5 if that body is standing in it on a later frame.
## A conceded boss is skipped rather than jumped to - he is in the group and
## takes nothing, and a jump spent on him is a jump the crowd did not get.
##
## The bolt is drawn by game/player/arc.gd in this character's spark colour,
## the way a boss draws his effects live rather than off a sheet: a line
## between two bodies has no fixed shape a sheet could hold.
func _arc(struck: Array[Node2D]) -> void:
	var chains: Array[PackedVector2Array] = []
	var touched: Array[Node2D] = []
	for primary in struck:
		var chain := PackedVector2Array([_hitbox.global_position, _chest(primary)])
		touched.append(primary)
		var from := primary
		for _jump in ARC_JUMPS:
			var next := _nearest_enemy(from.global_position)
			if next == null:
				break
			_swing_hits[next] = true
			_land(next, ARC_JUMP_POWER, "jump")
			chain.append(_chest(next))
			touched.append(next)
			from = next
		chains.append(chain)
	var bolt := Arc.new()
	bolt.setup(chains, _spark)
	get_parent().add_child(bolt)
	# THE THUNDERCLAP: the room shakes and goes white for a tenth of a second,
	# every body the bolt went through is left crackling, and every charge the
	# light hits left on them goes off. The stop is the frame's own (HIT_STOP).
	shook.emit(ARC_SHAKE[0], ARC_SHAKE[1])
	_screen_flash.flash(ARC_FLASH)
	_thunder(touched)
	# The bolt on everybody else's screen - not the shake or the flash, which
	# are the thrower's to feel.
	_tell("bolt", [chains, touched])


## The nearest enemy the arc may still jump to, or null. Group + method, never
## type, like everything else here that reaches across to the enemies.
##
## A body carrying THIS player's static charge beats an uncharged one anywhere
## inside the range, and the nearest wins among equals - so the light hits
## decide where the chain goes. That is the whole of the charge's logic: who,
## never how much. A partner's charge is theirs (static_charge.gd's `by`).
func _nearest_enemy(at: Vector2) -> Node2D:
	var best: Node2D = null
	var best_distance := ARC_JUMP_RANGE
	var best_charged := false
	for node in get_tree().get_nodes_in_group("enemies"):
		if _swing_hits.has(node) or not node.has_method("take_damage"):
			continue
		if node.get("has_conceded") == true or node.is_queued_for_deletion():
			continue
		var distance: float = (node as Node2D).global_position.distance_to(at)
		if distance > ARC_JUMP_RANGE:
			continue
		var charged := StaticCharge.of(node, self) != null
		if (charged and not best_charged) or (charged == best_charged and distance <= best_distance):
			best_distance = distance
			best = node
			best_charged = charged
	return best


## Where a bolt lands on a body: chest height above the feet the position marks.
func _chest(body: Node2D) -> Vector2:
	return body.global_position + Vector2(0, -10)


## Leaves the charge stance, one way or the other. `fired` flares the ring and
## hands it its own death; anything else drops it on the spot, because a ring
## that flashes on a cancelled charge tells the player something happened when
## nothing did. Every exit from the stance goes through here - the auto-fire,
## an early release, a conversation taking the wheel and a death - so the ring
## can never outlive the stance that built it.
func _end_charge(fired: bool) -> void:
	_charging = false
	_charge = 0.0
	_sprite.speed_scale = 1.0
	if _ring != null:
		if fired:
			_ring.fire()
		else:
			_ring.queue_free()
		_ring = null
	# Faded either way: an early release must not sound like something broke,
	# and a release into the heavy is masked by the heavy's own swing.
	_sfx_fade("charge", 0.08)


## THE DODGE, on the K key (or Ctrl, off the web). Refused while one is still
## rolling or cooling down, and from inside the heavy and its wildfire, whose
## rooted seconds are part of its damage maths. Anything lighter it cuts short:
## a swing, a slash or an arc is dropped where it stands - what the blade had
## already hit stays hit - and a charge is dropped like letting go early.
##
## It plays silent: a `dodge` cue is still to be cut (tools/sfx/player.py),
## and a cue fired with no file behind it is what test_player_sfx.gd catches.
func _start_dodge(direction: Vector2) -> void:
	if _dodging() or _dodge_cooldown > 0.0 or _attack == "heavy" or _attack == "wildfire":
		return
	var way := direction.normalized() if direction != Vector2.ZERO else -_facing_vector()
	if _charging:
		_end_charge(false)
	if _attack != "":
		_attack = ""
		_buffered = ""
		_combo_grace = 0.0
	_face(way)
	_dodge_t = 0.0
	_dodge_dir = way
	_dodge_swing = false
	_dust_clock = 0.0
	velocity = Vector2.ZERO
	_apply_animation("dodge", true)
	_kick_dust(global_position, _dodge_dir)


## One frame of a roll: the next stretch of a straight line at a steady speed,
## a slow taking the same share of it that it takes of a walk. The velocity is
## the roll's own every frame rather than carried, so a desk that stops it
## stops it, and nothing it ran into is still pushing on the next frame.
func _roll(delta: float) -> void:
	var was := _dodge_t
	_dodge_t = minf(_dodge_t + delta, DODGE_SECONDS)
	var stretch := DODGE_DISTANCE * (_dodge_t - was) / DODGE_SECONDS * slow_factor
	velocity = _dodge_dir * (stretch / delta) if delta > 0.0 else Vector2.ZERO


## After a roll's frame has moved: the trail of dust it leaves, and its end.
func _rolled(delta: float) -> void:
	_dust_clock -= delta
	if _dust_clock <= 0.0:
		_dust_clock = DUST_EVERY
		RollDust.kick(self, global_position, Vector2(-_dodge_dir.x * 12.0, 0.0), DUST_TRAIL_LIFE)
	if _dodge_t < DODGE_SECONDS:
		return
	_dodge_t = -1.0
	_dodge_cooldown = DODGE_COOLDOWN
	velocity = input_source.move() * SPEED * slow_factor * DODGE_EXIT
	_stand_dust(global_position, _dodge_dir)
	if _dodge_swing:
		_dodge_swing = false
		_start_attack(_combo_next if _combo_grace > 0.0 else "attack")
	else:
		_apply_animation("idle")


## A roll dropped without finishing - the world taking the wheel, a death, a
## respawn - with no dust, no swing owed and nothing to cool down from.
func _drop_dodge() -> void:
	_dodge_t = -1.0
	_dodge_swing = false
	_dodge_cooldown = 0.0


func _dodging() -> bool:
	return _dodge_t >= 0.0


## Whether a blow would miss this body now. A remote body's is its owner's
## word, from its newest step.
func _untouchable() -> bool:
	if remote:
		return _net_untouchable
	return _dodge_t >= DODGE_SAFE_FROM and _dodge_t <= DODGE_SAFE_UNTIL


## The two puffs kicked up behind a roll as it starts.
func _kick_dust(at: Vector2, way: Vector2) -> void:
	RollDust.kick(self, at + Vector2(-way.x * 4.0, 0.0), Vector2(-way.x * 30.0, -way.y * 20.0))
	RollDust.kick(self, at + Vector2(-way.x * 2.0 + way.y * 3.0, 0.0),
		Vector2(-way.x * 20.0, -way.y * 14.0))


## The one thrown ahead of a roll as it stands up.
func _stand_dust(at: Vector2, way: Vector2) -> void:
	RollDust.kick(self, at + Vector2(way.x * 3.0, 0.0), Vector2(way.x * 16.0, 0.0))


## The way this body faces, as a direction: where a roll with the stick at rest
## goes AWAY from.
func _facing_vector() -> Vector2:
	match _facing:
		Facing.UP:
			return Vector2.UP
		Facing.SIDE:
			return Vector2.LEFT if _facing_left else Vector2.RIGHT
		_:
			return Vector2.DOWN


func _on_animation_finished() -> void:
	if _attack == "":
		return
	var finished := _attack
	# The heavy always erupts into its wildfire before anything else - the
	# ledger is NOT cleared, so the pair lands once per enemy between them.
	if finished == "heavy":
		_attack = "wildfire"
		_apply_animation("wildfire", true)
		_sfx("wildfire")
		return
	_attack = ""
	# Still holding when an attack ends (and nothing buffered) flows into the
	# charge stance; a tap has long since released by now.
	if _buffered == "" and finished != "wildfire" \
			and input_source.attack_held():
		_charging = true
		# NOT zero: the button has been down since before this attack started,
		# and that time is part of the charge. This one line is what stops the
		# heavy charging the player twice for the same swing.
		_charge = _hold
		_apply_animation("charge", true)
		_ring = ChargeRing.new()
		_ring.setup(_spark)
		add_child(_ring)
		# Still a loop rather than a one-shot. The stance now has an end, but
		# not a LENGTH: it runs for CHARGE_SECONDS minus however much of the
		# swing the player had already held through, which is different every
		# time, and an early release can cut it anywhere.
		_sfx_loop("charge")
		return
	if _buffered != "":
		_start_attack(_buffered)
		return
	# A late press can still chain off a swing or a rising slash; the arc ends
	# the chain, so the press after it is a fresh swing rather than a fourth
	# hit - 5 + 7 + 12 is the whole cycle, and it is exactly one guard.
	if finished == "attack" or finished == "attack2":
		_combo_grace = COMBO_GRACE_SECONDS
		_combo_next = LIGHT_NEXT[finished]
	_apply_animation("idle")


## Whether the world on THIS machine may hurt, heal, slow or shove anybody: the
## host's may, offline included (a host with no guests), and a guest's never.
## That one rule is the whole of what lets a guest run a room's effects for
## the look of them - a torch, a fire pillar, a boss's copy - without any of
## them landing twice: on a guest every one of the five ways the world reaches
## a player is a no-op, and what the host decided arrives by net_reached() and
## net_health() instead (DESIGN.md's Multiplayer, *Who decides what*).
func _world_reaches() -> bool:
	return (not is_inside_tree() or multiplayer.is_server()) and not away


## A blow: metered by the grace window, and it opens a fresh one. Online it is
## decided here, on the host, and the rest of the party hears of it (`reached`):
## the owner to blink and carry it, everybody else to see it land.
##
## A body in the untouchable stretch of a roll takes nothing and opens no window:
## the blow simply missed. A remote body's roll is its owner's word for it.
func take_damage(amount: int) -> void:
	if not _world_reaches() or _grace > 0.0 or health <= 0 or _untouchable():
		return
	_grace = _grace_window
	_lose_health(amount)
	reached.emit("struck", [amount, _grace_window])
	_struck(amount)


## A blow landing, shown: the number off the head and the grunt. Past the grace
## check on purpose: a blow the window swallowed cost nothing, and a number for
## it would say otherwise.
##
## The grunt is metered for free by the window, so a crowd cannot stack gasps.
## Only on a blow that was SURVIVED: `die` plays at zero, and a gasp laid over
## the death breath in one frame is one muddy sound rather than two clear ones.
func _struck(amount: int) -> void:
	_number(amount)
	if health > 0:
		_sfx("hurt")


## The number for a blow or a drain of `amount`, over the picture - which on a
## remote body is a beat behind where the body stands.
func _number(amount: int) -> Node2D:
	var number := DamageNumber.spawn(self, amount)
	number.global_position += _sprite.position
	return number


## Health lost to a continuous effect rather than a blow - an aura, a poison,
## anything that sets its own rate. Deliberately outside the grace window in
## both directions: it is not blocked by one and it does not open one.
##
## The grace window exists to stop discrete hits stacking every physics frame,
## which is the wrong meter for something that already knows how fast it should
## work. Routed through take_damage(), a drain would be swallowed for 0.8s
## every time an unrelated torch clipped the player, and would blink the sprite
## as though they were being struck once a second.
##
## It is still SHOWN: health that goes with no number on it reads as a bug.
## The ticks share one number while it is fresh rather than putting up one each,
## so a drain is a trickle of small totals and not a pile of "-1"s.
func drain(amount: int) -> void:
	if not _world_reaches() or health <= 0:
		return
	_lose_health(amount)
	reached.emit("drained", [amount])
	_show_drain(amount)


func _show_drain(amount: int) -> void:
	if is_instance_valid(_drain_number) and _drain_number.call("absorbs"):
		_drain_number.call("add", amount)
	else:
		_drain_number = _number(amount)


## A status the player CARRIES, which is a third thing again: take_damage() and
## drain() both land and are over in the same frame, while this has a duration
## of its own and expires on its own. Outside the grace window for the same
## reason drain() is - it is not a blow, so a torch clip must not swallow it.
##
## Overlapping slows do not compound into a standstill: the strongest in force
## wins and the timer refreshes. Two wardens keep you slow for longer, never
## make you slower.
func apply_slow(factor: float, seconds: float) -> void:
	if not _world_reaches() or health <= 0:
		return
	# Decided here and carried by the owner, who is the one moving the body.
	if remote:
		reached.emit("slowed", [factor, seconds])
		return
	_slow(factor, seconds)


func _slow(factor: float, seconds: float) -> void:
	if health <= 0:
		return
	var strength := clampf(factor, MIN_SLOW_FACTOR, 1.0)
	if slow_seconds <= 0.0 or strength < slow_factor:
		slow_factor = strength
	slow_seconds = maxf(slow_seconds, seconds)


## A FOURTH thing, and the first one that does not touch health at all: being
## moved. The hub's floor scrubbers are heavy machines that bump into people,
## and what a bump costs is not blood, it is your position.
##
## It is shaped like apply_slow() rather than like take_damage(), and the shape
## is the whole of what makes it safe to add. A shove is something the player
## CARRIES for a moment and which expires on its own, so it sits outside the
## grace window in both directions - it is not a blow, so a torch clip must not
## swallow it, and being pushed must not buy immunity from the guard winding up
## behind you. Where a scrubber also wants to hurt, it calls take_damage() too,
## and the two meter themselves independently, which is correct: the damage is
## a blow and the push is not.
##
## Like a slow, overlapping shoves REFRESH rather than compound - the strongest
## push wins and the clock resets. Two machines catching a player between them
## must not add up to a launch across the room, and, more to the point, must
## never be able to post somebody through a wall: the impulse is fed through
## `move_and_slide()` with everything else, so the room's own collision is what
## stops it, and a velocity big enough to tunnel a 16px wall in one frame is the
## one way that guarantee could be lost.
func shove(direction: Vector2, force: float) -> void:
	if not _world_reaches() or health <= 0 or direction == Vector2.ZERO:
		return
	if remote:
		reached.emit("shoved", [direction, force])
		return
	_push(direction, force)


func _push(direction: Vector2, force: float) -> void:
	if health <= 0 or direction == Vector2.ZERO:
		return
	var push := direction.normalized() * minf(force, MAX_SHOVE)
	if _shove_seconds <= 0.0 or push.length() > _shove.length():
		_shove = push
	_shove_seconds = SHOVE_SECONDS


func _lose_health(amount: int) -> void:
	health = maxi(health - amount, 0)
	health_changed.emit(health, MAX_HEALTH)
	if health == 0:
		# Here rather than in take_damage() so that a drain kills as audibly as
		# a blow does - `drain()` is otherwise deliberately silent, but a death
		# is not a drain tick, it is the end of the run.
		_sfx("die")
		died.emit()


## Returns false when nothing was healed, so a pickup can stay on the floor
## for a player who is already full.
##
## A guest's pickups heal nobody, on the rule in _world_reaches(): the host's
## copy of the heart is the one that is spent, and the health it gives comes
## back on net_health().
func heal(amount: int) -> bool:
	if not _world_reaches() or health >= MAX_HEALTH or health <= 0:
		return false
	health = mini(health + amount, MAX_HEALTH)
	health_changed.emit(health, MAX_HEALTH)
	return true


## The host's word on this body's health, on a guest - where nothing else ever
## changes it. Says so on `health_changed` like any other change, which is all
## the HUD listens to; what a death MEANS is decided on the host and arrives
## separately (game.gd), so reaching 0 here ends nothing by itself.
func net_health(value: int) -> void:
	if value == health:
		return
	var was := health
	health = clampi(value, 0, MAX_HEALTH)
	health_changed.emit(health, MAX_HEALTH)
	# The one sound a death makes, here where nothing else ever kills anybody -
	# `_lose_health` plays it on the host.
	if was > 0 and health == 0:
		_sfx("die")


## What the host's world did to this body, on the owner's machine - `reached`'s
## other end. A blow shows its number and blinks for the host's grace window,
## and a slow or a shove is carried here, where the body is moved.
func net_reached(what: String, args: Array) -> void:
	match what:
		"struck":
			if args.size() < 2:
				return
			_grace = float(args[1])
			_struck(int(args[0]))
		"drained":
			if not args.is_empty():
				_show_drain(int(args[0]))
		"slowed":
			if args.size() >= 2:
				_slow(float(args[0]), float(args[1]))
		"shoved":
			if args.size() >= 2:
				_push(args[0], float(args[1]))


## The same blow or drain on somebody else's body, on a machine that only draws
## it: the number and the grunt, and nothing to carry.
func net_seen(what: String, args: Array) -> void:
	if args.is_empty():
		return
	match what:
		"struck":
			_struck(int(args[0]))
		"drained":
			_show_drain(int(args[0]))


## Back to full, called by game.gd when it respawns the player after a death -
## and back into the fight, if a party death had taken them out of it.
func revive() -> void:
	health = MAX_HEALTH
	_grace = 0.0
	# Statuses die with the life that collected them: respawning into a room
	# still slowed by whatever killed you is a second punishment for one death.
	slow_factor = 1.0
	slow_seconds = 0.0
	_drop_hands()
	_sprite.visible = true
	_sprite.modulate = Color.WHITE
	_down = false
	remove_from_group(FALLEN_GROUP)
	_belong()
	health_changed.emit(health, MAX_HEALTH)


## Up where it lies, from a teammate's revive (game/revive.gd): `amount` health
## and `grace` seconds of the window, so the first blow in a crowd does not put
## it straight back down - turned to whoever got it up, and rooted for
## RISE_SECONDS while `rise` plays. The pool of lives never hears of it.
func get_up(amount: int, grace: float, toward: Vector2) -> void:
	health = clampi(amount, 1, MAX_HEALTH)
	slow_factor = 1.0
	slow_seconds = 0.0
	_drop_hands()
	_sprite.visible = true
	_sprite.modulate = Color.WHITE
	_down = false
	remove_from_group(FALLEN_GROUP)
	_belong()
	_grace = grace
	_facing = Facing.SIDE
	_facing_left = toward.x < global_position.x
	_sprite.flip_h = _facing_left
	_sprite.speed_scale = 1.0
	_sprite.play(&"rise_side")
	_rise = RISE_SECONDS
	health_changed.emit(health, MAX_HEALTH)


## DOWN: a death in a party. The body falls and lies where it fell (the `fall`
## rows, held on their last frame), darker, while it waits to get up - at the
## door with a life from the pool, or where it lies when a teammate revives it -
## and nothing in the world can see it, by way of the rule everything already
## keeps: the world reaches the player through the `player` group, so leaving
## the group is leaving the fight. Enemies stop picking it, hazards, drains and
## pickups stop touching it, a door stops waiting for it, and a head count stops
## counting it - none of them had to learn what "down" is. It joins the
## `fallen` group instead, which is how a teammate finds it to revive.
##
## The fall faces the way the picture did as it went down, so it is the same on
## the owner's machine and on everybody else's - which keep this machine's fall
## rather than drawing the owner's (net_draw).
##
## A SOLO death never comes here. With nobody else in the room the room fades
## over it and the body is put back at the door (game.gd), as it always was.
func knock_down() -> void:
	var facing_left := _sprite.flip_h
	_down = true
	_belong()
	add_to_group(FALLEN_GROUP)
	set_physics_process(false)
	velocity = Vector2.ZERO
	_shove_seconds = 0.0
	slow_factor = 1.0
	slow_seconds = 0.0
	_grace = 0.0
	_drop_hands()
	_sprite.visible = true
	_sprite.modulate = DOWN_TINT
	_sprite.flip_h = facing_left
	_sprite.speed_scale = 1.0
	_sprite.play(&"fall_side")


## Whether this body is down - see knock_down(). Not whether it is in the
## fight, which `away` decides too: that is the `player` group.
func is_down() -> bool:
	return _down


## Who this body is reviving now, or null: its own hands' answer on the machine
## that moves it, and its owner's word - a peer id - on every other. Only ever a
## body that is down.
func revive_target() -> Node2D:
	if not remote:
		return _reviving if is_instance_valid(_reviving) and _reviving.is_in_group(FALLEN_GROUP) else null
	if _net_reviving == 0:
		return null
	for node in get_tree().get_nodes_in_group(FALLEN_GROUP):
		if node != self and int(node.get("peer")) == _net_reviving:
			return node
	return null


## The teammate who is down nearest this body within REVIVE_RANGE, while the
## interact key is held and nothing else has the hands - or null.
func _fallen_in_reach() -> Node2D:
	if not input_source.interact_held() or _attack != "" or _charging or _dodging():
		return null
	var best: Node2D = null
	var reach := REVIVE_RANGE
	for node in get_tree().get_nodes_in_group(FALLEN_GROUP):
		var body := node as Node2D
		if body == null or body == self:
			continue
		var d := global_position.distance_to(body.global_position)
		if d <= reach:
			reach = d
			best = body
	return best


## Where this body is DRAWN: where it stands, plus however far its picture is
## from that - which only a remote body's ever is, gliding a beat behind its
## newest step (net_draw). What a camera following somebody else follows, so it
## glides with the picture rather than stepping with the wire.
func drawn_at() -> Vector2:
	return global_position + _sprite.position


## Online: the machine that moves this body has gone silent, or been heard
## again (game/sync/bodies.gd) - see `away`.
func set_away(on: bool) -> void:
	if on == away:
		return
	away = on
	_belong()


## In the fight - the `player` group, which is how the whole world finds a
## player - while neither down nor away, and out of it otherwise. The shape
## goes with it, because a body nobody can see must not still stand in a
## doorway; deferred, because a death lands inside somebody's physics step - a
## strike, an area, a drain - and a shape cannot change while queries are
## flushing.
func _belong() -> void:
	var standing := not _down and not away
	if standing == is_in_group("player"):
		return
	if standing:
		add_to_group("player")
	else:
		remove_from_group("player")
	$CollisionShape2D.set_deferred("disabled", not standing)


## Whatever the player was mid-way through with the attack button, dropped.
## Without it, a death during the charge stance respawns a player still rooted
## in it - or, released during the fade, popping a wildfire at the spawn - and
## a death mid-swing carries a live attack across the fade.
func _drop_hands() -> void:
	_drop_dodge()
	_attack = ""
	_buffered = ""
	_hold = 0.0
	_end_charge(false)
	_combo_grace = 0.0
	_swing_hits.clear()
	_reviving = null
	_rise = 0.0
	_sfx_stop("charge")
	_apply_animation("idle")


## One sound, if the scene gave this body an `Audio` child and that child has
## one by that name. Every miss is legal and silent by design, which is what
## lets a cue be wired here before its WAV exists - and what makes a fresh
## checkout playable before an --import pass has ever been run.
##
## Deliberately the same four names `enemy_base` uses. They are not the same
## code (see player_audio.gd for why the player's node is not the enemies'),
## but somebody reading both should not have to learn two vocabularies for one
## idea. An empty id is a no-op, so ATTACK_SOUNDS can miss without a branch.
func _sfx(id: String) -> void:
	if _audio != null and id != "":
		_audio.play(id)


## The same deal for a sound that keeps going - the charge stance - and for the
## two ways of taking one back down. Faded where stopping is part of the move,
## cut where the move itself was cancelled.
func _sfx_loop(id: String) -> void:
	if _audio != null:
		_audio.loop(id)


func _sfx_fade(id: String, seconds: float) -> void:
	if _audio != null:
		_audio.fade_out(id, seconds)


func _sfx_stop(id: String) -> void:
	if _audio != null:
		_audio.stop(id)
