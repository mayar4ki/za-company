extends "res://tests/helpers.gd"
## Big Mo's newer moves, one at a time, each staged with a FRESH Big Mo so no
## cooldown, count or rotation leaks from one stage into the next - the reason
## test_ahmed_moves.gd stages Ahmed the same way. test_bosses.gd runs the fight
## he picks; this file asks the questions the four additions were made for.
##
## - HOOK OR UPPERCUT: the third punch is one of two, they want opposite
##   answers, and he never throws the same one three times running.
## - THE CORNER RUSH, which is older than the four but was unfair until its
##   crouch became a tell: he stands for it, then runs, and a player who sees
##   it and steps off his line a reaction later is passed by.
## - SHELL UP: three quick hits and he covers; a hit on the shell is blocked
##   and countered, a shell waited out drops his guard.
## - CLINCH & THROW: stand pressed against him and he heaves you off.
## - BURNING FLURRY: raging, every other string is five marching punches that
##   walk you back, and his breath is shorter.
##
## The attacks are begun by hand where the question is about the attack rather
## than the choice of it, so the geometry is the only thing being measured.
## The room is the empty lobby, so he is the only thing in it.

const BIG_MO := "res://game/bosses/big_mo/big_mo.tscn"
const Poses := preload("res://game/bosses/big_mo/poses.gd")

## Where he stands for every stage. The player is placed relative to it.
const AT := Vector2(232, 140)

const ORDER := ["picks", "uppercut_line", "uppercut_aside", "hook_aside",
	"hook_back", "rush_line", "rush_up", "rush_down", "shell_hit", "shell_wait",
	"clinch", "flurry", "done"]

## A human reaction, in frames: how long after the rush begins the player in
## `rush_up` and `rush_down` starts to step off his line. 0.40 s - long enough
## to see the crouch AND tell it from the punches, not just to twitch.
const REACTION_FRAMES := 24

## A stage that has not finished by then has failed; the next one runs anyway.
const STAGE_FRAMES := 420

var _m: Node2D
var _stage := ""
var _since := 0
var _note := {}


func _tick(frame: int) -> void:
	match frame:
		2:
			(current_scene.get_node("%PlayButton") as Button).pressed.emit()
		17:
			(current_scene.get_node("%Roster/reem") as Button).pressed.emit()
		32:
			_begin("picks")
	if _stage == "" or frame < 33:
		return
	_since += 1
	match _stage:
		"picks":
			_picks()
		"uppercut_line":
			_one_blow("uppercut", true, "on his line, 30 px out, the uppercut still reaches")
		"uppercut_aside":
			_one_blow("uppercut", false, "one step aside, the uppercut goes past")
		"hook_aside":
			_one_blow("hook", true, "but the same step aside is still inside the hook")
		"hook_back":
			_one_blow("hook", false, "and stepping back the uppercut's distance clears the hook")
		"rush_line":
			_rush(KEY_NONE)
		"rush_up":
			_rush(KEY_W)
		"rush_down":
			_rush(KEY_S)
		"shell_hit":
			_shell_hit()
		"shell_wait":
			_shell_wait()
		"clinch":
			_clinch()
		"flurry":
			_flurry()
		"done":
			_finish()
			_stage = ""
			return
	if _since > STAGE_FRAMES and _stage != "done":
		_check("big mo: the %s stage finished in time (%s)" % [_stage, str(_note)], false)
		_next()


# --- staging -----------------------------------------------------------------


func _next() -> void:
	_begin(ORDER[ORDER.find(_stage) + 1])


## A fresh Big Mo on AT, the player put back to full and placed for the stage.
func _begin(stage: String) -> void:
	_stage = stage
	_since = 0
	_note = {}
	if is_instance_valid(_m):
		_m.queue_free()
	_m = null
	_player().call("heal", 100)
	if stage == "done":
		return
	_m = (load(BIG_MO) as PackedScene).instantiate() as Node2D
	_level().get_node("Props").add_child(_m)
	_m.global_position = AT
	# Introduced already, so no stage waits on his hello.
	_m.set("_spotted", true)
	var offset := Vector2(40, 0)
	match stage:
		"uppercut_line", "hook_back":
			# Out of his reach circle, on his line: 30 px straight ahead.
			offset = Vector2(30, 0)
		"uppercut_aside", "hook_aside":
			# Inside the circle, twelve px off his line.
			offset = Vector2(12, -12)
		"shell_hit":
			# In reach, so the counter has somebody to land on.
			offset = Vector2(16, 0)
		"shell_wait":
			# Out of reach, so the stage measures the stance and nothing else.
			offset = Vector2(70, 0)
		"rush_line", "rush_up", "rush_down":
			# Out of reach and straight ahead: what the rush is for.
			offset = Vector2(70, 0)
		"clinch":
			# Pressed against him: closer than any punch needs.
			offset = Vector2(12, 0)
		"flurry":
			offset = Vector2(20, 0)
	_player().global_position = AT + offset
	match stage:
		"uppercut_line", "uppercut_aside":
			_m.call("_begin_attack", "uppercut")
		"hook_aside", "hook_back":
			_m.call("_begin_attack", "hook")
		"rush_line", "rush_up", "rush_down":
			_m.call("_begin_attack", "rush")
		"shell_hit", "shell_wait":
			# Breathing for ever, so he is between punches when the hits land -
			# mid-wind-up he is committed to the swing and does not cover up.
			_m.set("_breath", 99.0)
		"clinch":
			# Breathing for ever, so the only thing that can start is the clinch.
			_m.set("_breath", 99.0)
		"flurry":
			# Straight to half, so he goes up; the stage waits out the eruption.
			_m.call("take_damage", 108)


