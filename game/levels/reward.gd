extends Node2D
## A cleared room's reward: when the last body in the room goes down, it leaves
## one heart per head on the floor where it fell.
##
## A floor asks for it with `"reward": true` in its biome, and build_levels.gd
## answers with this node. It is the plain version of what Ivan does on the
## floors he walks: nobody arrives, nothing is said, the hearts are just there.
##
## ## Where the last body fell, and why that is the spot
##
## A room can finish anywhere - on the S, in any of three halls that cannot see
## each other - so an authored spot is a spot the player may never walk back
## to. The last kill is the one place that is certain to be on screen, next to
## whoever made it, the moment the room is over.
##
## ## "Over" is relief.gd's cue, word for word
##
## A conceded boss is not standing; a room is clear on its first frame too, so
## nothing drops until there has been a fight; and quiet between a floor's
## beats is not clear, so the sibling `Reinforcements` is asked whether it is
## spent. Why each of those is there is relief.gd's header - this is the same
## three guards answering the same question.
##
## ## One heart per head, once
##
## The count is game/heads.gd, the number a beat's `per_head` and Ivan's gift
## both read: four players sharing one heart is the same unfairness as one
## player facing four times the bodies. It drops once per visit, and "once"
## resets with the room, which is re-instantiated on every entry.
##
## Online it is the host's, like every beat: the hearts it makes reach a guest's
## room on the next snapshot (game/sync/world.gd), made from their scene, and a
## pair dropped on a guest would be gone there by the same one.

const Heads := preload("res://game/heads.gd")
const HEART := preload("res://game/heart.tscn")

## How far from the spot each heart lies when there is more than one, in world
## pixels. Under the heart's own 6 px pickup radius plus a body's, so a party's
## hearts are one step onto rather than a walk round - and small enough that a
## body which fell against a wall does not put a heart through it.
const SCATTER := 7.0

## Latched the first frame the room has somebody standing in it.
var _fought := false
## Where somebody was still standing on the last frame anybody was: the spot,
## once nobody is.
var _last := Vector2.ZERO


func _process(_delta: float) -> void:
	if not multiplayer.is_server():
		return
	var standing := _standing()
	if standing != null:
		_fought = true
		_last = standing.global_position
		return
	if not _fought or not _beats_spent():
		return
	_drop(Heads.count(get_tree()))
	set_process(false)


## Anybody in the room who is still a threat, or null. A conceded boss is not
## one - relief.gd's `_hostiles()`, asked for a body rather than a count.
func _standing() -> Node2D:
	for node in get_tree().get_nodes_in_group("enemies"):
		if node.get("has_conceded") == true or node.is_queued_for_deletion():
			continue
		return node as Node2D
	return null


## Whether this floor's second beat is done with. Asked of the sibling rather
## than known, and a floor without one has nothing to wait for.
func _beats_spent() -> bool:
	var beats := get_parent().get_node_or_null("Reinforcements")
	if beats == null or not beats.has_method("spent"):
		return true
	return bool(beats.call("spent"))


## Lays `count` hearts round where the last body fell, into the level's Y-sorted
## Props branch, where a heart is drawn in front of or behind the furniture.
func _drop(count: int) -> void:
	var props := get_parent().get_node_or_null("Props")
	if props == null:
		return
	for i in count:
		var heart := HEART.instantiate() as Node2D
		# Named so a guest's copy is made at the same path, and so a test can
		# tell these from a room's own heart.
		heart.name = "RewardHeart%d" % (i + 1)
		var spot := _last
		if count > 1:
			spot += Vector2.RIGHT.rotated(TAU * float(i) / float(count)) * SCATTER
		props.add_child(heart)
		# Whole pixels, like everything else this game draws.
		heart.global_position = spot.round()
