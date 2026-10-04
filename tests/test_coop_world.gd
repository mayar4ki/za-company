extends "res://tests/coop.gd"
## Two machines in one run (DESIGN.md's Multiplayer, M3) - the ENEMIES: the
## host runs the room, and the guest draws it from one snapshot twenty times a
## second (game/sync/world.gd). The harness is tests/coop.gd.
##
## On hellfire, which has all three of the smaller archetypes in one corner of
## it, and starts there - so the guest, which always loads the lobby, is also
## the check that a guest welcomed to another floor goes there:
##
## - **The same room**: every body the host has, the guest has, where the host
##   has it, and a body the host moves moves there too.
## - **A telegraph is the host's and is drawn everywhere**: a warden winding up
##   on the guest fills its field on the guest's screen, and the slow it lands
##   is carried by the guest's own body.
## - **A blow both ways**: the guest's swing hurts the host's guard, and the
##   guard's blow hurts the guest.
## - **What exists is the snapshot**: a body the host kills is gone on the
##   guest, a reinforcement the host lets in appears there - made from the
##   scene its entry carries - and goes when it dies.
## - **A door is the host's word**: the guest's doors show the host's room
##   sealed while anybody stands in it, and start their unlock when it is
##   beaten - a guest's own room could not tell, its beats never run.
##
## Every body but the one a step is about stands still (speed 0 on the HOST,
## where speed means anything), so a crowd never decides a check.

const HELLFIRE := "res://game/levels/hellfire/hellfire.tscn"
const WARDEN := "Props/Enemy3"
const GUARD := "Props/Enemy1"
const LONER := "Props/Enemy10"


func _init() -> void:
	port = 47951
	start_level = HELLFIRE


func _plan() -> Array[Callable]:
	return [_together, _still_room, _same_room, _moved, _warden_winds,
		_warden_lands, _face_guard, _guard_strikes, _guest_swings, _guard_dies,
		_reinforcement, _reinforcement_dies, _doors_sealed, _doors_open]


func _room_node(path: String) -> Node:
	var level := _level()
	return level.get_node_or_null(NodePath(path)) if level != null else null


## Every synced thing in the host's room, the same shape the probe answers.
func _host_enemies() -> Dictionary:
	var out := {}
	var level := _level()
	for node in get_nodes_in_group(&"synced"):
		if level.is_ancestor_of(node) and not node.is_queued_for_deletion():
			out[String(level.get_path_to(node))] = [(node as Node2D).global_position,
				node.get("health")]
	return out


func _still_room() -> void:
	for node in get_nodes_in_group("enemies"):
		node.set("speed", 0.0)
	_check("host: on hellfire, and every enemy stood still",
		_level() != null and _level().scene_file_path == HELLFIRE)


func _same_room() -> void:
	_expect("room: the guest has every body the host has, where the host has it",
		"enemies", [], func(theirs: Dictionary) -> bool:
			var ours := _host_enemies()
			if ours.size() < 10 or theirs.keys().size() != ours.keys().size():
				return false
			for path in ours:
				if not theirs.has(path) \
						or (theirs[path][0] as Vector2).distance_to(ours[path][0]) > 3.0:
					return false
			return true)


func _moved() -> void:
	var loner := _room_node(LONER) as Node2D
	_mark = loner.global_position + Vector2(40, 0)
	loner.global_position = _mark
	_expect("room: a body the host moves, moves on the guest", "get", [LONER,
		["global_position"]], func(a) -> bool:
			return a is Array and (a[0] as Vector2).distance_to(_mark) < 3.0)


## The guest stood in the warden's area: it winds up on the host, which is
## the only place it decides anything, and its field fills on the guest's
## screen from the phase the host sent.
func _warden_winds() -> void:
	(_room_node(WARDEN) as Node2D).set("speed", 35.0)
	_tell("teleport", [Vector2(72, 430)])
	_deadline = 600
	_expect("warden: winding up on the host, its field fills on the guest", "get",
		[WARDEN + "/ChargeRing", ["progress"]], func(a) -> bool:
			return a is Array and float(a[0]) > 0.3)


