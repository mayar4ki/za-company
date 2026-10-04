extends "res://game/enemies/enemy_base.gd"
## The brute archetype - the fourth, and the first one that is not the size of
## the cast. It walks slowly, plants itself, winds up for the better part of a
## second and slams the floor: everyone still inside the ring takes a real blow
## AND is thrown out of it.
##
## **The other three take your health, your time and your speed; this takes your
## POSITION.** That is the whole reason it exists. A bigger guard would be the
## first archetype again with a larger number on it, and the bestiary is built
## so a room is made by mixing kinds of threat rather than by adding more of
## one.
##
## ## Why there is so little here
##
## Almost none of this is new machinery, and that is the point the warden
## already made: a charge and a swing were the same shape, and so is a slam.
## Wind up, land it if it completes, recover, interruptible early and committed
## late. So the cycle is the base's, untouched, and what this file adds is only
## what a slam does differently from a sword:
##
## - the blow lands on a RING rather than in front (which is not even an
##   override - the base already strikes everything in the Touch area, so this
##   is a Touch shape tuned wide, exactly the trick the wraith's aura and the
##   warden's field are);
## - it shoves;
## - the floor draws the reach, because no animation on a body can.
##
## Three things it deliberately does NOT override, each of which was considered:
##
## - `_windup_needs_contact()` stays false. A slam lands on air. Stepping out of
##   the ring during the wind-up is the counterplay and it has to cost nothing
##   but timing - the warden returns true because a slow has to HOLD you, which
##   is the opposite bargain.
## - `_windup_tint()` stays the base's amber. The warden overrides it because
##   violet says "this is not a hit"; this IS a hit, so the default is already
##   telling the truth.
## - `_windup_state()` stays `attack`. The warden must not mime a strike because
##   it never lands one. This one does.
##
## ## The push is capped by the player, not by this file
##
## `shove()` clamps to the player's own `MAX_SHOVE`, so asking for more than 70
## buys nothing - the hub's scrubbers already ask for exactly that. What is
## different here is the company the push keeps: a scrubber is 6 damage and all
## push, a brute is a full blow and the same push. The scrubber moves you
## instead of hurting you; this hurts you AND moves you, which is why its ring
## is warm where the scrubber's scanner is cold.
##
## The push is also why the shove is never added to `velocity`: the player
## carries it, it decays on its own and it refreshes rather than stacking, so
## two brutes landing together move you no further than one. That is the
## player's rule and this file only has to not fight it.

## How hard the slam throws. At the player's `MAX_SHOVE` ceiling on purpose:
## being moved is half of what this attack IS, so it asks for all of it and
## lets the player decide what that means.
@export var shove_force := 70.0

@onready var _ring: Node2D = $SlamRing


func _ready() -> void:
	super()
	# The ring never carries the radius itself. Copying in the Touch shape's own
	# circle means the drawing IS the area - retune the shape and the ring moves
	# with it, and it can never be caught claiming a reach the brute does not
	# have. (_touch_area is only live once the base's _ready has run.)
	var shape := _touch_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape != null and shape.shape is CircleShape2D:
		_ring.radius = (shape.shape as CircleShape2D).radius
		_ring.position = shape.position


func _physics_process(delta: float) -> void:
	super(delta)
	# Read once, after the base has settled the phase for the frame. 0 outside
	# the wind-up, so being staggered, landing the blow and losing the player
	# all clear the ring without any of them being handled here.
	var progress := _windup_progress()
	_ring.set_progress(progress, progress >= commit_fraction)


## The blow, on everyone the base found standing in the ring. Damage first and
## the push second, in that order for a reason worth keeping: `take_damage()`
## opens the grace window, and a player killed by this should die where they
## were hit rather than be thrown by a corpse's worth of momentum.
func _touch_strike(player: Node2D) -> void:
	# A slam the roll made miss throws nobody either: the push is half of this
	# blow, not a second thing that happened to land on the same frame.
	if _untouchable(player):
		return
	if player.has_method("take_damage"):
		player.call("take_damage", contact_damage)
	if player.has_method("shove"):
		# Out of the ring, along the line from his feet - so a player standing
		# where the drawing said not to is moved to where it said was safe.
		player.call("shove", player.global_position - global_position, shove_force)


func _strike() -> void:
	super()
	# The floor says what just happened, whether or not anybody was standing on
	# it. Unlike the base's `hit` sound - which fires only on a blow that landed
	# - the slam is a thing that visibly happened to the ROOM, and a flourish
	# that appeared only when it connected would teach the player that a slam
	# they dodged was never thrown.
	_ring.land()
