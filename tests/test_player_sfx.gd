extends "res://tests/helpers.gd"
## What the player sounds like: that the body declares every cue player.gd can
## fire and no cue it never will, that each one resolves to a real file, that
## the charge stance is a sealed LOOP rather than a one-shot with a flag on it,
## and - the one thing here that is not the bestiary's test over again - that a
## body with no `Audio` child at all still plays.
##
## Its own suite because the last of those is destructive in the same way
## test_enemy_sfx.gd's death check is: it tears the Audio child off the live
## player and then swings, charges and takes a blow with it gone, which is not
## a room a next section can be handed unchanged. test_combat.gd keeps the
## fight; this keeps the noise.
##
## ## What is deliberately not checked, and why
##
## That anything is audible. Headless runs the Dummy audio driver, where
## `AudioStreamPlayer.playing` is false forever with a good stream assigned,
## and `--fixed-fps` never sleeps so `get_playback_position()` is a coin flip -
## test_menu.gd wrote that check, watched it flake and took it back out. So the
## evidence is what test_bosses.gd and test_enemy_sfx.gd both settled on:
## STRUCTURE, plus the one call that leaves a mark a person can see - the loop
## flag `player_audio.loop()` writes onto the stream.
##
## That mark is not a consolation prize. A forward loop sealed to frame 0 plays
## exact silence with every flag a check could read coming back correct (root
## CLAUDE.md, Testing), and the charge hum is the one sound here that could
## ship mute that way.

## Every cue player.gd can fire, and the whole of it. Kept here as a flat list
## on purpose rather than read back off `ATTACK_SOUNDS`: a test that derives
## its expectation from the thing under test agrees with a typo.
const CUES := ["swing", "swing2", "charge", "heavy", "wildfire",
	"hit", "hurt", "die", "dodge"]

## The one that is a loop, because the stance is held for as long as the button
## is (tools/sfx/player.py). Nothing else here holds.
const LOOPING := "charge"

var _audio: Node
var _sounds: Dictionary = {}
var _health_before := 0


func _tick(frame: int) -> void:
	match frame:
		2:
			(current_scene.get_node("%PlayButton") as Button).pressed.emit()
		17:
			(current_scene.get_node("%Roster/reem") as Button).pressed.emit()

		# ---- The contract, read off the live player rather than parsed out of
		# the scene file: what is under test is what `player_audio._ready()`
		# made of the dictionary, not what the dictionary says.
		32:
			_audio = _player().get_node_or_null("Audio")
			_check("sfx: the player carries its own sounds (%s)" % _audio,
				_audio != null)
			_sounds = _audio.get("sounds") if _audio != null else {}

			var absent: Array = CUES.filter(func(cue: String) -> bool:
				return not _sounds.has(cue))
			_check("sfx: every cue player.gd fires has a sound (%s)"
				% ("all %d" % CUES.size() if absent.is_empty() else str(absent)),
				absent.is_empty())
			# And nothing it can never reach. A spare cue is not harmless noise
			# in the folder - it is a file somebody generated, levelled and will
			# one day go hunting for the bug in, because it never plays.
			var spare: Array = _sounds.keys().filter(func(cue: String) -> bool:
				return not CUES.has(cue))
			_check("sfx: and no sound nothing will ever fire (%s)"
				% ("none" if spare.is_empty() else str(spare)), spare.is_empty())

			var missing: Array = _sounds.keys().filter(func(cue: String) -> bool:
				return _sounds[cue] == null)
			_check("sfx: every declared sound resolves (%s)"
				% ("all" if missing.is_empty() else str(missing)),
				missing.is_empty())
			# One AudioStreamPlayer per id, built in _ready. A dictionary entry
			# with no player behind it is a cue that is wired and silent.
			var built := 0
			for cue in CUES:
				if _audio != null and _audio.get_node_or_null("Sfx_%s" % cue) != null:
					built += 1
			_check("sfx: a player was built for each (%d of %d)"
				% [built, CUES.size()], built == CUES.size())

		# ---- The map from animation to cue. A typo in ATTACK_SOUNDS mutes a
		# swing with no error anywhere, because an id the node does not have is
		# silence BY DESIGN - which is exactly the promise that hides this.
		34:
			var map: Dictionary = _player().get("ATTACK_SOUNDS")
			_check("sfx: the four attacks each name a cue (%d)" % map.size(),
				map.size() == 4)
			var unknown: Array = map.values().filter(func(cue: String) -> bool:
				return not _sounds.has(cue))
			_check("sfx: and every one of them is a sound it owns (%s)"
				% ("all" if unknown.is_empty() else str(unknown)),
				unknown.is_empty())
			# The two lights must not share one clip. They are the halves of a
			# combo, and telling them apart by ear is the whole reason swing2
			# was cut as a separate rising slash rather than reusing swing.
			_check("sfx: the combo's two halves sound different (%s / %s)"
				% [map.get("attack"), map.get("attack2")],
				map.get("attack") != map.get("attack2"))
			# The arc has no clip of its own yet and rides on a REAL cue rather
			# than naming a missing one - the "every one is a sound it owns"
			# check above is what would catch a `swing3` wired before it is cut.
			_check("sfx: the arc opens on a cue that exists (%s)" % map.get("attack3"),
				_sounds.has(map.get("attack3")))

		# ---- The stance. The loop flag is the one thing a headless run can
		# see a `loop()` call by, and it must not be set before the player has
		# actually held the button: a charge sealed on spawn is the whole floor
		# humming from the first frame.
		36:
			_check("sfx: the charge is silent until it is held (loop %d)"
				% _loop_mode(LOOPING),
				_loop_mode(LOOPING) != AudioStreamWAV.LOOP_FORWARD)
			# Hold attack. The stance is entered when an attack ENDS with the
			# button still down, so this has to outlast a whole swing - and it
			# has to be READ before CHARGE_SECONDS is up, because the heavy now
			# fires itself rather than waiting for a release.
			_key(KEY_SPACE, true)
		65:
			_check("sfx: holding the button reaches the stance (%s)"
				% ("charging" if _player().get("_charging") else "not charging"),
				_player().get("_charging"))
			_check("sfx: and the stance starts the hum looping (loop %d)"
				% _loop_mode(LOOPING),
				_loop_mode(LOOPING) == AudioStreamWAV.LOOP_FORWARD)
			# The trap this project has already been bitten by twice: a forward
			# loop ending on frame 0 wraps before it has played anything, so the
			# bus receives exact silence while every flag a check could read
			# comes back correct. `loop_end` must be the real frame count.
			var wav := _stream(LOOPING)
			var frames := 0 if wav == null else int(wav.get_length() * wav.mix_rate)
			_check("sfx: sealed to a real end, not frame 0 (%d of %d)"
				% [0 if wav == null else wav.loop_end, frames],
				wav != null and wav.loop_end > 0
					and absi(wav.loop_end - frames) <= 1)
			# The seam itself, which is the OTHER way a loop ships broken: an
			# export ends mid-waveform and clicks once per pass. tools/sfx
			# crossfades the tail over the head, so the step across the join
			# should be no worse than an ordinary step inside the clip.
			_check_seam("res://game/player/sfx/charge.wav")
			# Let go short of the ready point: the stance ends with nothing
			# fired, which keeps the heavy out of the sections below.
			_key(KEY_SPACE, false)

		# ---- The promise the whole design rests on: a cue with no file, or no
		# `Audio` child at all, is silence with no branch anywhere. That is what
		# lets a fresh checkout run before a single WAV has been imported, and
		# nothing else in the suite would notice it breaking.
		96:
			_audio.get_parent().remove_child(_audio)
			_audio.queue_free()
			_check("sfx: the Audio child is gone (%s)"
				% _player().get_node_or_null("Audio"),
				_player().get_node_or_null("Audio") == null)
			# Drop the cached @onready reference too, so the body is exactly the
			# body a scene without an `Audio` child would have built: null, and
			# every _sfx call a no-op rather than a call into a freed node.
			_player().set("_audio", null)
			_key(KEY_SPACE, true)
		104:
			_check("sfx: a silent body still swings (%s)"
				% _player().get("_attack"), _player().get("_attack") != "")
		125:
			_check("sfx: and still reaches the charge stance (%s)"
				% ("charging" if _player().get("_charging") else "not charging"),
				_player().get("_charging"))
			_key(KEY_SPACE, false)
			_health_before = _player().health
		131:
			_player().call("take_damage", 5)
		140:
			_check("sfx: and still takes a hit without one (%d -> %d)"
				% [_health_before, _player().health],
				_player().health == _health_before - 5)
			_finish()


