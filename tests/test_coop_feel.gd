extends "res://tests/coop.gd"
## Two machines in one run (DESIGN.md's Multiplayer, M4) - THE FEEL: what the
## world in step looks and sounds like, now that it is in step. The harness is
## tests/coop.gd.
##
## - **Drawn a beat behind, and between.** Everybody else's body stands at its
##   newest word while its picture follows a tenth of a second later, and the
##   room's bodies glide between the host's snapshots instead of stepping
##   twenty times a second (game/sync/timeline.gd).
## - **The stop holds the picture.** A blow that lands online holds this
##   machine's animations and effects and never the engine's clock - the
##   host's world is everybody's - and never somebody else's player; and
##   somebody else's blow holds nothing here (game/picture_hold.gd).
## - **Everybody sees every blow.** A blow is a player's MOMENT, told through
##   the host (game/sync/world.gd's *A player's moment*): the number over the
##   body, the pieces when it dies, the bolt, the swing's air and its impact -
##   and a blow on a player is seen landing on every machine, grunt and all.
##   A remote body's own moves are read off its picture: its charge's ring and
##   hum, and the supernova when the heavy goes.
##
## On hellfire, with every enemy stood still on the host, and each blow staged
## against a body standing on its own.

const HELLFIRE := "res://game/levels/hellfire/hellfire.tscn"
const GLIDER := "Props/Enemy10"
const NORTH := "Props/Enemy9"
const GUARD := "Props/Enemy1"
const NUMBER := "res://game/player/damage_number.gd"
const BURST := "res://game/player/kill_burst.gd"
const NOVA := "res://game/player/supernova.gd"
const RING_GROUP := "player_charge"
const ARC_GROUP := "player_arcs"

## Latched over a wait, read by the checks after it.
var _lag := 0.0
var _scaled := false
var _held_before := 0
var _seen := {}
## The guest's picture on the host, as last put on screen, and how many frames
## put it further back than the one before (_on_screen).
var _shown_x := NAN
var _backward := 0
## Over a stop the host's blow holds: whether it held the host's own sprite,
## and whether it held the guest's.
var _held_mine := false
var _held_theirs := false


func _init() -> void:
	port = 47991
	start_level = HELLFIRE


func _plan() -> Array[Callable]:
	return [_together, _still_room, _guest_walks, _picture_lags, _picture_settles,
		_glide, _glide_trace, _glided, _host_faces, _host_swings, _host_stopped,
		_guest_sees_number, _guest_hears_swing, _guest_hears_hit, _host_kills,
		_guest_sees_burst, _guest_faces, _guest_mashes, _guest_blows_seen,
		_guest_held, _guest_charges, _charge_seen, _struck, _struck_seen,
		_struck_heard]


func _room_node(path: String) -> Node:
	var level := _level()
	return level.get_node_or_null(NodePath(path)) if level != null else null


func _hold() -> Node:
	return current_scene.get_node("PictureHold")


## How many nodes under `under` run the script at `path`.
func _count(under: Node, path: String) -> int:
	var count := 0
	for node in under.find_children("*", "", true, false):
		var script: Script = node.get_script()
		if script != null and script.resource_path == path:
			count += 1
	return count


func _plays(body: Node, id: String) -> int:
	return int(body.get_node("Audio").call("plays", id))


func _still_room() -> void:
	for node in get_nodes_in_group("enemies"):
		node.set("speed", 0.0)
	_check("host: on hellfire, and every enemy stood still",
		_level() != null and _level().scene_file_path == HELLFIRE)


# --- a beat behind, and between ----------------------------------------------------


## The guest walks east, and the host latches how far behind its body the
## picture of it is drawn - and watches every frame of that picture go on
## screen.
func _guest_walks() -> void:
	_lag = 0.0
	_mark = _second().global_position
	_shown_x = NAN
	_backward = 0
	process_frame.connect(_on_screen)
	_tell("key", [KEY_D, true])
	_wait("bodies: the guest walks", func() -> bool:
		var sprite := _second().get_node("AnimatedSprite2D") as Node2D
		_lag = maxf(_lag, -sprite.position.x)
		return _second().global_position.x > _mark.x + 40.0)


## Where the guest's picture is on THIS frame's screen. Read on process_frame,
## which comes after the network poll has stood the body on whatever step just
## arrived and before anything is drawn - a moment _tick, which runs before the
## poll, never sees.
func _on_screen() -> void:
	var x := (_second().get_node("AnimatedSprite2D") as Node2D).global_position.x
	if not is_nan(_shown_x) and x < _shown_x - 0.01:
		_backward += 1
	_shown_x = x


