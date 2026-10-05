extends Control
## The lobby's room (lobby.gd) - option A of the lobby preview, FOUR SEATS: the
## code and the join link, one seat per `MAX_PARTY`, and START for the host.
## The Open Games preview added the host's two powers over who is in it:
##
## - **ROOM: PUBLIC / PRIVATE**, between START and LEAVE - whether the list can
##   let anybody in or wants the code. The host screen's choice, still open to
##   change while waiting, and saved as that choice.
## - **KICK** on every guest's seat. It asks once - KICK? on the seat and in
##   words under the row - and goes on a second press inside `ARM_SECONDS`;
##   the player is out, and online cannot come back to this room.
##
## A guest gets the cast instead: arrows on their own seat, which left and
## right on the keyboard press, step to the next character nobody else plays
## (net.gd's *Who plays whom*). A guest seated on a character they did not ask
## for, because somebody had it, is told so on the waiting line.
##
## Everything here is drawn from Net, every time; nothing is kept but which
## KICK is asking.

signal leave_requested

const Seat := preload("res://ui/lobby/seat.gd")
const Heads := preload("res://game/heads.gd")
const HostView := preload("res://ui/lobby/host_view.gd")

const COPIED_SECONDS := 1.5
## How long a KICK? waits for its second press.
const ARM_SECONDS := 3.0
const ACCENT := Color("6eb39d")
const MID := Color("e8b84a")
const WARM := Color("ec773d")
const DIM := Color("987a68")

@onready var _title: Label = %RoomTitle
@onready var _link: Label = %Link
@onready var _seats: HBoxContainer = %Seats
@onready var _relay_line: Label = %RelayLine
@onready var _wait_line: Label = %WaitLine
@onready var _start_button: Button = %StartButton
@onready var _public_button: Button = %PublicButton
@onready var _leave_button: Button = %LeaveButton
@onready var _hint: Label = %RoomHint

var _copied := 0.0
## The guest whose KICK is asking, and for how much longer.
var _asking := 0
var _asking_left := 0.0


func _ready() -> void:
	for i in Heads.MAX_PARTY:
		var seat := Seat.new()
		seat.name = "Seat%d" % (i + 1)
		seat.kick_pressed.connect(_on_kick)
		seat.choose_pressed.connect(_on_choose)
		_seats.add_child(seat)
	_start_button.pressed.connect(Net.start_run)
	_public_button.pressed.connect(_on_public)
	_leave_button.pressed.connect(leave_requested.emit)
	# A method, so the connection goes with this screen: Net outlives it.
	Net.roster_changed.connect(_on_roster_changed)


## The lobby has just put this screen up.
func shown() -> void:
	_asking = 0
	_copied = 0.0
	refresh()
	(_start_button if Net.is_host() else _leave_button).grab_focus()


func _process(delta: float) -> void:
	if _copied > 0.0:
		_copied = maxf(_copied - delta, 0.0)
		if _copied == 0.0:
			refresh()
	if _asking != 0:
		_asking_left -= delta
		if _asking_left <= 0.0:
			_asking = 0
			refresh()


## Left and right are a guest's arrows, taken before the focus can see them:
## a guest's room has nothing else to the side of LEAVE, so they would move
## nothing anyway.
func _input(event: InputEvent) -> void:
	if not visible or Net.state != Net.State.LOBBY or Net.is_host():
		return
	for step in [-1, 1]:
		if event.is_action_pressed("ui_left" if step < 0 else "ui_right"):
			get_viewport().set_input_as_handled()
			var seat := _my_seat()
			if seat != null and seat.arrow(step).visible:
				# Pressed rather than called, so the keyboard sounds like a click.
				seat.arrow(step).pressed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		UiSound.back()
		leave_requested.emit()
	elif event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).physical_keycode == KEY_C:
		get_viewport().set_input_as_handled()
		_copy_link()


func _on_roster_changed() -> void:
	if visible and Net.state != Net.State.OFFLINE:
		refresh()


