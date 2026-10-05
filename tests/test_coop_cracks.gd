extends "res://tests/coop.gd"
## Two machines in one run (DESIGN.md's Multiplayer, M6) - THE CRACKS: the
## moments where two machines' pictures of one run could come apart, each made
## to happen on purpose. The harness is tests/coop.gd. A LAGGING guest is the
## probe's `stall`, which holds the guest's whole machine still - nothing sent,
## nothing heard, nothing drawn - the way a hitch or a bad line does.
##
## - **Two people talk to one NPC at once**: both press interact by HR on one
##   frame, so each machine starts its own conversation before it can hear of
##   the other's. The host's word decides: one conversation, the host's, and
##   the guest's closes again with HR busy on its screen.
## - **A door during a fade**: the guest's body leaves the doorway and comes
##   back while the host is already fading through it, as a guest's late steps
##   would have it - and the party still arrives once, in one room.
## - **Dying during a fade**: the guest's body, then the host's, dies on the way
##   through - one life each from the pool, and up on the far side at full
##   health on both machines with hands that work. Then a LAGGING guest whose
##   body dies after the host has arrived, while its own machine is still
##   frozen in the room before: down on both, up three seconds later.
## - **A boss conceding to a lagging guest**: the guest's swing brings Ahmed
##   down while its machine hitches; he concedes once on both, his bar comes
##   down on both, and the swings still on their way do nothing to him.
## - **A guest dropping mid-fight**: the guest's machine killed outright, no
##   goodbye, with a guard on it. A second into the silence its body is AWAY -
##   out of the fight, the guard's target no longer, and nothing lands on it -
##   and when the host gives up on the line it is gone, said across the top,
##   with the pool exactly as it was.

const HR := "Props/HrLady"
const LOBBY_LEVEL := "res://game/levels/lobby/lobby.tscn"
const AHMED := "res://game/levels/ahmed_office/ahmed_office.tscn"
const HELLFIRE := "res://game/levels/hellfire/hellfire.tscn"
const GUARD := "Props/Enemy1"
## How long the host waits on a silent guest here before dropping it. The
## game's own is longer, for a web tab that is only hidden; a suite has no
## reason to sit through it.
const DROP_SECONDS := 4.0

var _room_mark := 0
var _lives_mark := 0
var _concedes := 0


func _init() -> void:
	port = 48011
	ProjectSettings.set_setting("za/test/drop_seconds", DROP_SECONDS)


func _plan() -> Array[Callable]:
	return [_together,
		_by_hr, _both_press, _host_keeps_her, _guest_closed, _guest_hands, _busy_there,
		_hr_done, _hr_free_there,
		_into_door, _out_and_in, _arrived_once, _once, _arrived_once_there,
		_guest_dies_in_fade, _guest_up_here, _guest_up_there, _guest_moves_after,
		_pool_there,
		_host_dies_in_fade, _host_up_here, _host_up_there, _pool_there,
		_lagging_travel, _lagging_dies, _lagging_down_there, _lagging_down_body,
		_lagging_up, _lagging_hands, _pool_there,
		_to_ahmed, _arrived, _lagging_blow, _conceded_there, _conceded_state_there,
		_late_swings, _gave_in_once,
		_to_hellfire, _arrived, _guard_on_guest, _guest_drops, _away, _untouched,
		_untouched_health, _dropped, _pool_kept, _after_the_drop]


func _room_node(path: String) -> Node:
	var level := _level()
	return level.get_node_or_null(NodePath(path)) if level != null else null


func _boss() -> Node:
	return _room_node("Props/Boss")


func _arrived() -> void:
	var room: int = _sync().get("room")
	var level := String(_level().name)
	_expect("travel: the guest arrives there in the same room", "where", [],
		func(a: Array) -> bool:
			return a.size() == 4 and a[2] == room and a[3] == level)


func _travelling() -> bool:
	return bool(current_scene.get("_travelling"))


## The pool full again before a death is spent on purpose, on both machines.
func _refill() -> void:
	current_scene.call("net_lives", 3)
	_sync().call("lives_changed", 3)
	_lives_mark = 3


func _pool_there() -> void:
	var lives: int = current_scene.get("lives")
	_expect("pool: the guest's is the host's (%d)" % lives, "lives", [],
		func(n: int) -> bool: return n == lives)


