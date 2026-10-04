extends "res://tests/helpers.gd"
## Lock test: a room is sealed until it is beaten. Both of its doors, the way up
## and the way back down, while anybody hostile is standing in it or a beat is
## still to come (game/levels/room_clear.gd) - and then open, on the frame the
## room is won, for a party that is already standing in the doorway.
##
## Fought for real, which is the half test_chain.gd cannot do: the walk beats
## every room the short way (helpers.gd's `_clear_room`) so it can get on to
## the next one, and only checks each door's answer either side of that. Here
## the bodies are killed with blows and the beat is let fire, because the frame
## a last kill CUES a beat is the frame the door could get wrong: nobody is
## standing, and the beat it owes has not set off yet.
##
## Boots into the empty lobby and builds the fight by hand there, like
## test_reinforcements.gd: what is under test is the door's question, not any
## floor's dressing. The placed boys have their sight zeroed and are killed
## long before the room alert could walk them to the doorway. Then up to the
## content studio by that door, for a room with a way back down to be shut.

const REINFORCEMENTS := preload("res://game/levels/reinforcements.gd")
const OFFICE_BOY := "res://game/enemies/office_boy/office_boy.tscn"
const STUDIO := "res://game/levels/content_studio/content_studio.tscn"

var _placed: Array[Node2D] = []


func _tick(frame: int) -> void:
	match frame:
		2:
			(current_scene.get_node("%PlayButton") as Button).pressed.emit()
		17:
			(current_scene.get_node("%Roster/reem") as Button).pressed.emit()
		32:
			_check("lock: the lobby has nobody in it to beat, so its door is open",
				get_nodes_in_group("enemies").is_empty() and _exit().call("can_travel"))
			for at in [Vector2(104, 60), Vector2(436, 64)]:
				_placed.append(_place(at))
			# The beat the second kill cues, through the far door from the one
			# the player waits in - so nothing holds it, and it is the CUE that
			# is under test rather than the doorway hold.
			var beats := Node2D.new()
			beats.name = "Reinforcements"
			beats.set_script(REINFORCEMENTS)
			beats.set("waves", [{"after_kills": 2, "from": "start",
				"enemies": ["office_boy"]}])
			_level().add_child(beats)
			# Into the doorway, where the whole party now is: solo, one player
			# is all of it, so the only thing between them and the next floor is
			# the room.
			_player().global_position = Vector2(272, 24)
		60:
			_check("lock: two standing, and the party in the doorway goes nowhere",
				not _exit().call("can_travel") and _still_in("Lobby"))
		62:
			_placed[0].call("take_damage", 999)
		70:
			_check("lock: one of two down is not beaten",
				not _exit().call("can_travel") and _still_in("Lobby"))
		72:
			# The last placed body, and the kill that cues the beat. For the
			# frame it dies the room has nobody standing in it and the arrival
			# it owes is not through the door yet - quiet, and not beaten.
			# Asked on the same frame as the blow, because in play a blow lands
			# in the physics step and the door asks in that step too, before
			# the beat has had a frame to count the body: the body is queued to
			# free and still in the group, and has to be dead to both of them.
			_placed[1].call("take_damage", 999)
			_check("lock: on the very frame of the kill that cues a beat, still shut",
				not _exit().call("can_travel"))
		73:
			_check("lock: and the frame after it, with the beat on its way",
				not _exit().call("can_travel") and _still_in("Lobby"))
		90:
			_check("lock: the beat walked in, and the door waits for it (%d)"
				% _arrivals().size(),
				_arrivals().size() == 1 and _still_in("Lobby"))
		92:
			for body in _arrivals():
				body.call("take_damage", 999)
		94:
			# Never stepped off: a door asks every frame somebody is in it, so
			# the party standing there goes the moment the room is won.
			_check("lock: the last of them down, and the waiting party goes",
				current_scene.call("is_travelling") == true)
		170:
			_check("lock: up into the content studio (got %s)"
				% ("<none>" if _level() == null else _level().name),
				_level() != null and _level().scene_file_path == STUDIO)
			var back := _level().get_node("Props/Return") as Node2D
			_check("lock: its cast is standing, and both ways out are shut",
				not get_nodes_in_group("enemies").is_empty()
					and not _exit().call("can_travel")
					and not back.call("can_travel"))
			# Into the way back down: a door turned half a turn, so its
			# threshold is the same 16 px in front of it, pointing north.
			_player().global_position = back.to_global(Vector2(0, 16))
		200:
			_check("lock: the way back down is shut too",
				_still_in("ContentStudio"))
		202:
			# A beat cued past the room's whole population - bad data, and the
			# kind that has to cost a beat that never comes rather than a run
			# that cannot go on. With nobody left standing nothing more can
			# die, so the count it waits for is never coming either.
			_level().get_node("Reinforcements").set("waves",
				[{"after_kills": 99, "from": "returned", "enemies": ["office_boy"]}])
			for body in get_nodes_in_group("enemies"):
				body.queue_free()
		206:
			_check("lock: a beat that can never come does not hold the room",
				current_scene.call("is_travelling") == true)
		280:
			_check("lock: and the way back down took the party down (got %s)"
				% ("<none>" if _level() == null else _level().name),
				_level() != null and _level().name == "Lobby")
			_finish()


func _exit() -> Node:
	return _level().get_node("Props/Exit")


## On `room` and not on the way out of it.
func _still_in(room: String) -> bool:
	return _level() != null and _level().name == room \
		and current_scene.call("is_travelling") == false


func _place(at: Vector2) -> Node2D:
	var enemy := (load(OFFICE_BOY) as PackedScene).instantiate() as Node2D
	_level().get_node("Props").add_child(enemy)
	enemy.global_position = at
	enemy.set("sight_radius", 0.0)
	return enemy


## Everything the beat has sent in, told from the placed two by the name the
## spawner gives them.
func _arrivals() -> Array:
	return get_nodes_in_group("enemies").filter(func(e: Node) -> bool:
		return e.name.begins_with("Reinforcement") and not e.is_queued_for_deletion())
