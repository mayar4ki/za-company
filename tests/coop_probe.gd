extends Node
## The line between tests/test_coop.gd and the guest it starts (coop_guest.gd):
## the same node at /root/CoopProbe in both processes, so the suite can ASK the
## guest what its machine shows - where its body is, how much health it has, which
## floor it is on - and tell it what to press. Every check is the suite's; the
## guest only answers.
##
## It also holds both processes to the WALL CLOCK. A headless --fixed-fps run
## goes as fast as it can, and two of them would go at two different speeds
## while their messages cross in real time - so every frame here waits until
## its sixtieth of a second has really passed, and the two ends agree about
## how long anything took.

const STEP_MS := 1000.0 / 60.0

## Answers the guest has sent back, by question number. Read by the suite.
var answers := {}
var _asked := 0
var _since := 0
var _frames := 0
## Frames of attack-mashing left, on the guest - helpers.gd's rhythm.
var _mash := 0
## A trace being taken: a node in the room by its path, where it stood on each
## frame, and how many frames are left to take.
var _trace_path := ""
var _trace: Array = []
var _trace_left := 0
## A stall on the way: how many frames until it, and how long it holds this
## whole machine still - a lagging guest, as the host sees one.
var _stall_in := -1
var _stall_ms := 0
## Conversations this machine has begun since "watch_talks" - so a suite can
## see one that began and was closed again between two of its questions.
var _talks := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_since = Time.get_ticks_msec()


func _process(_delta: float) -> void:
	_frames += 1
	var due := _since + roundi(_frames * STEP_MS)
	var now := Time.get_ticks_msec()
	if due > now:
		OS.delay_msec(due - now)
	if _mash > 0:
		if _mash % 8 == 0:
			_press(KEY_SPACE, true)
		elif _mash % 8 == 4:
			_press(KEY_SPACE, false)
		_mash -= 1
	if _stall_in == 0:
		OS.delay_msec(_stall_ms)
		# Back on the wall clock from here, rather than racing to catch up
		# the frames the stall cost - a stalled machine resumes, it does not
		# fast-forward.
		_since = Time.get_ticks_msec()
		_frames = 0
	if _stall_in >= 0:
		_stall_in -= 1
	if _trace_left > 0:
		var level := _level(get_tree().current_scene)
		var node := level.get_node_or_null(NodePath(_trace_path)) as Node2D if level != null else null
		if node != null:
			_trace.append(node.global_position)
			_trace_left -= 1


## Ask the machine `peer` something; its answer lands in `answers` under the
## number this returns.
func ask(peer: int, what: String, args: Array = []) -> int:
	_asked += 1
	rpc_id(peer, &"_ask", _asked, what, args)
	return _asked


@rpc("any_peer", "call_remote", "reliable")
func _ask(id: int, what: String, args: Array) -> void:
	var value: Variant = _answer(what, args)
	rpc_id(multiplayer.get_remote_sender_id(), &"_told", id, value)
	if what == "quit":
		_leave_and_quit.call_deferred()


## Out of the party first, so the host hears the line go now rather than when
## ENet gives up on a silent peer - then a few frames for the word to get out.
func _leave_and_quit() -> void:
	get_tree().root.get_node("/root/Net").call("leave")
	for i in 10:
		await get_tree().process_frame
	get_tree().quit(0)


@rpc("any_peer", "call_remote", "reliable")
func _told(id: int, value: Variant) -> void:
	answers[id] = value


# --- the guest's side ------------------------------------------------------------


