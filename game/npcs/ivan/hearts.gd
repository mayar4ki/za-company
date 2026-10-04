extends RefCounted
## The throw. Ivan does not hand you a heart, he lobs it - one short arc per
## heart, fanned out in front of him, landing live.
##
## Its own file rather than twenty lines inside ivan.gd for the reason a boss's
## effects are their own files: this is the only part of him that is ANIMATION,
## and animation is the thing that gets retimed. Nothing here knows why he is
## throwing or how many - ivan.gd counts the heads, this puts that many hearts
## on the floor.
##
## ## Why the fan points at the player rather than around him
##
## He arrives at an authored spot, which on most floors is a safe corner - and
## the safe corners are the ones nothing else wanted, so there is furniture
## either side. A heart fanned all the way round him would land in the scenery
## on half of them. Aiming the whole fan at the person he is throwing to points
## it at open floor by construction, because that is where the player is
## standing.

const SCENE := preload("res://game/heart.tscn")

## Peak of the arc in world pixels, and the only number here that is about the
## picture: high enough to read as a lob over a 14px body, low enough that a
## heart does not leave the top of a 360px screen.
const LIFT := 14.0
## Seconds in the air, and seconds between one heart leaving and the next.
## Staggered so a party's four hearts read as four throws rather than as one
## shower - and so two of them never land on the same pixel.
const FLIGHT := 0.45
const STAGGER := 0.14

## How far in front of him they land, and how wide the fan opens per heart. The
## reach is a little under his own talk radius (30), so a heart lands where
## somebody standing in front of him can step onto it without walking away
## first.
const REACH := 26.0
const SPREAD := 0.42

## Where a heart leaves his hands. An NPC is drawn at double height with the
## sprite offset 24px up, so this is roughly his chest and not his feet.
const FROM_CHEST := Vector2(0, -22)


## Throws `count` hearts from `npc` toward `toward`, into whatever `npc` is
## parented to - which is the level's Y-sorted Props branch, the same place the
## room's own furniture lives. A heart outside it draws through the scenery.
static func throw(npc: Node2D, count: int, toward: Vector2) -> void:
	var parent := npc.get_parent()
	if parent == null or count <= 0:
		return
	var aim := toward - npc.global_position
	var direction := aim.normalized() if aim != Vector2.ZERO else Vector2.DOWN
	var start := npc.global_position + FROM_CHEST

	for i in count:
		var heart := SCENE.instantiate() as Area2D
		heart.name = "IvansHeart%d" % (i + 1)
		parent.add_child(heart)
		heart.global_position = start
		# Off for the length of the flight: a heart is a thing you walk onto,
		# and one that can be collected mid-air is collected out of his hands
		# on the frame he throws it.
		heart.monitoring = false

		var turn := (float(i) - float(count - 1) / 2.0) * SPREAD
		var land := npc.global_position + direction.rotated(turn) * REACH
		var flight := npc.create_tween()
		flight.tween_interval(float(i) * STAGGER)
		# Rounded on the way: everything else in this game draws on whole
		# pixels, and a heart sliding between two of them shimmers.
		flight.tween_method(
			func(k: float) -> void:
				if is_instance_valid(heart):
					heart.global_position = (start.lerp(land, k)
						+ Vector2(0, -LIFT * sin(k * PI))).round(),
			0.0, 1.0, FLIGHT)
		flight.tween_callback(
			func() -> void:
				if is_instance_valid(heart):
					heart.monitoring = true)
