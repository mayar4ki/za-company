extends Node
## The hit-stop, online (DESIGN.md's Multiplayer, M4): the PICTURE held still,
## and the world under it left running.
##
## Solo, a blow that lands slows the whole engine to a twentieth for a few
## hundredths of a second (game.gd's `_freeze`) - the room holding its breath.
## Online that clock is the host's whole world, and stopping it for one
## player's swing would stop it for everybody, fifty times a fight. So online a
## stop holds what is DRAWN and nothing that DECIDES:
##
## - **every animation** in the room stops on the frame it is showing - the
##   swing, the body it hit, this machine's player;
## - **every effect of the hit feel** (`EFFECTS`) stops where it is - the
##   number over the body, the burst, the bolt, the sparks;
## - and nothing else. Bodies keep moving, timers keep counting, an enemy winding
##   up keeps winding up, and the room is exactly as far along as it would have
##   been - which is the whole point.
##
## **Never somebody else's player**, nor anything drawn on it. Its picture is
## its owner's (game/sync/bodies.gd), held by its owner's own stops, and goes on
## gliding through this one - so a held sprite on it was legs frozen mid-stride
## sliding across the floor, every time this machine landed a blow.
##
## **And when it lets go, every animation is CAUGHT UP** by the time it was
## held (`catch_up`). A sprite left behind would be a sprite out of step with
## the body it draws, and a boss's sprite IS his telegraph: four stops inside
## one of his swings would draw the blow landing a third of a second before the
## picture of it. A swing that would have ended inside the stop is stopped just
## short of its last frame instead, so the sprite finishes it itself and says
## so - `animation_finished` is what ends a player's attack.
##
## A stop asked while one is held extends it rather than stacking, exactly as
## the solo one does.

const DamageNumber := preload("res://game/player/damage_number.gd")
const KillBurst := preload("res://game/player/kill_burst.gd")
const SparkBurst := preload("res://game/player/spark_burst.gd")
const StaticCharge := preload("res://game/player/static_charge.gd")
const Shock := preload("res://game/player/shock.gd")
const Arc := preload("res://game/player/arc.gd")
const Supernova := preload("res://game/player/supernova.gd")
const ChargeRing := preload("res://game/player/charge_ring.gd")
const ScreenFlash := preload("res://game/player/screen_flash.gd")
const LandingDust := preload("res://game/enemies/landing_dust.gd")

## The hit feel's effects, by script: what stops with the picture besides the
## animations. Found by script rather than marked, so none of them learns that
## a stop exists - one missing from here simply keeps moving through it.
const EFFECTS: Array[Script] = [DamageNumber, KillBurst, SparkBurst, StaticCharge,
	Shock, Arc, Supernova, ChargeRing, ScreenFlash, LandingDust]

## How many stops have held the picture this run - a readout for the suites,
## since a stop is over in a few frames and nothing else would say it happened.
var held := 0
## Node -> [its process mode before the stop, when it was taken].
var _held := {}
## When the stop lets go, on the wall clock - the stop is real time, like the
## solo one, which is timed with its timer ignoring the time scale.
var _until := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Hold the picture for `seconds`, or for longer if a stop already held runs on
## past that.
func hold(seconds: float) -> void:
	var now := _now()
	if _held.is_empty():
		held += 1
	_until = maxf(_until, now + seconds)
	var others := _others()
	for node in get_parent().find_children("*", "", true, false):
		if _held.has(node) or not (node is AnimatedSprite2D or EFFECTS.has(node.get_script())):
			continue
		if others.any(func(body: Node) -> bool: return body.is_ancestor_of(node)):
			continue
		_held[node] = [node.process_mode, now]
		node.process_mode = Node.PROCESS_MODE_DISABLED


## Everybody else's player - see the header.
func _others() -> Array:
	var game := get_parent()
	if not game.has_method("party"):
		return []
	return (game.call("party") as Array).filter(
		func(body: Node) -> bool: return is_instance_valid(body) and body.get("remote") == true)


## Whether a stop is holding the picture now.
func holding() -> bool:
	return not _held.is_empty()


## Let go now - also on every room change and on the way out, so a stop never
## outlives the fight that asked for it.
func release() -> void:
	var now := _now()
	for node in _held:
		if not is_instance_valid(node):
			continue
		node.process_mode = _held[node][0]
		if node is AnimatedSprite2D:
			catch_up(node, now - float(_held[node][1]))
	_held.clear()
	_until = 0.0


func _process(_delta: float) -> void:
	if not _held.is_empty() and _now() >= _until:
		release()


func _exit_tree() -> void:
	release()


## Moves `sprite` on by `seconds` of its own animation, as if it had never
## stopped. A one-shot animation that would have ended in that time is left
## just short of its end, so the sprite ends it itself - see the header.
static func catch_up(sprite: AnimatedSprite2D, seconds: float) -> void:
	var frames := sprite.sprite_frames
	if frames == null or not sprite.is_playing() or seconds <= 0.0:
		return
	var anim := sprite.animation
	var speed := frames.get_animation_speed(anim) * sprite.get_playing_speed()
	var count := frames.get_frame_count(anim)
	if speed <= 0.0 or count == 0:
		return
	var loops := frames.get_animation_loop(anim)
	var frame := sprite.frame
	var progress := sprite.frame_progress
	var left := seconds
	while left > 0.0:
		var length := frames.get_frame_duration(anim, frame) / speed
		if length <= 0.0:
			break
		var rest := (1.0 - progress) * length
		if left < rest:
			progress += left / length
			break
		left -= rest
		if frame + 1 < count:
			frame += 1
			progress = 0.0
		elif loops:
			frame = 0
			progress = 0.0
		else:
			progress = 0.99
			break
	sprite.set_frame_and_progress(frame, progress)


static func _now() -> float:
	return Time.get_ticks_usec() / 1000000.0
