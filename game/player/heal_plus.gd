extends Node2D
## One green plus sign floating up off a revive's ring - the Revive Lab
## preview's `Plus`, drawn as the page drew it: a 3 px cross (5 px for a big
## one) in green over a dark edge so it reads on any floor, drifting up, slowing
## and fading out over its last 40%.
##
## `top_level` and parented to the body it rose off, like a damage number: it
## stays where it rose rather than following the body, and goes wherever the
## body's world goes. Above everything standing in a room.

const EDGE := Color(10 / 255.0, 38 / 255.0, 20 / 255.0)
const Z := 50
## Up this fast to start with, give or take, and losing 1.5% of it a frame at
## 60 - the page's step.
const RISE_FROM := 14.0
const RISE_MORE := 8.0
const SIDEWAYS := 6.0
const SLOW := 0.985
const LIFE_FROM := 0.7
const LIFE_MORE := 0.3
const FADE_FROM := 0.6

var big := false
var colour := Color.WHITE
var velocity := Vector2.ZERO
var life := LIFE_FROM
var _at := Vector2.ZERO
var _age := 0.0


## The page's default motion: up at 14-22 px/s, a little either way.
static func drift() -> Vector2:
	return Vector2((randf() - 0.5) * SIDEWAYS, -(RISE_FROM + randf() * RISE_MORE))


static func spawn(body: Node, at: Vector2, is_big: bool, ink: Color, motion: Vector2) -> Node2D:
	var node: Node2D = (load("res://game/player/heal_plus.gd") as GDScript).new()
	node.big = is_big
	node.colour = ink
	node.velocity = motion
	node.life = LIFE_FROM + randf() * LIFE_MORE
	node.top_level = true
	node.z_index = Z
	body.add_child(node)
	node.call("_place", at)
	return node


func _place(at: Vector2) -> void:
	_at = at
	global_position = Vector2(floorf(at.x + 0.5), floorf(at.y + 0.5))


func _process(delta: float) -> void:
	_age += delta
	if _age >= life:
		queue_free()
		return
	_place(_at + velocity * delta)
	velocity.y *= pow(SLOW, delta * 60.0)
	queue_redraw()


func _draw() -> void:
	var t := _age / life
	var a := (1.0 - t) / (1.0 - FADE_FROM) if t > FADE_FROM else 1.0
	var r := 2 if big else 1
	var edge := Color(EDGE, a * 0.75)
	var ink := Color(colour, a)
	for k in range(-r, r + 1):
		draw_rect(Rect2(k - 1, -1, 3, 3), edge)
		draw_rect(Rect2(-1, k - 1, 3, 3), edge)
	for k in range(-r, r + 1):
		draw_rect(Rect2(k, 0, 1, 1), ink)
		draw_rect(Rect2(0, k, 1, 1), ink)