func _answer(what: String, args: Array) -> Variant:
	var game := get_tree().current_scene
	var sync: Node = game.get_node_or_null("Sync") if game != null else null
	match what:
		"where":
			var level := _level(game)
			return [game.scene_file_path if game != null else "",
				sync != null and bool(sync.get("welcomed")),
				int(sync.get("room")) if sync != null else -1,
				String(level.name) if level != null else ""]
		"body":
			var body := _body(sync, int(args[0]))
			if body == null:
				return []
			return [body.global_position, int(body.get("health")), body.call("is_down"),
				bool(body.get("remote")), float(body.get("slow_factor")),
				float(body.get("_grace")) > 0.0]
		"lives":
			return int(game.get("lives")) if game != null else -1
		"rows":
			var out := []
			if game != null:
				for row: Node in game.get_node("HUD/Hud").call("party_rows"):
					out.append((row.get_node("Name") as Label).text)
			return out
		"over":
			var menu := game.get_node_or_null("PauseMenu") if game != null else null
			if menu == null:
				return []
			return [menu.call("is_paused"), (menu.get_node("%Heading") as Label).text,
				get_tree().paused]
		"key":
			_press(int(args[0]), bool(args[1]))
			return true
		"mash":
			# Ends on a release, so the attack button is never left held.
			_mash = int(args[0]) / 8 * 8 + 1
			return true
		"enemies":
			# Every synced thing in the room: where it is and what it has left.
			var out := {}
			var level := _level(game)
			if level != null:
				for node in get_tree().get_nodes_in_group(&"synced"):
					if level.is_ancestor_of(node) and not node.is_queued_for_deletion():
						out[String(level.get_path_to(node))] = [
							(node as Node2D).global_position, node.get("health")]
			return out
		"get":
			# Properties of one node in the room, by its path there.
			var level := _level(game)
			var node := level.get_node_or_null(NodePath(String(args[0]))) if level != null else null
			if node == null:
				return null
			var values := []
			for prop in args[1]:
				values.append(node.get(String(prop)))
			return values
		"teleport":
			var mine := _body(sync, multiplayer.get_unique_id())
			if mine != null:
				mine.global_position = args[0]
			return mine != null
		"hurt_self":
			# The world on a guest reaches nobody: this is that rule, asked.
			var mine := _body(sync, multiplayer.get_unique_id())
			if mine == null:
				return -1
			mine.call("take_damage", int(args[0]))
			mine.call("drain", int(args[0]))
			mine.call("heal", int(args[0]))
			return int(mine.get("health"))
		"children":
			# How many children of a node in the room run one script.
			var level := _level(game)
			var node := level.get_node_or_null(NodePath(String(args[0]))) if level != null else null
			var count := 0
			if node != null:
				for child in node.get_children():
					var script: Script = child.get_script()
					if script != null and script.resource_path == String(args[1]):
						count += 1
			return count
		"boss_bar":
			var bar := game.get_node("HUD/Hud").get_node("%BossBar") as Control
			return [bar.visible, (bar.get_node("%BossName") as Label).text]
		"subtitle":
			var sub := game.get_node("Subtitle/BossSubtitle")
			return [sub.call("showing"), (sub.get_node("%Speaker") as Label).text,
				(sub.get_node("%Line") as Label).text]
		"shaking":
			return float(game.get("_shake_left"))
		"talking":
			return bool(game.get_node("Dialogue").call("talking")) if game != null else false
		"stop_talking":
			game.get_node("Dialogue").call("stop")
			return true
		"call":
			# A method on a node in the room, by its path there.
			var level := _level(game)
			var node := level.get_node_or_null(NodePath(String(args[0]))) if level != null else null
			if node == null:
				return false
			node.callv(String(args[1]), args[2])
			return true
		"trace":
			# Where a node in the room stands on each of the next N frames -
			# read back with "traced" once they are taken.
			_trace_path = String(args[0])
			_trace = []
			_trace_left = int(args[1])
			return true
		"traced":
			return _trace if _trace_left == 0 else []
		"count":
			# How many nodes run one script, under a body (by peer) or in the
			# room when the peer is 0.
			var under: Node = _level(game)
			if int(args[1]) != 0:
				under = _body(sync, int(args[1]))
			var count := 0
			if under != null:
				for node in under.find_children("*", "", true, false):
					var script: Script = node.get_script()
					if script != null and script.resource_path == String(args[0]):
						count += 1
			return count
		"plays":
			# How many times a body (by peer) has started one of its sounds.
			var body := _body(sync, int(args[0]))
			var audio := body.get_node_or_null("Audio") if body != null else null
			return int(audio.call("plays", String(args[1]))) if audio != null else -1
		"holds":
			# How many stops have held this machine's picture.
			var hold := game.get_node_or_null("PictureHold") if game != null else null
			return int(hold.get("held")) if hold != null else -1
		"screen":
			# The connection on this machine's screen: what the corner says,
			# the notice up top, whether the scoreboard is up, and every word
			# on it.
			if game == null or not game.has_method("scoreboard_up"):
				return []
			var hud := game.get_node("HUD/Hud")
			var words := []
			var layer := game.get_node_or_null("Scoreboard")
			if layer != null:
				for label in layer.find_children("*", "Label", true, false):
					if not label.is_queued_for_deletion():
						words.append((label as Label).text)
			return [hud.call("ping_text"), hud.call("notice_text"),
				game.call("scoreboard_up"), words]
		"stall":
			# This whole machine held still for args[0] ms, args[1] frames
			# from now: nothing sent, nothing heard, nothing drawn.
			_stall_ms = int(args[0])
			_stall_in = int(args[1])
			return true
		"watch_talks":
			var dialogue: Node = game.get_node("Dialogue")
			if not dialogue.is_connected(&"started", _on_talk_started):
				dialogue.connect(&"started", _on_talk_started)
			_talks = 0
			return true
		"talks":
			return _talks
		"hands":
			# This machine's own player: whether it is under a script, moving
			# under its own physics, down, and in the fight.
			var mine := _body(sync, multiplayer.get_unique_id())
			if mine == null:
				return []
			return [mine.call("scripted"), mine.is_physics_processing(), mine.call("is_down"),
				mine.is_in_group("player")]
		"revive":
			# A body's revive (by peer) as this machine knows it: how full,
			# whether it is filling, and how many rings are under the body.
			var body := _body(sync, int(args[0]))
			var revive: Node = game.get_node_or_null("Revive") if game != null else null
			if body == null or revive == null:
				return []
			var rings := 0
			for child in body.get_children():
				if child.is_in_group(&"revive_ring") and not child.is_queued_for_deletion():
					rings += 1
			return [float(revive.call("progress", body)), bool(revive.call("filling", body)), rings]
		"quit":
			return true
	return null


func _on_talk_started(_npc: Node) -> void:
	_talks += 1


func _press(code: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code as Key
	ev.keycode = code as Key
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _body(sync: Node, peer: int) -> Node2D:
	return sync.call("body_of", peer) if sync != null else null


func _level(game: Node) -> Node:
	if game == null:
		return null
	for child in game.get_children():
		if child is Node2D and child.has_method("spawn_position"):
			return child
	return null
