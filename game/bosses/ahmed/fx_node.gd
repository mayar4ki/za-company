extends Node2D
## What every one of Ahmed's thrown-off effects is: a node that is HIS child,
## so it draws in his slot in the room's y-sort exactly like the fire on his
## axe, but that stays pinned to the patch of floor it was born on while he
## walks away from it. It keeps its own clock from the frame it is spawned,
## and frees itself when that clock passes `life`.
##
## Spawned by ahmed.gd's `_spawn_fx`, which sets `boss`, `anchor` and `dir`
## (+1 facing right, -1 left) before adding it. A subclass draws in `_draw`
## from `_t` and, if it can hurt anybody, does that from `_tick`.

const Kit := preload("res://game/bosses/ahmed/fx_kit.gd")

var boss: Node2D
var anchor := Vector2.ZERO
var dir := 1.0
## Seconds this node lives for. Subclasses set it.
var life := 1.0

var _t := 0.0


func _ready() -> void:
	global_position = anchor


func _process(delta: float) -> void:
	_t += delta
	# Re-pinned every frame because the parent moves; the anchor does not.
	global_position = anchor
	_tick(delta)
	if _t >= life:
		queue_free()
		return
	queue_redraw()


func _tick(_delta: float) -> void:
	pass


## Everybody who could be standing in this: the player and every enemy - his
## office boys included, on the slam's own rule - but never Ahmed himself.
func _targets() -> Array:
	var out: Array = []
	for group in ["player", "enemies"]:
		for body in get_tree().get_nodes_in_group(group):
			if body != boss and body is Node2D and body.has_method("take_damage") \
					and not out.has(body):
				out.append(body)
	return out


## Whether a blow on `body` would miss it now - a player rolling (player.gd's
## `untouchable()`). An effect that hits each body once skips such a body
## WITHOUT counting it as hit, so a lane or a pillar it rolled into still burns
## it once the roll's stretch is over: a roll carries you through, it does not
## spend the attack.
func _untouchable(body: Node) -> bool:
	return body.has_method("untouchable") and bool(body.call("untouchable"))
