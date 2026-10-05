extends "res://tests/helpers.gd"
## The harness for a suite that is TWO machines (DESIGN.md's Multiplayer, M3):
## this process hosts, and a second Godot - tests/coop_guest.gd, started from
## here - joins over ENet on localhost through the real lobby and plays the same
## run. Two PROCESSES rather than test_net.gd's two SubViewports, because a run
## is the whole game: groups, the camera, the current scene and every
## `player`-group lookup in the world are one per process, and two games in one
## tree would see each other's bodies.
##
## Every check is made here. The guest is asked what its machine shows through
## the probe (tests/coop_probe.gd) and told what to press; both processes are
## held to the wall clock, so a second on one is a second on the other. What the
## guest prints comes back here under `guest|`, because nothing else would ever
## show its errors.
##
## A suite extends this, lists its steps in `_steps()` - each acting once and
## then giving a predicate a deadline, as in test_net.gd - and starts with
## `_open_room` and `_start`, which leave both machines in the game. Set
## `start_level` to begin the run on another floor: the host starts there, and
## the guest - which always loads the lobby - is welcomed to it and comes up.

const DEADLINE := 300
const LOBBY := "res://ui/lobby/lobby.tscn"
const GAME := "res://game/game.tscn"

## Each suite its own, so two of them never fight over one.
var port := 47941
## Where the run starts, or "" for the lobby.
var start_level := ""

var _probe: Node
var _pid := -1
var _io := {}
var _heard := ""
var _guest_id := 0
var _steps: Array[Callable] = []
var _at := 0
var _waiting := Callable()
var _label := ""
var _since := 0
var _deadline := DEADLINE
## The question being waited on, the last answer to it, and how to ask again.
var _asking := -1
var _ask_what := ""
var _ask_args := []
var _last: Variant = null


## The suite's steps, in order, after _open_room and _start.
func _plan() -> Array[Callable]:
	return []


## Steps in the lobby, between the guest joining and START - for a suite that
## needs the room arranged before the run begins.
func _in_lobby() -> Array[Callable]:
	return []


func _tick(frame: int) -> void:
	_hear_guest()
	if frame == 2:
		_probe = (load("res://tests/coop_probe.gd") as GDScript).new()
		_probe.name = "CoopProbe"
		root.add_child(_probe)
		_steps = [_open_room]
		_steps.append_array(_in_lobby())
		_steps.append(_start)
		_steps.append_array(_plan())
	if frame < 3:
		return
	if _waiting.is_valid():
		if _waiting.call():
			_check(_label, true)
			_waiting = Callable()
		elif frame - _since > _deadline:
			_check("%s (timed out; last answer %s)" % [_label, _last], false)
			_waiting = Callable()
		return
	if _at >= _steps.size():
		_wrap_up()
		return
	_since = frame
	_deadline = DEADLINE
	_steps[_at].call()
	_at += 1


func _wait(label: String, cond: Callable) -> void:
	_label = label
	_waiting = cond


## Ask the guest `what` until its answer satisfies `pred`, or the deadline.
## Asked again each time an answer comes back wrong, because what the guest
## shows catches up with what the host did a few frames later.
func _expect(label: String, what: String, args: Array, pred: Callable) -> void:
	_ask_what = what
	_ask_args = args
	_asking = _probe.call("ask", _guest_id, what, args)
	_wait(label, func() -> bool:
		var answers: Dictionary = _probe.get("answers")
		if not answers.has(_asking):
			return false
		_last = answers[_asking]
		if pred.call(_last):
			return true
		_asking = _probe.call("ask", _guest_id, _ask_what, _ask_args)
		return false)


## Tell the guest something and do not wait for it.
func _tell(what: String, args: Array = []) -> void:
	_probe.call("ask", _guest_id, what, args)


func _net() -> Node:
	return _autoload("Net")


## The guest's body, as this machine draws it.
func _second() -> Node2D:
	return current_scene.get_node_or_null("Player2") as Node2D


func _sync() -> Node:
	return current_scene.get_node_or_null("Sync")


func _wrap_up() -> void:
	_hear_guest()
	if _pid > 0 and OS.is_process_running(_pid):
		OS.kill(_pid)
	_net().call("leave")
	_finish()


## Whatever the guest has printed since the last frame, a whole line at a time.
## Read without blocking, and read every frame: a child whose pipe nobody
## empties stops dead when it fills.
func _hear_guest() -> void:
	for stream in ["stdio", "stderr"]:
		var pipe: FileAccess = _io.get(stream)
		if pipe == null:
			continue
		var chunk := pipe.get_buffer(65536)
		if not chunk.is_empty():
			_heard += chunk.get_string_from_utf8()
	while _heard.contains("\n"):
		var cut := _heard.find("\n")
		var line := _heard.left(cut).strip_edges(false, true)
		_heard = _heard.substr(cut + 1)
		if line.strip_edges() != "":
			print("  guest| ", line)


# --- in together ------------------------------------------------------------------


func _open_room() -> void:
	var err: int = _net().call("host_local", port, "reem")
	_check("host: a room on localhost (%s)" % error_string(err), err == OK)
	change_scene_to_file(LOBBY)
	_io = OS.execute_with_pipe(OS.get_executable_path(), ["--headless", "--path",
		ProjectSettings.globalize_path("res://"), "--fixed-fps", "60",
		"--script", "res://tests/coop_guest.gd", "--", "--coop-port=%d" % port], false)
	_pid = int(_io.get("pid", -1))
	_check("host: the guest's machine starts (pid %d)" % _pid, _pid > 0)
	_deadline = 900
	_wait("lobby: the guest joins and says hello", func() -> bool:
		var rows: Array = _net().call("roster")
		if rows.size() == 2 and rows[1].get("route") == "LAN":
			_guest_id = int(rows[1]["peer"])
			return true
		return false)


func _start() -> void:
	# Loaded here rather than preloaded: this file is compiled before the
	# autoloads exist, and game.gd names them.
	var game_script: GDScript = load("res://game/game.gd")
	game_script.next_start = start_level
	(current_scene.find_child("StartButton", true, false) as Button).pressed.emit()
	_deadline = 600
	_wait("start: both machines are in the game, and the guest's is up",
		func() -> bool:
			return current_scene != null and current_scene.scene_file_path == GAME \
				and _net().call("arrived_peers").has(_guest_id))


## Both on the host's floor, in the host's room - the first step of any suite
## that needs the guest to be looking at the same thing.
func _together() -> void:
	var room: int = _sync().get("room")
	var level := _level()
	_expect("guest: welcomed to the host's floor and room", "where", [],
		func(a: Array) -> bool:
			return a.size() == 4 and a[0] == GAME and a[1] == true and a[2] == room \
				and level != null and a[3] == String(level.name))
