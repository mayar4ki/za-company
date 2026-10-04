extends "res://tests/helpers.gd"
## What Ahmed says while he fights, and the subtitle it lands on.
##
## Its own suite because the headline cue needs a world the boss suite cannot
## give it: a taunt is what he says when the player will NOT come near him, so
## the whole first half of this file is a boss who never reaches anybody -
## which is the exact opposite of the fight test_bosses.gd has to run to check
## his attacks. One file, one world, as everywhere else here. (He has two
## answers of his own to a gap now - the leap and the chair - so this file
## holds both off; see frame 32.)
##
## He is kited by taking his speed away rather than by teleporting the player
## every frame: a boss walking after a player who is moved to stay ahead of him
## drifts across the room and into a wall, and what is under test is the gap,
## not the chase.
##
## Every line checked here is looked up in `taunts.gd` rather than spelled out,
## so rewording one is an edit to the data file and nothing else. The one that
## IS spelled out is spelled out on purpose: "I'm telling Big Mo." is the line
## DESIGN.md wrote for him, and the last thing anybody hears him say.

const Taunts := preload("res://game/bosses/ahmed/taunts.gd")
## The two cues that are allowed to speak over anything - see enemy_lines.gd.
const FORCED := ["spot", "concede"]

var _boss: Node2D
## Every line he said: frame, speaker, text, hold, and what he was swinging at
## the time. Recorded rather than sampled, because a line is an event.
var _said: Array = []

## His phase last frame, so an interrupt can land on the frame a wind-up
## STARTS rather than somewhere inside one - past `commit_fraction` the same
## hit is not an interrupt at all, and he says the other thing.
var _phase_was := 0
var _staggered_at := -1
var _hurt_at := -1
var _conceded_at := -1
var _taunt_one := ""
var _done := false


