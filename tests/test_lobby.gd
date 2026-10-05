extends "res://tests/helpers.gd"
## The way into online play through the real screens, as the Open Games
## preview drew them: the main menu's HOST ONLINE and JOIN ONLINE, the
## character select asking your name on the way, then the lobby's three
## screens - the list of games, the host screen and the room - up to START
## putting the party into the game.
##
## The lobby is a view of the `Net` autoload, so nothing here reaches the
## internet: the list of games is handed to Net's `rooms_listed` by the suite
## (helpers.gd holds the real ask off), a join from the list is caught before it
## leaves, and a room is hosted on ENet (`Net.host_local()`) with a guest
## joining from a Net of its own in a SubViewport - tests/test_net.gd's
## arrangement. What is checked is what the SCREENS do with what Net says.
##
## Driven by waits with deadlines, like test_net.gd, because a connection takes
## as long as it takes.

const PORT := 47921
const DEADLINE := 300
const NET := "res://autoload/net.gd"
const LOBBY := "res://ui/lobby/lobby.tscn"
const SELECT := "res://ui/character_select/character_select.tscn"
const MENU := "res://ui/main_menu/main_menu.tscn"
const GAME := "res://game/game.tscn"
const GameRow := preload("res://ui/lobby/game_row.gd")

var _guest: Node
var _guest_heard := {}
var _asked := []
var _steps: Array[Callable] = []
var _at := 0
var _waiting := Callable()
var _label := ""
var _since := 0


func _tick(frame: int) -> void:
	if frame == 2:
		_steps = [_menu, _select, _join_screen, _listed, _relisted, _private, _wrong_code,
			_refusals, _back_to_select, _back_to_menu, _host_route, _host_screen, _host_back,
			_host_again, _host_local, _hosted, _join,
			_seated, _kick_ask, _kick_go, _rejoin, _relay_and_link, _public_switch, _start,
			_in_game, _host_left_escape, _host_left_menu, _host_gone]
	if frame < 3:
		return
	if _waiting.is_valid():
		if _waiting.call():
			_check(_label, true)
			_waiting = Callable()
		elif frame - _since > DEADLINE:
			_check(_label + " (timed out)", false)
			_waiting = Callable()
		return
	if _at >= _steps.size():
		_finish()
		return
	_since = frame
	_steps[_at].call()
	_at += 1


func _wait(label: String, cond: Callable) -> void:
	_label = label
	_waiting = cond


func _on(path: String) -> Callable:
	return func() -> bool: return current_scene != null and current_scene.scene_file_path == path


func _net() -> Node:
	return _autoload("Net")


func _node(unique: String) -> Node:
	return current_scene.get_node("%" + unique)


func _text(unique: String) -> String:
	return (_node(unique) as Label).text


## A listing as the signaling service sends it, its zone relative to this
## machine's clock so the order does not depend on where the suite runs.
func _game(id: String, host: String, character: String, players: int, zone_off: int,
		status: String) -> Dictionary:
	return {"id": id, "host": host, "character": character, "players": players, "max": 4,
		"zone": int(_net().call("zone_minutes")) + zone_off, "status": status}


func _list() -> Array:
	return [
		_game("g_play", "Monaf", "monaf", 3, 0, "playing"),
		_game("g_far", "Hamza", "hamza", 1, -180, "open"),
		_game("g_priv", "Anas", "anas", 3, -60, "private"),
		_game("g_reem", "Reem", "reem", 2, 0, "open"),
		_game("g_full", "Ismeel", "ismeel", 4, -480, "full"),
		_game("g_omar", "Omar", "omar", 1, 30, "open"),
	]


func _rows() -> Array:
	return _node("Join").call("rows")


func _hosts() -> Array:
	return _rows().map(func(row) -> String: return row.room["host"])


func _focus() -> Control:
	return current_scene.get_viewport().gui_get_focus_owner()


# --- the way in -------------------------------------------------------------------


