extends "res://game/bosses/ahmed/fx_node.gd"
## The THREE-WAY WAVE: the fire wave, sent out as a fan of three.
##
## The single wave taught one thing - sidestep, do not backpedal - and a
## player who has learned it steps a long way to the side and is done. Three
## lanes 24 degrees apart move the safe ground to BETWEEN two of them, so the
## sidestep has to be a small one: step a little, not a lot.
##
## Spawned by ahmed.gd on the wave's impact frame, 13 px in front of his feet
## where the blade lands. The preview's numbers: each front runs from 14 px to
## 96 px over 0.6 s, eased out, as a seven-flame wall across its lane, and
## dies over the next quarter second; the scorch it leaves fades by 1.9 s.
##
## It hurts the old wave's way, which is the test's way of saying the lane you
## see is the lane that burns: one hit per body, to anyone in a lane whom its
## front has reached - office boys included.

const ORIGIN := 13.0
const LANES := [-0.42, 0.0, 0.42]
const FROM := 14.0
const RUN := 82.0
const SECONDS := 0.6
const DIES := 0.85
## A lane is three pixels either side of its line; a body is a few more.
const HALF_WIDTH := 3.0
const BODY := 4.0
## Slack past the drawn front, as the old wave had, so a body on the edge of
## the fire is in it.
const SLACK := 6.0

var damage := 15
var _hit := {}


func _ready() -> void:
	life = 1.9
	super()


func _front() -> float:
	return FROM + RUN * Kit.eo(Kit.seg(_t, 0.0, SECONDS))


func _tick(_delta: float) -> void:
	if _t >= DIES:
		return
	var d := _front()
	var origin := anchor + Vector2(ORIGIN * dir, 0.0)
	for body in _targets():
		if _hit.has(body) or _untouchable(body):
			continue
		var rel: Vector2 = body.global_position - origin
		var fwd := rel.x * dir
		for a in LANES:
			var r := fwd * cos(a) + rel.y * sin(a)
			var w := -fwd * sin(a) + rel.y * cos(a)
			if r >= 10.0 and r <= d + SLACK and absf(w) <= HALF_WIDTH + BODY:
				_hit[body] = true
				body.call("take_damage", damage)
				break


## A local point along a lane, mirrored the way axe_fire.gd mirrors when he
## faces left (a pixel at x lands at -1 - x).
func _at(x: float, y: float) -> Vector2:
	return Vector2(x if dir > 0.0 else -1.0 - x, y)


func _draw() -> void:
	var t := _t
	var d := _front()
	var dying := Kit.seg(t, 0.6, DIES)
	var f := Kit.seg(t, 0.9, 1.9)
	for k in LANES.size():
		var a: float = LANES[k]
		var ca := cos(a)
		var sa := sin(a)
		for r in range(10, int(ceilf(d))):
			if Kit.h(r, k, 2) < f:
				continue
			var age := t - (r - 14.0) / RUN * SECONDS
			var p := _at(ORIGIN + ca * r, sa * r)
			Kit.px(self, p.x, p.y, Kit.R[3] if age < 0.5 else Kit.SCORCH)
	if dying >= 1.0:
		return
	for k in LANES.size():
		var a: float = LANES[k]
		var ca := cos(a)
		var sa := sin(a)
		for w in range(-3, 4):
			var p := _at(ORIGIN + ca * d - sa * w, sa * d + ca * w)
			Kit.flame(self, p.x, p.y, (5 - absi(w)) * (1.0 - dying) + 1, 1, t, k * 9 + w)
