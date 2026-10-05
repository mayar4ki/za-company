extends "res://tests/coop.gd"
## Two machines in one run (DESIGN.md's Multiplayer, M5) - THE CONNECTION ON
## SCREEN, each piece as the Ping On Screen preview picked it. The harness is
## tests/coop.gd.
##
## - **The corner**: the host's says HOST, the guest's says its ping to the
##   host once one is measured.
## - **The relay line**: a guest who only got in through the relay is told so
##   across the top as the run starts, and nobody else is.
## - **The scoreboard**: up on either machine only while Tab is held, one row
##   per player with this machine's marked YOU, the host's saying HOST and the
##   relayed guest's saying RELAY.
## - **Somebody leaving**: the guest quitting is said across the top of the
##   host's screen, by the name their row called them.
##
## The host leaving cannot be asked of a guest whose line to the host just
## went, so its panel is test_lobby.gd's, on a run the host is told is over.
## ENet has no relay, so the guest is put on one in the lobby by telling the
## host's Net, the way test_lobby.gd does.

const RELAY_LINE := "! CONNECTED THROUGH RELAY - EXPECT HIGHER PING"


func _init() -> void:
	port = 48001


func _in_lobby() -> Array[Callable]:
	return [_onto_relay]


func _plan() -> Array[Callable]:
	return [_together, _relay_told, _corner_host, _corner_guest, _host_board,
		_host_board_down, _guest_board, _guest_board_down, _guest_leaves]


func _onto_relay() -> void:
	var rows: Dictionary = _net().get("_rows")
	rows[_guest_id]["route"] = "RELAY"
	_net().call("_broadcast")
	_check("lobby: the guest is on the relay", rows[_guest_id]["route"] == "RELAY")


func _hud() -> Node:
	return current_scene.get_node("HUD/Hud")


## The scoreboard's words on this machine.
func _board_words() -> Array:
	var words := []
	for label in current_scene.get_node("Scoreboard").find_children("*", "Label", true, false):
		if not label.is_queued_for_deletion():
			words.append((label as Label).text)
	return words


func _relay_told() -> void:
	_expect("relay: the guest is told it came in through the relay", "screen", [],
		func(a: Array) -> bool: return a.size() == 4 and a[1] == RELAY_LINE)
	_check("relay: and the host, which is direct to itself, is told nothing",
		_hud().call("notice_text") == "")


func _corner_host() -> void:
	_check("corner: the host's says HOST (%s)" % _hud().call("ping_text"),
		_hud().call("ping_text") == "HOST")


func _corner_guest() -> void:
	_deadline = 400
	_expect("corner: the guest's says its ping to the host, once measured", "screen", [],
		func(a: Array) -> bool:
			return a.size() == 4 and String(a[0]).ends_with(" MS") \
				and String(a[0]).trim_suffix(" MS").is_valid_int())


func _host_board() -> void:
	_check("board: down until Tab is held", current_scene.call("scoreboard_up") == false)
	_key(KEY_TAB, true)
	_wait("board: up on the host while Tab is held", func() -> bool:
		return current_scene.call("scoreboard_up") == true and _f - _since > 2)


func _host_board_down() -> void:
	var words := _board_words()
	_check("board: a row for each of the party, by name - their characters' (%s)" % [words],
		words.has("REEM") and words.has("ANAS"))
	_check("board: this machine's row marked YOU, and only it",
		words.count("YOU") == 1 and words.find("YOU") == words.find("REEM") + 1)
	_check("board: the host's row says HOST, the relayed guest's RELAY",
		words.has("HOST") and words.has("RELAY"))
	_key(KEY_TAB, false)
	_wait("board: and down again when Tab is let go", func() -> bool:
		return current_scene.call("scoreboard_up") == false)


func _guest_board() -> void:
	_tell("key", [KEY_TAB, true])
	_expect("board: up on the guest while ITS Tab is held, with its own row YOU",
		"screen", [], func(a: Array) -> bool:
			var seen: Array = a[3] if a.size() == 4 else []
			return a.size() == 4 and a[2] == true and seen.count("YOU") == 1 \
				and seen.find("YOU") == seen.find("ANAS") + 1 and seen.has("REEM"))
	_check("board: the guest's Tab is not the host's", current_scene.call("scoreboard_up") == false)


func _guest_board_down() -> void:
	_tell("key", [KEY_TAB, false])
	_expect("board: and down there when it is let go", "screen", [],
		func(a: Array) -> bool: return a.size() == 4 and a[2] == false)


func _guest_leaves() -> void:
	_tell("quit")
	_deadline = 600
	_wait("left: the guest quitting is said across the host's screen",
		func() -> bool: return _hud().call("notice_text") == "ANAS LEFT THE GAME")
