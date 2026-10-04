extends Node
## The noise the player makes. `game/enemies/enemy_audio.gd`'s job for the
## other side of the fight, and deliberately NOT that file.
##
## The placement rule in the root CLAUDE.md would bubble a shared node up to
## `game/`, and this one is not shared: it does a different job with the same
## shape, and the difference is the first line of it. An enemy is somewhere -
## a room holds up to seven of them and which corner a wind-up came from is
## the whole of what panning is for. The player is never anywhere: the camera
## is on them, so their pan is 0 on every frame of every room, and an
## `AudioStreamPlayer2D` here is an attenuation curve and a distance
## calculation bought to produce silence's exact twin. So this is a plain
## `AudioStreamPlayer` and a plain `Node`, and it is smaller than its
## counterpart rather than a copy of it:
##
## - no `play_detached`. That exists because an enemy plays `die` on the frame
##   it is `queue_free`d and takes its own speakers with it. The player is
##   revived, never freed - `revive()` puts the same node back to full - so a
##   death here outlives itself for free.
## - no `max_distance` and no `attenuation`, per above.
##
## What it keeps is the bargain, which is the part worth having twice: the
## scene fills `sounds` with id -> stream and NOTHING else happens. player.gd
## already calls `swing`, `swing2`, `charge`, `heavy`, `wildfire`, `hit`,
## `hurt`, `die` and `dodge` on whichever of them exist, so a cue arrives by
## owning a file and one with no file is silence with no branch anywhere -
## which is also what a fresh checkout looks like before the WAVs are imported.
##
## One player per id, built once: an id retriggered mid-play restarts rather
## than stacking, which is exactly what a swing on a mashed combo wants.
##
## **Somebody ELSE's player is somewhere** (DESIGN.md's Multiplayer, M4). The
## argument above is about the body this machine's camera follows; a party
## brings bodies it does not, and a teammate swinging across the room is a
## sound from across the room. So a REMOTE body's speakers are built
## positional, on the enemies' own numbers for the enemies' own reason - the
## one place the header's first line does not hold, and it is decided once,
## here, from the body this node belongs to.

## id -> AudioStream. Filled in player.tscn.
@export var sounds: Dictionary = {}
## Trim for the whole body, over the levels baked into the files themselves.
@export var volume_db := 0.0
## A remote body's falloff: game/enemies/enemy_audio.gd's defaults, because a
## teammate is heard across the same rooms an enemy is.
const REMOTE_MAX_DISTANCE := 600.0
const REMOTE_ATTENUATION := 0.2

## id -> AudioStreamPlayer, or AudioStreamPlayer2D on a remote body - the two
## answer every call below alike.
var _players := {}
var _fades := {}
## How many times each cue was started - a readout, kept where the sound is
## really started, because headless has no `playing` (UiSound keeps the same).
var _plays := {}


func _ready() -> void:
	var positional: bool = get_parent() != null and get_parent().get("remote") == true
	for id in sounds:
		var stream: AudioStream = sounds[id]
		if stream == null:
			continue
		var player: Node
		if positional:
			var placed := AudioStreamPlayer2D.new()
			placed.max_distance = REMOTE_MAX_DISTANCE
			placed.attenuation = REMOTE_ATTENUATION
			player = placed
		else:
			player = AudioStreamPlayer.new()
		player.name = "Sfx_%s" % id
		player.set("stream", stream)
		player.set("volume_db", volume_db)
		add_child(player)
		_players[id] = player


## How many times `id` has been started on this body.
func plays(id: String) -> int:
	return int(_plays.get(id, 0))


## Fire once. An unknown id is silence, deliberately - see the header.
func play(id: String) -> void:
	var player = _players.get(id)
	if player == null:
		return
	_plays[id] = plays(id) + 1
	_cancel_fade(id)
	player.volume_db = volume_db
	player.play()


## Fire and keep firing. Nothing on the player loops today - the charge stance
## deliberately uses a capped one-shot, because the clip RUNNING OUT is the
## ready cue (see tools/sfx/player.py). It is here because the day something
## does, the `loop_end` trap below is not one anybody should walk into twice.
func loop(id: String) -> void:
	var player = _players.get(id)
	if player == null or player.playing:
		return
	_plays[id] = plays(id) + 1
	# `loop_end` is in FRAMES and must be the real count - 0 does not mean "to
	# the end". A forward loop ending on frame 0 wraps before it has played
	# anything, so the sound runs in total silence with its loop flag set and
	# every test passing. The third copy of this fix in the project, and the
	# three subsystems are deliberately separate: see `enemy_audio.loop` and
	# `autoload/music.gd`'s `_seal`.
	var wav := player.stream as AudioStreamWAV
	if wav != null and (wav.loop_mode != AudioStreamWAV.LOOP_FORWARD
			or wav.loop_end <= 0):
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_cancel_fade(id)
	player.volume_db = volume_db
	player.play()


func stop(id: String) -> void:
	var player = _players.get(id)
	if player == null:
		return
	_cancel_fade(id)
	player.stop()


## Take a sound down over `seconds` and stop it, rather than cutting it. What
## the charge does when the stance is abandoned: an early release loses
## nothing, so it must not sound like something broke.
func fade_out(id: String, seconds: float) -> void:
	var player = _players.get(id)
	if player == null or not player.playing:
		return
	_cancel_fade(id)
	var tween := create_tween()
	_fades[id] = tween
	tween.tween_property(player, "volume_db", -60.0, seconds)
	tween.tween_callback(player.stop)


func _cancel_fade(id: String) -> void:
	var tween: Tween = _fades.get(id)
	if tween != null and tween.is_valid():
		tween.kill()
	_fades.erase(id)
