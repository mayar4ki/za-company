extends "res://tests/coop.gd"
## Two machines, a revive each way (game/revive.gd). The harness is
## tests/coop.gd. The host is the truth: it counts the seconds and says when
## somebody is up, and a guest's machine only says who its own player is
## reviving, in its body's state.
##
## - **The host revives the guest**: the host's player holds E over the guest's
##   body, the guest's machine draws its ring filling on the host's word, and
##   the guest gets up where it lay at 50 - on both machines, with its hands.
## - **The guest revives the host**: the guest holds E, the host counts it off
##   that word alone, a blow the host lands on the guest knocks a second off on
##   both machines, and the host gets up where it lay at 50 on both.
## - **The pool never hears of either.**
##
## In the lobby, well away from HR, whose prompt the same key answers.

## Where the host's player and the guest's body stand, 12 px apart.
const HERE := Vector2(196, 150)
const THERE := Vector2(184, 150)
## The host's peer id, which is how the guest is asked about the host's body.
const HOST := 1

var _before_blow := 0.0


func _init() -> void:
	port = 48021


func _plan() -> Array[Callable]:
	return [_together, _place,
		_guest_falls, _guest_down_there,
		_host_holds, _filling_there, _guest_up, _guest_up_there, _guest_hands,
		_host_falls, _guest_holds, _blow, _blow_there, _host_up, _host_up_there,
		_pool, _pool_there]


func _place() -> void:
	# The hearts are spent, so whoever falls stays down: only a revive helps.
	current_scene.set("lives", 0)
	_player().global_position = HERE
	_tell("teleport", [THERE])
	_wait("place: the guest's body comes to stand by the host's", func() -> bool:
		return _second() != null and _second().global_position.distance_to(THERE) < 1.0)


func _guest_falls() -> void:
	_second().call("drain", 999)
	_wait("down: the guest's body goes down on the host, and stays down", func() -> bool:
		return _second().call("is_down") and _lives() == 0 and not paused)


func _guest_down_there() -> void:
	_expect("down: and on the guest's own machine", "hands", [], func(a: Array) -> bool:
		return a.size() == 4 and a[2] == true)


func _host_holds() -> void:
	_key(KEY_E, true)
	_wait("host holds: the host's player holding E fills the guest's revive", func() -> bool:
		return _revive().call("filling", _second()) and _progress(_second()) > 0.3)


func _filling_there() -> void:
	_expect("host holds: the guest's machine draws a ring under itself, filling on the host's word",
		"revive", [_guest_id], func(a: Array) -> bool:
			return a.size() == 3 and a[1] == true and float(a[0]) > 0.3 and a[2] == 1)


func _guest_up() -> void:
	_wait("guest up: on the host, up where it lay at 50", func() -> bool:
		return not _second().call("is_down") and _second().get("health") == 50 \
			and _second().global_position.distance_to(THERE) < 1.0)


func _guest_up_there() -> void:
	_key(KEY_E, false)
	_expect("guest up: and on its own machine, at 50", "body", [_guest_id],
		func(a: Array) -> bool:
			return a.size() >= 6 and a[2] == false and a[1] == 50)


func _guest_hands() -> void:
	_expect("guest up: with its hands back - its own to move, and in the fight", "hands", [],
		func(a: Array) -> bool:
			return a.size() == 4 and a[1] == true and a[2] == false and a[3] == true)


func _host_falls() -> void:
	_player().call("drain", 999)
	_wait("host down: the host's player goes down, and the run goes on", func() -> bool:
		return _player().call("is_down") and not paused)


func _guest_holds() -> void:
	_tell("key", [KEY_E, true])
	_wait("guest holds: the host counts the guest's E, said only in its body's state",
		func() -> bool:
			return _revive().call("filling", _player()) and _progress(_player()) > 0.4)


func _blow() -> void:
	_before_blow = _progress(_player())
	_second().call("take_damage", 10)
	_wait("blow: a blow on the guest knocks a second off the host's count", func() -> bool:
		return _progress(_player()) < _before_blow - 0.2)


func _blow_there() -> void:
	var mark := _before_blow
	_expect("blow: and off the guest's copy of it", "revive", [HOST], func(a: Array) -> bool:
		return a.size() == 3 and float(a[0]) < mark - 0.1)


func _host_up() -> void:
	_wait("host up: up where it lay, at 50", func() -> bool:
		return not _player().call("is_down") and _player().get("health") == 50 \
			and _player().global_position.distance_to(HERE) < 1.0)


func _host_up_there() -> void:
	_tell("key", [KEY_E, false])
	_expect("host up: and on the guest's machine", "body", [HOST], func(a: Array) -> bool:
		return a.size() >= 6 and a[2] == false and a[1] == 50)


func _pool() -> void:
	_check("pool: the host's never moved (%s)" % _lives(), _lives() == 0)


func _pool_there() -> void:
	_expect("pool: nor did the guest hear of any change to it", "lives", [],
		func(a: Variant) -> bool:
			return a == 3)


func _revive() -> Node:
	return current_scene.get_node("Revive")


func _progress(body: Node) -> float:
	return float(_revive().call("progress", body))
