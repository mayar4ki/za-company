extends "res://tests/helpers.gd"
## Ahmed's attacks, one at a time: what each of them DOES, staged on its own so
## that nothing else he might throw can get in the way. test_bosses.gd runs the
## fight he picks; this file asks the five questions the picks were made for.
##
## - The FISSURE: backing straight off a chop walks you down the crack, and the
##   pillars burn you there even though the axe missed.
## - The SHOVE: a sweep that lands pushes you out of his reach.
## - The LEAP: out of reach and off his fan, he jumps - he is in the air, the
##   ring is on the floor where you stood, and he comes down on it.
## - The FAN's gap: standing between two of the three waves is safe.
## - The CHAIR: keep away from him for three seconds and it comes out, spins,
##   rolls at you, hits, stops, and leaves him sitting there dizzy.
##
## Plus the weight every impact lands with: the hit-stop really slows the room
## and really lets it go again, the shake is asked for, and a star is drawn.
##
## Each stage spawns a FRESH Ahmed - his cooldowns and his alternation are
## state, and a stage that inherited the last one's would be testing the order
## the stages ran in. Stages advance off what he is doing rather than off frame
## numbers, the way test_bosses.gd stages its wave. The room is the empty
## lobby, so he is the only thing in it.

const AHMED := "res://game/bosses/ahmed/ahmed.tscn"
const FissureScript := preload("res://game/bosses/ahmed/fissure.gd")
const ShoveDust := preload("res://game/bosses/ahmed/shove_dust.gd")
const LeapMark := preload("res://game/bosses/ahmed/leap_mark.gd")
const SlamLand := preload("res://game/bosses/ahmed/slam_land.gd")
const FanWave := preload("res://game/bosses/ahmed/fan_wave.gd")
const ChairRun := preload("res://game/bosses/ahmed/chair_run.gd")
const ImpactStar := preload("res://game/bosses/ahmed/impact_star.gd")

## A stage that has not finished by then has failed; the next one runs anyway.
const STAGE_FRAMES := 420

var _boss: Node2D
var _stage := ""
var _since := 0
var _prev := ""
var _note := {}

var _froze := 0
var _froze_seconds := 0.0
var _shook := 0
var _min_scale := 1.0
var _star_seen := false


func _tick(frame: int) -> void:
	match frame:
		2:
			(current_scene.get_node("%PlayButton") as Button).pressed.emit()
		17:
			(current_scene.get_node("%Roster/reem") as Button).pressed.emit()
		32:
			_begin("fissure")
	if _stage == "" or frame < 33:
		return
	_since += 1
	_watch_juice()
	var now: String = _boss.get("attack") if is_instance_valid(_boss) else ""
	var started := now != "" and now != _prev
	_prev = now
	match _stage:
		"fissure":
			_fissure(now, started)
		"shove":
			_shove(now, started)
		"leap":
			_leap(now)
		"fan":
			_fan(now, started)
		"chair":
			_chair(now, started)
		"done":
			_finish()
			_stage = ""
			return
	if _since > STAGE_FRAMES and _stage != "done":
		_check("moves: the %s stage finished in time (%s)" % [_stage, str(_note)], false)
		_next()


# --- staging -----------------------------------------------------------------


const ORDER := ["fissure", "shove", "leap", "fan", "chair", "done"]


func _next() -> void:
	_begin(ORDER[ORDER.find(_stage) + 1])