func _menu() -> void:
	var play := current_scene.get_node("%PlayButton") as Button
	var host := current_scene.get_node("%HostButton") as Button
	var join := current_scene.get_node("%JoinButton") as Button
	_check("menu: HOST ONLINE and JOIN ONLINE sit under PLAY",
		host.global_position.y > play.global_position.y
			and join.global_position.y > host.global_position.y)
	# Measured as test_menu.gd measures the select, by the column's own size -
	# a headless window is not 640x360, so positions would not say. Still five
	# buttons, paid for in gaps and not in height: no taller than the
	# four-button column it replaced (339).
	var need := (current_scene.get_node("CenterContainer/Menu") as Control).get_combined_minimum_size()
	_check("menu: five buttons in no more height than four took (%s)" % need,
		need.y <= 339.0)
	join.pressed.emit()
	_wait("menu: JOIN ONLINE opens the character select", _on(SELECT))


func _select() -> void:
	var name_edit := _node("NameEdit") as LineEdit
	_check("select: on the way online it asks your name (%s)" % name_edit.text,
		name_edit.visible and name_edit.text == "PLAYER")
	_check("select: and says where Enter goes (%s)" % _text("Hint"),
		_text("Hint") == "ARROWS SELECT   ENTER GO ONLINE   ESC BACK")
	name_edit.text = "Mayar"
	(current_scene.get_node("%Roster/reem") as Button).pressed.emit()
	_wait("select: picking somebody opens the list of games", _on(LOBBY))


func _join_screen() -> void:
	_check("join: the list is up, the host screen and the room are not",
		(_node("Join") as Control).visible and not (_node("Host") as Control).visible
			and not (_node("Room") as Control).visible)
	_check("join: the name typed on the way is kept",
		_autoload("Settings").call("get_value", &"online", &"name", "") == "Mayar")
	_check("join: before any answer it is looking (%s)" % _text("EmptyTitle"),
		_text("EmptyTitle") == "LOOKING FOR GAMES..." and (_node("EmptyTitle") as Control).visible)
	_check("join: with no games, BACK has the focus", (_node("JoinBack") as Button).has_focus())
	_check("join: a suite never asks the real service", _net().get("_browser") == null)
	_net().emit_signal("rooms_listed", _list())


func _listed() -> void:
	_check("list: open first, then private, full, playing - nearest time zone first (%s)" % [_hosts()],
		_hosts() == ["Reem", "Omar", "Hamza", "Anas", "Ismeel", "Monaf"])
	var rows := _rows()
	_check("list: every row says what it is",
		rows.map(func(row) -> String: return (row.get_node("Status") as Label).text)
			== ["OPEN", "OPEN", "OPEN", "PRIVATE", "FULL", "PLAYING"])
	_check("list: the first games to arrive take the focus from BACK",
		rows[0].has_focus())
	_check("list: the line says what Enter will do (%s)" % _text("ListLine"),
		_text("ListLine") == "REEM'S GAME HAS 2 FREE SEATS - ENTER TO JOIN")
	_check("list: what nobody can join cannot be pressed; a private game can",
		rows[4].disabled and rows[5].disabled and not rows[3].disabled and not rows[0].disabled)
	_check("list: the headers are up and the empty lines are not",
		(_node("ListHeaders") as Control).visible and not (_node("EmptyTitle") as Control).visible)
	_check("list: a time zone in the host's own clock's words",
		GameRow.zone_text(180) == "UTC+3" and GameRow.zone_text(-300) == "UTC-5"
			and GameRow.zone_text(330) == "UTC+5:30" and GameRow.zone_text(0) == "UTC")
	(rows[4] as Control).grab_focus()
	_check("list: a full game says why not (%s)" % _text("ListLine"),
		_text("ListLine") == "ISMEEL'S GAME IS FULL - IT OPENS AGAIN IF A SEAT FREES UP")
	(rows[5] as Control).grab_focus()
	_check("list: and so does a started one (%s)" % _text("ListLine"),
		_text("ListLine") == "MONAF'S RUN HAS STARTED - NOBODY CAN JOIN A RUN ONCE IT BEGINS")
	(rows[1] as Control).grab_focus()


