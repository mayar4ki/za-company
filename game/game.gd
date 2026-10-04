extends Node2D
## Gameplay host. Owns the party, the camera, the HUD and the pause menu, and
## swaps one Level child in and out beneath them.
##
## The party's bodies are never re-instantiated, so anything they accumulate -
## facing, health - survives a door transition for free, and the pause menu is
## not duplicated per map.
##
## Escape is handled by the PauseMenu child, which pauses the tree instead of
## leaving the scene. Leaving for the main menu is one of its options.
##
## ## The party
##
## One body per member, spawned here from `next_party` - and when nothing has
## said otherwise that is ONE member, the saved pick on the keyboard, which is
## every solo run (DESIGN.md's Multiplayer, M1). The first member is THIS
## machine's: the camera follows them and the HUD's big bar is theirs, while
## the rest get a row each under the hearts. Solo is a party of one and plays
## exactly as it did when this scene owned a single `$Player`:
##
## - **Lives are one pool**, `lives`, held here because they are nobody's own.
## - **A death alone** fades the room and puts the body back at the door, as it
##   always has. **A death in company** is no reason to stop anybody else's
##   game: the body goes DOWN where it fell (player.gd's knock_down), the pool
##   pays a life, and it gets up at the door `GET_UP_SECONDS` later. With the
##   pool empty it stays down, and the run ends when nobody is standing.
## - **A door waits for everyone standing** (door_base.gd) and carries the rest
##   through: whoever was waiting to get up gets up on the far side.
## - **The room alert is anyone's**: the first of them to walk out of the
##   doorway wakes the room for all of them.
## - **Down is a seat in the stands**: while this machine's player is down the
##   camera follows somebody still standing, and the attack button moves it on
##   to the next (_watch).
## - **Anyone down can be revived** where they lie, by a teammate holding
##   interact over them for a few seconds - as often as it takes, and the pool
##   never hears of it (game/revive.gd).
##
## ## Online
##
## Every machine runs this same scene, and one of them - the host - decides
## (DESIGN.md's Multiplayer, M3). A member with a `peer` that is not this
## machine's is REMOTE: its body is drawn where its owner says (player.gd's
## `remote`). Deaths, lives, getting up, the doors and the end of the run are
## the host's alone; a guest hears them from `Sync` (game/sync/) through the
## `net_*` functions at the bottom of this file, and runs exactly what the host
## ran. Offline `Sync` is inert and none of that happens.

const START_LEVEL := "res://game/levels/lobby/lobby.tscn"
const MENU_SCENE := "res://ui/main_menu/main_menu.tscn"
## Where the NEXT run starts instead, when the development level select
## (ui/level_select/) has just named a floor. Spent on use, so the run after it
## starts in the lobby again unless the screen is passed through a second time.
static var next_start := ""
## Who plays the NEXT run: one Dictionary per member, in party order, each with
## an optional `character` (a roster id; empty is the saved pick), `input` (an
## input_source.gd; the keyboard by default), `name` (what the HUD calls them)
## and `local` (this machine's member - the first, when none says so). Empty is
## a party of one. Spent on use like `next_start`, and capped at
## Heads.MAX_PARTY. ui/lobby/ fills it from Net's roster when a host starts.
static var next_party: Array = []
const FADE_SECONDS := 0.28
## The party's lives, ONE pool however many are playing.
const MAX_LIVES := 3
## How long a body that went down in company lies there before it gets up at
## the door. Long enough to be a cost - the room carries on without you - and
## short enough that nobody puts the controller down.
const GET_UP_SECONDS := 3.0
## How far apart the party is stood when a door or a spawn puts them down, in a
## row across the marker. Wider than two bodies (10 px) so nobody arrives
## standing in anybody, and narrow enough that four of them (36 px) stay inside
## the 54 px walk every floor keeps clear.
const PARTY_SPACING := 12.0
## How far from where they came in the player may stand before the room knows
## they are there - see _alert_room(). Three tiles, measured from the spot the
## door put them on rather than from the door itself, because every spawn marker
## stands three and a half tiles or more inside its threshold. The doorway is
## the one safe place in a room: walking from door to door is walking INTO it.
const ALERT_RADIUS := 3 * 16.0

## Typed by preloaded script rather than by the `class_name` those scripts also
## declare: global class names come from a cache the editor writes, which a
## fresh checkout running headless does not have yet.
const LevelType := preload("res://game/levels/level.gd")
const DoorType := preload("res://game/levels/door_base.gd")
const PlayerType := preload("res://game/player/player.gd")
const PlayerScene := preload("res://game/player/player.tscn")
const Roster := preload("res://game/player/characters/roster.gd")
const Heads := preload("res://game/heads.gd")
const HudType := preload("res://ui/hud/hud.gd")
const PauseMenuType := preload("res://ui/pause_menu/pause_menu.gd")
const LevelTitleType := preload("res://ui/level_title/level_title.gd")
const DialogueType := preload("res://game/dialogue/dialogue_director.gd")
const SubtitleType := preload("res://ui/subtitle/subtitle.gd")
const SyncType := preload("res://game/sync/sync.gd")
const PictureHold := preload("res://game/picture_hold.gd")
const ScoreboardType := preload("res://ui/scoreboard/scoreboard.gd")
const HostLeftType := preload("res://ui/host_left/host_left.gd")
const Ping := preload("res://ui/ping.gd")
const InputSource := preload("res://game/player/input_source.gd")
const VirtualInput := preload("res://game/player/virtual_input.gd")
const ReviveType := preload("res://game/revive.gd")

