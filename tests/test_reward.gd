extends "res://tests/helpers.gd"
## Reward test: a cleared room's hearts. That nothing drops in a room that was
## never fought, nor while somebody is still standing, nor between a floor's
## beats; that the room clearing drops one heart per head where the last body
## fell, live, and that walking onto one heals; and that it drops once.
##
## Boots into the empty lobby and builds the reward by hand, the way
## test_ivan.gd builds its beat and for the same reason: what is under test is
## reward.gd's cue and its drop, not which floor carries one. The floor that
## does is checked off disk at the end, in `_baked()`.
##
## The first room is cleared by killing a real office boy, because that is the
## road a player takes. The second uses a stand-in in the `enemies` group and a
## stand-in second beat, because what it asks - two heads, and a beat not yet
## spent - is about the count and the wait, and a real body walking about for
## twenty frames would make the spot depend on where it wandered.

const REWARD := preload("res://game/levels/reward.gd")
const OFFICE_BOY := "res://game/enemies/office_boy/office_boy.tscn"

var _reward: Node2D
var _boy: Node2D
## Where the last body stood as it went down, and so where the hearts belong.
var _spot := Vector2.ZERO
var _heart: Area2D
var _health_before := 0
var _stand_in: Node2D
var _beats: Node


func _tick(frame: int) -> void:
	match frame:
		2:
			(current_scene.get_node("%PlayButton") as Button).pressed.emit()
		17:
			(current_scene.get_node("%Roster/reem") as Button).pressed.emit()
		32:
			_check("reward: the lobby starts empty, so the reward is ours (%d)"
				% get_nodes_in_group("enemies").size(),
				get_nodes_in_group("enemies").is_empty())
			# Out of the doorway and well away from where the boy will fall: a
			# heart dropped under the player's feet is collected on the frame it
			# lands, which is the right game and the wrong test.
			_player().global_position = Vector2(272, 120)
			_reward = Node2D.new()
			_reward.name = "Reward"
			_reward.set_script(REWARD)
			_level().add_child(_reward)
		44:
			# A room is clear on its first frame too, and hearts lying in a room
			# nobody has fought in are a pickup, not a reward.
			_check("reward: an empty room is not a won one - nothing drops",
				_dropped().is_empty())
			_boy = (load(OFFICE_BOY) as PackedScene).instantiate() as Node2D
			_level().get_node("Props").add_child(_boy)
			_boy.global_position = Vector2(120, 248)
			_boy.set("sight_radius", 0.0)
		52:
			_check("reward: and nothing while somebody is still standing",
				_dropped().is_empty())
			_spot = _boy.global_position
			_boy.call("take_damage", 999)
		58:
			var dropped := _dropped()
			_check("reward: the room clears - one head, one heart (%d)" % dropped.size(),
				dropped.size() == 1)
			if not dropped.is_empty():
				_heart = dropped[0]
				_check("reward: where the last body fell (%.1f px off)"
					% _heart.global_position.distance_to(_spot),
					_heart.global_position.distance_to(_spot) < 3.0)
				_check("reward: and live", _heart.monitoring)
			# Hurt on purpose: a heart only heals into a bar with room in it.
			_player().call("take_damage", 40)
		62:
			_health_before = int(_player().get("health"))
			_check("reward: the player has something to heal (%d of 100)"
				% _health_before, _health_before < 100)
			if _heart != null:
				_player().global_position = _heart.global_position
		72:
			_check("reward: walking onto it heals (%d -> %d)"
				% [_health_before, int(_player().get("health"))],
				int(_player().get("health")) > _health_before)
			_check("reward: and it is gone once taken",
				_heart == null or not is_instance_valid(_heart))
			_player().global_position = Vector2(272, 120)
			# ---- Once -------------------------------------------------------
			# A second fight in the same visit is not a second reward: the
			# room was cleared once, and a room that pays out per lull is a
			# room that can be farmed.
			_stand_in = _standing_at(Vector2(200, 260))
		76:
			_stand_in.queue_free()
		84:
			_check("reward: it drops once, however often the room goes quiet (%d)"
				% _dropped().size(), _dropped().is_empty())
			# ---- Two heads, and the beat it waits for -----------------------
			_reward.queue_free()
			var second := Node2D.new()
			second.name = "SecondPlayer"
			second.add_to_group("player")
			_level().add_child(second)
			second.global_position = Vector2(80, 80)
			_reward = Node2D.new()
			_reward.name = "Reward2"
			_reward.set_script(REWARD)
			_level().add_child(_reward)
			# A second beat still to come. Quiet between a floor's beats is not
			# clear, and the reward asks its sibling exactly as Ivan does.
			_beats = Node.new()
			_beats.name = "Reinforcements"
			_beats.set_script(_script("extends Node\nvar done := false\n"
				+ "func spent() -> bool:\n\treturn done\n"))
			_level().add_child(_beats)
			_stand_in = _standing_at(Vector2(200, 260))
		90:
			_spot = _stand_in.global_position
			_stand_in.queue_free()
		98:
			_check("reward: and nothing while a beat is still to come (%d)"
				% _dropped().size(), _dropped().is_empty())
			_beats.set("done", true)
		104:
			var dropped := _dropped()
			_check("reward: two heads, two hearts (%d)" % dropped.size(),
				dropped.size() == 2)
			var live := dropped.filter(func(h: Area2D) -> bool: return h.monitoring)
			_check("reward: both of them live (%d)" % live.size(), live.size() == 2)
			var near := dropped.filter(func(h: Area2D) -> bool:
				return h.global_position.distance_to(_spot) <= REWARD.SCATTER + 1.0)
			_check("reward: both round where it fell (%d of %d)"
				% [near.size(), dropped.size()], near.size() == dropped.size())
			if dropped.size() == 2:
				_check("reward: and not on top of each other",
					dropped[0].global_position != dropped[1].global_position)
			_baked()
			_finish()


## The floor that carries it, read back off disk. Everything above builds its
## own, so without this the biome entry could be gone and every check would
## still pass - the hole test_ivan.gd's `_baked()` closes for his floors.
func _baked() -> void:
	var lab := (load("res://game/levels/innovation_lab/innovation_lab.tscn")
		as PackedScene).instantiate()
	var node := lab.get_node_or_null("Reward")
	_check("reward: the innovation lab carries one",
		node != null and node.get_script() == REWARD)
	lab.free()
	# And the lobby does not: no fight, nothing to be after - the same pair of
	# truths test_ivan.gd keeps for Ivan.
	var lobby := (load("res://game/levels/lobby/lobby.tscn")
		as PackedScene).instantiate()
	_check("reward: the lobby has none - nothing to be after",
		lobby.get_node_or_null("Reward") == null)
	lobby.free()


## Somebody standing in the room as far as the reward can tell: a body in the
## `enemies` group with nothing else to it. Everything else in the game that
## walks that group asks `has_method` first, so a bare node is invisible to it.
func _standing_at(at: Vector2) -> Node2D:
	var body := Node2D.new()
	body.name = "StandIn"
	body.add_to_group("enemies")
	_level().add_child(body)
	body.global_position = at
	return body


func _script(source: String) -> GDScript:
	var script := GDScript.new()
	script.source_code = source
	script.reload()
	return script


## Every heart a reward dropped, told from a room's own by the name it gives them.
func _dropped() -> Array:
	var found: Array = []
	for node in _level().get_node("Props").get_children():
		if node.name.begins_with("RewardHeart") and is_instance_valid(node) \
				and not node.is_queued_for_deletion():
			found.append(node)
	return found
