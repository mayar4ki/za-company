extends Node
## REVIVE: a teammate who is down, picked back up where they lie - option A,
## Steady hands, from the Revive Lab preview (2026-10-04), with the owner's
## three changes: green, plus signs, and the one reviving stays standing.
##
## ## The rules
##
## - **Anyone standing, on anyone down, as often as it takes.** Stand within
##   REVIVE_RANGE (player.gd) and hold interact; the hands do the rest - rooted,
##   turned to them, no swinging (player.gd's `_reviving`).
## - **SECONDS of holding** gets them up. Two on one body is no faster than one.
## - **Letting go runs it back down** at the same speed, and every blow the one
##   reviving takes knocks BLOW_COST seconds off.
## - **Up where they lie**, with HEALTH and GRACE seconds of the window, so the
##   first blow in a crowd does not put them straight back down.
## - **The pool of lives never hears of it.** With lives left a body still gets
##   up at the door GET_UP_SECONDS later on its own (game.gd), so a revive is
##   what the party does once the hearts are gone - or to get somebody up where
##   they are, if it is quick enough. The run still ends when nobody is standing.
##
## ## Online
##
## The host is the truth, as for everything else that is decided. Each machine
## knows who its own player is reviving (its hands) and says so in its body's
## state (player.gd's net_state); the HOST counts the seconds off the newest
## word, knocks off a blow it lands, and says when somebody is up. A guest is
## told every time a body starts or stops filling, or loses a second, with how
## full it is (sync.gd's `revive_changed`), and fills or empties its own copy in
## between - so its ring runs smoothly at the same rate and is corrected at each
## word. Getting up is the host's word too (`revived`).
##
## ## On screen
##
## The ring under the body (game/player/revive_ring.gd), the plus signs off it
## (heal_plus.gd), the crown of them and a green +50 when it is done, and the E
## over a body this machine's player could revive (revive_prompt.gd). All drawn
## on every machine from what that machine knows; nothing on screen crosses the
## wire but the progress.

const PlayerType := preload("res://game/player/player.gd")
const ReviveRing := preload("res://game/player/revive_ring.gd")
const RevivePrompt := preload("res://game/player/revive_prompt.gd")
const HealPlus := preload("res://game/player/heal_plus.gd")
const DamageNumber := preload("res://game/player/damage_number.gd")

## Seconds of holding that get somebody up.
const SECONDS := 4.0
## What they get up with, and how long nothing can touch them after.
const HEALTH := 50
const GRACE := 1.0
## Seconds a blow on the one reviving knocks off, and how long the ring shows
## red for it.
const BLOW_COST := 1.0
const LOST_SECONDS := 0.3
## The +50, in the ring's green.
const HEAL_EDGE := Color(10 / 255.0, 38 / 255.0, 20 / 255.0)
## The crown of plus signs when somebody gets up: this many, round the body,
## going up faster than the ring's.
const CROWN := 8
const CROWN_RX := 10.0
const CROWN_RY := 4.0
const CROWN_LIFT := 4.0
const CROWN_RISE := 22.0
const CROWN_RISE_MORE := 10.0
const CROWN_SPREAD := 10.0

## Untyped: game.gd preloads this file, so this one cannot preload it back.
var _game
var _sync
## body -> 0..1, how full its revive is; body -> whether somebody is holding.
var _progress := {}
var _filling := {}
## body -> its ring, while it has one.
var _rings := {}
var _prompt: RevivePrompt


func setup(game, sync) -> void:
	_game = game
	_sync = sync
	_prompt = RevivePrompt.new()
	_prompt.name = "RevivePrompt"
	_prompt.visible = false
	add_child(_prompt)
	# A blow on somebody reviving knocks a second off - decided where blows
	# are, on the host, which is the only machine `reached` is said on.
	for body: PlayerType in _game.party():
		body.reached.connect(_on_reached.bind(body))


## How full `body`'s revive is, 0..1. For tests and the HUD.
func progress(body: PlayerType) -> float:
	return float(_progress.get(body, 0.0))


## Whether anybody is filling `body`'s revive now, as this machine knows it.
func filling(body: PlayerType) -> bool:
	return bool(_filling.get(body, false))


## Who is reviving `body`: the first of the party standing whose hands - or
## whose owner's word - say so. Nobody, for a body that is not down.
func reviver_of(body: PlayerType) -> PlayerType:
	if body == null or not body.is_down():
		return null
	for other: PlayerType in _game.party():
		if other != body and not other.is_down() and not other.away \
				and other.revive_target() == body:
			return other
	return null