@onready var _camera: Camera2D = $Camera2D
@onready var _fade: ColorRect = $Transition/Fade
@onready var _hud: HudType = $HUD/Hud
@onready var _title: LevelTitleType = $Title/LevelTitle
@onready var _pause_menu: PauseMenuType = $PauseMenu
@onready var _dialogue: DialogueType = $Dialogue
@onready var _subtitle: SubtitleType = $Subtitle/BossSubtitle

## The party's lives - see the header. Public as the readout tests and the HUD
## read.
var lives := MAX_LIVES

## Every member's body, in party order - the same order on every machine.
var _players: Array[PlayerType] = []
## This machine's, and everybody else's in that order: the HUD's rows.
var _local: PlayerType
var _others: Array[PlayerType] = []
## What each of the others is called on its HUD row, kept so the rows can be
## built again when somebody leaves.
var _names := {}
## The run across machines - see the header. Built on every machine, inert
## offline.
var _sync: SyncType
## This machine's hands, kept aside while an overlay has them (online, where
## the pause menu no longer stops the game - see _process).
var _hands: InputSource = null
## The bodies that went down in company and are waiting to get up, each with
## the number of the wait it is on - so a body got up early by a door, and
## felled again, is not stood up a second time by the first wait running out.
var _getting_up := {}
var _wait := 0
## Who this machine's camera follows while its own player is down - see
## _watch(). Null while they stand.
var _watching: PlayerType = null
## Picking somebody back up where they lie - see game/revive.gd.
var _revive: ReviveType

var _level: LevelType
var _travelling := false
## Whether this room's one-time alert (see _alert_room) has already fired.
## Reset on every arrival, like everything else a room carries no state across.
var _room_alerted := false
## Where each body came into this room - the centres of the ALERT_RADIUS.
var _arrived_at := {}
## World-space extent of the level on screen now; drives the camera.
var _bounds := Rect2()
## Camera shake: world pixels of throw, and how much of it is left to spend.
var _shake_throw := 0.0
var _shake_left := 0.0
var _shake_span := 0.12
## Hit-stop: which stop is the latest. Each one's timer lets the world go only
## if no later stop has been asked for since - so they extend, never stack.
var _freeze_token := 0
## The hit-stop online, which holds the picture rather than the clock - see
## _freeze.
var _hold: PictureHold
## The connection on screen, online only (DESIGN.md's Multiplayer, M5): the
## scoreboard held on Tab, at the top of the canvas stack, and the name of
## whoever is hosting, which the party's end needs after Net has forgotten it.
var _scoreboard: ScoreboardType = null
var _host_name := ""
## How long the relay line stays up at the start of a run, and how long the
## line saying somebody left does.
const RELAY_NOTICE_SECONDS := 5.0
const LEFT_NOTICE_SECONDS := 3.0
## The relay line's strip is the preview's: wide enough for the words with
## room either side, where the line about somebody leaving is as wide as it
## needs to be and never narrower than this.
const RELAY_NOTICE_WIDTH := 420.0
const LEFT_NOTICE_WIDTH := 200.0
## The scoreboard's canvas layer: over everything a run draws, under nothing.
const SCOREBOARD_LAYER := 7
## The menu theme's accent, which the host's corner says HOST in, and its warm
## colour, which somebody leaving is said in (tools/build_ui_theme.gd).
const HOST_COLOUR := Color("6eb39d")
const LEFT_COLOUR := Color("ec773d")

## How slow "stopped" is. Not zero: a zero delta is a division waiting to
## happen somewhere in every script that measures a speed, and a twentieth of
## a frame's worth of motion across five frames is nothing anybody can see.
const FREEZE_SCALE := 0.05


func _ready() -> void:
	# Re-applied live: zoom is reachable from the pause menu, with the game
	# sitting right behind the panel.
	Display.changed.connect(_apply_zoom)
	# The party ending under this machine - the host leaving - ends the run
	# here too. Nothing to do offline, where Net never says it.
	Net.ended.connect(_on_party_ended)
	_sync = SyncType.new()
	_sync.name = "Sync"
	add_child(_sync)
	_hold = PictureHold.new()
	_hold.name = "PictureHold"
	add_child(_hold)
	_spawn_party()
	_revive = ReviveType.new()
	_revive.name = "Revive"
	add_child(_revive)
	_revive.setup(self, _sync)
	# Pushed once here so the HUD never starts blank.
	_hud.set_health(_local.health, PlayerType.MAX_HEALTH)
	_hud.set_lives(lives, MAX_LIVES)
	# Every friendly face in the game, wired once here rather than per room -
	# see _on_node_added. Connected BEFORE the first level is built, because
	# building one is what adds the first of them.
	get_tree().node_added.connect(_on_node_added)
	# Talking, online: the rest of the party hears of it (game/sync/talk.gd).
	_dialogue.started.connect(_sync.talk_began)
	_dialogue.finished.connect(_sync.talk_ended)
	_dialogue.spoke.connect(_sync.spoke)
	# The front end's track ends here rather than at the character select, so
	# it carries over the load and goes out under the first room's fade-in.
	Music.fade_out()
	var first := next_start if not next_start.is_empty() else START_LEVEL
	next_start = ""
	_enter_level(first, &"start")
	_show_connection()
	# Last: from here this end exists, so the other one may be spoken to.
	_sync.begin(_players)