# --- two people, one NPC -----------------------------------------------------------


func _by_hr() -> void:
	var hr := _room_node(HR) as Node2D
	_player().global_position = hr.global_position + Vector2(-8, 14)
	_tell("teleport", [hr.global_position + Vector2(8, 14)])
	_tell("watch_talks")
	_expect("two at once: the guest stands by HR and is offered her", "get",
		[HR + "/Prompt", ["visible"]], func(a) -> bool: return a is Array and a[0] == true)


## On one frame on both keyboards. A press is acted on at the start of the
## next frame, and anything sent then lands at the other end's next poll -
## so each machine has begun its own before the other's word can reach it.
func _both_press() -> void:
	_check("two at once: and so is the host",
		(_room_node(HR + "/Prompt") as Control).visible)
	_tell("key", [KEY_E, true])
	_tell("key", [KEY_E, false])
	_key(KEY_E, true)
	_key(KEY_E, false)
	_expect("two at once: the guest's machine began one too, before it heard",
		"talks", [], func(n: int) -> bool: return n == 1)


func _host_keeps_her() -> void:
	_wait("two at once: the host's word decides - HR is the host's to talk to",
		func() -> bool:
			var hr := _room_node(HR)
			return _f - _since > 20 and _dialogue().call("talking") \
				and hr.get("led_by") == 0 and hr.get("_talking") == true)


func _guest_closed() -> void:
	_expect("two at once: and the guest's conversation is closed again", "talking", [],
		func(on: bool) -> bool: return not on)


func _guest_hands() -> void:
	_expect("two at once: with the guest's hands its own", "hands", [],
		func(a: Array) -> bool: return a.size() == 4 and a[0] == false and a[1] == true)


func _busy_there() -> void:
	_expect("two at once: HR busy on the guest's screen, and nobody's to lead there",
		"get", [HR, ["_talking", "led_by"]], func(a) -> bool:
			return a is Array and a[0] == true and a[1] == 0)


func _hr_done() -> void:
	_dialogue().call("stop")
	_wait("two at once: once the host is done she is free here", func() -> bool:
		var hr := _room_node(HR)
		return hr.get("_talking") == false and hr.get("led_by") == 0)


func _hr_free_there() -> void:
	_expect("two at once: and free there", "get", [HR, ["_talking", "led_by"]],
		func(a) -> bool: return a is Array and a[0] == false and a[1] == 0)


# --- a door during a fade -------------------------------------------------------------


func _into_door() -> void:
	_room_mark = _sync().get("room")
	_player().global_position = Vector2(266, 78)
	_tell("teleport", [Vector2(278, 78)])
	_key(KEY_W, true)
	_tell("key", [KEY_W, true])
	_deadline = 600
	_wait("door: both walk into the lobby's door, and the host's fade begins",
		_travelling)


## The guest's late steps, as a host hears them from a guest that has not
## heard of the door yet: out of the doorway, and back in, mid-fade.
func _out_and_in() -> void:
	_key(KEY_W, false)
	_tell("key", [KEY_W, false])
	var at := _second().global_position
	_wait("door: the guest's body leaves the doorway and comes back, mid-fade",
		func() -> bool:
			if _f - _since < 5:
				_second().global_position = at + Vector2(0, 40)
			return _f - _since > 8)


func _arrived_once() -> void:
	_deadline = 400
	_wait("door: the party arrives in the studio", func() -> bool:
		return not _travelling() and String(_level().name) == "ContentStudio" \
			and _f - _since > 90)


func _once() -> void:
	_check("door: once - one room on from the lobby (%d, was %d)"
		% [_sync().get("room"), _room_mark], _sync().get("room") == _room_mark + 1)


func _arrived_once_there() -> void:
	var room: int = _sync().get("room")
	_expect("door: and the guest is in that one room", "where", [],
		func(a: Array) -> bool:
			return a.size() == 4 and a[2] == room and a[3] == "ContentStudio")


# --- dying during a fade --------------------------------------------------------------