## Every answer replaces the last whole, and the picked game stays picked.
func _relisted() -> void:
	var omar: Control = _rows()[1]
	var next := _list().filter(func(game) -> bool: return game["id"] != "g_reem")
	for game in next:
		if game["id"] == "g_omar":
			game["players"] = 2
	_net().emit_signal("rooms_listed", next)
	_check("relist: a game that went is gone (%s)" % [_hosts()], not _hosts().has("Reem"))
	_check("relist: the picked game is still picked, as the same row",
		omar.has_focus() and _rows()[0] == omar)
	_check("relist: and shows what changed (%s)" % (omar.get_node("Count") as Label).text,
		(omar.get_node("Count") as Label).text == "2/4")
	_net().emit_signal("rooms_listed", next.filter(func(game) -> bool: return game["id"] != "g_omar"))
	_check("relist: when the picked game goes, the focus goes where it was (%s)" % _focus().name,
		_rows()[0].has_focus() and _rows()[0].room["host"] == "Hamza")
	_net().emit_signal("rooms_listed", _list())


func _private() -> void:
	var anas: Control = _rows()[3]
	anas.grab_focus()
	_check("private: the line says it wants a code (%s)" % _text("ListLine"),
		_text("ListLine") == "ANAS' GAME IS PRIVATE - ENTER, THEN TYPE THE CODE THEY GAVE YOU")
	# The join is caught before it reaches Net: there is no service to ask.
	var join := _node("Join")
	join.disconnect("join_requested", Callable(current_scene, "_on_join_requested"))
	join.connect("join_requested", func(room_id: String, code: String) -> void:
		_asked.append([room_id, code]))
	(anas as Button).pressed.emit()
	var box: Control = join.call("code_box")
	_check("private: Enter opens the box for its code",
		box.visible and (box.get_node("Title") as Label).text == "ANAS' GAME IS PRIVATE"
			and (box.get_node("Code") as LineEdit).has_focus())
	var code := box.get_node("Code") as LineEdit
	code.text = "k7q"
	code.text_changed.emit("k7q")
	(box.get_node("Join") as Button).pressed.emit()
	_check("private: a short code is asked for again (%s)" % (box.get_node("Note") as Label).text,
		(box.get_node("Note") as Label).text == "TYPE THE 6-LETTER CODE" and _asked.is_empty())
	code.text = "k7q2px"
	code.text_changed.emit("k7q2px")
	_check("private: a code is shown in capitals (%s)" % code.text, code.text == "K7Q2PX")
	(box.get_node("Join") as Button).pressed.emit()
	_check("private: and goes with the game's id, never its name (%s)" % [_asked],
		_asked == [["g_priv", "K7Q2PX"]])
	_check("private: the box waits for the answer",
		(box.get_node("Join") as Button).disabled and not code.editable)


func _wrong_code() -> void:
	var box: Control = _node("Join").call("code_box")
	_net().emit_signal("failed", "wrong_code")
	_check("wrong code: the box stays up and says so (%s)" % (box.get_node("Note") as Label).text,
		box.visible and (box.get_node("Note") as Label).text == "THAT CODE IS NOT FOR THIS GAME"
			and not (box.get_node("Join") as Button).disabled)
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	_wait("wrong code: Escape closes the box, not the screen",
		func() -> bool: return (not box.visible and (_node("Join") as Control).visible
			and _focus() is GameRow))


func _refusals() -> void:
	_net().emit_signal("failed", "room_full")
	_check("refused: said in words on the line (%s)" % _text("ListLine"),
		_text("ListLine") == "THAT GAME IS FULL")
	_net().emit_signal("rooms_unreachable")
	_check("unreachable: the list goes and says why (%s)" % _text("EmptyTitle"),
		_rows().is_empty() and _text("EmptyTitle") == "CAN'T REACH THE SERVER"
			and (_node("JoinBack") as Button).has_focus())
	_net().emit_signal("rooms_listed", [])
	_check("empty: nobody is hosting (%s / %s)" % [_text("EmptyTitle"), _text("EmptyNote")],
		_text("EmptyTitle") == "NO GAMES RIGHT NOW" and _text("EmptyNote") == "HOST ONE FROM THE MAIN MENU"
			and _text("JoinHint") == "ESC BACK")


