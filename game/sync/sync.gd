extends Node
## The run, kept in step across machines (DESIGN.md's Multiplayer, M3) - the
## half of online play that lives in the game, where `Net` is the half that
## owns the wire. game.gd builds one of these as `Sync` on every machine, so it
## sits at the same path everywhere and the two ends can call each other; it
## does nothing at all offline, which is every solo run and every suite but
## the online ones.
##
## ## The host is the truth, for everything but where a body is
##
## Each machine moves its own player and says where it is (Bodies, below). The
## HOST decides everything else - what hurts, what heals, who is down, how many
## lives are left, when the party goes through a door and where it lands - and
## tells the guests, who draw it. A guest's world is the same scene running the
## same code, and is kept harmless by one rule in player.gd: on a guest, the
## world reaches nobody (`_world_reaches()`). What the host decided arrives here.
##
## ## The room
##
## Every arrival is a new ROOM, counted by the host and carried on everything
## that is only true in one of them. A message from the room before - a body's
## last step on its way through the door - is dropped rather than drawn in the
## room after, where it would stand somebody in the wrong place.
##
## ## When to speak
##
## Two machines load a scene at their own speed, and a call to a node that is
## not there yet is lost. So the host speaks to a guest's game only once that
## guest has said it is up (`Net.arrived()`), and opens with a WELCOME holding
## everything it missed: the room, the floor, the lives, every body's health
## and who is down. A guest speaks to the host only once welcomed.
##
## ## One clock, the host's, a tenth of a second ago
##
## Everything the host says is stamped with the HOST's time (M4), and a guest
## reads that clock through game/sync/clock.gd. What is DRAWN - the room's
## bodies, everybody else's player - is drawn `DELAY` behind it, gliding
## between the states either side of that moment (game/sync/timeline.gd)
## rather than stepping twenty or thirty times a second. And what the host
## says ABOUT the room is played at the same moment of the same clock
## (`later()`): a blow on this machine's player, its health, a body going down,
## a boss's line - so the number comes up as the drawn sword lands, not a tenth
## of a second before it. Only arriving somewhere is not on the clock: the
## welcome and the order to travel are acted on when heard, and the order to
## travel plays out everything still waiting first.
##
## What is DECIDED is never late: the host decides on the newest word it has,
## and each machine moves its own player at once. Only pictures wait.

const Bodies := preload("res://game/sync/bodies.gd")
const World := preload("res://game/sync/world.gd")
const Talk := preload("res://game/sync/talk.gd")
const Clock := preload("res://game/sync/clock.gd")
const PlayerType := preload("res://game/player/player.gd")

## How far behind the host's word a picture is drawn, in seconds. Two
## snapshots' worth, so there is nearly always a state on both sides of the
## moment being drawn, with room for one to arrive late or not at all.
const DELAY := 0.1

## Whether this run is an online one. Decided once, when the scene is built:
## a run never goes online or offline in the middle.
var active := false
## The host's count of arrivals - see the header. 0 on a guest until welcomed.
var room := 0
## A guest, once the host has welcomed it - the only time it may speak.
var welcomed := false

## Untyped: game.gd preloads this file, so this one cannot preload it back.
var _game
var _bodies: Bodies
var _world: World
var _talk: Talk
## Where the host is now, for whoever arrives late - and where it is going,
## between ordering a door and arriving, so a guest who turns up in that gap
## is welcomed to the floor everybody else is about to be on.
var _level_path := ""
var _spawn: StringName = &"start"
var _heading_to := []
## A guest's reading of the host's clock; the host's of each guest's, which it
## turns their stamps into its own time with.
var _host_clock := Clock.new()
var _guest_clocks := {}
## What the host said, waiting for the picture to reach it: [stamp, call],
## oldest first. A guest's only - see the header.
var _waiting: Array = []
var _drawn_frame := -1
var _drawn_at := 0.0


func _ready() -> void:
	_game = get_parent()
	active = Net.state == Net.State.IN_RUN
	_bodies = Bodies.new()
	_bodies.name = "Bodies"
	add_child(_bodies)
	_world = World.new()
	_world.name = "World"
	add_child(_world)
	_talk = Talk.new()
	_talk.name = "Talk"
	add_child(_talk)
	if not active:
		return
	if is_host():
		Net.peer_arrived.connect(_on_peer_arrived)
		Net.peer_left.connect(_on_peer_left)


