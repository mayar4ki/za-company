extends RefCounted
## Whether a room is BEATEN: nobody hostile still standing in it, and nothing
## more on its way in.
##
## One definition, because three things wait on it and would drift the day
## there were three: every door (door_base.gd's `can_travel()` - a room is
## sealed until it is beaten), the friendly arrivals (relief.gd - Ivan and
## Dominique walk in once it is), and a cleared room's hearts (reward.gd). A
## door that opened a frame before Ivan set off, or a heart that dropped while
## the doors were still shut, would be the room saying two things about itself.
##
## ## Standing
##
## The `enemies` group, less anybody on their way out of it. A conceded boss
## takes himself out of the group (boss_base.gd's `_concede`) and is skipped
## here as well, so being beaten never depends on which of the two a boss does
## first. A body killed this frame is queued to free and still in the group
## until the frame ends, and as far as the room is concerned it is already
## gone - reinforcements.gd counts its dead on the same terms, so the frame a
## last kill lands is never a frame the room looks beaten to one and owes a
## beat to the other.
##
## ## Nothing more coming
##
## Asked of the level's `Reinforcements` node (`spent()`), because a floor is
## quiet between the last kill of its opening arrangement and the group that
## kill cues, and quiet is not beaten. A floor with no beat has no node to ask.
##
## Static and handed what it needs, for game/heads.gd's reason: the callers are
## a door, an arrival and a drop, and none of them is the right owner for an
## instance.


## The first body in the room that is still a threat, or null.
static func standing(tree: SceneTree) -> Node2D:
	for node in tree.get_nodes_in_group("enemies"):
		if node.get("has_conceded") == true or node.is_queued_for_deletion():
			continue
		return node as Node2D
	return null


## Whether every beat `level` has is done with. A level with none - or no level
## to ask - has nothing to wait for.
static func beats_spent(level: Node) -> bool:
	var beats: Node = null if level == null else level.get_node_or_null("Reinforcements")
	if beats == null or not beats.has_method("spent"):
		return true
	return bool(beats.call("spent"))


## Both at once: nobody standing, and nobody coming.
static func beaten(tree: SceneTree, level: Node) -> bool:
	return standing(tree) == null and beats_spent(level)