func _picture_lags() -> void:
	_tell("key", [KEY_D, false])
	process_frame.disconnect(_on_screen)
	_check("picture: walking, the host draws the guest a beat behind its body (%.1f px)"
		% _lag, _lag > 3.0 and _lag < 30.0)
	_check("picture: and a guest walking east is never drawn a step back (%d frames)"
		% _backward, _backward == 0)
	_wait("picture: and once it stands still, the picture is where the body is",
		func() -> bool:
			var sprite := _second().get_node("AnimatedSprite2D") as Node2D
			return _f - _since > 10 and sprite.position == Vector2.ZERO)


func _picture_settles() -> void:
	_expect("bodies: and the guest's own body is where the host stands it", "body",
		[_guest_id], func(a: Array) -> bool:
			return a.size() == 6 and (a[0] as Vector2).distance_to(_second().global_position) < 4.0)


## A body the host walks steadily east, a pixel a frame - through the room's
## furniture rather than into it, which would hold it up on the host...
func _glide() -> void:
	var glider := _room_node(GLIDER) as CharacterBody2D
	glider.collision_mask = 0
	_wait("room: the host walks a body steadily", func() -> bool:
		glider.global_position.x += 1.0
		return _f - _since > 20)


## ...which the guest traces frame by frame while it goes on walking.
func _glide_trace() -> void:
	var glider := _room_node(GLIDER) as Node2D
	_tell("trace", [GLIDER, 30])
	_wait("room: and keeps walking it while the guest watches", func() -> bool:
		glider.global_position.x += 1.0
		return _f - _since > 45)


## Twenty snapshots a second would move it on one frame in three; drawn between
## them it moves on nearly every frame.
func _glided() -> void:
	_expect("picture: on the guest it glides, moving on nearly every frame", "traced", [],
		func(a: Array) -> bool:
			if a.size() < 30:
				return false
			var moved := 0
			for i in range(1, a.size()):
				if (a[i] as Vector2) != (a[i - 1] as Vector2):
					moved += 1
			return moved >= 24 and (a[-1] as Vector2).x - (a[0] as Vector2).x > 20.0)


# --- the stop holds the picture ------------------------------------------------------


## The host's player beside the guard in the north, turned to face it by
## walking into it.
func _host_faces() -> void:
	_player().global_position = Vector2(98, 168)
	_key(KEY_D, true)
	_wait("blows: the host walks up to a guard", func() -> bool: return _f - _since > 12)


## One swing, and the frames after it watched for the engine's clock moving.
func _host_swings() -> void:
	_key(KEY_D, false)
	_held_before = int(_hold().get("held"))
	_scaled = false
	_held_mine = false
	_held_theirs = false
	_key(KEY_SPACE, true)
	var guard := _room_node(NORTH)
	var mine := _player().get_node("AnimatedSprite2D")
	var theirs := _second().get_node("AnimatedSprite2D")
	_wait("blows: the host's swing lands", func() -> bool:
		if _f - _since == 4:
			_key(KEY_SPACE, false)
		_scaled = _scaled or Engine.time_scale != 1.0
		_held_mine = _held_mine or mine.process_mode == Node.PROCESS_MODE_DISABLED
		_held_theirs = _held_theirs or theirs.process_mode == Node.PROCESS_MODE_DISABLED
		return int(guard.get("health")) < int(guard.get("max_health")) and _f - _since > 8)


func _host_stopped() -> void:
	_check("stop: online it holds the host's picture (%d)" % int(_hold().get("held")),
		int(_hold().get("held")) > _held_before)
	_check("stop: and never the engine's clock, which is everybody's world", not _scaled)
	_check("stop: it holds the host's own sprite", _held_mine)
	_check("stop: and never the guest's, which is its owner's picture", not _held_theirs)


func _guest_sees_number() -> void:
	_expect("seen: the host's blow puts its number up on the guest", "count",
		[NUMBER, 0], func(n: int) -> bool: return n >= 1)


func _guest_hears_swing() -> void:
	_expect("heard: the host's swing, read off its picture on the guest", "plays",
		[1, "swing"], func(n: int) -> bool: return n >= 1)


func _guest_hears_hit() -> void:
	_expect("heard: and its impact, on the host's word", "plays", [1, "hit"],
		func(n: int) -> bool: return n >= 1)


