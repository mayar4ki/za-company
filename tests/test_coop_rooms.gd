extends "res://tests/coop.gd"
## Two machines in one run (DESIGN.md's Multiplayer, M3) - the ROOMS: what a
## floor does besides its enemies, from the host, in the guest's room by the
## same one snapshot (game/sync/world.gd). The harness is tests/coop.gd.
##
## - **The studio**: the guest's clock keeps the host's time - it runs its own
##   and is put right only if it comes apart - and the dolly rolls where the
##   host's does.
## - **The call floor**: the wiring fires on the host's count; Ivan walks in on
##   the host and in through the guest's door too, with his lines; the hearts he
##   throws there land on the guest's floor, and one the guest walks onto heals
##   the guest - decided on the host, gone everywhere.
## - **The hub**: the scrubbers wander where the host's dice send them.
##
## Floors are changed by the host's own travel, which is what a door does,
## rather than by walking each one: the walk is test_coop.gd's.
##
## Every enemy stands still (speed 0 on the host), so nothing but the room
## under test reaches anybody.

const STUDIO := "res://game/levels/content_studio/content_studio.tscn"
const CALL := "res://game/levels/call_center/call_center.tscn"
const HUB := "res://game/levels/the_hub/the_hub.tscn"

var _health := 0


func _init() -> void:
	port = 47961
	start_level = STUDIO


func _plan() -> Array[Callable]:
	return [_together, _still, _clock, _dolly, _to_call, _arrived, _still,
		_wiring, _ivan, _thrown, _hurt, _heart_spent, _to_hub, _arrived, _scrubbers]


func _room_node(path: String) -> Node:
	var level := _level()
	return level.get_node_or_null(NodePath(path)) if level != null else null


func _still() -> void:
	for node in get_nodes_in_group("enemies"):
		node.set("speed", 0.0)
	_check("host: on %s, every enemy stood still" % _level().name, _level() != null)


func _clock() -> void:
	_expect("studio: the guest's clock keeps the host's time", "get",
		["Studio", ["phase", "_left"]], func(a) -> bool:
			var studio := _room_node("Studio")
			return a is Array and int(a[0]) == int(studio.get("phase")) \
				and absf(float(a[1]) - float(studio.get("_left"))) < 0.3)


func _dolly() -> void:
	_deadline = 900
	_expect("studio: and the dolly rolls where the host's does", "get",
		["Props/Dolly", ["global_position"]], func(a) -> bool:
			var dolly := _room_node("Props/Dolly") as Node2D
			return a is Array and float(dolly.get("_along")) > 0.2 \
				and (a[0] as Vector2).distance_to(dolly.global_position) < 8.0)


func _to_call() -> void:
	current_scene.call("_travel", CALL, &"start")
	_deadline = 600
	_wait("travel: the host takes the party to the call floor",
		func() -> bool: return _level() != null and _level().scene_file_path == CALL)


func _arrived() -> void:
	var room: int = _sync().get("room")
	var level := String(_level().name)
	_expect("travel: the guest arrives there in the same room", "where", [],
		func(a: Array) -> bool:
			return a.size() == 4 and a[2] == room and a[3] == level)


func _wiring() -> void:
	_expect("wiring: the guest's runs fire on the host's count", "get",
		["Props/Surge1", ["_elapsed"]], func(a) -> bool:
			var surge := _room_node("Props/Surge1")
			return a is Array and absf(float(a[0]) - float(surge.get("_elapsed"))) < 0.3)


func _ivan() -> void:
	_room_node("Relief").call("_arrive")
	var ivan := _room_node("Props/Ivan")
	_check("ivan: walks in on the host", ivan != null)
	var says := String(ivan.get("conversation")) if ivan != null else "?"
	_expect("ivan: and in on the guest, with his lines for this floor", "get",
		["Props/Ivan", ["conversation", "global_position"]], func(a) -> bool:
			return a is Array and String(a[0]) == says and says != "" \
				and (a[1] as Vector2).distance_to((ivan as Node2D).global_position) < 8.0)


func _thrown() -> void:
	var ivan := _room_node("Props/Ivan")
	ivan.call("set_talking", true)
	ivan.call("set_talking", false)
	_check("hearts: thrown on the host, one per head (%s)" % ivan.call("has_given"),
		_room_node("Props/IvansHeart1") != null and _room_node("Props/IvansHeart2") != null)
	_deadline = 600
	_expect("hearts: and landing on the guest's floor", "enemies", [],
		func(theirs: Dictionary) -> bool:
			var heart := _room_node("Props/IvansHeart1") as Node2D
			return theirs.has("Props/IvansHeart1") and theirs.has("Props/IvansHeart2") \
				and heart != null and heart.get("monitoring") == true \
				and (theirs["Props/IvansHeart1"][0] as Vector2).distance_to(heart.global_position) < 2.0)


## Hurt by MORE than a heart (40). Two heads are two hearts, landing about 11
## px apart, and a body stood on one is on both - so at a heart's worth exactly
## whichever of the two is touched first fills the bar and the other is rightly
## left lying for a player who is full, and which one that is, is the order the
## physics server happens to report them in. Hurt past a heart, both are spent
## whichever comes first.
func _hurt() -> void:
	_second().set("_grace", 0.0)
	_second().call("take_damage", 60)
	_expect("hearts: the guest has a heart's worth to take", "body", [_guest_id],
		func(a: Array) -> bool:
			_health = int(a[1]) if a.size() == 6 else 0
			return a.size() == 6 and int(a[1]) <= 60)


func _heart_spent() -> void:
	_tell("teleport", [(_room_node("Props/IvansHeart1") as Node2D).global_position])
	_deadline = 600
	_expect("hearts: one the guest walks onto heals the guest, and is gone there",
		"body", [_guest_id], func(a: Array) -> bool:
			return a.size() == 6 and int(a[1]) > _health \
				and _room_node("Props/IvansHeart1") == null)


func _to_hub() -> void:
	current_scene.call("_travel", HUB, &"start")
	_deadline = 600
	_wait("travel: and on to the hub",
		func() -> bool: return _level() != null and _level().scene_file_path == HUB)


## Within a beat of the host's: the guest draws it a tenth of a second behind
## (sync.gd's `DELAY`), and the answer takes a frame or two to come back, which
## at 60 px/s is the best part of ten pixels before the room has done anything
## wrong.
func _scrubbers() -> void:
	_expect("hub: the scrubbers wander where the host's dice send them", "get",
		["Props/Scrubber1", ["global_position"]], func(a) -> bool:
			var scrubber := _room_node("Props/Scrubber1") as Node2D
			return a is Array and (a[0] as Vector2).distance_to(scrubber.global_position) < 16.0)