func _tick(frame: int) -> void:
	# A fight that never gave him a quiet moment would otherwise run forever.
	# Generous: everything below lands inside 2600 frames when it works, the
	# last thousand of which are the settle doing nothing. First, and outside
	# _drive: a fight that went wrong in a way _drive cannot see - the boss gone
	# with the room he was in - must still end the run as a FAILURE. Inside
	# _drive this sat behind its own early return, and a suite that never ends
	# is worse than one that fails.
	if frame > 4000 and not _done:
		_check("barks: the fight reached its end (staggered %d, hurt %d, conceded %d)"
			% [_staggered_at, _hurt_at, _conceded_at], false)
		_done = true
		_finish()
		return
	_drive(frame)

	match frame:
		2:
			(current_scene.get_node("%PlayButton") as Button).pressed.emit()
		17:
			(current_scene.get_node("%Roster/reem") as Button).pressed.emit()
		32:
			_check("barks: the lobby starts empty, so the fight is placed (%d)"
				% get_nodes_in_group("enemies").size(),
				get_nodes_in_group("enemies").is_empty())
			_boss = (load("res://game/bosses/ahmed/ahmed.tscn") as PackedScene).instantiate() as Node2D
			_level().get_node("Props").add_child(_boss)
			_boss.connect("said", _on_said)
			# 60 px apart: outside his axe (Touch r 24) and well inside his
			# sight (110), which is the whole of what a kite is.
			_player().global_position = Vector2(272, 140)
			_boss.global_position = Vector2(272, 200)
			# Rooted, so the gap holds without the player having to run - and
			# his two answers to a gap held off, the leap that would close it
			# and the chair that would roll across it. (The chair says the
			# taunt as it comes; that it does is test_ahmed_moves.gd's, and
			# what is under test here is boss_base's own clock for it.)
			_boss.set("speed", 0.0)
			_boss.set("_leap_timer", 1.0e6)
			_boss.set("_chair_timer", 1.0e6)
			# The wiring under test is game.gd's own rather than a second copy
			# of it written here: _watch_boss is what a built room runs, so a
			# boss placed by hand into an already-built one is handed over the
			# same way. It connects the bar, the shake and the subtitle in one.
			current_scene.call("_watch_boss")
		60:
			_check("barks: he has a mouth of his own (%s)"
				% _boss.get_node_or_null("Lines"),
				_boss.get_node_or_null("Lines") != null)
			_check("barks: seeing the player is the first thing he says (%d line(s))"
				% _said.size(), _said.size() == 1)
			_check("barks: and it came out of his own file (cue '%s')" % _cue_at(0),
				_cue_at(0) == "spot")
			# His SCENE names him, never his node: build_levels.gd calls the
			# instance "Boss", and a subtitle reading BOSS is the one thing it
			# must not say - the same trap the HUD bar has.
			_check("barks: the subtitle names him AHMED (%s)" % _subtitle_speaker(),
				_subtitle_speaker() == "AHMED")
			_check("barks: and carries the line he actually said (%s)" % _subtitle_line(),
				_subtitle_line() == String(_said[0]["text"]))
			_check("barks: it is on screen", _subtitle().call("showing"))
			# Measured, for the reason the settings panel is measured: the
			# longest thing he says is a line in a data file anybody can
			# reword, and a line that grew off the screen would be a line the
			# player cannot read, which nothing else here would notice.
			#
			# Its SIZE against the design viewport and its own margin off the
			# bottom, never absolute screen coordinates: a headless run's
			# viewport is not 640x360.
			var block := _subtitle().get_node("Text") as Control
			var line := _subtitle().get_node("%Line") as Label
			var under: float = _subtitle().size.y - (block.position.y + block.size.y)
			_check("barks: the line fits the 640x360 screen (%s)" % block.size,
				block.size.x <= _base_viewport().x
				and block.size.y <= _base_viewport().y)
			_check("barks: and sits clear of the bottom edge (%.0f px under it)" % under,
				under >= 8.0)
			# The one that a screenshot taught and nothing else would catch:
			# the bottom of the screen in a FIGHT belongs to his health bar and
			# the name over it, so a line pinned where the dialogue box sits
			# lands straight on top of them. Read off the bar's own label, so
			# moving either end is what fails.
			var bar_top: float = (_boss_bar().get_node("%BossName") as Label).global_position.y
			var block_bottom: float = block.global_position.y + block.size.y
			_check("barks: and clear of his health bar (%.0f px above it)"
				% (bar_top - block_bottom), block_bottom <= bar_top)
			# Off the LABEL's own wrapped count, the same measure the dialogue
			# box trusts: it cannot disagree with the text it is drawing.
			_check("barks: and says it in a line or two (%d)" % line.get_line_count(),
				line.get_line_count() <= 2)
		# Counted rather than frame-numbered, and this is why: which line he
		# opens with is a throw of the dice, the two are different lengths, and
		# a line's length IS its hold - so a longer hello pushes the first
		# taunt a whole attempt further down the road. Deadlines, not clocks.
		500:
			var taunts := _taunts()
			_check("barks: kept out of his reach, he complains about it (%d)"
				% taunts.size(), taunts.size() >= 1)
			_taunt_one = "" if taunts.is_empty() else String(taunts[0])
		900:
			var said := _taunts()
			_check("barks: kept there, he says it again (%d taunt(s))" % said.size(),
				said.size() >= 2)
			# Never the same one twice running, which is what makes a repeat
			# mean he has genuinely run out rather than that the dice went that
			# way. The pick guarantees it, so this is an equality and not a
			# sample: any two in a row differ.
			var repeats := []
			for i in range(1, said.size()):
				if said[i] == said[i - 1]:
					repeats.append(said[i])
			_check("barks: and never the same one twice running (%s)" % str(said),
				repeats.is_empty() and _taunt_one != "")
			# Let him walk. From here he closes 60 px at speed 40 and swings.
			_boss.set("speed", 40.0)