## One screen at a time: the join screen backs out to the character select
## that led to it, still on its way online, and only that goes home.
func _back_to_select() -> void:
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	_wait("join: Escape backs out to the character select, still on its way online",
		func() -> bool: return _on(SELECT).call() and (_node("NameEdit") as Control).visible)


func _back_to_menu() -> void:
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	_wait("select: and Escape from there is the main menu", _on(MENU))


func _host_route() -> void:
	(current_scene.get_node("%HostButton") as Button).pressed.emit()
	_wait("menu: HOST ONLINE opens the character select", _on(SELECT))


func _host_screen() -> void:
	(current_scene.get_node("%Roster/reem") as Button).pressed.emit()
	_wait("select: picking somebody opens the host screen", func() -> bool:
		return (_on(LOBBY).call() and (_node("Host") as Control).visible
			and not (_node("Join") as Control).visible))


func _host_back() -> void:
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	_wait("host: Escape backs out to the character select", _on(SELECT))


func _host_again() -> void:
	(current_scene.get_node("%Roster/reem") as Button).pressed.emit()
	_wait("select: and a pick from there is the HOST screen again, not the list",
		func() -> bool: return _on(LOBBY).call() and (_node("Host") as Control).visible)


func _host_local() -> void:
	var public := _node("PublicChoice") as Button
	var difficulty := _node("DifficultyChoice") as Button
	_check("host: public by default (%s), OPEN THE ROOM focused" % public.text,
		public.text == "ROOM: PUBLIC" and (_node("OpenButton") as Button).has_focus())
	_check("host: and says what that means (%s)" % _text("PublicLine"),
		_text("PublicLine") == "ANYONE CAN JOIN FROM THE LIST OF GAMES")
	public.pressed.emit()
	_check("host: private, remembered (%s / %s)" % [public.text, _text("PublicLine")],
		public.text == "ROOM: PRIVATE"
			and _text("PublicLine") == "IN THE LIST FOR ALL TO SEE - ONLY YOUR CODE GETS IN"
			and _autoload("Settings").call("get_value", &"online", &"public", true) == false)
	public.pressed.emit()
	_check("host: the difficulty is the saved one (%s)" % difficulty.text,
		difficulty.text == "DIFFICULTY: MEDIUM")
	difficulty.pressed.emit()
	_check("host: a press steps it round and saves it (%s)" % difficulty.text,
		difficulty.text == "DIFFICULTY: HARD"
			and _autoload("Settings").call("get_value", &"game", &"difficulty", "") == "hard")
	difficulty.pressed.emit()
	difficulty.pressed.emit()
	_check("host: and round again to MEDIUM (%s)" % difficulty.text, difficulty.text == "DIFFICULTY: MEDIUM")
	var err: int = _net().call("host_local", PORT, "Mayar", "reem")
	_check("host: the suite hosts on ENet the way OPEN THE ROOM would online (%s)" % error_string(err),
		err == OK)
	_wait("host: the lobby shows the room Net opened",
		func() -> bool: return (_node("Room") as Control).visible)


func _hosted() -> void:
	_check("room: a local game has no code to show (%s)" % _text("RoomTitle"),
		_text("RoomTitle") == "LOCAL GAME" and _text("Link") == "")
	var seats := _seats()
	_check("room: one seat per MAX_PARTY (%d)" % seats.size(), seats.size() == 4)
	_check("room: the host's own seat, theirs and marked HOST, with no KICK",
		seats[0].get("kind") == "player" and _seat_text(seats[0], "Name") == "MAYAR"
			and _seat_text(seats[0], "Line1") == "HOST" and not seats[0].call("kick_button").visible)
	_check("room: the rest are open",
		seats.slice(1).all(func(s) -> bool: return s.get("kind") == "open"))
	_check("room: alone, it says what to do (%s)" % _text("WaitLine"),
		_text("WaitLine") == "START WHEN EVERYONE IS IN")
	_check("room: START is the host's, and focused",
		(_node("StartButton") as Button).visible and (_node("StartButton") as Button).has_focus())
	_check("room: a local game is in no list, so it has no PUBLIC switch",
		not (_node("PublicButton") as Button).visible)
	_check("room: the keys a local host has (%s)" % _text("RoomHint"),
		_text("RoomHint") == "ENTER START    ESC LEAVE")


