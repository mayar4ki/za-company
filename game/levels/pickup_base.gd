extends Area2D
class_name PickupBase
## Base for every level's own heal pickup. Touched by the player, it heals and
## disappears - unless the player is already full, in which case it stays on
## the floor for later. (Later means walking off and back on: body_entered
## only fires on the way in.)
##
## Levels are re-instantiated on every entry, so a consumed pickup is back the
## next time the room loads. Deliberate for now: rooms have no persistent
## state of any kind yet.

## 40, about two and a half of the office boy's 15 - what it was worth when it
## was set at 25 against a guard that hit for 10. Raised on 2026-10-04 so the
## heart kept pace when the blows went up; it does not scale with difficulty,
## which is part of what makes HARD hard.
@export var heal_amount := 40

## The sprite bobs, the node stays put: Y-sort and the collision shape read
## the node position, so only the drawing should move.
const BOB_PIXELS := 1.0
const BOB_HZ := 1.4

@onready var _sprite: Sprite2D = $Sprite2D

var _sprite_rest_y := 0.0
var _time := randf() * TAU


func _ready() -> void:
	_sprite_rest_y = _sprite.position.y
	body_entered.connect(_on_body_entered)
	# Online a pickup is the host's: on a guest the player's heal() refuses it
	# (player.gd's _world_reaches), the host's copy is the one spent, and the
	# room's snapshot takes it away here (game/sync/world.gd). Where it is
	# rides along too, because one Ivan throws is still flying.
	add_to_group(&"synced")


func net_state() -> Array:
	return [global_position, monitoring]


func apply_net_state(state: Array) -> void:
	if state.size() < 2:
		return
	global_position = state[0]
	monitoring = bool(state[1])


## A heart still in the air, between two snapshots (game/sync/world.gd).
func net_between(a: Array, b: Array, weight: float) -> void:
	if a.size() >= 2 and b.size() >= 2:
		global_position = (a[0] as Vector2).lerp(b[0], weight)


func _process(delta: float) -> void:
	_time += delta
	# Rounded so the bob steps whole pixels instead of shimmering between them.
	_sprite.position.y = _sprite_rest_y + roundf(sin(_time * TAU * BOB_HZ) * BOB_PIXELS)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player") or not body.has_method("heal"):
		return
	if body.call("heal", heal_amount):
		queue_free()
