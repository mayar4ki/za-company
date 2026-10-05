extends Control
## Online play's front door (DESIGN.md's Multiplayer), as the Open Games preview
## drew it: three screens on one scene, each a script of its own.
##
## - **Join a game** (join_view.gd): the list of games and nothing else.
## - **Host a game** (host_view.gd): who can join, the difficulty, OPEN THE ROOM.
## - **The room** (room_view.gd): the four seats, START, the host's PUBLIC /
##   PRIVATE switch and KICK.
##
## The main menu's JOIN ONLINE and HOST ONLINE say which screen opens first
## (opening.gd), and the character select on the way asked who to play - which
## is also who you are called, since nobody types a name (net.gd's *Who plays
## whom*). This file only ROUTES: which screen is up, what a refusal says and on
## which screen, and START turning the party into a run. Like every screen
## here it is a view of the `Net` autoload and keeps no party state, which is
## what lets a suite host through `Net.host_local()` and find the room already
## up when this scene opens.
##
## On the web the ADDRESS is the way in from a phone: `#join=CODE` (and `&relay`
## after it to force the relay, for testing) joins that room on arrival, as
## the character last picked, once per page load.

const MENU_SCENE := "res://ui/main_menu/main_menu.tscn"
const SELECT_SCENE := "res://ui/character_select/character_select.tscn"
const GAME_SCENE := "res://game/game.tscn"
const GameType := preload("res://game/game.gd")
const Opening := preload("res://ui/lobby/opening.gd")
const CharacterSelect := preload("res://ui/character_select/character_select.gd")
const Roster := preload("res://game/player/characters/roster.gd")

## What a refusal says to a player, by Net's reason code.
const REASONS := {
	"no_server": "CAN'T REACH THE SERVER - CHECK YOUR CONNECTION",
	"no_such_room": "THAT GAME IS GONE - IT CLOSED, OR THE CODE IS WRONG",
	"wrong_code": "THAT CODE IS NOT FOR THIS GAME",
	"room_full": "THAT GAME IS FULL",
	"started": "THAT RUN HAS ALREADY STARTED",
	"version": "THAT GAME IS ON ANOTHER VERSION",
	"kicked": "THE HOST REMOVED YOU FROM THAT GAME",
	"unreachable": "COULD NOT CONNECT",
	"no_route": "COULD NOT CONNECT, EVEN THROUGH THE RELAY",
	"host_left": "THE HOST LEFT",
	"server_full": "THE SERVER IS FULL - TRY AGAIN SOON",
	"too_many_rooms": "TOO MANY GAMES ARE OPEN FROM YOUR NETWORK",
}

## The join link is used once per page load, so leaving a room it opened and
## coming back to the lobby does not join it all over again.
static var _link_spent := false

@onready var _join: Control = %Join
@onready var _host: Control = %Host
@onready var _room: Control = %Room

## Whether this machine went in as the host. Net has forgotten by the time a
## refusal says why, and it decides which screen the refusal is said on.
var _hosting := false
## Whether the page's join link brought this machine here, past the character
## select - so there is no select behind it to go back to.
var _by_link := false


func _ready() -> void:
	Music.play(Music.MENU)
	_join.connect("join_requested", _on_join_requested)
	_join.connect("back_requested", _back.bind(Opening.View.JOIN))
	_host.connect("open_requested", _on_open_requested)
	_host.connect("back_requested", _back.bind(Opening.View.HOST))
	_room.connect("leave_requested", _on_leave)
	# Methods rather than lambdas: a connection to a method is dropped when this
	# screen is freed, and Net outlives every screen.
	Net.hosted.connect(_on_in_room)
	Net.joined.connect(_on_in_room)
	Net.failed.connect(_on_refused)
	Net.ended.connect(_on_refused)
	Net.run_started.connect(_on_run_started)

	var link := {} if _link_spent else _link_args()
	var view := Opening.take()
	if Net.state == Net.State.LOBBY:
		_hosting = Net.is_host()
		_show(_room)
	elif link.has("join"):
		_link_spent = true
		_by_link = true
		_show(_join)
		_join.call("joining", String(link["join"]))
		Net.join(String(link["join"]), _character(), bool(link.get("relay", false)))
	elif view == Opening.View.HOST:
		_show(_host)
	else:
		_show(_join)


func _exit_tree() -> void:
	Net.stop_browsing()


## One screen up and the rest down. The list is asked for only while it is
## the screen showing.
func _show(view: Control) -> void:
	for each: Control in [_join, _host, _room]:
		each.visible = each == view
	if view == _join:
		Net.browse()
	else:
		Net.stop_browsing()
	view.call("shown")


func _on_join_requested(room_id: String, code: String) -> void:
	_hosting = false
	Net.join_listed(room_id, code, _character())


func _on_open_requested(public: bool) -> void:
	_hosting = true
	Net.host(_character(), public)


func _on_in_room(_code := "") -> void:
	_hosting = Net.is_host()
	_show(_room)


## Out of the room, back to the screen that led into it.
func _on_leave() -> void:
	Net.leave()
	_show(_host if _hosting else _join)


func _on_refused(reason: String) -> void:
	var message := String(REASONS.get(reason, "THE SERVER SAID NO (%s)" % reason))
	if _hosting:
		if not _host.visible:
			_show(_host)
		_host.call("say", message)
	else:
		if not _join.visible:
			_show(_join)
		_join.call("refused", reason, message)


## One screen back, which is the character select that led here - set to come
## back to this same screen, so BACK and a pick undo each other. Only a page
## opened by a join link has no select behind it, and goes home instead.
func _back(view: Opening.View) -> void:
	Net.leave()
	if _by_link:
		get_tree().change_scene_to_file(MENU_SCENE)
		return
	Opening.view = view
	CharacterSelect.next_scene = scene_file_path
	get_tree().change_scene_to_file(SELECT_SCENE)


## Everybody into the run, in the roster's order, which is the same order on
## every machine. This machine's member is marked `local` and drives its body
## from the keyboard; everybody else's body carries its owner's `peer`, and is
## drawn wherever that machine says it is (game.gd's header, *Online*).
func _on_run_started(rows: Array) -> void:
	var me := Net.my_id()
	var party := []
	for row: Dictionary in rows:
		party.append({"character": String(row.get("character", "")),
			"name": String(row.get("name", "")), "peer": int(row["peer"]),
			"local": int(row["peer"]) == me})
	GameType.next_party = party
	get_tree().change_scene_to_file(GAME_SCENE)


func _character() -> String:
	return String(Settings.get_value(&"player", &"character", Roster.DEFAULT_ID))


## A page has no command line, so on the web the address is one:
## `#join=K7Q2PX` joins that room, and `&relay` after it forces the relay.
static func _link_args() -> Dictionary:
	var out := {}
	if not OS.has_feature("web"):
		return out
	var hash := String(JavaScriptBridge.eval("window.location.hash", true))
	for part in hash.trim_prefix("#").split("&", false):
		if part.begins_with("join="):
			out["join"] = part.substr(5).strip_edges().to_upper()
		elif part == "relay":
			out["relay"] = true
	return out