func _join() -> void:
	var view := SubViewport.new()
	view.name = "GuestView"
	root.add_child(view)
	set_multiplayer(SceneMultiplayer.new(), view.get_path())
	_guest = (load(NET) as GDScript).new()
	_guest.name = "Net"
	view.add_child(_guest)
	_guest.connect("run_started", func(rows: Array) -> void: _guest_heard["run_started"] = rows)
	_guest.connect("ended", func(reason: String) -> void: _guest_heard["ended"] = reason)
	_guest.connect("failed", func(reason: String) -> void: _guest_heard["failed"] = reason)
	_guest.call("join_local", "127.0.0.1", PORT, "Ivo", "anas")
	_wait("join: the guest takes the second seat",
		func() -> bool: return _seats()[1].get("kind") == "player")


func _seated() -> void:
	var seat: Node = _seats()[1]
	_check("seat: their name and their route (%s, %s)" % [_seat_text(seat, "Name"), _seat_text(seat, "Line2")],
		_seat_text(seat, "Name") == "IVO" and _seat_text(seat, "Line2") == "LAN")
	_check("seat: not this machine's, so it does not walk", seat.get("_mine") == false)
	_check("seat: the host gets KICK on a guest's seat (%s)" % seat.call("kick_button").text,
		seat.call("kick_button").visible and seat.call("kick_button").text == "KICK")
	_check("room: with company the waiting line goes", _text("WaitLine") == "")
	_wait("seat: the host's measured ping lands on the card",
		func() -> bool: return _seat_text(_seats()[1], "Line1").ends_with(" MS"))


func _kick_ask() -> void:
	var kick: Button = _seats()[1].call("kick_button")
	kick.pressed.emit()
	_check("kick: the first press only asks (%s)" % kick.text,
		kick.text == "KICK?" and (_net().call("roster") as Array).size() == 2)
	_check("kick: and says what the second will do (%s)" % _text("RelayLine"),
		_text("RelayLine") == "PRESS AGAIN TO KICK IVO - THEY CAN'T COME BACK TO THIS ROOM")


func _kick_go() -> void:
	(_seats()[1].call("kick_button") as Button).pressed.emit()
	_check("kick: the second press empties their seat",
		_seats()[1].get("kind") == "open" and (_net().call("roster") as Array).size() == 1)
	_check("kick: the asking line is gone (%s)" % _text("RelayLine"), _text("RelayLine") == "")
	_wait("kick: and they are told why",
		func() -> bool: return _guest_heard.get("failed") == "kicked")


## There is no signaling service on ENet to remember them by, so on a LAN they
## may come back; online the service refuses their address (its own suite).
func _rejoin() -> void:
	_guest.call("join_local", "127.0.0.1", PORT, "Ivo", "anas")
	_wait("kick: on a LAN they may come back to the second seat",
		func() -> bool: return _seats()[1].get("kind") == "player" and _seat_text(_seats()[1], "Line2") == "LAN")


func _relay_and_link() -> void:
	# Neither a relay nor a code exists on ENet, so both are told to the host's
	# Net directly: what is under test is what the screen does with them.
	var rows: Dictionary = _net().get("_rows")
	var guest_id: int = _guest.call("my_id")
	rows[guest_id]["route"] = "RELAY"
	_net().set("_code", "K7Q2PX")
	_net().emit_signal("roster_changed")
	_check("relay: the host is told who is on it (%s)" % _text("RelayLine"),
		_text("RelayLine") == "! IVO IS ON THE RELAY - EXPECT A HIGHER PING")
	_check("link: a room with a code shows it (%s)" % _text("RoomTitle"),
		_text("RoomTitle") == "ROOM K7Q2PX")
	_check("link: and its join link, with the key to copy it (%s)" % _text("Link"),
		_text("Link") == "JOIN LINK  dev.za-company.mayar-deeb.dev/#join=K7Q2PX   C COPY")
	_key(KEY_C, true)
	_key(KEY_C, false)
	_wait("link: C copies it, and says so",
		func() -> bool: return _text("Link") == "JOIN LINK COPIED")