## The half that cannot be written as frame numbers: an interrupt has to land
## at the START of a wind-up, and which frame that is depends on how long he
## took to walk over.
func _drive(frame: int) -> void:
	if _boss == null or not is_instance_valid(_boss) or _done:
		return

	# He swings at a player who is standing there taking it, and the fight has
	# to last long enough for him to get a few swings announced before this
	# file starts interfering with it. Topping the player up is cheaper than
	# choreographing a dodge, and nothing here is testing his damage. Stood back
	# on the spot each time too: every sweep shoves the player away from his
	# feet, which is north here, and enough of them in a row walked the player
	# out through the lobby's door - taking the fight, and him, with the room.
	if frame > 980 and frame % 120 == 0 and _conceded_at < 0:
		_player().call("revive")
		_player().global_position = Vector2(272, 140)

	var phase := int(_boss.get("phase"))
	var winding_up := phase == 1 and _phase_was != 1
	_phase_was = phase

	# One hit on the FIRST frame of a swing he throws while he can be heard.
	# Both halves matter. Early, because the interrupt rules only stagger a
	# wind-up before `commit_fraction` - land late and he is merely hurt, which
	# is the other cue. And quiet, because what is under test is the REACTION:
	# a line arriving on top of one still being read is exactly what the policy
	# exists to prevent, so hitting him mid-sentence tests the other half of it.
	if frame > 1300 and _staggered_at < 0:
		if winding_up and not _mouth().call("holding"):
			_boss.call("take_damage", 1)
			_staggered_at = frame
		return

	# A hit on a boss who is NOT mid-wind-up hurts and nothing more.
	if _staggered_at > 0 and _hurt_at < 0 and frame > _staggered_at + 150 \
			and phase != 1 and not _mouth().call("holding"):
		_boss.call("take_damage", 1)
		_hurt_at = frame
		return

	# Three frames later, with that line still on screen: the end has to be
	# heard over whatever he was in the middle of saying.
	if _hurt_at > 0 and _conceded_at < 0 and frame == _hurt_at + 3:
		_boss.call("take_damage", 500)
		_conceded_at = frame
		return

	if _conceded_at > 0 and frame == _conceded_at + 5:
		_report()
	if _conceded_at > 0 and frame == _conceded_at + 140:
		_close()

	# And then nothing, for long enough to prove it. He settles over
	# BREATH_HARD + BREATH_FADE seconds from the moment the concede hands off
	# to `beaten`, so this waits the whole span out and a little more. It is the
	# slowest thing in the suite by far and it earns the seconds: the bug it
	# guards - a boss panting at full volume for the rest of the floor, over
	# Ivan's lines and a room whose music has already gone - is one that only
	# shows up by WAITING, which is exactly what no other check here does.
	if _conceded_at > 0 and frame == _conceded_at + 60 * 19:
		_settled()