## Everything in the room, drawn from Net.
func refresh() -> void:
	var rows := Net.roster()
	var me := Net.my_id()
	var host := Net.is_host()
	var code := Net.code()
	_title.text = "ROOM %s" % code if code != "" else "LOCAL GAME"
	var link := Net.join_link().trim_prefix("https://").trim_prefix("http://")
	if _copied > 0.0:
		_link.text = "JOIN LINK COPIED"
		_link.add_theme_color_override(&"font_color", ACCENT)
	else:
		_link.text = "JOIN LINK  %s   C COPY" % link if link != "" else ""
		_link.add_theme_color_override(&"font_color", DIM)
	var asking_name := ""
	var mine := {}
	for i in _seats.get_child_count():
		var seat: Seat = _seats.get_child(i)
		if i < rows.size():
			var peer := int(rows[i]["peer"])
			if peer == me:
				mine = rows[i]
			seat.show_row(rows[i], peer == me, host and peer != me, not host and peer == me)
			seat.arm(peer == _asking)
			if peer == _asking:
				asking_name = String(rows[i].get("name", "")).to_upper()
		else:
			seat.show_open()
	if _asking != 0 and asking_name == "":
		_asking = 0  # they left while being asked about

	if _asking != 0:
		_say(_relay_line, "PRESS AGAIN TO KICK %s - THEY CAN'T COME BACK TO THIS ROOM" % asking_name, WARM)
	else:
		_say(_relay_line, _relay_text(rows, me, host), MID)

	var taken := String(mine.get("taken", ""))
	if not host and taken != "":
		_say(_wait_line, "%s WAS TAKEN, SO YOU'RE %s - ARROWS TO CHANGE"
			% [Net.name_of(taken).to_upper(), String(mine.get("name", "")).to_upper()], MID)
	elif not host:
		var host_name := String(rows[0]["name"]).to_upper() if not rows.is_empty() else "THE HOST"
		_say(_wait_line, "WAITING FOR %s TO START" % host_name, ACCENT)
	elif code == "":
		_say(_wait_line, "START WHEN EVERYONE IS IN" if rows.size() == 1 else "", ACCENT)
	elif Net.is_public():
		_say(_wait_line, "PUBLIC - ANYONE IN THE LIST CAN JOIN UNTIL YOU START", ACCENT)
	else:
		_say(_wait_line, "PRIVATE - PLAYERS NEED YOUR CODE: %s" % code, MID)
	_start_button.visible = host
	# A local game is not in any list, so it has nothing to be public in.
	_public_button.visible = host and code != ""
	_public_button.text = "ROOM: PUBLIC" if Net.is_public() else "ROOM: PRIVATE"
	var keys: Array[String] = []
	if host:
		keys.append("ENTER START")
	elif String(mine.get("character", "")) != "":
		keys.append("ARROWS CHANGE CHARACTER")
	if link != "":
		keys.append("C COPY LINK")
	keys.append("ESC LEAVE")
	_hint.text = "    ".join(keys)


## Read by tests.
func seats() -> Array:
	return _seats.get_children()


func _my_seat() -> Seat:
	var me := Net.my_id()
	for seat: Seat in _seats.get_children():
		if seat.peer == me and seat.kind == "player":
			return seat
	return null


func _relay_text(rows: Array, me: int, host: bool) -> String:
	var relayed: Array = rows.filter(func(row: Dictionary) -> bool: return row.get("route") == "RELAY")
	var mine: Array = rows.filter(func(row: Dictionary) -> bool: return int(row["peer"]) == me)
	if host and relayed.size() == 1:
		return "! %s IS ON THE RELAY - EXPECT A HIGHER PING" % String(relayed[0]["name"]).to_upper()
	if host and relayed.size() > 1:
		return "! %d PLAYERS ARE ON THE RELAY - EXPECT HIGHER PINGS" % relayed.size()
	if not host and not mine.is_empty() and mine[0].get("route") == "RELAY":
		return "! CONNECTED THROUGH RELAY - EXPECT HIGHER PING"
	return ""


## First press asks, the second - while it is still asking - kicks.
func _on_kick(peer: int) -> void:
	if peer == _asking and _asking_left > 0.0:
		_asking = 0
		Net.kick(peer)
		_start_button.grab_focus()
	else:
		_asking = peer
		_asking_left = ARM_SECONDS
	refresh()


## A guest's arrow: the next character round the cast that nobody else plays,
## asked of the host, and kept as this player's pick the way the character
## select keeps one.
func _on_choose(step: int) -> void:
	var character := Net.next_free(step)
	if character == "":
		return
	Net.choose(character)
	Settings.set_value(&"player", &"character", character)


func _on_public() -> void:
	var public := not Net.is_public()
	Net.set_public(public)
	Settings.set_value(HostView.SETTINGS, HostView.PUBLIC_KEY, public)
	refresh()


func _copy_link() -> void:
	var link := Net.join_link()
	if link == "":
		return
	DisplayServer.clipboard_set(link)
	_copied = COPIED_SECONDS
	refresh()


static func _say(label: Label, text: String, colour: Color) -> void:
	label.text = text
	label.add_theme_color_override(&"font_color", colour)