func _warden_lands() -> void:
	_deadline = 600
	_expect("warden: and the slow it lands is carried by the guest's own body",
		"body", [_guest_id], func(a: Array) -> bool:
			return a.size() == 6 and float(a[4]) < 1.0)


## The guest beside the guard - inside its 9 px reach - and turned to face
## it by walking into it for a few frames.
func _face_guard() -> void:
	(_room_node(WARDEN) as Node2D).set("speed", 0.0)
	_tell("teleport", [Vector2(33, 424)])
	_tell("key", [KEY_D, true])
	_wait("blows: the guest walks up to the guard", func() -> bool:
		return _f - _since > 12)


## Standing there taking it: the guard winds up and strikes on the host, and
## the blow is the guest's to feel.
func _guard_strikes() -> void:
	_tell("key", [KEY_D, false])
	_deadline = 600
	_expect("blows: the guard's blow, decided on the host, hurts the guest",
		"body", [_guest_id], func(a: Array) -> bool:
			return a.size() == 6 and int(a[1]) < 100)


## Swinging back. Its blows are reported to the host, which is where they
## count - three of them are a guard.
func _guest_swings() -> void:
	_tell("mash", [64])
	_deadline = 600
	_wait("blows: and the guest's swing hurts the host's guard",
		func() -> bool:
			var guard := _room_node(GUARD)
			return guard == null or int(guard.get("health")) < int(guard.get("max_health")))


func _guard_dies() -> void:
	var guard := _room_node(GUARD)
	if guard != null:
		guard.call("take_damage", 999)
	_expect("snapshot: a body the host kills is gone on the guest", "enemies", [],
		func(theirs: Dictionary) -> bool:
			return not theirs.is_empty() and not theirs.has(GUARD))


func _reinforcement() -> void:
	var beat := _room_node("Reinforcements")
	beat.call("_spawn", "regular", Vector2(240, 300))
	_mark = Vector2(240, 300)
	var arrived := ""
	for node in _level().get_node("Props").get_children():
		if String(node.name).begins_with("Reinforcement"):
			arrived = "Props/" + String(node.name)
			node.set("speed", 0.0)
	_check("host: a reinforcement walks in (%s)" % arrived, arrived != "")
	_expect("snapshot: and appears on the guest, made from its scene", "get",
		[arrived, ["global_position", "scene_file_path"]], func(a) -> bool:
			return a is Array and (a[0] as Vector2).distance_to(_mark) < 3.0 \
				and String(a[1]) == "res://game/enemies/regular/regular.tscn")


func _reinforcement_dies() -> void:
	var arrived := ""
	for node in _level().get_node("Props").get_children():
		if String(node.name).begins_with("Reinforcement"):
			arrived = "Props/" + String(node.name)
			node.call("take_damage", 999)
	_expect("snapshot: and goes there when it dies here (%s)" % arrived, "enemies", [],
		func(theirs: Dictionary) -> bool:
			return not theirs.is_empty() and not theirs.has(arrived))


## A guest's room cannot work out whether it is beaten - its beats never run -
## so its doors show the HOST's word, carried in the snapshot
## (game/levels/door_base.gd's sealed()). Hellfire still has bodies standing.
func _doors_sealed() -> void:
	_check("host: hellfire is still sealed with its bodies standing",
		bool(_room_node("Props/Exit").call("sealed")))
	_expect("doors: the guest's way up shows the host's room sealed", "get",
		["Props/Exit", ["_host_sealed"]], func(a) -> bool:
			return a is Array and a[0] == 1)


## Beaten the short way on the host; the guest's lamps and padlock follow.
func _doors_open() -> void:
	_clear_room()
	_check("host: and beaten, both ways open",
		not bool(_room_node("Props/Exit").call("sealed"))
			and not bool(_room_node("Props/Return").call("sealed")))
	_expect("doors: the guest hears it, and its lock starts the unlock", "get",
		["Props/Return/Lock", ["_since"]], func(a) -> bool:
			return a is Array and float(a[0]) >= 0.0)