func _hp() -> int:
	return _player().get("health")


# --- the stages ----------------------------------------------------------------


## The choice itself, asked of the script directly: the shape of a string, the
## two finishers, and the rule that keeps the read a read.
func _picks() -> void:
	var seq: Array = []
	for i in 3:
		_m.set("_breath", 0.0)
		seq.append(_m.call("_pick_attack"))
	_check("big mo: a string is jab, jab, then the big one (%s)" % str(seq),
		seq.slice(0, 2) == ["jab", "jab"] and seq[2] in ["hook", "uppercut"])
	_check("big mo: and a breath after it (%.2f s)" % _m.get("_breath"),
		is_equal_approx(_m.get("_breath"), 0.7))
	var picks: Array = []
	for i in 90:
		picks.append(_m.call("_finisher"))
	var longest := 1
	var run := 1
	for i in range(1, picks.size()):
		run = run + 1 if picks[i] == picks[i - 1] else 1
		longest = maxi(longest, run)
	_check("big mo: he throws both finishers (%d hooks, %d uppercuts)"
		% [picks.count("hook"), picks.count("uppercut")],
		picks.has("hook") and picks.has("uppercut"))
	_check("big mo: and never the same one three times running (longest run %d)" % longest,
		longest <= 2)
	_check("big mo: the two finishers wind up for the same 0.70 s (%.2f vs %.2f)"
		% [Poses.windup_of("uppercut"), Poses.windup_of("hook")],
		is_equal_approx(Poses.windup_of("uppercut"), Poses.windup_of("hook")))
	_next()


## One finisher, begun by hand, and whether it reached the player where they
## stand. 18 on MEDIUM either way.
func _one_blow(id: String, lands: bool, what: String) -> void:
	if _since == 2:
		_check("big mo: the %s plays its own row (%s)" % [id, _sprite_of(_m).animation],
			_sprite_of(_m).animation == StringName(id + "_side"))
	if _since == 60:
		var hp := _hp()
		_check("big mo: %s (%d)" % [what, hp], hp == (78 if lands else 100))
		_next()


## The corner rush, begun by hand on a player 70 px straight ahead. He crouches
## where he stands for the whole tell and only then runs, so a player who stays
## on his line is hit on arrival and one who steps off it a reaction time after
## the crouch is passed by - either way, though up is the longer step, his reach
## being centred above his feet. 15 on MEDIUM.
func _rush(step: Key) -> void:
	var aside := step != KEY_NONE
	if _since == 2:
		_check("big mo: the rush plays its own row (%s)" % _sprite_of(_m).animation,
			_sprite_of(_m).animation == &"rush_side")
	if _since == roundi(Poses.tell_of("rush") * 60.0) - 2:
		var crept: float = absf(_m.global_position.x - AT.x)
		_check("big mo: he stands still through the rush's %.2f s tell (%.1f px moved)"
			% [Poses.tell_of("rush"), crept], crept < 0.5)
	if aside and _since == REACTION_FRAMES:
		_key(step, true)
	# A few frames past the blow, and well inside the recover - the next thing
	# he could throw is still most of a second away.
	if _since == roundi(Poses.windup_of("rush") * 60.0) + 6:
		if aside:
			_key(step, false)
		var ran: float = _m.global_position.x - AT.x
		_check("big mo: and then he runs at you (%.0f px)" % ran, ran > 50.0)
		if aside:
			_check("big mo: seen and stepped %s a reaction later, the rush goes past (%d)"
				% ["up" if step == KEY_W else "down", _hp()], _hp() == 100)
		else:
			_check("big mo: stood on his line, the rush lands on arrival (%d)" % _hp(),
				_hp() == 85)
		_next()


