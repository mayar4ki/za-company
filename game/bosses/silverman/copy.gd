extends Node2D
## THE SPLIT's other half. A seam runs down Silverman, and there are two of
## him; this is the one that walks.
##
## It is **not a body and not an add**, and keeping that true is the whole job
## of this file. It is in no group, it has no health, no bar, no collision and
## nothing to interrupt, it cannot be hit, and it is gone a second and a half
## after it arrived. A boss floor's real adds arrive on `at_boss_fraction` and
## are enemies; two systems that put fighters in a room is one too many, so
## this one puts a THREAT in the room instead: something that occupies ground
## and costs you once for standing where it is going.
##
## **It costs no art.** What it draws is `ghost_side` - the dulled body already
## sitting on his sheet for smear.gd to stamp - so a copy of him is a copy of
## him by construction, one rung down, which is exactly how a reflection of a
## man made of metal ought to read. Nothing here knows what he looks like.
##
## It is drawn one rung down rather than tinted for the reason the smear is:
## his look is six exact values and a modulate is a multiply that lands
## between two of them. Alpha is fine - that is blending against the room, not
## bending his ramp - and is what the collapse spends.

## The row it wears. Never played by the boss himself.
const GHOST_ANIM := "ghost_side"

## Out of him, then at you, then back into him. The three add up to its life.
const EMERGE := 0.30
const WALK := 1.20
const COLLAPSE := 0.30
## How far out of him it steps before it starts walking.
const STEP_OUT := 22.0
## Half the player's 90, like every other body of his - it closes, it does not
## chase.
const SPEED := 54.0
## Close enough to have arrived. His own body radius, near enough.
const REACH := 11.0

var _boss: Node2D
var _damage := 0
var _dir := 1.0
var _from := Vector2.ZERO
var _time := 0.0
var _spent := false
var _sprite: AnimatedSprite2D


## Everything it is ever told, and it is told it once: who cast it, what the
## blow is worth (already scaled by the base, like every attack's), and which
## way he was facing when he divided.
func cast(boss: Node2D, damage: int, facing: float) -> void:
	_boss = boss
	_damage = damage
	_dir = facing
	_from = global_position
	_sprite = boss.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D


func _process(delta: float) -> void:
	# He never outlives the man who cast him: a conceding boss takes his own
	# reflection down with him.
	if _boss == null or not is_instance_valid(_boss) or _boss.get("has_conceded"):
		queue_free()
		return
	_time += delta
	if _time >= EMERGE + WALK + COLLAPSE:
		queue_free()
		return
	if _time > EMERGE and _time < EMERGE + WALK:
		_walk(delta)
	elif _time <= EMERGE:
		# Out of him sideways, which is the only part of this that is not
		# walking - it is still half inside him at the start.
		var out := STEP_OUT * (_time / EMERGE)
		global_position = _from + Vector2(out * _dir, 0.0)
	queue_redraw()


## At the player, and through them exactly once. It goes in via take_damage(),
## so the grace window meters it against everything else in the room like any
## other blow - a copy of him is not a special case. Which player is HIS
## answer, asked every frame: a copy of him is after whoever he is after.
func _walk(delta: float) -> void:
	var player := _boss.call("target") as Node2D
	if player == null:
		return
	var to_player := player.global_position - global_position
	var distance := to_player.length()
	if distance > REACH:
		global_position += (to_player / maxf(distance, 0.001)) * SPEED * delta
		_dir = signf(to_player.x) if absf(to_player.x) > 0.01 else _dir
		return
	if _spent or not player.has_method("take_damage"):
		return
	# Rolling through it is not being reached by it: it is spent on a blow that
	# can land, so it keeps coming for the rest of its walk (player.gd's
	# `untouchable()`).
	if player.has_method("untouchable") and bool(player.call("untouchable")):
		return
	_spent = true
	player.call("take_damage", _damage)


func _draw() -> void:
	if _sprite == null:
		return
	var frames := _sprite.sprite_frames
	if frames == null or not frames.has_animation(GHOST_ANIM):
		return
	var tex := frames.get_frame_texture(GHOST_ANIM, 0)
	if tex == null:
		return
	# The same corner smear.gd stamps at, for the same reason: the sheet's
	# cell is 64 px and his sprite offset is what stands its feet on the
	# origin. Mirrored about that origin when it faces left, which is what
	# flip_h does on the boss himself.
	var size := tex.get_size()
	var corner := Vector2(-size.x * 0.5, _sprite.offset.y - size.y * 0.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1.0 if _dir < 0.0 else 1.0, 1.0))
	draw_texture(tex, corner, Color(1.0, 1.0, 1.0, _alpha()))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Half-there while it climbs out of him, solid while it walks, and spent on
## the way back in.
func _alpha() -> float:
	if _time <= EMERGE:
		return 0.35 + 0.6 * (_time / EMERGE)
	var left := EMERGE + WALK + COLLAPSE - _time
	if left < COLLAPSE:
		return 0.95 * (left / COLLAPSE)
	return 0.95