func _public_switch() -> void:
	var public := _node("PublicButton") as Button
	_check("public: a room with a code has the switch, private as Net opened it (%s)" % public.text,
		public.visible and public.text == "ROOM: PRIVATE")
	_check("public: and says the code is the way in (%s)" % _text("WaitLine"),
		_text("WaitLine") == "PRIVATE - PLAYERS NEED YOUR CODE: K7Q2PX")
	public.pressed.emit()
	_check("public: a press opens it to the list (%s / %s)" % [public.text, _text("WaitLine")],
		_net().call("is_public") == true and public.text == "ROOM: PUBLIC"
			and _text("WaitLine") == "PUBLIC - ANYONE IN THE LIST CAN JOIN UNTIL YOU START"
			and _autoload("Settings").call("get_value", &"online", &"public", false) == true)


func _start() -> void:
	var rows: Dictionary = _net().get("_rows")
	rows[int(_guest.call("my_id"))]["route"] = "LAN"
	_net().set("_code", "")
	(_node("StartButton") as Button).pressed.emit()
	_wait("start: START puts this machine into the game", _on(GAME))


func _in_game() -> void:
	var party: Array = current_scene.call("party")
	_check("game: one body per member of the roster (%d)" % party.size(), party.size() == 2)
	_check("game: this machine's is the host, as the character it picked",
		_player().get("character") == "reem")
	var other := current_scene.get_node_or_null("Player2")
	_check("game: the guest's body, as their character, drawn where their machine says",
		other != null and other.get("character") == "anas" and other.get("remote") == true
			and other.get("peer") == int(_guest.call("my_id")))
	_check("game: this machine's own body is its own to move",
		_player().get("remote") == false and _player().get("peer") == 1)
	var hud_rows: Array = current_scene.get_node("HUD/Hud").call("party_rows")
	_check("game: the guest's HUD row carries the name they typed",
		hud_rows.size() == 1 and (hud_rows[0].get_node("Name") as Label).text == "Ivo")
	_check("game: the guest heard START too, with the same party",
		_guest_heard.get("run_started") is Array and (_guest_heard["run_started"] as Array).size() == 2)
	_check("game: the host's Net is in the run", _net().get("state") == 3)
	# The run ending under this machine - as it does for a guest whose host
	# goes - freezes the room under a panel saying so (M5's pick, option B),
	# naming whoever was hosting.
	_net().emit_signal("ended", "host_left")
	_wait("ended: the host leaving freezes the run under a panel saying so",
		func() -> bool:
			var panel := current_scene.get_node_or_null("HostLeft")
			return panel != null and panel.call("line") == "MAYAR'S GAME HAS ENDED" \
				and paused and panel.call("main_menu_button").has_focus())


## Escape has nothing to go back to: the panel stays, and the pause menu under
## it never hears the key.
func _host_left_escape() -> void:
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	_wait("ended: Escape does nothing to it, and opens no pause menu", func() -> bool:
		return _f - _since > 6 and current_scene.get_node_or_null("HostLeft") != null \
			and not _pause_menu().call("is_paused"))


func _host_left_menu() -> void:
	var panel := current_scene.get_node("HostLeft")
	(panel.call("main_menu_button") as Button).pressed.emit()
	_wait("ended: and its MAIN MENU is the way home, unpaused", func() -> bool:
		return _on(MENU).call() and not paused)


func _host_gone() -> void:
	_check("menu: arriving home left the party", _net().get("state") == 0)
	_wait("menu: and the guest was told the host left",
		func() -> bool: return _guest_heard.get("ended") == "host_left")


func _seats() -> Array:
	return _node("Room").call("seats")


func _seat_text(seat: Node, child: String) -> String:
	return (seat.get_node(child) as Label).text
