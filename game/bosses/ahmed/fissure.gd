extends "res://game/bosses/ahmed/fx_node.gd"
## The FISSURE CHOP's second half: the blade bites the floor, a crack runs on
## ahead of it, and a row of fire pillars bursts up along the crack.
##
## The chop asks you to get out of its reach; this is what makes WHICH way
## matter. Backing straight off - the obvious answer to an overhead - walks
## you down the crack, and the pillars come up under you. Step to the side.
##
## Spawned by ahmed.gd on the chop's impact frame, at his feet, facing his
## way. The preview's numbers: a 73 px crack from 17 px in front of him, laid
## in 0.35 s; seven pillars 11 px apart from 24 px, 0.06 s apart from 0.45 s,
## each up for 0.4 s. The fire on the axe itself - the geyser where the blade
## lands - is still axe_fire.gd's, off the chop's own frames.
##
## It hurts the way the wave does: one hit per body for the whole fissure,
## to anyone standing on the line when a pillar comes up under them - office
## boys included.

const CRACK_FROM := 17.0
const CRACK_RUN := 73.0
const CRACK_SECONDS := 0.35
const PILLARS := 7
const PILLAR_FROM := 24.0
const PILLAR_GAP := 11.0
const PILLAR_AT := 0.45
const PILLAR_STEP := 0.06
const PILLAR_UP := 0.4
const PILLAR_HEIGHT := 15.0
## How close to a pillar a body must stand to be burned by it: half the gap
## across the line, and the crack's own wobble plus a body's width along it.
const HIT_ALONG := 5.0
const HIT_ACROSS := 7.0
## A pillar only burns while it is properly up, not on its first or last pixel.
const HIT_FROM := 0.3

var damage := 8
var _hit := {}


func _ready() -> void:
	life = 1.95
	super()


## Local forward distance to a drawn x, mirrored the way axe_fire.gd mirrors:
## a pixel at local x lands at -1 - x when he faces left.
func _x(forward: float) -> float:
	return forward if dir > 0.0 else -1.0 - forward


func _tick(_delta: float) -> void:
	for k in PILLARS:
		var tk := PILLAR_AT + k * PILLAR_STEP
		if _t < tk or _t >= tk + PILLAR_UP or sin(PI * (_t - tk) / PILLAR_UP) < HIT_FROM:
			continue
		var at := PILLAR_FROM + k * PILLAR_GAP
		for body in _targets():
			if _hit.has(body) or _untouchable(body):
				continue
			var rel: Vector2 = body.global_position - anchor
			if absf(rel.y) <= HIT_ACROSS and absf(rel.x * dir - at) <= HIT_ALONG:
				_hit[body] = true
				body.call("take_damage", damage)


func _draw() -> void:
	var t := _t
	var fr := clampf(t / CRACK_SECONDS, 0.0, 1.0) * CRACK_RUN
	var fade := Kit.seg(t, 1.3, 1.9)
	var gone := Kit.seg(t, 1.9, 1.93)
	for i in int(fr) + 1:
		var f := CRACK_FROM + i
		var x := _x(f)
		var y := Kit.rnd((Kit.h(int(f) >> 1, 7) - 0.5) * 2.4)
		if fade >= 1.0:
			if Kit.h(f, 3) > gone:
				Kit.px(self, x, y, Kit.SCORCH)
			continue
		var age := t - i / CRACK_RUN * CRACK_SECONDS
		var col: Color
		if age < 0.12:
			col = Kit.R[0]
		elif age < 0.5:
			col = Kit.R[1]
		else:
			col = Kit.R[2 + int(Kit.h(f, floorf(t * 10.0)) * 2.0)]
		if fade > 0.0 and Kit.h(f, 5) < fade:
			col = Color("3c1612")
		Kit.px(self, x, y, col)
		if Kit.h(f, 9) > 0.82:
			Kit.px(self, x, y + (1 if Kit.h(f, 4) > 0.5 else -1), col)
	for k in PILLARS:
		var tk := PILLAR_AT + k * PILLAR_STEP
		if t >= tk and t < tk + PILLAR_UP:
			Kit.flame(self, _x(PILLAR_FROM + k * PILLAR_GAP), 0,
				3 + PILLAR_HEIGHT * sin(PI * (t - tk) / PILLAR_UP), 3, t, k * 13)