func _stream(cue: String) -> AudioStreamWAV:
	var audio := _player().get_node_or_null("Audio")
	if audio == null:
		return null
	var one := audio.get_node_or_null("Sfx_%s" % cue) as AudioStreamPlayer
	return null if one == null else one.stream as AudioStreamWAV


func _loop_mode(cue: String) -> int:
	var wav := _stream(cue)
	return -1 if wav == null else wav.loop_mode


## The step across a loop's join against the worst step INSIDE it.
##
## test_enemy_sfx.gd measures the same thing against the clip's MEAN step, and
## that is right for the drain and wrong here: this bed is quiet in the export
## and takes a large make-up gain to reach -28, so its samples land on a coarse
## quantization grid (~621) with long flat runs between them - a median step of
## zero and a mean of 276 that no actual step in the file is anywhere near.
## Measured that way a perfectly sealed join fails, which is a check calling
## the audio broken because the statistic does not fit the material.
##
## So the claim is tested as it is actually worded: a join no worse than the
## steps the clip already makes on its own. That still has teeth - the failure
## this guards against is a join stepping by THOUSANDS past anything internal
## (the menu track's was 22376 of 32768, root CLAUDE.md's Music), not one
## landing inside the material's own range.
func _check_seam(path: String) -> void:
	var s := _pcm(path)
	if s.size() < 400:
		_check("sfx: the charge's loop seam is crossfaded (%d frames)"
			% s.size(), false)
		return
	var worst := 0.0
	for i in range(1, s.size()):
		worst = maxf(worst, absf(s[i] - s[i - 1]))
	var seam := absf(s[s.size() - 1] - s[0])
	_check("sfx: the charge's loop seam is crossfaded (step %.0f, worst inside %.0f)"
		% [seam, worst], seam <= maxf(worst, 200.0))


func _pcm(path: String) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_length() < 44:
		return out
	f.seek(12)   # past "RIFF" + size + "WAVE"
	while f.get_position() + 8 <= f.get_length():
		var id := f.get_buffer(4).get_string_from_ascii()
		var size := f.get_32()
		if id == "data":
			var bytes := f.get_buffer(size)
			for i in range(0, bytes.size() - 1, 2):
				var v := bytes[i] | (bytes[i + 1] << 8)
				out.append(float(v - 65536 if v >= 32768 else v))
			return out
		f.seek(f.get_position() + size + (size & 1))
	return out
