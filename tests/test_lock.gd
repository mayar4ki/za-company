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
			_check("lamps: and says so - green, no padlock (%s)" % [_look(_exit())],
				_shows_open(_exit()))
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
			# The same door, sealed again by the bodies placed in it.
			_check("lamps: red, with the padlock shut on the door (%s)" % [_look(_exit())],
				_shows_sealed(_exit()))
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
			_check("lamps: both doors red and padlocked (%s / %s)"
				% [_look(_exit()), _look(back)],
				_shows_sealed(_exit()) and _shows_sealed(back))
			# The way back down is the north door turned half a turn; its
			# padlock is mirrored inside its box so the turn brings it upright.
			_check("lamps: the padlock on the way back down is turned upright",
				_look(back)[5] == true and _look(_exit())[5] == false)
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
			# Nothing was won in a room that was open on arrival, so nothing
			# is played: green from the first frame.
			_check("lamps: a room open on arrival plays no unlock (%s)" % [_look(_exit())],
				_shows_open(_exit()))
			# The unlock, watched rather than walked through: one body, and
			# the player off in the room rather than in a doorway, where the
			# party would go on the frame it died and take the door with it.
			_placed = [_place(Vector2(104, 60))]
			_player().global_position = Vector2(272, 150)
		283:
			_check("lamps: one body placed seals it again (%s)" % [_look(_exit())],
				_shows_sealed(_exit()))
			_placed[0].call("take_damage", 999)
		286:
			# The first BLINK_FOR of the unlock: the lamps blink white, and the
			# padlock holds shut through it.
			var look := _look(_exit())
			_check("lamps: the room beaten, the lamps blink white (%s)" % [look],
				look[0] == _lock_const(_exit(), "BLINK") and look[2] and not look[3])
		300:
			var look := _look(_exit())
			_check("lamps: then green, and the padlock springs open green (%s)" % [look],
				look[0] == _lock_const(_exit(), "GREEN") and look[2] and look[3]
					and look[4] == 1.0)
		330:
			var look := _look(_exit())
			_check("lamps: past halfway the open padlock fades (%s)" % [look],
				look[2] and look[3] and look[4] > 0.0 and look[4] < 1.0)
		360:
			_check("lamps: and is gone, leaving the lamps green (%s)" % [_look(_exit())],
				_shows_open(_exit()) and _exit().call("can_travel"))
			_finish()


func _exit() -> Node:
	return _level().get_node("Props/Exit")


## What a door's lamps and padlock show now - door_lock.gd's own `_look()`:
## [lamp core, lamp glow, padlock drawn, padlock open, its alpha, turned].
func _look(door: Node) -> Array:
	return door.get_node("Lock").call("_look")


func _lock_const(door: Node, name: String) -> Variant:
	return (door.get_node("Lock").get_script() as Script).get_script_constant_map()[name]


## Red - lit or dim, it pulses - with the padlock drawn and shut.
func _shows_sealed(door: Node) -> bool:
	var look := _look(door)
	return look[0] in [_lock_const(door, "RED"), _lock_const(door, "RED_DIM")] \
		and look[2] and not look[3]


## Green, and no padlock.
func _shows_open(door: Node) -> bool:
	var look := _look(door)
	return look[0] == _lock_const(door, "GREEN") and not look[2]


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