## One body per member of `next_party` - see the header. Each owns its health;
## game.gd only wires it to the HUD and decides what a death means, and its
## blows ask for the hit-stop and the shake on exactly a boss's terms (see
## _watch_boss): it says a blow landed, this owns the clock and the camera.
func _spawn_party() -> void:
	var members: Array = next_party if not next_party.is_empty() else [{}]
	next_party = []
	members = members.slice(0, Heads.MAX_PARTY)
	# This machine's member: the one marked `local` - online, where the party is
	# in the HOST's order on every machine - or the first.
	var mine := 0
	for i in members.size():
		if (members[i] as Dictionary).get("local", false):
			mine = i
	var others := 1
	var names: Array[String] = []
	for i in members.size():
		var member: Dictionary = members[i]
		var body := PlayerScene.instantiate() as PlayerType
		# This machine's keeps the name game.tscn gave the one player it used to
		# hold, so a path to it - every suite's - still reaches this machine's.
		if i == mine:
			body.name = "Player"
		else:
			others += 1
			body.name = "Player%d" % others
		body.character = String(member.get("character", ""))
		if member.get("input") != null:
			body.input_source = member["input"]
		# Whoever hosts is peer 1 online; kept for the day they leave, by which
		# time Net has forgotten everybody's name (_on_party_ended).
		if int(member.get("peer", 0)) == 1:
			_host_name = String(member.get("name", ""))
		# Online, everybody's body but this machine's is somebody else's to
		# move. A party on ONE machine has no peers, and is all this machine's.
		body.peer = int(member.get("peer", 1))
		body.remote = member.has("peer") and i != mine
		add_child(body)
		# Where game.tscn held it: straight after the background, so the y-sort
		# breaks ties against the room exactly as it always has.
		move_child(body, 1 + i)
		body.health_changed.connect(_on_health_changed.bind(body))
		body.died.connect(_on_player_died.bind(body))
		# The hit feel of a body moved HERE: a remote body's swings are its own
		# machine's to feel.
		if not body.remote:
			body.froze.connect(_freeze)
			body.shook.connect(_shake)
		_players.append(body)
		if i != mine:
			_others.append(body)
			# A player's own name online; the character's off it, where nobody
			# chose one.
			var shown := String(member.get("name", ""))
			if shown == "":
				shown = String(Roster.find(body.character).get("name", body.character))
			names.append(shown)
			_names[body] = shown
	_local = _players[mine]
	_hud.set_party(names)


## This machine's player is the big bar; everybody else is a row under it.
func _on_health_changed(health: int, max_health: int, body: PlayerType) -> void:
	if body == _local:
		_hud.set_health(health, max_health)
	else:
		_hud.set_member_health(_others.find(body), health, max_health)


## The party, for whoever needs every body rather than the standing ones the
## `player` group holds - tests, and the day a scoreboard lists them.
func party() -> Array[PlayerType]:
	return _players


## This machine's player - for game/revive.gd, which puts the E over the body it
## could revive.
func local_player() -> PlayerType:
	return _local


## Whether the party is on its way through a door, frozen under the fade.
func is_travelling() -> bool:
	return _travelling


## The floor in play now, for game/sync/, which keeps it in step.
func current_level() -> LevelType:
	return _level


func _process(delta: float) -> void:
	_watch()
	_camera.global_position = _camera_target()
	_apply_shake(delta)
	_hold_hands(_pause_menu.is_paused() and _sync.active)
	if not _travelling and not _room_alerted and _anyone_walked_in():
		_room_alerted = true
		_alert_room()
	_hold_scoreboard()


# --- the connection on screen (DESIGN.md's Multiplayer, M5) -------------------------


## An online run's corner ping and scoreboard, and the relay line for a guest
## who only got in through the relay - each picked from the Ping On Screen
## preview. Nothing here offline, which is every solo run: the HUD is exactly
## what it always was.
func _show_connection() -> void:
	if not _sync.active:
		return
	var layer := CanvasLayer.new()
	layer.name = "Scoreboard"
	layer.layer = SCOREBOARD_LAYER
	add_child(layer)
	_scoreboard = ScoreboardType.new()
	_scoreboard.visible = false
	layer.add_child(_scoreboard)
	Net.roster_changed.connect(_on_roster)
	_on_roster()
	if String(_my_row().get("route", "")) == "RELAY":
		_hud.notice("! CONNECTED THROUGH RELAY - EXPECT HIGHER PING", Ping.MID,
			RELAY_NOTICE_WIDTH, RELAY_NOTICE_SECONDS)


## This machine's row of Net's roster, or {} once there is none.
func _my_row() -> Dictionary:
	for row: Dictionary in Net.roster():
		if int(row.get("peer", 0)) == Net.my_id():
			return row
	return {}


## The roster moved - a ping measured, once a second: the corner says this
## machine's distance to the host, or HOST on the host's own screen.
func _on_roster() -> void:
	var mine := _my_row()
	if mine.is_empty():
		return
	if String(mine.get("route", "")) == "HOST":
		_hud.set_ping("HOST", HOST_COLOUR)
	else:
		var ms := int(mine.get("ping", -1))
		_hud.set_ping("..." if ms < 0 else "%d MS" % ms, Ping.colour(ms))
	if _scoreboard != null and _scoreboard.visible:
		_scoreboard.show_rows(Net.roster(), Net.my_id(), Net.code())


## Up for as long as Tab is held, and filled the moment it comes up.
func _hold_scoreboard() -> void:
	if _scoreboard == null:
		return
	var held := InputMap.has_action(&"scoreboard") and Input.is_action_pressed(&"scoreboard")
	if held and not _scoreboard.visible:
		_scoreboard.show_rows(Net.roster(), Net.my_id(), Net.code())
	_scoreboard.visible = held