func _physics_process(delta: float) -> void:
	var host: bool = _sync.is_host()
	var counting: bool = not _game.is_travelling()
	for body: PlayerType in _game.party():
		if not body.is_down():
			if _progress.has(body):
				clear(body)
			continue
		var was := progress(body)
		var fill := filling(body)
		if host:
			fill = counting and reviver_of(body) != null
		var now := clampf(was + (delta if fill else -delta) / SECONDS, 0.0, 1.0)
		if not fill and now == 0.0 and was == 0.0:
			_filling.erase(body)
			_drop_ring(body)
			continue
		_progress[body] = now
		if host and fill != filling(body):
			_sync.revive_changed(body, now, fill, false)
		_filling[body] = fill
		_ring_for(body).progress = now
		_ring_for(body).live = fill
		if host and now >= 1.0:
			_game.revived(body, reviver_of(body))
	_show_prompt()


## The host's word on a guest: how full `body`'s revive is, whether it is
## filling, and whether a blow just knocked some off.
func heard(body: PlayerType, value: float, fill: bool, lost: bool) -> void:
	if not body.is_down():
		return
	_progress[body] = value
	_filling[body] = fill
	var ring := _ring_for(body)
	ring.progress = value
	ring.live = fill
	if lost:
		ring.lost = LOST_SECONDS


## `body` just got up from a revive, on any machine: the ring flares, a crown of
## plus signs goes up and the +50 with them.
func stood(body: PlayerType) -> void:
	var ring: ReviveRing = _rings.get(body)
	_rings.erase(body)
	_progress.erase(body)
	_filling.erase(body)
	if ring == null:
		ring = _ring_for(body)
		_rings.erase(body)
	ring.flare()
	var centre := body.drawn_at()
	for i in CROWN:
		var a := float(i) / CROWN * TAU
		HealPlus.spawn(body, centre + Vector2(cos(a) * CROWN_RX, sin(a) * CROWN_RY - CROWN_LIFT),
			i % 2 == 0, ReviveRing.HEAL if i % 3 != 0 else ReviveRing.HEAL_LIGHT,
			Vector2(cos(a) * CROWN_SPREAD, -(CROWN_RISE + randf() * CROWN_RISE_MORE)))
	DamageNumber.spawn_healed(body, HEALTH, ReviveRing.HEAL, HEAL_EDGE)


## Nothing more to show for `body`: up at the door, or gone.
func clear(body: PlayerType) -> void:
	_progress.erase(body)
	_filling.erase(body)
	_drop_ring(body)


## A new room: nobody carried through it is part-way up any more.
func new_room() -> void:
	for body in _rings.keys():
		_drop_ring(body)
	_progress.clear()
	_filling.clear()


func _on_reached(what: String, _args: Array, body: PlayerType) -> void:
	if what != "struck":
		return
	var target := body.revive_target() as PlayerType
	if target == null or not target.is_down() or progress(target) <= 0.0:
		return
	var now := maxf(progress(target) - BLOW_COST / SECONDS, 0.0)
	_progress[target] = now
	var ring := _ring_for(target)
	ring.progress = now
	ring.lost = LOST_SECONDS
	_sync.revive_changed(target, now, filling(target), true)


func _ring_for(body: PlayerType) -> ReviveRing:
	var ring: ReviveRing = _rings.get(body)
	if ring == null or not is_instance_valid(ring):
		ring = ReviveRing.new()
		ring.name = "ReviveRing"
		body.add_child(ring)
		ring.setup(body)
		_rings[body] = ring
	return ring


func _drop_ring(body: PlayerType) -> void:
	var ring: ReviveRing = _rings.get(body)
	_rings.erase(body)
	if ring != null and is_instance_valid(ring) and not ring.flaring():
		ring.queue_free()


## The E over the body this machine's player could revive: in reach, and
## nobody on it yet.
func _show_prompt() -> void:
	var mine: PlayerType = _game.local_player()
	var over: PlayerType = null
	if mine != null and not mine.is_down() and not _game.is_travelling():
		var reach := PlayerType.REVIVE_RANGE
		for body: PlayerType in _game.party():
			if body == mine or not body.is_down() or reviver_of(body) != null:
				continue
			var d := mine.global_position.distance_to(body.global_position)
			if d <= reach:
				reach = d
				over = body
	_prompt.over(over)
