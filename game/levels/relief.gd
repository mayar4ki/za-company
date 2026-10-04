extends Node2D
## A room's beats that are NOT fights, and there are two of them. When the floor
## is finally clear, somebody walks in through a door somebody chose, crosses to
## a spot somebody chose, and waits there: Ivan with a heart per head (`relief`),
## or Dominique with what is standing on the next floor up (`briefing`).
##
## ## Two beats, one script, and the script names nobody
##
## This file has never mentioned Ivan outside its comments - the NPC, the door
## and the lines are all data - so the day a second arrival was wanted it cost a
## key in biome data and a node name, and nothing here. The two are told apart
## by ROLE the way the prop shelves are: `Relief` heals, `Briefing` warns, and a
## floor may carry one, the other, or both.
##
## Both firing at once is the normal case rather than the edge one - two of the
## three briefing floors also feed you - which is why a floor that has both
## sends them through OPPOSITE doors. Two arrivals at one threshold is two solid
## bodies in the same sixteen pixels, shoving each other out of it; the doors
## also carry the difference between them, since one has come from where the
## player has been and the other from where they are going.
##
## ## Why it is a beat and not a placement
##
## Standing him in the room from the first frame would make him furniture in a
## fight - a solid 64px body in a room whose enemy positions were picked against
## sight radii and clear lanes, and a heart on offer while the arrangement the
## floor is FOR is still standing. The whole of what makes his healing a
## lifeline rather than a supply is that it arrives after the cost has been
## paid. So he is an arrival, exactly like the bodies in reinforcements.gd, and
## he has an authored destination rather than an authored position for exactly
## the reason they have neither: you cannot walk in at a spot.
##
## It is also why he belongs beside that file instead of inside it. A beat there
## is one question - is the fight far enough along - and this is the opposite
## one: is it over. Threading a friendly body through a script that spawns
## enemies would have cost both of them their one sentence.
##
## ## "Over" has to mean over, on both kinds of floor
##
## What over IS is game/levels/room_clear.gd's, because the room's doors wait
## on the same answer: they open on the frame he sets off, and a friendly face
## walking in to a room still sealed - or a door opening on a room he has not
## yet decided is clear - would be the floor saying two things about itself.
## It skips anybody who has conceded, which is what makes one definition serve
## a boss floor and an ordinary one: a boss is never freed - he is still
## standing in the room when you leave - so counting bodies alone could never
## reach zero on the four floors that have one.
##
## Two more things have to be true before it is over, and each of them was a
## way of getting this wrong:
##
## - **He waits until he has seen a fight.** A room is clear on its first frame
##   too, and an Ivan who walks in before anything has happened is a vending
##   machine in a doorway. `_fought` latches the first frame a hostile is
##   standing, so the cue is a room that has been emptied rather than a room
##   that is empty.
## - **He waits for the beats to be spent.** A floor with reinforcements is
##   quiet between the last kill of the opening arrangement and the arrival of
##   the group it cues, and quiet is not clear. room_clear.gd asks the sibling
##   node (`spent()`), the same ask-don't-listen shape the doors and the beats
##   themselves use - and a floor with no beat simply has no node to ask.
##
## ## The walk can fail, and it is allowed to
##
## NPCs have no pathfinding - they slide off whatever they touch, like the
## enemies do - so a route that clips a plant pot after a prop is nudged would
## otherwise leave him walking into it forever. WALK_TIMEOUT stops him where he
## got to, which costs a slightly wrong spot rather than a heal the player
## cannot reach. The dialogue director guards its own walks the same way and for
## the same reason.
##
## ## He does not start the conversation himself
##
## `greets` exists on npc_base and is deliberately not used here. It fires on
## the talk radius being ENTERED, and somebody walking across the room drags
## that radius over the player on the way - so a greeting would land mid-stride,
## halfway to where they were going. The deeper reason is the lobby's: a
## conversation that starts itself takes the wheel off a player who has not
## pressed anything, and the player has just finished a fight. The prompt over
## his head is the invitation, and taking it is theirs.

const NPC_SCENE := "res://game/npcs/%s/%s.tscn"
const RoomClear := preload("res://game/levels/room_clear.gd")

## How long he may spend crossing the room before he gives up and stands where
## he is. Generous: the longest honest walk on any floor is the full height of a
## room at 45px/s, about seven seconds.
const WALK_TIMEOUT := 12.0

## Authored per floor as `relief` in tools/biomes/<level>.gd and written in by
## build_levels.gd:
##
##   npc      a folder under game/npcs/. Only Ivan heals and only Dominique
##            briefs, and this file knows neither of those things
##   from     the spawn marker they walk in through - "start" is the south door,
##            "returned" the north one a briefing comes down by
##   at       where he stands afterwards, in level pixels
##   say      the .gd of beats he carries (game/dialogue/dialogue_director.gd)
@export var npc := "ivan"
@export var from: StringName = &"start"
@export var at := Vector2.ZERO
@export_file("*.gd") var say := ""

## Latched the first frame this room has somebody standing in it - see the
## header. Until then there has been no fight to be after.
var _fought := false
var _npc: Node2D = null
var _walked := 0.0


func _process(delta: float) -> void:
	# The host's beat. A guest's room gets whoever walks in from the host's
	# snapshot (game/sync/world.gd), so a second one here would be a twin.
	if not multiplayer.is_server():
		return
	if _npc != null:
		_cross(delta)
		return
	if RoomClear.standing(get_tree()) != null:
		_fought = true
		return
	if not _fought or not RoomClear.beats_spent(get_parent()):
		return
	_arrive()


func _arrive() -> void:
	var scene := load(NPC_SCENE % [npc, npc]) as PackedScene
	if scene == null:
		push_warning("%s: no npc scene for relief '%s'" % [get_parent().name, npc])
		set_process(false)
		return
	_npc = scene.instantiate() as Node2D
	_npc.name = npc.to_pascal_case()
	_npc.set("conversation", say)
	# Into Props, where the room's own people already are: that is the Y-sorted
	# branch, and anybody outside it draws through the furniture.
	get_parent().get_node("Props").add_child(_npc)
	_npc.global_position = _threshold()
	_npc.call("walk_to", at)
	_walked = 0.0


## Watches the walk in, and ends it one way or the other.
func _cross(delta: float) -> void:
	_walked += delta
	if bool(_npc.call("walking")) and _walked < WALK_TIMEOUT:
		return
	_npc.call("stop")
	# Turned to face the room he has just walked into rather than left looking
	# whichever way the last step went, which on a spot against a wall is at the
	# wall. The `facing` export every other NPC is placed with is no use to
	# somebody who arrives: it is applied in _ready, before he moves.
	var level := get_parent()
	if level != null and level.has_method("bounds"):
		_npc.call("face_towards", (level.call("bounds") as Rect2).get_center())
	set_process(false)


## Where he comes in. Asked of the level by name through has_method, the same
## way reinforcements.gd avoids typing a level: an unknown marker falls back to
## the middle of the room, so a typo in biome data costs a bad entrance rather
## than a crash.
func _threshold() -> Vector2:
	var level := get_parent()
	if level != null and level.has_method("spawn_position"):
		return level.call("spawn_position", from)
	return global_position
