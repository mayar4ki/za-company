extends Node2D
## A room's SECOND BEAT: a small authored group that walks in through a door
## once enough of the opening arrangement is dead - or, on a boss floor, once
## the boss is down to a named share of his health. See `_due()` for why those
## are two cues rather than one with an option.
##
## ## Why this is not waves
##
## A room here is an ARRANGEMENT, not a population. The content studio is three
## overlapping drain fields you route around; asset recovery is four boys behind
## a colonnade of dividers you pull one at a time; the executive floor is one
## 64 px gap you have to choose to step through. All three fights are made of
## WHERE the enemies are, and a stream of respawns flattens every one of them
## into the same fight - because a room's shape only matters while its enemies
## are placed.
##
## So this is deliberately finite and deliberately authored: one or two beats
## per floor, each a named group arriving from a named door at a known cue. The
## room clears, and once clear it stays clear. Nothing here loops, nothing here
## escalates, and no floor gets a beat unless its lesson wants restating - see
## tools/biomes.gd for which do.
##
## A BOSS floor is the exception to "not waves" being about arrangements, and it
## is the one place a beat is not a second thought about a room's shape: an
## arena has no arrangement to flatten, and an add arriving at a health
## threshold is a PHASE of the one fight rather than noise standing in it from
## the first frame. `_due()` is what makes that cue reachable.
##
## ## The one thing a reinforcement has that a placement does not
##
## It has no position. Everything in `enemies` in a biome is an authored
## `at` - a spot picked against sight radii, the door line and the clear lanes -
## and you cannot multiply a spot. A reinforcement instead names a SPAWN MARKER
## (`from`, defaulting to "start", the south door you walked in by) and asks the
## level for it, so the only thing it needs to know is which way people arrive.
##
## That is what makes this the right place for the game to scale with how many
## players are in it. The count itself is game/heads.gd, shared with the one
## other thing that reads it - Ivan hands out a heart per head - because two
## definitions of how big the party is would drift the day there are two of
## them.
##
## ## No signals, for the reason the doors have none
##
## Nothing tells this node an enemy died. It counts the `enemies` group, exactly
## as a door asks whether its room is beaten, so nobody has to find
## anybody at the right moment and a room built without a beat simply has no
## node. Deaths are a `queue_free()` in enemy_base.gd and there is no death
## signal to hang off; counting is not a workaround for that, it is the same
## ask-don't-listen shape the rest of the level layer already uses.
##
## The health cue is the same shape one step further: it ASKS the boss what he
## has left, rather than the boss learning that a floor has a beat on it. That
## is the whole reason this is ten lines here instead of a summon hook on
## boss_base.gd - a summon would need its own release interval, its own doorway
## hold and its own head count, all of which are already in this file.

## Arrivals are single file, this far apart. A doorway is single file, so a pair
## walking in one after the other is both what the fiction says and what keeps
## two bodies from landing in the same 16 px of threshold.
const RELEASE_INTERVAL := 0.6

## An arrival holds while the player is this close to the threshold. Dropping an
## enemy on top of somebody is the one thing a spawn must never do, and standing
## in the doorway is exactly where a player who has just cleared three quarters
## of a room tends to be. The hold is indefinite and costs nothing: they move,
## the beat lands.
const SAFE_RADIUS := 64.0

const ENEMY_SCENE := "res://game/enemies/%s/%s.tscn"

const Heads := preload("res://game/heads.gd")
const RoomClear := preload("res://game/levels/room_clear.gd")