## A fresh Ahmed at `at`, and the player put back to full.
func _begin(stage: String) -> void:
	_stage = stage
	_since = 0
	_prev = ""
	_note = {}
	if is_instance_valid(_boss):
		_boss.queue_free()
	_boss = null
	_player().call("heal", 100)
	if stage == "done":
		return
	_boss = (load(AHMED) as PackedScene).instantiate() as Node2D
	_level().get_node("Props").add_child(_boss)
	# Wired the way a room wires him, so the hit-stop and the shake go where
	# they would in play: game.gd's own hookup, asked for by name.
	if stage == "fissure":
		_boss.connect("froze", func(s: float) -> void:
			_froze += 1
			_froze_seconds = s)
		_boss.connect("shook", func(_s: float, _t: float) -> void: _shook += 1)
		current_scene.call("_watch_boss")
	match stage:
		"fissure", "shove":
			# Side by side, in reach: the axe's own fight.
			_boss.global_position = Vector2(232, 140)
			_player().global_position = Vector2(260, 140)
			if stage == "shove":
				# The alternation opens on the chop; this stage wants the other.
				_boss.set("_last_melee", "chop")
		"leap":
			# Out of reach and well off his fan - below and to the right.
			_boss.global_position = Vector2(232, 120)
			_player().global_position = Vector2(272, 190)
			_note["target"] = _player().global_position
		"fan":
			# In front of him, in the gap between the middle wave and the low
			# one: 13 px off the middle lane, 12.6 off the 0.42 rad one, where
			# each lane is 3 wide and a body counts 4 more.
			_boss.global_position = Vector2(212, 140)
			_player().global_position = Vector2(272, 153)
			_boss.set("_leap_timer", 99.0)
			_boss.set("_chair_timer", 99.0)
		"chair":
			# A hundred pixels off, square in front of him, and kept there: past
			# the fan's reach, and the leap and the wave are both held off so
			# that the only thing three seconds of keeping away can earn is the
			# chair.
			_boss.global_position = Vector2(172, 140)
			_player().global_position = Vector2(272, 140)
			_boss.set("_leap_timer", 99.0)
			_boss.set("_wave_timer", 99.0)
			# Already introduced, so his hello is not still being spoken - one
			# line at a time - at the moment the chair wants the taunt.
			_boss.set("_spotted", true)
			_boss.connect("said", func(_who: String, text: String, _s: float) -> void:
				if _boss.get("attack") == "chair":
					_note["line"] = text)


func _watch_juice() -> void:
	_min_scale = minf(_min_scale, Engine.time_scale)
	if is_instance_valid(_boss):
		for child in _boss.get_children():
			if child.get_script() == ImpactStar:
				_star_seen = true


func _child_of(script: GDScript) -> Node:
	if not is_instance_valid(_boss):
		return null
	for child in _boss.get_children():
		if child.get_script() == script:
			return child
	return null


# --- the stages ----------------------------------------------------------------


## The chop, with the player stepping straight back the moment it is coming.
func _fissure(now: String, started: bool) -> void:
	if started and now == "chop":
		_check("moves: in reach, the chop comes first", true)
		# Straight back along his line, out of the axe and onto the crack.
		_player().global_position = _boss.global_position + Vector2(60, 0)
	if now == "chop" and _boss.get("phase") == 2 and not _note.has("cracked"):
		_note["cracked"] = _since
		_check("moves: the chop leaves a fissure on the floor",
			_child_of(FissureScript) != null)
		_check("moves: the hit-stop holds the room while it lands (scale %.2f)"
			% Engine.time_scale, Engine.time_scale < 1.0)
		_check("moves: and draws a star where it lands", _star_seen)
	if _note.has("cracked") and _since == _note["cracked"] + 12:
		_check("moves: the hit-stop lets the room go again (scale %.2f)" % Engine.time_scale,
			is_equal_approx(Engine.time_scale, 1.0))
		_check("moves: the stop is asked for by signal, the preview's 0.08 s (%d, %.2f)"
			% [_froze, _froze_seconds], _froze >= 1 and is_equal_approx(_froze_seconds, 0.08))
		_check("moves: and so is the shake (%d)" % _shook, _shook >= 1)
	if _note.has("cracked") and _since == _note["cracked"] + 70:
		# The axe missed; the pillars did not. 8, not 16 and not 24.
		_check("moves: backing straight off, the pillars catch you - 8 (%s)"
			% _player().get("health"), _player().get("health") == 92)
		_next()


## The sweep, landing, and what it does to where you stand.
func _shove(now: String, started: bool) -> void:
	if started and not _note.has("first"):
		_note["first"] = now
		_check("moves: the alternation gives a sweep (%s)" % now, now == "sweep")
	if now == "sweep" and _boss.get("phase") == 2 and not _note.has("hit"):
		_note["hit"] = _since
		_note["gap"] = _boss.global_position.distance_to(_player().global_position)
		_check("moves: the sweep lands 15 (%s)" % _player().get("health"),
			_player().get("health") == 85)
		_check("moves: and kicks up dust where you skid", _child_of(ShoveDust) != null)
	if _note.has("hit") and _since == _note["hit"] + 40:
		var gap: float = _boss.global_position.distance_to(_player().global_position)
		# Touch is r 24 and the body r 5: past 29 is out of his reach.
		_check("moves: the sweep shoves you out of his reach (%.1f -> %.1f px)"
			% [_note["gap"], gap], gap > _note["gap"] + 10.0 and gap > 29.0)
		_next()