## game.gd, once the party is spawned and the first floor is in: from here
## both ends exist, so a guest says so and the host greets anybody already up.
func begin(party: Array) -> void:
	_bodies.track(party)
	if not active:
		return
	if is_host():
		for id in Net.arrived_peers():
			_on_peer_arrived(id)
	else:
		Net.arrived()


func is_host() -> bool:
	return not active or multiplayer.is_server()


## Everybody whose game is up, but the host - the only ones worth calling.
func guests() -> Array[int]:
	return Net.arrived_peers() if active and multiplayer.is_server() else [] as Array[int]


## A call to every guest whose game is up, by name - on this node, or `on`.
func to_guests(method: StringName, args: Array = [], on: Node = null) -> void:
	var node := on if on != null else self
	for id in guests():
		node.callv(&"rpc_id", [id, method] + args)


## The floor this machine is standing in, or null mid-swap.
func level() -> Node:
	return _game.current_level()


# --- the clock ---------------------------------------------------------------------


## The host's time, as this machine reads it - see the header. Its own clock on
## the host and offline.
func now() -> float:
	if active and not is_host():
		return _host_clock.there()
	return Clock.local()


## The moment the picture is showing: `DELAY` behind the host's word. Read once
## per physics frame, so everything drawn on one frame is drawn at one moment.
func drawn() -> float:
	var frame := Engine.get_physics_frames()
	if frame != _drawn_frame:
		_drawn_frame = frame
		_drawn_at = now() - DELAY
	return _drawn_at


## A guest heard something the host stamped.
func heard(stamp: float) -> void:
	if active and not is_host():
		_host_clock.heard(stamp)


## The host: `stamp` on guest `peer`'s clock, as the host's own time.
func from_guest(peer: int, stamp: float) -> float:
	var clock: Clock = _guest_clocks.get(peer)
	if clock == null:
		clock = Clock.new()
		_guest_clocks[peer] = clock
	clock.heard(stamp)
	return clock.here(stamp)


## Something the host said at `stamp`, done when the picture gets there - at
## once on the host, whose picture is its own word.
func later(stamp: float, call: Callable) -> void:
	if not active or is_host():
		call.call()
		return
	heard(stamp)
	var i := _waiting.size()
	while i > 0 and float(_waiting[i - 1][0]) > stamp:
		i -= 1
	_waiting.insert(i, [stamp, call])


## Everything still waiting, done now - the room is about to change.
func flush() -> void:
	var due := _waiting
	_waiting = []
	for item in due:
		(item[1] as Callable).call()


## Before Bodies and World, which are children and run after: what the host said
## lands on the frame before the picture of the same moment is drawn.
func _physics_process(_delta: float) -> void:
	if _waiting.is_empty():
		return
	var at := drawn()
	while not _waiting.is_empty() and float(_waiting[0][0]) <= at:
		var item: Array = _waiting.pop_front()
		(item[1] as Callable).call()


func body_of(peer: int) -> PlayerType:
	return _bodies.body_of(peer)


## Talking, which game/sync/talk.gd keeps in step: a conversation on this
## machine began or ended, and a line of it was shown.
func talk_began(npc: Node) -> void:
	_talk.began(npc)


func talk_ended(npc: Node) -> void:
	_talk.ended(npc)


func spoke(speaker: String, text: String) -> void:
	_talk.spoke(speaker, text)


# --- what the host tells everybody ------------------------------------------------


## The host is leaving for another floor: so is everybody, together.
func travelling(level_path: String, spawn: StringName) -> void:
	if active and is_host():
		_heading_to = [room + 1, level_path, spawn]
		to_guests(&"_travel", _heading_to)


## A floor is in. The host counts it; a guest takes the host's count, which it
## was handed with the order to come.
func entered(level_path: String, spawn: StringName, as_room := 0) -> void:
	_level_path = level_path
	_spawn = spawn
	_heading_to = []
	room = room + 1 if is_host() else as_room
	# The last room's pictures are not this one's.
	_world.forget()
	_bodies.new_room()


func lives_changed(lives: int) -> void:
	if active and is_host():
		to_guests(&"_lives", [now(), lives])


func went_down(body: PlayerType) -> void:
	if active and is_host():
		to_guests(&"_down", [now(), body.peer])