func _report() -> void:
	_check("barks: interrupted, he says so (cue '%s')" % _cue_said_at(_staggered_at),
		_cue_said_at(_staggered_at) == "stagger")
	_check("barks: merely hurt, he says something else (cue '%s')"
		% _cue_said_at(_hurt_at), _cue_said_at(_hurt_at) == "hurt")

	# Every swing he opened while he could be heard announced itself, and the
	# cue IS the attack id - which is what gets a new boss lines for a new
	# attack without either file learning the other's vocabulary.
	var announced := []
	for line in _said:
		if line["attack"] != "" and _cue_of(String(line["text"])) == line["attack"]:
			announced.append(line["attack"])
	_check("barks: he announces the swing on the wind-up (%s)" % str(announced),
		not announced.is_empty())

	_check("barks: the end jumps the queue (said on frame %d of %d)"
		% [_frame_said_at(_conceded_at), _conceded_at],
		_frame_said_at(_conceded_at) == _conceded_at)
	_check("barks: and it is the line he was written (%s)" % _text_said_at(_conceded_at),
		_text_said_at(_conceded_at) == "I'm telling Big Mo.")
	_check("barks: it is the last thing he says (%s)" % String(_said[-1]["text"]),
		String(_said[-1]["text"]) == "I'm telling Big Mo.")

	# The one rule that holds across the whole recording: nothing he said was
	# ever painted over something still being read. The two forced cues are
	# exempt by design, and both are checked above for landing at all.
	var overlaps := []
	for i in range(1, _said.size()):
		if _cue_at(i) in FORCED:
			continue
		var ends: float = float(_said[i - 1]["frame"]) \
			+ float(_said[i - 1]["seconds"]) * 60.0
		if float(_said[i]["frame"]) < ends:
			overlaps.append(_said[i]["text"])
	_check("barks: no line was painted over one still being read (%s)"
		% str(overlaps), overlaps.is_empty())

	_check("barks: everything he said came out of taunts.gd (%d line(s))"
		% _said.size(),
		_said.all(func(l): return _cue_of(String(l["text"])) != ""))

	# The clip drives the hold, which is the one thing a subtitle cannot work
	# out for itself - a line must not finish reading while he is still saying
	# it. Conditional on the file being THERE on purpose: a fresh checkout has
	# not run an import pass, every clip is legally missing, and the same lines
	# still read on their own time. So this checks the contract when there is
	# audio to check it against, and passes silently when there is not.
	var voiced := 0
	var short := []
	for line in _said:
		var clip := _clip_of(String(line["text"]))
		if clip <= 0.0:
			continue
		voiced += 1
		if float(line["seconds"]) + 0.01 < clip:
			short.append(line["text"])
	_check("barks: no line reads faster than he says it (%d voiced, %s)"
		% [voiced, str(short)], short.is_empty())
	_check("barks: his last line is up (%s)" % _subtitle_line(),
		_subtitle().call("showing")
		and _subtitle_line() == "I'm telling Big Mo.")


## Beaten, and quiet. The picture must NOT stop - he is still there and still
## alive when the player walks back out, which is what the looping row is for -
## but the panting is an event with an end, and the bug was that it had none.
func _settled() -> void:
	var sprite := _boss.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var breath := _boss.get_node("Audio").get_node_or_null("Sfx_breath") \
		as AudioStreamPlayer2D
	# Missing is legal here as everywhere: a checkout that has not imported his
	# WAVs has no player to have stopped. The picture half still holds.
	if breath != null:
		_check("barks: he gets his breath back rather than keeping it (%.1f dB, %s)"
			% [breath.volume_db, "playing" if breath.playing else "stopped"],
			not breath.playing or breath.volume_db <= -40.0)
	_check("barks: but he is still breathing to look at (%s, speed %.2f)"
		% [sprite.animation, sprite.speed_scale],
		sprite.animation == &"beaten_side" and sprite.is_playing())
	_check("barks: slower than he was, which is what settling looks like (%.2f)"
		% sprite.speed_scale, sprite.speed_scale < 1.0)
	_finish()