func _host_kills() -> void:
	_room_node(NORTH).set("health", 1)
	_key(KEY_SPACE, true)
	_wait("blows: the host's next swing kills it", func() -> bool:
		if _f - _since == 4:
			_key(KEY_SPACE, false)
		var guard := _room_node(NORTH)
		return _f - _since > 4 and (guard == null or guard.is_queued_for_deletion()))


func _guest_sees_burst() -> void:
	_expect("seen: and it breaks apart on the guest's floor too", "count", [BURST, 0],
		func(n: int) -> bool: return n >= 1)


# --- everybody sees every blow --------------------------------------------------------


## The guest beside the guard by the west wall, turned to face it.
func _guest_faces() -> void:
	_tell("teleport", [Vector2(33, 424)])
	_tell("key", [KEY_D, true])
	_wait("blows: the guest walks up to a guard", func() -> bool: return _f - _since > 12)


## Mashing through a whole combo, the host latching what it draws of it.
func _guest_mashes() -> void:
	_tell("key", [KEY_D, false])
	_tell("mash", [96])
	_held_before = int(_hold().get("held"))
	_seen = {"number": false, "arc": false, "burst": false}
	var props := _level().get_node("Props")
	_deadline = 600
	_wait("blows: the guest's combo is dealt on the host", func() -> bool:
		for node in props.get_children():
			var script: Script = node.get_script()
			if script != null and script.resource_path == NUMBER \
					and (node as Node2D).global_position.distance_to(Vector2(44, 424)) < 40.0:
				_seen["number"] = true
		_seen["arc"] = _seen["arc"] or not get_nodes_in_group(ARC_GROUP).is_empty()
		_seen["burst"] = _seen["burst"] or _count(_level(), BURST) > 0
		# The mash runs out before the next step holds the button down.
		return _room_node(GUARD) == null and _f - _since > 120)


func _guest_blows_seen() -> void:
	_check("seen: the guest's blows put their numbers up over the guard on the host",
		_seen["number"])
	_check("seen: its arc's bolt is drawn on the host", _seen["arc"])
	_check("seen: and the guard it killed breaks apart there", _seen["burst"])
	_check("heard: its swings, read off its picture on the host (%d)"
		% _plays(_second(), "swing"), _plays(_second(), "swing") >= 1)
	_check("heard: and their impact (%d)" % _plays(_second(), "hit"),
		_plays(_second(), "hit") >= 1)
	_check("stop: somebody else's blows hold nothing on the host",
		int(_hold().get("held")) == _held_before)


func _guest_held() -> void:
	_expect("stop: the guest's own blows held the guest's picture", "holds", [],
		func(n: int) -> bool: return n >= 1)


## Held down: the charge, then the heavy going off by itself.
func _guest_charges() -> void:
	_seen = {"ring": false, "nova": false}
	_tell("key", [KEY_SPACE, true])
	_deadline = 300
	_wait("charge: the guest holds the button down", func() -> bool:
		for node in get_nodes_in_group(RING_GROUP):
			_seen["ring"] = _seen["ring"] or _second().is_ancestor_of(node)
		_seen["nova"] = _seen["nova"] or _count(_second(), NOVA) > 0
		return _seen["nova"] and _f - _since > 10)


func _charge_seen() -> void:
	_tell("key", [KEY_SPACE, false])
	_check("seen: the guest's charge draws its ring on the host", _seen["ring"])
	_check("seen: and its heavy goes off there as a supernova", _seen["nova"])
	_check("heard: with the charge's hum and the heavy's own noise",
		_plays(_second(), "charge") >= 1 and _plays(_second(), "heavy") >= 1)


## A blow on each body, decided here as every blow on a player is - once both
## are out of their grace, and with the grunts counted so far, since the
## guards have been swinging at both of them.
func _struck() -> void:
	_expect("struck: both bodies out of their grace", "plays", [1, "hurt"],
		func(n: int) -> bool:
			_health_mark = n
			return _f - _since > 60)


func _struck_seen() -> void:
	var numbers := _count(_second(), NUMBER)
	var grunts := _plays(_second(), "hurt")
	_player().call("take_damage", 10)
	_second().call("take_damage", 10)
	_check("seen: a blow on the guest's body puts its number over it on the host",
		_count(_second(), NUMBER) > numbers)
	_check("heard: and its grunt, from where the guest stands",
		_plays(_second(), "hurt") > grunts)
	_expect("seen: a blow on the host's body puts its number over it on the guest",
		"count", [NUMBER, 1], func(n: int) -> bool: return n >= 1)


func _struck_heard() -> void:
	_expect("heard: and its grunt there", "plays", [1, "hurt"],
		func(n: int) -> bool: return n > _health_mark)