## Whether the scoreboard is up. For tests.
func scoreboard_up() -> bool:
	return _scoreboard != null and _scoreboard.visible


## Online nothing pauses (DESIGN.md's *The rules of a party*): the pause menu
## and the death screen are overlays with the room still running behind them,
## so while one is up this machine's player is handed still hands rather than
## walking about under the menu's own arrow keys - and handed its own back
## when it closes.
func _hold_hands(held: bool) -> void:
	if held and _hands == null:
		_hands = _local.input_source
		_local.input_source = VirtualInput.new()
	elif not held and _hands != null:
		_local.input_source = _hands
		_hands = null


## Whether anybody standing is more than ALERT_RADIUS from where they came in.
func _anyone_walked_in() -> bool:
	for body in _players:
		if not body.is_down() and _arrived_at.has(body) \
				and body.global_position.distance_to(_arrived_at[body]) > ALERT_RADIUS:
			return true
	return false


## Zoom decides how much world fits on screen, which in turn decides whether
## _camera_target() frames the room whole or follows the player around it.
func _apply_zoom() -> void:
	_camera.zoom = Vector2.ONE * Display.zoom()
	# Reposition here rather than waiting for _process: the tree is paused while
	# the settings panel is open, so nothing else would run until it closes.
	_camera.global_position = _camera_target()
	_camera.reset_smoothing()


## Fade out, swap, fade back in. Input is suspended for the whole trip so a key
## held through the transition cannot walk the player straight back into the
## door they just arrived beside.
##
## `as_room` is the host's count for the floor being entered, on a guest that
## was told to come (net_travel); the host counts its own.
func _travel(level_path: String, spawn: StringName, as_room := 0) -> void:
	if _travelling:
		return
	# A door reached mid-conversation ends it: the NPC saying the line is about
	# to be freed with the room, and the player must not arrive next door still
	# under someone else's control.
	_dialogue.stop()
	_travelling = true
	_hold_party()
	# Everybody goes together: the guests are told as the host's fade begins.
	_sync.travelling(level_path, spawn)

	var out := create_tween()
	out.tween_property(_fade, "color:a", 1.0, FADE_SECONDS)
	await out.finished

	_enter_level(level_path, spawn, as_room)

	var back := create_tween()
	back.tween_property(_fade, "color:a", 0.0, FADE_SECONDS)
	await back.finished

	_release_party()
	_travelling = false


## Every body frozen for a fade, and only the standing ones let go after it: a
## body that is down stays as still as it fell.
func _hold_party() -> void:
	for body in _players:
		body.set_physics_process(false)
		body.velocity = Vector2.ZERO


func _release_party() -> void:
	for body in _players:
		if not body.is_down():
			body.set_physics_process(true)


## Each death spends one of the party's lives. Alone, while any remain, dying
## costs the ground covered in this room, and the last one ends the run. In
## company see _go_down.
func _on_player_died(body: PlayerType) -> void:
	if _players.size() > 1:
		_go_down(body)
		return
	# Dying hands the body back before anything else does anything with it -
	# a respawn moves the player, and a conversation still holding the wheel
	# would keep walking them back towards whoever was talking.
	_dialogue.stop()
	# And whatever the boss was shouting goes with it: the player is about to
	# be somewhere the line was not said.
	_subtitle.clear()
	if _spend_life() > 0:
		_respawn()
	else:
		_game_over()


## The run was the host's, and the host has gone: the room freezes under a panel
## saying so (ui/host_left/), and its one button is the way to the main menu.
## Any other ending under a run goes straight there, unpaused.
func _on_party_ended(reason: String) -> void:
	if reason == "host_left" and _sync.active:
		if _pause_menu.is_paused():
			_pause_menu.resume()
		var panel := HostLeftType.new()
		panel.name = "HostLeft"
		add_child(panel)
		panel.open(_host_name)
		return
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)


## One life out of the pool. Returns how many remain, so the caller chooses
## respawn or game over from the same call instead of racing a signal.
func _spend_life() -> int:
	lives = maxi(lives - 1, 0)
	_hud.set_lives(lives, MAX_LIVES)
	_sync.lives_changed(lives)
	return lives


## A death in company. Nobody else's game stops for it: the body goes down
## where it fell, and the pool pays for it to get up at the door a few seconds
## later - or, with the pool empty, it stays down. The run ends only when
## nobody is standing and nobody is about to be.
##
## The life is spent NOW rather than when the body gets up, so the hearts say
## the truth the moment it happens and a second death on the same frame finds
## the pool as it really is.
func _go_down(body: PlayerType) -> void:
	_fall(body)
	_sync.went_down(body)
	if lives > 0:
		_spend_life()
		_wait += 1
		_getting_up[body] = _wait
		# Paused with the game: the pause menu must not be a way to skip it.
		get_tree().create_timer(GET_UP_SECONDS, false).timeout.connect(
			_get_up.bind(body, _wait))
	elif _getting_up.is_empty() and _nobody_standing():
		_game_over()


## Whether every body in the party is down. Asked of the bodies rather than of
## the `player` group, which a body whose machine has gone silent is out of too
## (player.gd's `away`) - and somebody who is only not answering has not lost
## the run for everybody.
func _nobody_standing() -> bool:
	for body in _players:
		if not body.is_down():
			return false
	return true