## Out of reach, off the fan: the leap, start to landing.
func _leap(now: String) -> void:
	if now == "slam" and _boss.call("is_leaping") and not _note.has("air"):
		_note["air"] = _since
		var mark := _child_of(LeapMark) as Node2D
		_check("moves: out of reach and off his fan, he LEAPS", true)
		# Where you stand as he leaves the ground, not where you stood when
		# the crouch began - the crouch is the time you have to move.
		_check("moves: the ring goes down where you stand as he jumps (%s vs %s)"
			% [mark.global_position if mark else "none", _player().global_position],
			mark != null and mark.global_position.distance_to(_player().global_position) < 1.0)
		if mark != null:
			_note["target"] = mark.global_position
	if _note.has("air") and _since == _note["air"] + 15:
		var sprite := _boss.get_node("AnimatedSprite2D") as Node2D
		_check("moves: he is off the ground mid-leap (%.0f px up)" % -sprite.position.y,
			sprite.position.y < -8.0)
	if now == "slam" and _boss.get("phase") == 2 and not _note.has("landed"):
		_note["landed"] = _since
		var sprite := _boss.get_node("AnimatedSprite2D") as Node2D
		_check("moves: he comes down on the ring (%.1f px off it)"
			% _boss.global_position.distance_to(_note["target"]),
			_boss.global_position.distance_to(_note["target"]) < 2.0)
		_check("moves: and on the floor (%.0f)" % sprite.position.y, sprite.position.y == 0.0)
		_check("moves: with fire where he lands", _child_of(SlamLand) != null)
	if _note.has("landed") and _since == _note["landed"] + 3:
		_check("moves: the ring is gone once he has landed", _child_of(LeapMark) == null)
		_check("moves: standing still in it costs the slam's 20 (%s)"
			% _player().get("health"), _player().get("health") == 80)
		_next()


## Three waves, and the player standing between two of them.
func _fan(now: String, started: bool) -> void:
	if started:
		_check("moves: in front and out of reach, he sends the wave (%s)" % now, now == "wave")
	if now == "wave" and _boss.get("phase") == 2 and not _note.has("sent"):
		_note["sent"] = _since
		var fan := _child_of(FanWave)
		_check("moves: the wave goes out as a fan", fan != null)
	if _note.has("sent") and _since == _note["sent"] + 60:
		_check("moves: between two of the waves is safe (%s)" % _player().get("health"),
			_player().get("health") == 100)
		_next()


## Kept away for three seconds: the chair, start to finish.
func _chair(now: String, started: bool) -> void:
	# Kiting: a hundred pixels ahead of him, until he commits to something.
	if not _note.has("began"):
		_player().global_position = _boss.global_position + Vector2(100, 0)
	if started:
		_note["began"] = _since
		_check("moves: three seconds kept away earns the chair (%s after %.1f s)"
			% [now, _since / 60.0], now == "chair" and _since >= 180)
	if now == "chair" and _boss.get("phase") == 1:
		var flipped: bool = (_boss.get_node("AnimatedSprite2D") as AnimatedSprite2D).flip_h
		if flipped:
			_note["spun"] = true
	if now == "chair" and _boss.call("is_charging") and not _note.has("rolling"):
		_note["rolling"] = _since
		_note["from"] = _boss.global_position
		_check("moves: he spins it up on the wind-up", _note.has("spun"))
		var taunts: Array = []
		for line in (load("res://game/bosses/ahmed/taunts.gd") as GDScript) 				.get_script_constant_map()["LINES"]["taunt"]:
			taunts.append(line["text"])
		_check("moves: and says the taunt as he sits down (%s)" % _note.get("line", "nothing"),
			taunts.has(_note.get("line", "")))
		_check("moves: the run has its trail", _child_of(ChairRun) != null)
	if _note.has("rolling") and not _note.has("stopped") and now == "chair" \
			and not _boss.call("is_charging"):
		_note["stopped"] = _since
		_check("moves: the chair rolls at you (%.0f px)"
			% _boss.global_position.distance_to(_note["from"]),
			_boss.global_position.distance_to(_note["from"]) > 40.0)
		_check("moves: and hits - 18 (%s)" % _player().get("health"),
			_player().get("health") == 82)
		_check("moves: then sits there dizzy (phase %s)" % _boss.get("phase"),
			_boss.get("phase") == 2)
	if _note.has("stopped") and now == "" and not _note.has("up"):
		_note["up"] = _since
		var dizzy: float = (_since - _note["stopped"]) / 60.0
		_check("moves: for about a second and a half (%.2f s)" % dizzy,
			dizzy > 1.4 and dizzy < 1.8)
		_check("moves: the slow-motion never sticks (scale %.2f, lowest seen %.2f)"
			% [Engine.time_scale, _min_scale], is_equal_approx(Engine.time_scale, 1.0))
		_next()