## Authored per floor as `reinforcements` in tools/biomes/<level>.gd and written
## in by build_levels.gd. One dictionary per beat, in the order they fire:
##
##   after_kills     how many of this room's dead it waits for
##   at_boss_fraction  INSTEAD of after_kills, on a boss floor: the share of
##                   his max health he has to be down to (0.5 = half). See
##                   `_due()`
##   from            the spawn marker they walk in through ("start" = south
##                   door); a floor can name markers of its own under `spawns`
##   enemies         the base group, in release order - no positions, see above
##   per_head        added once per head BEYOND the first, in release order
##
## **`enemies` is fixed and only `per_head` scales, and that split is the whole
## reason there are two lists.** Multiplying one list gave every extra player a
## copy of every type in the beat - which on a boss floor means a second
## `call_center`, and two of those do not stack a slow, they REFRESH it. Two
## slowers is a player who is slowed permanently, and being slowed through a
## telegraph you could otherwise sidestep is the one thing here that reads as
## unfair rather than hard. So a beat now says outright which bodies a crowd
## brings, and `call_center` is in no floor's `per_head`.
##
## It also makes the head count matter MORE, not less: a beat can hand a solo
## player the arrangement it was tuned for and still answer a party of four,
## instead of every number being a multiple of the solo one.
@export var waves: Array = []

## The room as built, counted on the first frame rather than in _ready: callers
## add a level and ask it questions in the same frame, so this node's _ready is
## not a moment at which the room is reliably finished being one.
var _population := -1
var _released := 0
var _next := 0
var _queue: Array[String] = []
var _from: StringName = &"start"
var _cooldown := 0.0


func _process(delta: float) -> void:
	# The host's beat. A guest's room gets every arrival from the host's own
	# snapshot (game/sync/world.gd), so a second door opening here would be a
	# second set of bodies.
	if not multiplayer.is_server():
		return
	if _population < 0:
		_population = _alive()
		return
	_release(delta)
	# One beat resolves before the next is looked at: a queue still emptying is
	# a beat that has not landed yet, and firing the one after it would stack
	# two arrivals into the same doorway.
	if _next >= waves.size() or not _queue.is_empty():
		return
	var wave: Dictionary = waves[_next]
	if not _due(wave):
		return
	_next += 1
	_from = StringName(wave.get("from", "start"))
	# The interval spaces arrivals WITHIN a beat and must never delay the start
	# of one: left alone it still holds whatever the last release set, so a beat
	# would inherit the previous beat's wait before its own first body. The
	# first one through the door goes as soon as the door is clear.
	_cooldown = 0.0
	# The base group arrives whatever the head count, and `per_head` is added
	# once per head BEYOND the first. See the export doc for why the two lists
	# are not one list multiplied.
	for type in wave.get("enemies", []):
		_queue.append(String(type))
	for _extra in Heads.count(get_tree()) - 1:
		for type in wave.get("per_head", []):
			_queue.append(String(type))


## Lets one enemy through per RELEASE_INTERVAL, oldest first.
func _release(delta: float) -> void:
	if _queue.is_empty():
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var at := _threshold()
	if _crowded(at):
		return
	_spawn(_queue.pop_front(), at)
	_cooldown = RELEASE_INTERVAL


func _spawn(type: String, at: Vector2) -> void:
	var scene := load(ENEMY_SCENE % [type, type]) as PackedScene
	if scene == null:
		push_warning("%s: no enemy scene for reinforcement type '%s'"
			% [get_parent().name, type])
		return
	var enemy := scene.instantiate() as Node2D
	_released += 1
	enemy.name = "Reinforcement%d" % _released
	# Into Props, where the placed enemies already are: that is the Y-sorted
	# branch, and an enemy outside it draws through the furniture.
	get_parent().get_node("Props").add_child(enemy)
	enemy.global_position = at
	# And no post. A placed enemy keeps a leash around the spot it was placed
	# on, so that a cleared room is still the arrangement it was authored as;
	# this one was never authored anywhere - it came through a door to find the
	# player, and the only thing it could be leashed to is the doorway.
	if enemy.has_method("unleash"):
		enemy.call("unleash")


## Whether every beat this floor has is spent: nobody still to walk in, and no
## beat left whose cue can still come. Asked rather than announced, like
## everything else here - the room's doors and game/levels/relief.gd both need
## to know the fight is over and not merely quiet (room_clear.gd), and a room
## in the gap between two beats is quiet.
func spent() -> bool:
	if not _queue.is_empty():
		return false
	if _next >= waves.size():
		return true
	# Not counted yet, so nothing can be said about what is still to come.
	if _population < 0:
		return false
	return not _can_come(waves[_next])