## A body down where it fell, on whichever machine is drawing it.
func _fall(body: PlayerType) -> void:
	# A conversation holding this body's wheel is over; anybody else's goes on.
	if _dialogue.listener() == body:
		_dialogue.stop()
	body.knock_down()
	_hud.set_member_down(_others.find(body), true)


func _get_up(body: PlayerType, wait: int) -> void:
	if not is_instance_valid(body) or _getting_up.get(body, -1) != wait:
		return
	_getting_up.erase(body)
	_stand_up(body, _level.spawn_position(&"start") + _slot(body))
	# Mid-fade the party is frozen, and the fade lets everyone standing go.
	if not _travelling:
		body.set_physics_process(true)


## Back on their feet at `at`, full health, in the fight again.
func _stand_up(body: PlayerType, at: Vector2) -> void:
	body.global_position = at
	body.revive()
	_revive.clear(body)
	_hud.set_member_down(_others.find(body), false)
	_sync.stood_up(body, at)


## Up where it lay, revived by `by` (game/revive.gd) - the host's call. The
## wait at the door it may have been on is overtaken, exactly as a door
## overtakes one: it does nothing when it runs out.
func revived(body: PlayerType, by: PlayerType) -> void:
	_getting_up.erase(body)
	var toward := by.global_position if by != null else body.global_position
	_lift(body, toward)
	_sync.revived(body, toward)


## A revive's getting up, on whichever machine is drawing it.
func _lift(body: PlayerType, toward: Vector2) -> void:
	body.get_up(ReviveType.HEALTH, ReviveType.GRACE, toward)
	_hud.set_member_down(_others.find(body), false)
	_revive.stood(body)
	# Mid-fade the party is frozen, and the fade lets everyone standing go.
	if not _travelling:
		body.set_physics_process(true)


## Where in the row across a spawn marker this body stands - see
## PARTY_SPACING. Nothing for a party of one, who stands on the marker itself.
func _slot(body: PlayerType) -> Vector2:
	var i := _players.find(body)
	return Vector2((i - (_players.size() - 1) / 2.0) * PARTY_SPACING, 0.0).round()


## The run is over: the pause overlay comes up as a death screen (YOU DIED,
## CONTINUE disabled) with the room still visible behind it, frozen by the
## tree pause. Leaving through MAIN MENU builds a fresh party next run, so
## health and lives reset by construction.
func _game_over() -> void:
	for body in _players:
		body.velocity = Vector2.ZERO
	_pause_menu.show_game_over()
	_sync.over()


## Death with lives to spare is a fade back to this room's start marker with
## full health. Reuses the travel fade so dying and arriving read as the same
## kind of cut.
func _respawn() -> void:
	# A death can land mid-transition (a hazard right beside a door); let the
	# travel finish rather than fight it for the fade.
	while _travelling:
		await get_tree().process_frame
	_travelling = true
	_local.set_physics_process(false)
	_local.velocity = Vector2.ZERO

	var out := create_tween()
	out.tween_property(_fade, "color:a", 1.0, FADE_SECONDS)
	await out.finished

	_local.global_position = _level.spawn_position(&"start")
	_local.revive()

	var back := create_tween()
	back.tween_property(_fade, "color:a", 0.0, FADE_SECONDS)
	await back.finished

	_local.set_physics_process(true)
	_travelling = false


func _enter_level(level_path: String, spawn: StringName, as_room := 0) -> void:
	if _level != null:
		# Detach before freeing: the replacement is added in the same frame and
		# would otherwise collide with the outgoing level's node name.
		remove_child(_level)
		_level.queue_free()

	# Before the room goes in rather than with the rest of the reset below:
	# building it adds every placed enemy through _on_node_added, and the last
	# room's spent alert would otherwise be handed to all of them on arrival.
	_room_alerted = false
	_revive.new_room()
	_level = (load(level_path) as PackedScene).instantiate()
	add_child(_level)
	move_child(_level, 0)

	# Group rather than a type search, for the same reason as the preloads above.
	# The outgoing level has already left the tree, so this only sees new doors.
	for node in get_tree().get_nodes_in_group("door"):
		var door := node as DoorType
		if door != null:
			door.travelled.connect(_on_door)

	_watch_boss()

	# Nothing carries over from the room just left, the camera least of all: a
	# shake still decaying would offset the first frame of the new one, and a
	# line still up would be shouted by a boss who is now a floor away.
	_shake_left = 0.0
	_camera.offset = Vector2.ZERO
	_unfreeze()
	_subtitle.clear()

	# The whole party is carried through, standing or not, in a row across the
	# marker; anybody who was waiting to get up gets up here, at this room's
	# door, which is exactly where the wait would have put them.
	var marker := _level.spawn_position(spawn)
	_arrived_at.clear()
	for body in _players:
		var at := marker + _slot(body)
		if _getting_up.has(body):
			_getting_up.erase(body)
			_stand_up(body, at)
		else:
			body.global_position = at
		_arrived_at[body] = at

	# Frame the new level before the first frame of it is drawn, then drop the
	# smoothing history - otherwise the camera glides across from wherever the
	# level we just left had put it.
	_bounds = _level.bounds()
	_apply_zoom()

	# Announce the room. Called here rather than after the fade finishes, so the
	# name is already up on the black and the room appears behind it; and here
	# rather than from the door, so arriving at the start of a run names the
	# lobby too. A respawn deliberately does not come through here - dying and
	# getting up in the same room is not arriving somewhere.
	_title.show_title(_level.title())
	_sync.entered(level_path, spawn, as_room)