## Three quick hits, the shell, a hit on it, and the counter.
func _shell_hit() -> void:
	match _since:
		1:
			for i in 3:
				_m.call("take_damage", 1)
			_check("big mo: three quick hits and he covers up", _m.call("is_shelled"))
			_note["hp"] = _m.get("health")
		3:
			_check("big mo: the shell is its own row (%s)" % _sprite_of(_m).animation,
				_sprite_of(_m).animation == &"shell_side")
			_m.call("take_damage", 10)
			_check("big mo: a hit on the shell is blocked (%s -> %s hp)"
				% [_note["hp"], _m.get("health")], _m.get("health") == _note["hp"])
			_check("big mo: and answered at once - the counter (%s)" % _m.get("attack"),
				_m.get("attack") == "counter")
			_check("big mo: the counter cannot be mashed out of (commit %.2f)"
				% _m.get("commit_fraction"), is_zero_approx(_m.get("commit_fraction")))
		40:
			_check("big mo: the counter lands 15 (%d)" % _hp(), _hp() == 85)
			_next()


## The shell waited out: the guard drops, hits land, and it does not come back
## inside its cooldown.
func _shell_wait() -> void:
	match _since:
		1:
			for i in 3:
				_m.call("take_damage", 1)
			_note["hp"] = _m.get("health")
		60:
			_check("big mo: waited out, the shell drops his guard",
				_m.call("is_open") and not _m.call("is_shelled"))
			_check("big mo: open is its own row (%s)" % _sprite_of(_m).animation,
				_sprite_of(_m).animation == &"open_side")
			_m.call("take_damage", 10)
			_check("big mo: and a hit on the open guard lands (%s -> %s)"
				% [_note["hp"], _m.get("health")], _m.get("health") == _note["hp"] - 10)
		120:
			_check("big mo: the guard comes back up", not _m.call("is_open"))
			for i in 3:
				_m.call("take_damage", 1)
			_check("big mo: and he will not shell again inside the cooldown",
				not _m.call("is_shelled"))
			_next()


## Pressed against him through his breath.
func _clinch() -> void:
	var now: String = _m.get("attack")
	if now == "clinch" and not _note.has("began"):
		_note["began"] = _since
		_check("big mo: pressed against him, he clinches (after %.2f s)" % (_since / 60.0),
			_since >= 48)
	if _note.has("began") and _since == _note["began"] + 50:
		var gap: float = _m.global_position.distance_to(_player().global_position)
		_check("big mo: the clinch costs 8 (%d)" % _hp(), _hp() == 92)
		_check("big mo: and throws you clear of his reach (%.1f px)" % gap, gap > 30.0)
		_next()


## Raging: the rotation, the breath, and five punches walking you back.
func _flurry() -> void:
	if _since == 2:
		_check("big mo: half health sets him alight", _m.get("is_raging"))
	if _since == 70:
		# The eruption is over (0.95 s). The rotation, asked of the script -
		# from the top of a string, since he has been punching since it ended.
		_m.set("_step", 0)
		_m.set("_flurry_due", false)
		_m.set("_after_flurry", false)
		var seq: Array = []
		for i in 5:
			_m.set("_breath", 0.0)
			seq.append(_m.call("_pick_attack"))
		_check("big mo: raging, every other string is the flurry (%s)" % str(seq),
			seq.slice(0, 2) == ["jab", "jab"] and seq[3] == "flurry"
				and seq[2] in ["hook", "uppercut"] and seq[4] in ["hook", "uppercut"])
		_check("big mo: and the breath is shorter on fire (%.2f s)"
			% _m.call("_breath_length"), is_equal_approx(_m.call("_breath_length"), 0.4))
		_m.set("_breath", 0.0)
		_m.set("_step", 0)
		_m.set("_after_flurry", false)
		# He has been jabbing since the eruption ended; start the flurry clean.
		_player().call("heal", 100)
		_player().global_position = _m.global_position + Vector2(20, 0)
		_note["from"] = _player().global_position.x
		_note["mo"] = _m.global_position.x
		_m.call("_begin_attack", "flurry")
	if _since == 72:
		_check("big mo: the flurry plays its own row (%s)" % _sprite_of(_m).animation,
			_sprite_of(_m).animation == &"flurry_side")
	if _since == 70 + 90:
		var pushed: float = _player().global_position.x - float(_note["from"])
		var marched: float = _m.global_position.x - float(_note["mo"])
		_check("big mo: the flurry walks you back (%.0f px)" % pushed, pushed > 30.0)
		_check("big mo: because he marches after you (%.0f px)" % marched, marched > 20.0)
		_check("big mo: and it hurts, a little (%d)" % _hp(), _hp() < 100 and _hp() >= 88)
		_next()


func _sprite_of(boss: Node2D) -> AnimatedSprite2D:
	return boss.get_node("AnimatedSprite2D") as AnimatedSprite2D