func _guest_dies_in_fade() -> void:
	_refill()
	current_scene.call("_travel", LOBBY_LEVEL, &"start")
	_wait("fade: the guest's body dies on the way through", func() -> bool:
		if _f - _since == 6:
			_second().set("_grace", 0.0)
			_second().call("take_damage", 500)
		return _f - _since > 6 and _second().call("is_down") \
			and current_scene.get("lives") == _lives_mark - 1)


func _guest_up_here() -> void:
	_wait("fade: and is up on the far side, at full health", func() -> bool:
		return not _travelling() and String(_level().name) == "Lobby" \
			and not _second().call("is_down") and _second().get("health") == 100)


func _guest_up_there() -> void:
	_expect("fade: up on the guest's machine too, at full health", "body",
		[_guest_id], func(a: Array) -> bool:
			return a.size() == 6 and a[1] == 100 and a[2] == false)


func _guest_moves_after() -> void:
	_expect("fade: with hands that work - its own, moving, in the fight", "hands", [],
		func(a: Array) -> bool:
			return a == [false, true, false, true])


func _host_dies_in_fade() -> void:
	_refill()
	current_scene.call("_travel", LOBBY_LEVEL, &"start")
	_wait("fade: the host's own body dies on the way through", func() -> bool:
		if _f - _since == 6:
			_player().set("_grace", 0.0)
			_player().call("take_damage", 500)
		return _f - _since > 6 and _player().call("is_down") \
			and current_scene.get("lives") == _lives_mark - 1)


func _host_up_here() -> void:
	_wait("fade: and is up on the far side, at full health, moving", func() -> bool:
		return not _travelling() and not _player().call("is_down") \
			and _player().get("health") == 100 and _player().is_physics_processing())


func _host_up_there() -> void:
	_expect("fade: and up on the guest's machine", "body", [1], func(a: Array) -> bool:
		return a.size() == 6 and a[1] == 100 and a[2] == false)


## The guest's machine frozen as the host goes through a door, and still
## frozen when the host has arrived and the guest's body dies there.
func _lagging_travel() -> void:
	_refill()
	_room_mark = _sync().get("room")
	_tell("stall", [900, 0])
	_wait("lag: the host goes through while the guest's machine is frozen",
		func() -> bool:
			if _f - _since == 3:
				current_scene.call("_travel", LOBBY_LEVEL, &"start")
			return _f - _since > 3 and _sync().get("room") == _room_mark + 1)


func _lagging_dies() -> void:
	_second().set("_grace", 0.0)
	_second().call("take_damage", 500)
	_check("lag: the guest's body dies in the new room, one life from the pool",
		_second().call("is_down") and current_scene.get("lives") == _lives_mark - 1)


func _lagging_down_there() -> void:
	var room: int = _sync().get("room")
	_deadline = 400
	_expect("lag: caught up, the guest is through the door too, in the same room",
		"where", [], func(a: Array) -> bool: return a.size() == 4 and a[2] == room)


func _lagging_down_body() -> void:
	_expect("lag: and its body is down there", "hands", [],
		func(a: Array) -> bool: return a.size() == 4 and a[2] == true)


func _lagging_up() -> void:
	_deadline = 400
	_wait("lag: up at this room's door three seconds later", func() -> bool:
		return not _second().call("is_down") and _second().get("health") == 100)


func _lagging_hands() -> void:
	_expect("lag: and up on the guest's machine, its hands its own", "hands", [],
		func(a: Array) -> bool: return a == [false, true, false, true])


# --- a boss conceding to a lagging guest ----------------------------------------------


func _to_ahmed() -> void:
	_refill()
	current_scene.call("_travel", AHMED, &"start")
	_deadline = 400
	_wait("boss: the party goes up to Ahmed", func() -> bool:
		return not _travelling() and _level().scene_file_path == AHMED \
			and _boss() != null)


## One blow from the end, the guest beside him swinging - and twenty frames in,
## its machine hitches for most of a second, so the blow that finishes him
## reaches the host from a guest that is behind.
func _lagging_blow() -> void:
	var boss := _boss() as Node2D
	boss.set("speed", 0.0)
	boss.set("health", 4)
	boss.connect(&"conceded", func() -> void: _concedes += 1)
	_tell("teleport", [boss.global_position + Vector2(-14, 0)])
	_tell("key", [KEY_D, true])
	_deadline = 600
	_wait("boss: the lagging guest's swing brings him down on the host",
		func() -> bool:
			if _f - _since == 8:
				_tell("key", [KEY_D, false])
				_tell("mash", [120])
				_tell("stall", [700, 4])
			return boss.get("has_conceded") == true)