## Whether `wave`'s cue can still arrive. Beats fire in order, so the next one
## being out of reach puts every one after it out of reach too - and a beat that
## can never come must not count as one still owed: the doors are shut until
## the room is beaten, and a door waiting on a beat that will never land is a
## run that has ended without saying so.
##
## Two ways for a cue to be out of reach. A health cue dies with the boss's
## concede: he gives in AT zero and `_due()` stops asking once he has, so a blow
## that takes him from above a threshold to nothing leaves that beat unfired for
## good (deliberately - kill him that fast and he does not get to call
## security). And a kill cue needs somebody left to kill: with nobody standing,
## `_killed()` is as high as it will ever get.
func _can_come(wave: Dictionary) -> bool:
	if _due(wave):
		return true
	if wave.has("at_boss_fraction"):
		var boss := get_parent().get_node_or_null("Props/Boss")
		return boss != null and boss.get("has_conceded") != true
	return RoomClear.standing(get_tree()) != null


## Where this beat walks in. Asked of the level by name through has_method, the
## same way everything else here avoids typing a level: `spawn_position` falls
## back to the middle of the room on an unknown marker, which is survivable, so
## a typo in biome data costs a bad entrance rather than a crash.
func _threshold() -> Vector2:
	var level := get_parent()
	if level != null and level.has_method("spawn_position"):
		return level.call("spawn_position", _from)
	return global_position


func _crowded(at: Vector2) -> bool:
	for player in get_tree().get_nodes_in_group("player"):
		var body := player as Node2D
		if body != null and body.global_position.distance_to(at) < SAFE_RADIUS:
			return true
	return false


## Whether this beat's cue has come. A beat is cued by KILLS by default and a
## boss floor's by the boss's HEALTH instead, and the two are alternatives
## rather than an option because they are the same question asked of the only
## two things a room can be counting down.
##
## `after_kills` cannot serve a boss floor, which is why the second cue exists.
## A boss is in the `enemies` group and is never freed - he is still standing in
## the room when you leave - so he inflates the population by one and never
## subtracts, and `_killed()` therefore reports only the adds. On a floor whose
## whole population is one boss the only number it can reach is 0, and a beat
## cued at 0 is a placement that walks in through a door, which is worse than a
## placement: it lands while the player is still reading the room.
##
## Asked of the boss rather than heard from him, the same way a door finds out
## whether its room is beaten, and for the same reason - nobody has to find
## anybody at the right moment, and a floor with no boss simply never fires.
## The concede guard is load-bearing: he concedes AT zero, which satisfies every
## threshold at once, so without it the last beat of a fight lands on the frame
## the fight ends.
##
## A FRACTION rather than a health number because his health is no longer one
## number: it grows by `health_per_head` with every player beyond the first, and
## an absolute "72" written for a solo Ahmed would fire on a party's at the
## start of the fight instead of at its first quarter.
func _due(wave: Dictionary) -> bool:
	if not wave.has("at_boss_fraction"):
		return _killed() >= int(wave.get("after_kills", 0))
	var boss := get_parent().get_node_or_null("Props/Boss")
	if boss == null or boss.get("has_conceded") == true:
		return false
	return float(boss.get("health")) \
			<= float(wave["at_boss_fraction"]) * float(boss.get("max_health"))


## Everything this room has buried. The count includes what this node has
## already sent in, so killing a reinforcement counts toward the next beat
## exactly as killing a placed enemy does.
func _killed() -> int:
	return _population + _released - _alive()


## A body killed this frame is queued to free and still in the group until the
## frame ends, and it is not alive: counted, the last kill of an arrangement
## would read as one short for a frame, `spent()` would see nobody standing and
## a kill cue not yet due, and the doors would open on the frame that cues the
## beat they should be waiting for.
func _alive() -> int:
	var alive := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		if not node.is_queued_for_deletion():
			alive += 1
	return alive