func stood_up(body: PlayerType, at: Vector2) -> void:
	if active and is_host():
		to_guests(&"_up", [now(), body.peer, at])


## A revive started or stopped filling on the host, or lost a second to a blow
## (game/revive.gd): how full it is now, and whether it is filling. A guest
## fills or empties its own copy between two of these.
func revive_changed(body: PlayerType, progress: float, filling: bool, lost: bool) -> void:
	if active and is_host():
		to_guests(&"_revive", [now(), body.peer, progress, filling, lost])


## Up where it lay, from a revive, turned towards `toward`.
func revived(body: PlayerType, toward: Vector2) -> void:
	if active and is_host():
		to_guests(&"_revived", [now(), body.peer, toward])


func over() -> void:
	if active and is_host():
		to_guests(&"_over", [now()])


# --- the host's side -----------------------------------------------------------


func _on_peer_arrived(id: int) -> void:
	# Not before this end is built: begin() greets everybody already up.
	if _level_path == "":
		return
	var downs: Array[int] = []
	var health := {}
	for body: PlayerType in _game.party():
		health[body.peer] = body.health
		if body.is_down():
			downs.append(body.peer)
	var where := _heading_to if not _heading_to.is_empty() else [room, _level_path, _spawn]
	rpc_id(id, &"_welcome", where[0], where[1], where[2], _game.lives, health, downs)


## A guest gone, mid-run: their body goes with them, and so does their place
## at every door - the pool is untouched (DESIGN.md's *Rules that keep it
## honest*).
func _on_peer_left(id: int) -> void:
	_guest_clocks.erase(id)
	var body := body_of(id)
	if body == null:
		return
	_bodies.forget(id)
	_game.net_left(body)
	to_guests(&"_left", [id])


# --- what a guest hears ----------------------------------------------------------


@rpc("authority", "call_remote", "reliable")
func _welcome(host_room: int, level_path: String, spawn: StringName, lives: int,
		health: Dictionary, downs: Array) -> void:
	for id in health:
		var body := body_of(int(id))
		if body != null:
			body.net_health(int(health[id]))
	for id in downs:
		var body := body_of(int(id))
		if body != null and not body.is_down():
			_game.net_down(body)
	_game.net_lives(lives)
	if level_path != _level_path:
		_game.net_travel(level_path, spawn, host_room)
	else:
		room = host_room
	welcomed = true


## Acted on when heard, and only once everything the host said before it is
## done: a body that went down on the way to the door went down first.
@rpc("authority", "call_remote", "reliable")
func _travel(host_room: int, level_path: String, spawn: StringName) -> void:
	flush()
	_game.net_travel(level_path, spawn, host_room)


@rpc("authority", "call_remote", "reliable")
func _lives(stamp: float, lives: int) -> void:
	later(stamp, _game.net_lives.bind(lives))


@rpc("authority", "call_remote", "reliable")
func _down(stamp: float, peer: int) -> void:
	later(stamp, _down_now.bind(peer))


func _down_now(peer: int) -> void:
	var body := body_of(peer)
	if body != null:
		_game.net_down(body)


@rpc("authority", "call_remote", "reliable")
func _up(stamp: float, peer: int, at: Vector2) -> void:
	later(stamp, _up_now.bind(peer, at))


func _up_now(peer: int, at: Vector2) -> void:
	var body := body_of(peer)
	if body != null:
		_game.net_up(body, at)


@rpc("authority", "call_remote", "reliable")
func _revive(stamp: float, peer: int, progress: float, filling: bool, lost: bool) -> void:
	later(stamp, func() -> void:
		var body := body_of(peer)
		if body != null:
			_game.net_revive(body, progress, filling, lost))


@rpc("authority", "call_remote", "reliable")
func _revived(stamp: float, peer: int, toward: Vector2) -> void:
	later(stamp, func() -> void:
		var body := body_of(peer)
		if body != null:
			_game.net_revived(body, toward))


@rpc("authority", "call_remote", "reliable")
func _over(stamp: float) -> void:
	later(stamp, _game.net_over)


@rpc("authority", "call_remote", "reliable")
func _left(peer: int) -> void:
	var body := body_of(peer)
	if body == null:
		return
	_bodies.forget(peer)
	_game.net_left(body)