func _conceded_there() -> void:
	_deadline = 400
	_expect("boss: conceded on the guest's machine too, his bar down", "boss_bar", [],
		func(a: Array) -> bool: return a.size() == 2 and a[0] == false)


func _conceded_state_there() -> void:
	_expect("boss: at nothing there either", "get", ["Props/Boss", ["has_conceded",
		"health"]], func(a) -> bool: return a is Array and a[0] == true and a[1] == 0)


## The guest is still swinging, and swings sent from behind keep arriving.
func _late_swings() -> void:
	_wait("boss: the swings still on their way arrive", func() -> bool:
		return _f - _since > 150)


func _gave_in_once() -> void:
	var boss := _boss()
	_check("boss: he gave in ONCE (%d)" % _concedes, _concedes == 1)
	_check("boss: and the late swings were nothing to him - at nothing, out of the fight",
		boss.get("health") == 0 and boss.get("has_conceded") == true
			and not boss.is_in_group("enemies"))


# --- a guest dropping mid-fight --------------------------------------------------------


func _to_hellfire() -> void:
	_refill()
	current_scene.call("_travel", HELLFIRE, &"start")
	_deadline = 400
	_wait("drop: the party goes on to hellfire", func() -> bool:
		return not _travelling() and _level().scene_file_path == HELLFIRE)


## The guest beside the guard, turned to face it by walking into it - every
## other body stood still - until the guard is after the guest.
func _guard_on_guest() -> void:
	for node in get_nodes_in_group("enemies"):
		node.set("speed", 0.0)
	var guard := _room_node(GUARD)
	_tell("teleport", [Vector2(33, 424)])
	_tell("key", [KEY_D, true])
	_deadline = 400
	_wait("drop: the guard has the guest", func() -> bool:
		if _f - _since == 12:
			_tell("key", [KEY_D, false])
		return _f - _since > 14 and guard.call("target") == _second())


## The guest's machine gone - killed, not quit: no goodbye, nothing on the
## line, exactly as a crash or a pulled cable leaves it.
func _guest_drops() -> void:
	OS.kill(_pid)
	_deadline = 180
	_wait("drop: a second into the silence the guest's body is AWAY",
		func() -> bool:
			return _second() != null and _second().get("away") == true \
				and not _second().is_in_group("player"))


func _away() -> void:
	var guard := _room_node(GUARD)
	_check("drop: away is not down - nothing spent on it",
		not _second().call("is_down") and current_scene.get("lives") == _lives_mark)
	_check("drop: and the guard is not after it any more",
		guard == null or guard.call("target") != _second())
	_health_mark = _second().get("health")


func _untouched() -> void:
	_wait("drop: a second and a half away", func() -> bool: return _f - _since > 90)


func _untouched_health() -> void:
	var health: Variant = _second().get("health") if _second() != null else null
	_check("drop: and nothing landed on it meanwhile (%s)" % health, health == _health_mark)


func _dropped() -> void:
	_deadline = 60 * int(DROP_SECONDS + 4)
	_wait("drop: once the host gives up on the line, the body is gone, and said so",
		func() -> bool:
			return _second() == null and (current_scene.call("party") as Array).size() == 1 \
				and current_scene.get_node("HUD/Hud").call("notice_text") == "ANAS LEFT THE GAME")


func _pool_kept() -> void:
	_check("drop: the pool is exactly what it was (%d)" % current_scene.get("lives"),
		current_scene.get("lives") == _lives_mark)


## A few more rounds of the roster and the ping once the line is given up on,
## none of which may be sent down it - the transport holds a peer for a while
## after it is asked to let go, and a packet to one going down is an error.
func _after_the_drop() -> void:
	_wait("drop: the run goes on, a party of one, for a few rounds of the roster",
		func() -> bool:
			return _f - _since > 150 and (current_scene.call("party") as Array).size() == 1 \
				and (_net().call("roster") as Array).size() == 1)
