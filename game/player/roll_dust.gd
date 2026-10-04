extends Node2D
## One puff of a roll's dust: kicked up behind the roll as it starts, left
## under it every DUST_EVERY seconds while it tumbles, and thrown ahead of it as
## it stands up (player.gd's *The dodge*). The Dodge Lab preview's `Puff`, as
## the page drew it: a soft grey ellipse that drifts on its own velocity, slows
## by a tenth a frame, rises 3 px and thins out over its life.
##
## The same puff landing_dust.gd throws two of when a juggled body lands -
## same ink, same blob, same 0.35 s - with a velocity of its own instead of a
## fixed spread. A neighbour rather than that file bubbled up, on
## player_audio.gd's terms: a roll asks for one puff at a time, aimed.
##
## Left in the body's parent rather than on the body, so the roll leaves its
## dust behind it, and top-level, which draws it over the bodies the way the
## page did. Ticks on the physics clock, the page's 60 a second.

const LIFE := 0.35
const INK := Color(200 / 255.0, 196 / 255.0, 210 / 255.0)
## The share of its speed a puff keeps each frame.
const DECAY := 0.9

var _at := Vector2.ZERO
var _velocity := Vector2.ZERO
var _life := LIFE
var _age := 0.0


## A puff at `at` in world pixels, drifting at `velocity` px/s.
static func kick(body: Node2D, at: Vector2, velocity: Vector2, life := LIFE) -> void:
	var world := body.get_parent()
	if world == null:
		return
	var node: Node2D = (load("res://game/player/roll_dust.gd") as GDScript).new()
	world.add_child(node)
	node.top_level = true
	node.global_position = Vector2.ZERO
	node._at = at
	node._velocity = velocity
	node._life = life


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= _life:
		queue_free()
		return
	_at += _velocity * delta
	_velocity *= DECAY
	queue_redraw()


func _draw() -> void:
	var t := _age / _life
	_blob(_at + Vector2(0, -t * 3.0), 3.0 + t * 5.0, 2 + roundi(t * 2.0),
		Color(INK, 0.55 * (1.0 - t)))


## A soft pixel ellipse, row by row - landing_dust.gd's, line for line.
func _blob(centre: Vector2, w: float, h: int, ink: Color) -> void:
	for j in h:
		var k := 1.0 - absf((j + 0.5) / h * 2.0 - 1.0)
		var ww := maxf(1.0, roundf(w * (0.55 + 0.45 * k)))
		draw_rect(Rect2(roundf(centre.x - ww / 2.0), roundf(centre.y - h / 2.0 + j), ww, 1), ink)
