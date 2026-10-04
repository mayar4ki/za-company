"""What the bosses sound like, when make.py cuts it. The recipe, not the engine.

    python tools/sfx/make.py bosses
    python tools/sfx/make.py bosses --only silverman/ceiling_crash --force
    python tools/sfx/make.py bosses --report

A third recipe beside `enemies.py` and `player.py`, and a third for their
reason: a boss is not a member of the bestiary and his cues are not its cues.
Ahmed's sounds predate make.py and were cut by hand, so they are not in here;
this file starts with the first boss sound the pipeline made.

## The cues are the boss's, and they arrive by existing

A boss makes noise by carrying an `Audio` child (game/enemies/enemy_audio.gd)
holding id -> stream, and his script fires names at it - so a cue with no file
is silence with no branch anywhere (game/bosses/CLAUDE.md, The noise). Online
every one of them is the host's to make and tell, which boss_base.gd's `_sfx`
already does.

## Silverman: the glass ceiling coming down

`ceiling_crash`, fired by silverman.gd's `_ceiling_fall` as each wave lands -
the same clip twice, 0.7 s apart, because it is the same thing happening twice:
panes the size of a desk hitting a stone floor. It is the first sound he has
ever owned; his voice is `tools/voice/`'s.

It is levelled at -17, between a boss's ordinary blow (-19, Ahmed's) and the
slam (-16), the one blow the camera shakes hardest for. The ceiling shakes the
room too, and each wave is seven or eight panes at once, but it is warned about
for the best part of a second on the floor first - it does not need to be the
loudest thing in the building to be heard.
"""

## Where they land: `sfx/` is what the game loads and `src/sfx/` keeps the
## untouched export, the player's split exactly - and for the player's reason,
## since `game/bosses/<id>/src/` already means his hand-owned sheet and the
## raw takes of his voice.
OUT = "game/bosses/%s/sfx"
RAW = "game/bosses/%s/src/sfx"

MODEL = "eleven_text_to_sound_v2"

## Ahmed's ceiling, the one every subsystem shares.
PEAK_CEILING_DB = -3.0

## The bestiary's number: high enough that "dry, close, no music" is obeyed.
PROMPT_INFLUENCE = 0.55

## cue -> RMS target. See the header.
LEVELS = {
	"ceiling_crash": -17.0,
}

## The bestiary's tail, verbatim. Dry and close: any reverb in the file is
## reverb the game cannot take back out, and his office is all hard surfaces.
STYLE = "dry, close, mono, no music, no reverb tail, game sound effect"

## boss id -> cue -> spec.
##   prompt   what to generate, minus STYLE
##   seconds  what to ask the API for; it is padded and then trimmed
##   limit    hard cap on the finished clip
CAST = {
	"silverman": {
		# Loud on the first sample, because the pane lands on the frame the
		# sound fires - a crash that builds would arrive after its own picture.
		# Then the shards: the tinkle is what says glass rather than a door
		# slamming, and it is what the shards on screen are doing for the next
		# second. Capped at 1.3 s so the first wave's tail is settling, not
		# still crashing, when the second lands 0.7 s later.
		"ceiling_crash": {
			"prompt": "a large heavy pane of glass dropped from above shattering "
				"on a hard stone floor, a sharp loud crash at full force from the "
				"very first sample, then small glass shards scattering and "
				"tinkling as they settle, one single crash",
			"seconds": 1.6, "limit": 1.3,
		},
	},
}

## (boss id, cue) -> why this take was kept. A take somebody listened to and
## approved is pinned here, so a later --force cannot re-roll it.
KEEP = {
	("silverman", "ceiling_crash"):
		"approved 2026-10-04: take 3 of 4 (0.99 s), auditioned over the live attack",
}