## A door says the party is through. The host's call (DESIGN.md's *The rules
## of a party*): a guest's doors count who is standing in them like anybody's,
## and go nowhere - the host's door is the one that moves everybody.
func _on_door(level_path: String, spawn: StringName) -> void:
	if _sync.is_host():
		_travel(level_path, spawn)


## The friendly faces, and the one thing in this scene that is wired as people
## ARRIVE rather than as a room is built. An NPC raises its hand; the director
## in this scene does the talking, and nothing in game.gd knows what any of them
## says.
##
## The doors above can be found by group the moment the level goes in, because
## a room has all the doors it will ever have. People it does not: a floor that
## has been cleared walks Ivan in through one of those doors minutes later
## (game/levels/relief.gd), and an NPC who arrives after the sweep would never
## be connected to anything - his prompt would come up and the key would do
## nothing. Listening to the tree instead catches both, since instancing a level
## adds every node in it one at a time too.
##
## Enemies arrive late on the same terms - a beat walks them in through a door
## (game/levels/reinforcements.gd) - and one that arrives after the room alert
## has fired would otherwise be the only body in the room nobody told. So it is
## told here, on its way in - deferred, because reinforcements.gd `unleash()`es
## a body one line AFTER add_child, and it is having no post that makes it an
## arrival rather than something placed.
func _on_node_added(node: Node) -> void:
	# The enemies are the host's to move, and so are their alerts.
	if _room_alerted and node.is_in_group("enemies") and _sync.is_host():
		_alert_arrival.call_deferred(node)
		return
	if not node.is_in_group("npcs") or not node.has_signal(&"talk_requested"):
		return
	if not node.is_connected(&"talk_requested", _on_talk_requested):
		node.connect(&"talk_requested", _on_talk_requested)


## Untyped on purpose: by the time a deferred call lands the body may already
## be gone - killed on the frame it walked in - and a freed object cannot be
## converted to a Node, so a typed parameter fails before the check can run.
func _alert_arrival(node) -> void:
	if is_instance_valid(node) and node.has_method("roaming") \
			and node.call("roaming") and node.has_method("alert"):
		node.call("alert")


func _on_talk_requested(npc: Node2D) -> void:
	# Declined while the room is changing under everyone's feet: the fade is
	# already running and the NPC is about to be freed with the level.
	if _travelling or _local.is_down():
		return
	# This machine's player, who is the one with a key to press. Who talks in a
	# party is still DESIGN.md's open question; this is its default.
	_dialogue.talk(npc, _local)


## The one push a room gets, fired once by _process the moment the player is
## more than ALERT_RADIUS from where they came in. Every enemy already standing
## here gets alert()ed, as if it had just seen the player; what happens next is
## entirely the leash's (patience, the bound off each body's own post, the walk
## home if nothing comes of it). The doorway is the only safe ground - the walk
## to the far door is not, so no room is crossed without anybody noticing. It
## changes WHEN the first sighting can happen, never what one costs.
## Anything that walks in later is alerted as it arrives (_on_node_added), and
## a reinforcement, having no post, keeps coming (enemy_base.alert()).
func _alert_room() -> void:
	# The host's room is the one with enemies in it that move; a guest's are
	# drawn where the host's stand.
	if not _sync.is_host():
		return
	for node in get_tree().get_nodes_in_group("enemies"):
		if node.has_method("alert"):
			node.alert()


## A boss floor puts a second bar on screen. Found by GROUP at the moment the
## room is built, exactly like the doors above and for the same reason:
## nothing in game.gd names a boss, and a floor without one simply clears the
## bar. A floor whose boss has already conceded - the player walking back down
## through a fight they have won - clears it too.
##
## Wired by signal rather than asked every frame, which is the HUD's shape:
## the player's own health arrives the same way. He is never freed, so the bar
## comes down on `conceded` rather than on him disappearing.
##
## His MUSIC is the third thing hung here, for the same reason as the other
## two: a boss floor is the only floor with a track, and the moments it starts
## and stops are exactly the moments the bar goes up and comes down. Which is
## also what makes the silence right - a floor with no live boss fades out
## whatever was playing, so walking back down through a fight already won is
## as quiet as the fight is over, and no room has to say so.
func _watch_boss() -> void:
	_hud.clear_boss()
	var theme := ""
	for node in get_tree().get_nodes_in_group("bosses"):
		if not node.has_method("title") or node.get("has_conceded"):
			continue
		_hud.set_boss(node.call("title"), node.get("health"), node.get("max_health"))
		node.connect(&"health_changed", Callable(_hud, "set_boss_health"))
		node.connect(&"conceded", Callable(_hud, "clear_boss"))
		# A boss may also shake the room. Checked for rather than assumed, so a
		# boss who never throws the camera about needs no shake code of his own
		# - the same deal the bar gets one line above.
		if node.has_signal(&"shook"):
			node.connect(&"shook", Callable(self, "_shake"))
		# And the hit-stop, on exactly those terms: he says a blow landed, and
		# this is what owns the clock.
		if node.has_signal(&"froze"):
			node.connect(&"froze", Callable(self, "_freeze"))
		# And a mouth, on the same terms again. A boss who says nothing emits
		# nothing, so no floor and nothing here has to know which of them talk.
		if node.has_signal(&"said"):
			node.connect(&"said", Callable(self, "_on_boss_said"))
		# And a theme, on the same terms. `get` rather than a typed read so a
		# boss predating the export is a boss with no track, not a crash.
		var declared: Variant = node.get("music")
		theme = declared if declared is String else ""
		if theme != "":
			# And back to the bed when he gives in. Not silence: the floor is an
			# ordinary floor the moment he concedes - Ivan walks in on half of
			# them - and the theme leaving is the fight ending, not the music
			# ending.
			node.connect(&"conceded", Callable(Music, "fade_to").bind(_bed()))
		break

	# After the loop, not inside it: a floor with no boss AND a boss floor whose
	# boss has already conceded both land here, and both want the bed rather
	# than a theme of anyone's.
	#
	# `fade_to` and not `play`, because the menu track is still going as the
	# first room is built (_ready has just asked it to leave) and a straight
	# `play` would cut it dead - this queues the bed behind the fade it is
	# already taking. It is idempotent on the track for the other nine floors,
	# so a door between two ordinary rooms does not restart the bed underneath
	# it: the music crosses the building with the player, and only a boss
	# interrupts it.
	if theme == "":
		Music.fade_to(_bed())
	else:
		Music.play(theme)


