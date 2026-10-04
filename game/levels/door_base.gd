extends Area2D
class_name DoorBase
## Base for every level's own door scene: the one thing doors must agree on is
## how they tell game.gd that the player walked into them.
##
## Each level owns its `door.tscn` outright - its own art, collision and extra
## nodes - and a level that needs different behaviour (a lock, a key, a one-way
## passage) writes its own script extending this one and swaps it in. Only the
## `travelled` handshake has to stay the same, because game.gd is what does the
## swapping.
##
## The doorway sits in a gap cut through the wall ring, so the scene carries its
## own `Seal` body across that gap: the map stays closed whether or not the
## transition fires, and that same body is what keeps a locked door solid.
##
## **A room is sealed until it is beaten** - both of its doors, the way up and
## the way back down: nobody hostile standing, and no beat still to come
## (room_clear.gd). Until then the party walks into the threshold and nothing
## happens. On a boss floor that is the boss, who stops counting the moment he
## concedes, so the arena's gate is the same rule as every other room's. The
## lobby has nobody in it and is open from its first frame.
##
## **And it says so** (door_lock.gd): a lamp on each jamb and a padlock in the
## doorway, red while sealed and green once the room is beaten. What they show
## is `sealed()`, and online that is the HOST's word: a guest's room cannot
## work out "beaten" for itself, because the beats only run on the host, so the
## door rides the room's snapshot (game/sync/world.gd) carrying the host's
## answer, and a guest's door shows that.
##
## **A door waits for the party.** It goes only once every STANDING player is
## in the doorway, and says so meanwhile ("1/2", door_count.gd). Standing is
## the `player` group: a body that is down has left it (player.gd's
## knock_down), so the door neither waits for one nor counts one, and game.gd
## carries it through with everybody else. Solo, one player in the doorway is
## the whole party and the door goes the moment they step in, as it always has.

signal travelled(level_path: String, spawn: StringName)

const DoorCount := preload("res://game/levels/door_count.gd")
const DoorLock := preload("res://game/levels/door_lock.gd")
const RoomClear := preload("res://game/levels/room_clear.gd")
## Where the count stands, from the door's origin and turned with it: into the
## room, past the threshold, so it is in front of whoever is waiting.
const COUNT_AT := Vector2(0, 30)

@export_file("*.tscn") var target_level: String
## Name of the Marker2D under the destination level's Spawns node.
@export var target_spawn: StringName = &"start"
## Which of the level's doorway textures this instance wears.
@export var art: Texture2D

## Latched because the threshold sits right against a solid seal: without it, a
## player nudged back onto it mid-fade would queue a second travel. Physics is
## frozen on the player for that whole fade, so nothing can leave the threshold
## while the latch matters.
var _used := false
## The party members standing in the doorway now.
var _inside := {}
var _count: DoorCount
## What the host last said about this room, on a guest: -1 until it has said
## anything, then 1 sealed or 0 open.
var _host_sealed := -1


func _ready() -> void:
	$Sprite2D.texture = art
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_count = DoorCount.new()
	_count.name = "Count"
	_count.top_level = true
	_count.z_index = 50
	_count.visible = false
	add_child(_count)
	# After the sprite in the tree, so it draws over the doorway art; it turns
	# with the door and is drawn with it, so a player in the doorway stands in
	# front of it.
	var lock := DoorLock.new()
	lock.name = "Lock"
	add_child(lock)
	add_to_group(&"synced")


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_inside[body] = true
	_consider()


## Stepping off the threshold re-arms the door, and the case that needs it is
## not the obvious one: a level is swapped in while the arriving player still
## carries the position they had when the LAST door fired, which for two doors
## in the same place in both rooms is right on top of this one. That fires the
## new level's door during the transition, where game.gd is still travelling and
## drops it - so without re-arming, the door ahead of you is spent before you
## ever walk to it, and the chain dead-ends at the second room.
func _on_body_exited(body: Node2D) -> void:
	# Out of the count whether or not it is still a player: one that went down
	# standing here left the group first, and still has to leave the doorway.
	_inside.erase(body)
	if body.is_in_group("player"):
		_used = false
	_consider()


## Asked every frame somebody is waiting, and not only when somebody arrives,
## because the party can become complete without anyone moving: the one player
## still out in the room goes down, and everyone left is already here.
func _physics_process(_delta: float) -> void:
	if not _inside.is_empty():
		_consider()


func _consider() -> void:
	var here := 0
	for body in _inside.keys():
		if not is_instance_valid(body):
			_inside.erase(body)
		elif (body as Node).is_in_group("player"):
			here += 1
	var standing := get_tree().get_nodes_in_group("player").size()
	if here == 0 or here >= standing:
		_count.visible = false
	else:
		_count.global_position = to_global(COUNT_AT).round()
		_count.show_count(here, standing)
	if here > 0 and here >= standing and not _used and can_travel():
		_used = true
		travelled.emit(target_level, target_spawn)


## Whether the door will go: once the room is beaten, and not before. Asked on
## every attempt rather than told, so the door and the last body in the room
## never have to find each other at the right moment - and because a door asks
## every frame somebody is standing in it, a party already waiting in the
## doorway goes the frame the room is won, without stepping off and on again.
##
## The level is the door's `owner`: build_levels.gd places every door in the
## level scene, so that is what instancing a level makes it. Still the override
## point for a door that wants a lock of its own on top.
func can_travel() -> bool:
	return RoomClear.beaten(get_tree(), owner)


## Whether the room this door leads out of is still sealed - what its lamps and
## padlock show. On the host, and solo, that is can_travel() turned round. A
## guest shows what the host last said, and works it out itself only until the
## first snapshot arrives - which on a floor with enemies standing in it agrees.
func sealed() -> bool:
	if _host_sealed >= 0 and not multiplayer.is_server():
		return _host_sealed == 1
	return not can_travel()


## The room's snapshot (game/sync/world.gd): a door is placed by the level, so
## it is at the same path on every machine and carries only the host's answer.
func net_state() -> Array:
	return [sealed()]


func apply_net_state(state: Array) -> void:
	if not state.is_empty():
		_host_sealed = 1 if bool(state[0]) else 0


## Nothing to draw between two snapshots. Answered anyway, because a synced
## thing that answers it takes its state WITH the picture rather than when it is
## heard (world.gd's _show): a door taking it a tenth of a second early would
## open on a guest's screen before the last body there is drawn falling.
func net_between(_a: Array, _b: Array, _weight: float) -> void:
	pass
