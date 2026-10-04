extends Node2D
## The number that flies up off the player when a blow lands - "-18" in red,
## rising and fading over most of a second.
##
## It was picked off the Silverman attack preview, where it was drawn to make
## the hit checks readable and turned out to be the part worth keeping, so it
## is that preview's drawing shipped verbatim: the same 3x5 digits with a
## one-pixel dark outline, the same red, 14 px a second of rise, solid for half
## a second and gone by 0.8. A pixel font drawn as rects rather than a Label,
## because a Label's font is antialiased at any size small enough to sit over
## a 32 px body, and this one is the game's own pixels.
##
## **A blow gets its own; a drain's ticks share one.** player.gd spawns one
## from `take_damage()` past the grace window - so a blow the window swallowed
## shows nothing, which is the truth. `drain()` shows too, because health that
## goes with no number on it reads as a missing number rather than as a
## different kind of harm - but a drain lands a point at a time, several a
## second and more with two wraiths on you, so a number per tick is a stack of
## "-1"s on the head. Instead a tick lands on the newest drain number while it
## is still solid (`absorbs()`) and its total climbs, "-1" to "-2"; once that
## one has started to fade the next tick starts a fresh one. A drain therefore
## reads as a steady trickle of small numbers, which is what it is.
##
## It is `top_level`, so it stays where the blow landed while the player walks
## out from under it rather than riding along like a hat, and it sits at a
## high `z_index` so a prop the player is standing behind cannot hide it. It
## frees itself.
##
## **It also flies off the enemies, the other way round.** A blow the PLAYER
## lands puts its amount over the body it hit (`spawn_dealt()`): white for the
## blade, the spark colour for a bolt's jump, double size for the heavy, and
## with no minus sign - the minus is what says the number is yours to lose. It
## is parented to the body's PARENT rather than the body, because the blow that
## matters most is the one that kills, and that body is freed on the same
## frame. Picked from the Combo Lab preview with the rest of the hit feel.

## Where it starts, above the body's origin: 6 px over the top of a 32 px cell
## drawn at offset -8, which is where the preview put it.
const RISE_FROM := Vector2(0.0, -30.0)
## World px per second.
const RISE_SPEED := 14.0
const LIFE := 0.8
## Fully opaque until here, then linear to nothing at LIFE.
const FADE_FROM := 0.5
const COLOUR := Color("ff7a7a")
const OUTLINE := Color("07080c")
## Above everything standing in a room.
const Z := 50

## 3x5 glyphs, row-major, "1" is ink. Only what a damage number can spell.
const GLYPHS := {
	"0": "111101101101111", "1": "010110010010111", "2": "111001111100111",
	"3": "111001111001111", "4": "101101111001001", "5": "111100111001111",
	"6": "111100111101111", "7": "111001001001001", "8": "111101111101111",
	"9": "111101111001111", "-": "000000111000000", "+": "000010111010000",
}

## What it says. Set by `spawn()` and `add()`; read by tests.
var text := ""
## How it is drawn. The defaults are the player's own red "-N"; `spawn_dealt()`
## sets them for a number over an enemy.
var colour := COLOUR
var outline := OUTLINE
var prefix := "-"
## Screen pixels per glyph pixel. The outline stays one pixel at any size.
var size := 1
var _amount := 0
var _age := 0.0


## One number for a blow of `amount`, over `body`. Parented to the body so it
## goes wherever the body's world goes (a door swaps the level, not the
## player), but top-level so it does not follow the body about.
static func spawn(body: Node2D, amount: int) -> Node2D:
	var node: Node2D = (load("res://game/player/damage_number.gd") as GDScript).new()
	node.add(amount)
	node.top_level = true
	node.z_index = Z
	body.add_child(node)
	node.global_position = (body.global_position + RISE_FROM).round()
	return node


## A blow the player landed, over the enemy it landed on. See the header.
static func spawn_dealt(body: Node2D, amount: int, ink: Color, edge: Color,
		pixel := 1) -> Node2D:
	var node: Node2D = (load("res://game/player/damage_number.gd") as GDScript).new()
	node.colour = ink
	node.outline = edge
	node.prefix = ""
	node.size = pixel
	node.add(amount)
	node.top_level = true
	node.z_index = Z
	body.get_parent().add_child(node)
	node.global_position = (body.global_position + RISE_FROM).round()
	return node


## Health given back over `body` - a revive's +50 - in `ink` with a plus, and
## otherwise exactly the player's own number: parented to the body, top-level.
static func spawn_healed(body: Node2D, amount: int, ink: Color, edge: Color) -> Node2D:
	var node: Node2D = (load("res://game/player/damage_number.gd") as GDScript).new()
	node.colour = ink
	node.outline = edge
	node.prefix = "+"
	node.add(amount)
	node.top_level = true
	node.z_index = Z
	body.add_child(node)
	node.global_position = (body.global_position + RISE_FROM).round()
	return node


## Whether another drain tick should land on this number rather than start its
## own: only while it is still fully opaque, so a total never changes on a
## number that is already leaving.
func absorbs() -> bool:
	return _age < FADE_FROM and not is_queued_for_deletion()


func add(amount: int) -> void:
	_amount += amount
	text = "%s%d" % [prefix, _amount]
	queue_redraw()


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var alpha := 1.0 - clampf((_age - FADE_FROM) / (LIFE - FADE_FROM), 0.0, 1.0)
	var width := (text.length() * 4 - 1) * size
	var origin := Vector2(-floorf(width / 2.0), -roundf(_age * RISE_SPEED))
	var ink := Color(colour, alpha)
	var edge := Color(outline, alpha)
	var dot := Vector2(size, size)
	# Outline first, everywhere, then the ink over it - so where two strokes'
	# outlines overlap a neighbour's ink, the ink wins.
	for pass_ink in [false, true]:
		for i in text.length():
			var glyph: String = GLYPHS.get(text[i], "")
			for k in glyph.length():
				if glyph[k] != "1":
					continue
				var at := origin + Vector2(i * 4 + k % 3, floori(k / 3.0)) * size
				if pass_ink:
					draw_rect(Rect2(at, dot), ink)
				else:
					for off in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
						draw_rect(Rect2(at + off, dot), edge)