## What this floor plays with no live boss over it: its own track if its biome
## named one, and the building's bed otherwise. The fallback is here rather than
## spelled out at each of the three places that used to say Music.DEFAULT,
## because a floor with a track of its own has to win in all three - including
## the one that runs when its boss gives in, where the room goes back to being
## an ordinary floor and an ordinary floor is still THIS one.
func _bed() -> String:
	if _level == null:
		return Music.DEFAULT
	var declared: Variant = _level.get("music")
	if declared is String and declared != "":
		return declared
	return Music.DEFAULT


## A boss shouting. Dropped rather than queued while an NPC is talking: the
## dialogue box is at the bottom of the screen too, and it holds the player's
## hands as well as their eyes - a line shouted over it would be the one thing
## on screen they could not answer. Nothing is lost by dropping it, because a
## bark is only ever about the moment it was said in.
func _on_boss_said(speaker: String, text: String, seconds: float) -> void:
	if _dialogue.talking():
		return
	_subtitle.show_line(speaker, text, seconds)


## Who the camera follows while this machine's player is down (the 2026-10-03
## playtest: a screen parked on a body that cannot move reads as the game
## having frozen). Somebody still standing - first whoever is nearest the body
## that fell, so the camera goes to the fight that was going on rather than
## across the building. The pick sticks; the attack button moves it on to the
## next one standing; and it moves on by itself when the one being watched goes
## down too. With nobody standing it stays where it is, on the last fight there
## was, and getting up takes the camera straight back.
##
## Nothing crosses the wire for it: every machine already draws every body, so
## watching somebody is only pointing a camera.
func _watch() -> void:
	if not _local.is_down():
		if _watching != null:
			_watching = null
			_hud.set_watching("", false)
		return
	var standing: Array[PlayerType] = []
	for body in _players:
		if body != _local and not body.is_down() and not body.away:
			standing.append(body)
	if standing.is_empty():
		if _watching == null:
			_hud.set_watching("", false)
		return
	if not standing.has(_watching):
		var from := _local.global_position if _watching == null else _watching.drawn_at()
		var nearest := standing[0]
		for body in standing:
			if body.drawn_at().distance_to(from) < nearest.drawn_at().distance_to(from):
				nearest = body
		_watching = nearest
	elif standing.size() > 1 and _local.input_source.attack_pressed():
		_watching = standing[(standing.find(_watching) + 1) % standing.size()]
	var helper := _revive.reviver_of(_local)
	_hud.set_watching(String(_names.get(_watching, "")), standing.size() > 1,
		String(_names.get(helper, "")) if helper != null else "")


## Who the camera is following: this machine's player, or whoever _watch()
## picked while they are down. For tests.
func watched() -> PlayerType:
	return _local if _watching == null else _watching


## Where the camera wants to be, decided per axis:
##
## - the level is wider/taller than the screen -> follow the player, stopping at
##   the walls so the void outside the map never comes into view
## - the level already fits -> sit on its centre and show the whole room
##
## Deliberately not Camera2D's own limits: those cannot express the second case.
## Asked to keep a 544 px room inside a 640 px view they contradict themselves,
## and the camera ends up jammed against one edge.
func _camera_target() -> Vector2:
	var view := get_viewport_rect().size / _camera.zoom
	var half := view * 0.5
	var centre := _bounds.get_center()
	# This machine's player, whoever else is in the room: each machine's camera
	# follows its own, so no floor is ever too big for a party. Somebody else's
	# only while this one is down (_watch), and then where their picture is.
	var target := _local.global_position if _watching == null else _watching.drawn_at()
	if view.x >= _bounds.size.x:
		target.x = centre.x
	else:
		target.x = clampf(target.x, _bounds.position.x + half.x, _bounds.end.x - half.x)
	if view.y >= _bounds.size.y:
		target.y = centre.y
	else:
		target.y = clampf(target.y, _bounds.position.y + half.y, _bounds.end.y - half.y)
	return target


## A blow landed hard enough to move the room. Reached by signal from whoever
## threw it; applied here because this is what owns a camera.
func _shake(strength: float, seconds: float) -> void:
	_shake_throw = strength
	_shake_span = maxf(seconds, 0.001)
	_shake_left = _shake_span


