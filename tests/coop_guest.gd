extends SceneTree
## The second machine for tests/test_coop.gd: a whole Godot of its own, started
## by that suite and never on its own - which is why it is not in run_all.gd's
## list. It opens the lobby, joins the suite's party on localhost, and from
## there is only hands and eyes: everything it does, it is told to do through
## the probe (coop_probe.gd), and everything it sees, it is asked.
##
## It deliberately does not extend helpers.gd. Settings are the suite's to back
## up and restore; a second process doing the same would put the developer's
## file back while the suite was still running.
##
## Run by: <godot> --headless --path . --fixed-fps 60 --script res://tests/coop_guest.gd -- --coop-port=N

const PORT_ARG := "--coop-port="
## Never outlive the suite: a guest whose suite died stops on its own.
const LIFETIME_FRAMES := 60 * 180

var _f := 0
var _port := 0


func _initialize() -> void:
	ProjectSettings.set_setting("za/dev/level_select", false)
	# The lobby's list of games is never asked of the real service from a
	# suite (helpers.gd says why); this machine joins by address anyway.
	ProjectSettings.set_setting("za/test/no_room_list", true)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(PORT_ARG):
			_port = int(arg.trim_prefix(PORT_ARG))
	var probe: Node = (load("res://tests/coop_probe.gd") as GDScript).new()
	probe.name = "CoopProbe"
	root.add_child(probe)
	var lobby := (load("res://ui/lobby/lobby.tscn") as PackedScene).instantiate()
	root.add_child(lobby)
	current_scene = lobby


func _process(_delta: float) -> bool:
	_f += 1
	if _f == 2:
		root.get_node("/root/Net").call("join_local", "127.0.0.1", _port, "anas")
	if _f > LIFETIME_FRAMES:
		quit(1)
	return false