## The other half of the subtitle: it takes itself down without being asked,
## which is what makes it safe in a fight nobody is pausing.
func _close() -> void:
	_check("barks: and it takes itself down when the line is done",
		not _subtitle().call("showing"))

	# Big Mo's own cue. `rage` is not one of the seven boss_base fires - he
	# says it himself on the frame he catches fire - so this is the check that
	# a boss can ADD a cue of his own without the base or the runner learning
	# it. His lines file and his script have to agree, and nothing else would
	# notice if one of them stopped.
	var m := (load("res://game/bosses/big_mo/big_mo.tscn") as PackedScene).instantiate() as Node2D
	_level().get_node("Props").add_child(m)
	var said := [""]
	m.connect("said", func(_c, t, _x): said[0] = t)
	m.call("_say", "rage")
	_check("barks: Big Mo has a cue of his own for going up (%s)"
		% ("<nothing>" if said[0] == "" else said[0]),
		said[0] != "")
	m.queue_free()

	# A boss with no lines is legal and silent, with no branch anywhere but
	# `_say` - the same deal a boss with no sounds and no theme is on.
	#
	# It used to be asked of whichever boss happened to still be mute: Big Mo
	# until he was given a mouth, then Silverman until he was. That ran out,
	# which the note here always said it would - all three talk now, and a
	# promise about SILENCE cannot be kept by a boss who has lines.
	#
	# So it is asked the way test_player_sfx.gd asks its own version: TEAR THE
	# CHILD OFF and swing anyway. That is the better question in any case. The
	# old one could only ever be answered by a boss nobody had got round to
	# writing yet, and it proved the absence was survivable by accident; this
	# one proves it on the boss who talks most, and it cannot go stale.
	var quiet := (load("res://game/bosses/silverman/silverman.tscn") as PackedScene).instantiate() as Node2D
	var mouth := quiet.get_node_or_null("Lines")
	var had_mouth := mouth != null
	if had_mouth:
		quiet.remove_child(mouth)
		mouth.queue_free()
	_level().get_node("Props").add_child(quiet)
	var heard := [false]
	quiet.connect("said", func(_s, _t, _x): heard[0] = true)
	quiet.call("_say", "concede")
	_check("barks: a boss whose Lines child is gone says nothing (had one: %s)"
		% had_mouth,
		had_mouth and quiet.get_node_or_null("Lines") == null and not heard[0])
	# And he is not merely quiet - he is still a working boss. A missing mouth
	# that took the fight with it would pass the check above.
	quiet.call("take_damage", 8)
	_check("barks: and he still takes a hit with no mouth to say so (%d)"
		% int(quiet.get("health")),
		int(quiet.get("health")) < int(quiet.get("max_health")))
	quiet.queue_free()

	_bilingual()
	# The run does not end here any more: `_settled()` waits Ahmed's breath out
	# and finishes instead.


## Silverman says everything twice - Swedish, then the same thing in English -
## and this is the only place anything checks that he still does.
##
## A sweep off disk rather than a fight, so it lives here rather than in
## test_silverman.gd: that file walks him down three phases and every check
## after the first depends on how much health he has left, while none of this
## needs him standing anywhere. It is the shape test_ivan.gd's six-floor sweep
## already has.
##
## The headline is the one nothing else in the game would notice. A line added
## in English only is legal everywhere - `enemy_lines.gd` reads a string and
## has no opinion about how many languages are in it, the clip is cut from
## whatever is written, and the subtitle draws one row instead of two without
## complaining. It would simply be a man who stopped doing the thing that makes
## him him, and it would ship.
func _bilingual() -> void:
	var lines: Dictionary = load("res://game/bosses/silverman/taunts.gd") \
		.get_script_constant_map().get("LINES", {})
	_check("barks: Silverman has lines at all (%d cues)" % lines.size(),
		not lines.is_empty())

	var one_language: Array = []
	var same_twice: Array = []
	var missing: Array = []
	var clips: Dictionary = {}
	var shared: Array = []
	var total := 0
	for cue in lines:
		for line in lines[cue]:
			total += 1
			var halves := String(line.get("text", "")).split("\n")
			if halves.size() != 2 or halves[0].strip_edges() == "" \
					or halves[1].strip_edges() == "":
				one_language.append(cue)
			elif halves[0] == halves[1]:
				same_twice.append(cue)
			var clip := String(line.get("voice", ""))
			if clip == "" or not ResourceLoader.exists(clip):
				missing.append(clip if clip != "" else "<none> on " + cue)
			if clips.has(clip):
				shared.append(clip)
			clips[clip] = true

	_check("barks: every one of his lines is said twice, Swedish then English (%d lines%s)"
		% [total, "" if one_language.is_empty() else ", one language on " + str(one_language)],
		one_language.is_empty())
	# A halved line that is the same string twice is the failure the check
	# above cannot see: it has two rows and says one thing.
	_check("barks: and the two halves are not the same words twice (%s)"
		% ("all differ" if same_twice.is_empty() else str(same_twice)),
		same_twice.is_empty())
	# A missing clip is legal and silent by design, which is exactly why a typo
	# in one has to be caught here - the game's own answer is a man moving his
	# lips. Cf. the mutterers in test_enemy_sfx.gd.
	_check("barks: and every line names a clip that is really on disk (%s)"
		% ("all %d" % total if missing.is_empty() else str(missing)),
		missing.is_empty())
	# They all cut into one folder off a derived name, so a collision would
	# silently play another cue's read.
	_check("barks: and no two lines share one recording (%s)"
		% ("%d clips" % clips.size() if shared.is_empty() else str(shared)),
		shared.is_empty())

	# Every cue he has lines for is a cue something actually fires. `glare`,
	# `split` and `ceiling` are his attack ids, which the base says on the
	# wind-up; `meeting`
	# and `review` are his own, said by silverman.gd as a phase arrives. A cue
	# nobody fires is a line nobody hears, and it reads as written work.
	var base := ["spot", "taunt", "hurt", "stagger", "concede"]
	var his: Array = load("res://game/bosses/silverman/silverman.gd") \
		.get_script_constant_map().get("PHASE_CUE", {}).values()
	var attacks := ["glare", "split", "ceiling"]
	var reachable := base + his + attacks
	var orphans := lines.keys().filter(func(c: String) -> bool: return not c in reachable)
	_check("barks: and every cue he speaks on is one something fires (%s)"
		% ("all %d" % lines.size() if orphans.is_empty() else str(orphans)),
		orphans.is_empty())
	# The other direction, and the one a new phase would break: his two phase
	# cues have to be the two silverman.gd actually names.
	var unsaid := his.filter(func(c: String) -> bool: return not lines.has(c))
	_check("barks: and both phase announcements have something to announce (%s)"
		% ("" if unsaid.is_empty() else str(unsaid)),
		his.size() == 2 and unsaid.is_empty())