## The world held still for `seconds` of unscaled time - the hit-stop. The whole
## room, on purpose, rather than the boss and the body he hit: a blow that
## stops two people while everything else in the room carries on reads as lag,
## not weight. Overlapping stops extend rather than stack, and the timer runs
## on unscaled time, or the stop would stretch itself twentyfold.
##
## Solo only (DESIGN.md's *Rules that keep it honest*): online the clock is the
## host's whole world, and stopping it for one player's hit would stop it for
## everybody. So online the stop holds the PICTURE - every animation and every
## effect of the hit feel - and leaves the world running under it
## (game/picture_hold.gd). Asked by this machine's own player's blows, and by a
## boss's on every machine.
func _freeze(seconds: float) -> void:
	if _sync.active:
		_hold.hold(seconds)
		return
	_freeze_token += 1
	Engine.time_scale = FREEZE_SCALE
	get_tree().create_timer(seconds, true, false, true).timeout.connect(
		_thaw.bind(_freeze_token))


func _thaw(token: int) -> void:
	if token == _freeze_token:
		_unfreeze()


## Back to full speed now. Also on every room change and on the way out, so a
## stop can never outlive the fight that asked for it - a menu running at a
## twentieth of its speed would be the bug report.
func _unfreeze() -> void:
	_freeze_token += 1
	Engine.time_scale = 1.0
	if _hold != null:
		_hold.release()


func _exit_tree() -> void:
	_unfreeze()


## The shake as an OFFSET, so _camera_target() above stays the only thing that
## decides where the camera is pointed. Framing a room and being shoved about
## are separate questions, and adding them together would fight the clamping
## that keeps the void outside the map off screen.
##
## Quantized to whole world pixels, because a camera parked on a fraction of
## one is exactly what makes a pixel-art room crawl - the same reason the
## window size setting only offers whole multiples of the base viewport.
func _apply_shake(delta: float) -> void:
	if _shake_left <= 0.0:
		if _camera.offset != Vector2.ZERO:
			_camera.offset = Vector2.ZERO
		return
	_shake_left = maxf(_shake_left - delta, 0.0)
	var mag := _shake_throw * (_shake_left / _shake_span)
	var tick := Time.get_ticks_msec()
	_camera.offset = Vector2(
		roundf(_jitter(tick, 1) * 2.0 * mag),
		roundf(_jitter(tick, 2) * mag))


## -0.5..0.5, steady within a frame and different the next.
static func _jitter(a: int, b: int) -> float:
	return float(absi((a * 73856093) ^ (b * 19349663)) % 1000) / 1000.0 - 0.5


# --- the host's word, on a guest (game/sync/sync.gd) -------------------------------


## Everybody to another floor. A guest still fading through the last door goes
## on through this one the moment it lands, rather than being dropped by the
## latch that keeps one machine from travelling twice.
func net_travel(level_path: String, spawn: StringName, as_room: int) -> void:
	while _travelling:
		await get_tree().process_frame
	_travel(level_path, spawn, as_room)


func net_lives(value: int) -> void:
	lives = value
	_hud.set_lives(lives, MAX_LIVES)


func net_down(body: PlayerType) -> void:
	if not body.is_down():
		_fall(body)


## Up at `at`, the host's door. Physics only for a body this machine moves, and
## not mid-fade, where the fade lets everyone standing go.
func net_up(body: PlayerType, at: Vector2) -> void:
	_stand_up(body, at)
	if not _travelling:
		body.set_physics_process(true)


## The host's word on a revive's progress (game/revive.gd's header).
func net_revive(body: PlayerType, progress: float, filling: bool, lost: bool) -> void:
	_revive.heard(body, progress, filling, lost)


## Up where it lay - the host's revive, played here.
func net_revived(body: PlayerType, toward: Vector2) -> void:
	if body.is_down():
		_getting_up.erase(body)
		_lift(body, toward)


func net_over() -> void:
	_game_over()


## A line somebody else in the party is being told, read along on the
## subtitle - which takes nobody's hands - for about as long as it takes to
## read. Not over a conversation of this machine's own, which owns the bottom
## of the screen.
func net_line(speaker: String, text: String) -> void:
	if not _dialogue.talking():
		_subtitle.show_line(speaker, text, maxf(2.0, text.length() / 13.0))


## Somebody else reached this NPC first - two pressed on one frame, and the
## host says it was not this machine (game/sync/talk.gd's *Two at once*). The
## conversation begun here closes, and this machine's player has its hands
## back; whatever the other one is told goes up on the subtitle like any.
func net_refused(npc: Node) -> void:
	if _dialogue.talking_to() == npc:
		_dialogue.stop()


## A member gone from the party, mid-run - on the host when they drop, and on
## every guest when the host says so. Their body leaves with them; the rows
## under the hearts close up; and if they were the last one standing, nobody is.
func net_left(body: PlayerType) -> void:
	if body == _local:
		return
	# Said across the top, in the name everybody's row called them by.
	var who := String(_names.get(body, ""))
	if who != "":
		_hud.notice("%s LEFT THE GAME" % who.to_upper(), LEFT_COLOUR,
			LEFT_NOTICE_WIDTH, LEFT_NOTICE_SECONDS)
	body.remove_from_group("player")
	if body == _watching:
		_watching = null
	_players.erase(body)
	_others.erase(body)
	_names.erase(body)
	_getting_up.erase(body)
	_arrived_at.erase(body)
	_revive.clear(body)
	var names: Array[String] = []
	for other in _others:
		names.append(String(_names.get(other, "")))
	_hud.set_party(names)
	for i in _others.size():
		_hud.set_member_health(i, _others[i].health, PlayerType.MAX_HEALTH)
		_hud.set_member_down(i, _others[i].is_down())
	body.queue_free()
	if _sync.is_host() and _getting_up.is_empty() and _nobody_standing():
		_game_over()