## His `Lines` child - what decides whether he has room to say anything.
func _mouth() -> Node:
	return _boss.get_node("Lines")


func _on_said(speaker: String, text: String, seconds: float) -> void:
	_said.append({
		"frame": _f,
		"speaker": speaker,
		"text": text,
		"seconds": seconds,
		# What he was swinging as he said it - "" unless the line IS an attack
		# announcing itself, since `_say` runs before the wind-up is entered.
		"attack": String(_boss.get("attack")) if is_instance_valid(_boss) else "",
	})


## Everything he has taunted with so far, in order.
func _taunts() -> Array:
	var out := []
	for line in _said:
		if _cue_of(String(line["text"])) == "taunt":
			out.append(String(line["text"]))
	return out


## Which cue a line belongs to, looked up in the data rather than spelled out
## here: rewording a line must stay an edit to one file.
func _cue_of(text: String) -> String:
	for cue in Taunts.LINES:
		for line in Taunts.LINES[cue]:
			if String(line["text"]) == text:
				return cue
	return ""


func _cue_at(i: int) -> String:
	return "" if i >= _said.size() else _cue_of(String(_said[i]["text"]))


## How long his recording of a line runs, or 0.0 when there isn't one on disk -
## which is a legal state, not a failure. Looked up through the same data the
## game reads, so a line that is re-cut or re-pointed needs no edit here.
func _clip_of(text: String) -> float:
	for cue in Taunts.LINES:
		for line in Taunts.LINES[cue]:
			if String(line["text"]) != text:
				continue
			var path := String(line.get("voice", ""))
			if path == "" or not ResourceLoader.exists(path):
				return 0.0
			var stream := load(path) as AudioStream
			return 0.0 if stream == null else stream.get_length()
	return 0.0


## What he said on a given frame, for the cues this file fires itself.
func _said_on(frame: int) -> Dictionary:
	for line in _said:
		if int(line["frame"]) >= frame and int(line["frame"]) <= frame + 1:
			return line
	return {}


func _cue_said_at(frame: int) -> String:
	var line := _said_on(frame)
	return "" if line.is_empty() else _cue_of(String(line["text"]))


func _text_said_at(frame: int) -> String:
	var line := _said_on(frame)
	return "" if line.is_empty() else String(line["text"])


func _frame_said_at(frame: int) -> int:
	var line := _said_on(frame)
	return -1 if line.is_empty() else int(line["frame"])
