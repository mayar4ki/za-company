"""What the player sounds like. The recipe, not the engine.

`make.py` is the mechanism; this is the data, on the same split as
`enemies.py` beside it - and it is deliberately a SECOND recipe rather than
another entry in that one, because the player is not a member of the bestiary
and its cues are not the bestiary's cues.

    python tools/sfx/make.py player
    python tools/sfx/make.py player --only player/hurt --force
    python tools/sfx/make.py player --report

## One body, one voice, forever

The ten characters share one sheet and one animation set and always will
(game/player/CLAUDE.md, Characters), so they share one set of sounds for
exactly the same reason: a swing drawn once lands on all ten, and a swing
CUT once has to as well. That is why this file has a single member where
`enemies.py` has six - the cast is one body wearing ten palettes.

It has one consequence that has to be designed for rather than discovered:
**the hurt cue cannot commit to a gender.** Nine of the ten characters are
not whoever the clip sounds like, and a plainly male grunt coming out of a
character who is not male is the animation telling the truth while the audio
lies - the same failure the office boy's wrench exists to avoid, arriving from
the other direction. So `hurt` and `die` are asked for breathy and neutral in
pitch, carried by air rather than by tone.

## The cues are player.gd's, and they arrive by existing

Same bargain as every other body in the game: `game/player/player_audio.gd`
holds id -> stream and player.gd fires names at it, so a cue that has no file
is silence with no branch anywhere. Nine of them, and the split between the
first two is the one worth keeping straight:

- `swing` / `swing2`   the two light attacks, fired when the swing STARTS.
                       Air, not impact - nothing has been struck yet.
- `hit`                fired only from `_strike()`, and only when a blow
                       actually reached somebody. This is the enemies' rule
                       (game/enemies/CLAUDE.md, The noise) pointed the other
                       way: an impact over empty air teaches the player that
                       the sound does not mean they connected.
- `charge`             the stance, and the only LOOP here. It has an end (the
                       heavy fires itself at CHARGE_SECONDS) but no LENGTH -
                       the stance runs for however much of the charge the
                       opening swing did not already cover, and an early
                       release cuts it anywhere. The ready cue is neither the
                       hum nor the eyes: it is the ring at the player's feet.
                       See its entry below for the spec that was tried first
                       and why it was wrong.
- `heavy` / `wildfire` the spin and the ring of fire it erupts into.
- `hurt`               the player taking a blow. Metered by the grace window
                       for free, because `take_damage()` already is - a
                       crowded room cannot stack gasps.
- `die`                health reaching zero.
- `dodge`              the tumble roll, fired on the press - the frame the roll
                       starts, and only a roll that DID start, so a press the
                       cooldown refuses is silent. Never doubled: two rolls are
                       at least 0.77 s apart and the clip is under 0.4 s.

**`drain()` is deliberately silent**, and it is the one absence anybody is
likely to call a bug. A drain runs every physics frame and knows its own rate
(root CLAUDE.md, three ways the world reaches the player); a gasp on each of
those is sixty gasps a second, and routing it through the grace window to
thin them out is exactly the mistake `drain()` exists to not make. The thing
draining you is already making the noise - the wraith's `drain` loop - so the
information is on the bus already, coming from the right direction.

## Levels are relative, and the player sits at the top of the chain

No audio bus layout and no volume setting yet, so a file's own level IS the
mix (root CLAUDE.md, Music). The bosses were levelled first, the enemies under
them; the player goes ABOVE both, and it is the same arithmetic argument
upside down. A room holds up to seven enemies and one player, and the sound
that says YOU are losing is the one sound in the mix that must never be won by
a crowd.

    player hurt          -19 RMS      level with a boss's blow, and for the
    player die           -19          same reason: nothing may bury it
    heavy                -20          its rooted second should land like it
    wildfire             -21
    player hit           -22          level with an enemy's hit - one blow
                                      landing is one blow landing
    boss ordinary blow   -19          (game/bosses/ahmed/CLAUDE.md, What he sounds like)
    enemy hit            -22          (enemies.py)
    swing2               -26          heard on every combo
    dodge                -26          your own move, on the swings' shelf
    swing                -27          heard MORE than anything else in the
                                      game; 5 under the impact it precedes
    enemy telegraph      -29
    charge               -28          a build, on the telegraph's shelf

The 5 dB between `swing` and `hit` is the enemies' 7 narrowed, on purpose. A
wind-up warns about somebody else's blow and must stay out of its way; a swing
is the player's own hand and is heard hundreds of times a room, so it wants to
be quiet for fatigue rather than for legibility - and burying it under its own
impact by the full 7 makes the combo feel like it is not connected to the
button.

## The same two frozen-take rules as everywhere else

`KEEP` pins a sound that was listened to and approved, because generation is
no more deterministic than text-to-speech and a re-run must not re-roll
something already right. And re-shaping is FREE: `make.py player --relevel`
re-trims and re-levels from the untouched exports in `game/player/src/sfx/`,
so only a new PERFORMANCE costs credits.
"""

## Where they land. `sfx/` is what the game loads, `src/sfx/` keeps the
## untouched export beside it - the enemies', bosses' and music's split
## exactly. It is `src/sfx/` rather than `src/` for the enemies' own reason:
## `game/player/src/` already means one documented thing, the cast's hand-owned
## sheet (`character_cc0.png`), and eight WAVs dropped in beside that PNG would
## blur a rule someone has to trust.
##
## The id slot is the owning FOLDER, which is what it has always been - the
## bestiary spells it `game/enemies/%s/sfx` because an enemy owns its sounds,
## and the player owns its own one level up.
OUT = "game/%s/sfx"
RAW = "game/%s/src/sfx"

MODEL = "eleven_text_to_sound_v2"

## Ahmed's ceiling. Three subsystems now, one headroom.
PEAK_CEILING_DB = -3.0

## How literally the model takes the prompt. The bestiary's number, unchanged:
## high enough that "dry, close, no music" is obeyed.
PROMPT_INFLUENCE = 0.55

## cue -> RMS target. See the header for why these numbers and not others.
LEVELS = {
	"swing": -27.0,
	"swing2": -26.0,
	"charge": -28.0,
	"heavy": -20.0,
	"wildfire": -21.0,
	"hit": -22.0,
	"hurt": -19.0,
	"die": -19.0,
	"dodge": -26.0,
}

## The tail of every prompt, and the bestiary's verbatim - a game sound is dry
## and close, because the room it plays in is 640 px wide and any reverb in the
## file is reverb the game cannot take back out.
STYLE = "dry, close, mono, no music, no reverb tail, game sound effect"

## id -> cue -> spec.
##   prompt   what to generate, minus STYLE
##   seconds  what to ask the API for; it is padded and then trimmed
##   limit    hard cap on the finished clip, where one is load-bearing
CAST = {
	"player": {
		# Light attack one. The most-heard sound in the game by a wide margin,
		# so it is asked for SHORT and dry: anything with a tail on it becomes
		# a smear the third time it fires inside a combo.
		#
		# It carries NO metal, which is the one thing about it worth stating.
		# Three shimmering candidates were auditioned against this one and the
		# bare air won, for a reason that only shows up in the combo: a steel
		# ring is a pitch, and three pitched swings inside 0.86 s play as a
		# little tune that the third press then has to talk over. Air has no
		# note to repeat. It also leaves the metal to `hit`, so the bright part
		# of the combo is the part that LANDED - which is the split the two
		# cues exist to draw.
		"swing": {
			"prompt": "a fast blade cutting through air, a short low breathy "
				"whoosh with no metal ring at all, dull and woody, nothing "
				"struck, no impact",
			"seconds": 0.7, "limit": 0.35,
		},
		# Light attack two - a rising slash, a launcher rather than a thrust
		# (game/player/CLAUDE.md). So it goes UP, which is the whole of how a
		# player tells the two halves of the combo apart with their ears.
		"swing2": {
			"prompt": "a sword slashing upward in a fast rising arc, a whoosh "
				"that pitches upward as it travels, brighter and a little "
				"longer than a flat swing, nothing struck, no impact",
			"seconds": 0.8, "limit": 0.45,
		},
		# The stance, and the one cue here that is a LOOP. It was specced as a
		# one-shot capped at CHARGE_SECONDS so that running out would be the
		# ready cue, and that was wrong on its own terms: the stance is held
		# for as long as the button is, so there is no fixed length for a clip
		# to run out AT, and a sound that stops 0.35 s before the heavy is
		# available actively misinforms. The ready cue is the ring at the
		# player's feet (game/player/charge_ring.gd); the ears get a hum that
		# holds for as long as you do, and the heavy's own swing is the payoff.
		#
		# So it takes the wraith drain's road at the first fork: `steady`
		# CHOOSES a stretch rather than trimming to one, because trimming asks
		# where a sound starts and a held note is the thing with no answer to
		# that. Two rolls came back a plateau that decays - the model will not
		# build on request - and `steadiest` is exactly the tool for turning a
		# plateau into a bed.
		"charge": {
			"prompt": "a sword blade gathering energy, starting from near "
				"silence and growing continuously louder and higher the "
				"entire time, quietest at the very beginning and loudest at "
				"the very end, one unbroken rise with no gaps, no impact and "
				"no release at the end",
			"seconds": 2.0, "steady": 0.5, "loop": True,
		},
		# The spin. 24 damage and a rooted second, so it is the one swing
		# in the game allowed to be broad and heavy.
		#
		# It ACCELERATES, and that is the half of the cue the flat sweep was
		# missing. The heavy is the only attack in the game the player holds a
		# button for, and it fires itself at the end of the hold; a swing that
		# is equally fast from its first sample says nothing about which end
		# of that it is. Rising into the whoosh puts the weight late, where
		# the blow is. The `charge` loop is still the cue that says the hold
		# is happening - this is the one that says it is over.
		"heavy": {
			"prompt": "a heavy blade spun in a full circle, starting slower "
				"and lower and accelerating into a fast broad whoosh, one "
				"continuous accelerating movement with no gaps and no "
				"separate events in it",
			"seconds": 1.0,
		},
		# What the heavy erupts into. Ignition on the first instant, because
		# the ring is already out at full radius on the animation's frame one.
		#
		# Crackle rather than whoomph, and the reason is the frame it shares.
		# `heavy` is already a big moving body of air and `hit` is landing in
		# the same tenth of a second; a second whoosh under those is a third
		# low sound in one instant and the whole thing reads as one muddy
		# thump. Crackle sits ABOVE all of it and is the one texture in the
		# stack nothing else is making - so the fire is heard as fire rather
		# than as more of the swing.
		"wildfire": {
			"prompt": "flames sweeping outward across a floor, loud crackling "
				"and roaring fire at full force from the very first sample, "
				"dying away continuously to nothing, no build-up and no gaps",
			"seconds": 1.2,
		},
		# A blow that LANDED. Fired from _strike() and nowhere else.
		#
		# Stylised rather than recorded, and it is the same call `swing` made
		# arriving from the other side: this is a 640 px pixel-art game, and a
		# convincing sword-into-flesh take is detail nothing on screen is
		# drawing. What the player needs from this cue is that it happened,
		# at a rate of three a second - so it is short, crunchy and gone,
		# which is also what keeps a heavy landing on four bodies from
		# turning into porridge.
		"hit": {
			"prompt": "a punchy stylised video game hit, a short crunchy "
				"impact with a tight low thump under it, maximum on the "
				"first sample and gone immediately, single hit",
			"seconds": 0.8,
		},
		# The player taking a blow. Breath-forward and neutral in pitch - see
		# the header for why this one cannot sound like a particular person.
		# Light on the thud on purpose too: whatever struck you is playing its
		# own `hit` in the same frame, and two impacts stacked read as one
		# muddy one.
		"hurt": {
			"prompt": "one short sharp gasp of pain, breathy and androgynous "
				"with almost no pitch to it, a soft cloth-and-body thud under "
				"it, a single voice, one syllable",
			"seconds": 0.7,
		},
		# Health at zero. Same neutrality rule, plus the sword leaving the
		# hand - the one thing on screen that is true of all ten characters.
		"die": {
			"prompt": "a body hitting a hard floor together with a sword, a "
				"breathy exhale of air knocked out with almost no pitch to "
				"it and steel ringing off tile, everything arriving in the "
				"same instant and ringing down smoothly to nothing, one "
				"single unbroken event with no pauses and no second hit",
			"seconds": 0.9,
		},
		# The tumble roll. Picked by ear in the Roll Sound Lab preview from
		# eight takes - cloth, tumble, scuff and dive, two of each - played in
		# the room beside the swings, the hits and the office boys' own cues.
		#
		# It is AIR with a shape to it, and the shape is the point: it rises
		# into the roll and drops out of it, so it reads as a body going over
		# rather than a blade going past - which is the one thing it must not
		# be mistaken for, since a swing is also a whoosh and is heard more
		# than anything else in the game. Capped at 0.4 s, a beat past the
		# roll's 0.32, so it is over before the cooldown is.
		"dodge": {
			"prompt": "a body diving sideways, a very fast low airy swoosh "
				"that rises then drops, soft and breathy, no voice, no metal, "
				"nothing struck",
			"seconds": 0.7, "limit": 0.4,
		},
	},
}

## (id, cue) -> why it was kept. See the header.
##
## The first eight are pinned on SHAPE rather than on ears - `--report` is the
## half of a review a machine can do (make.py's note under it), and it is the
## half that caught every sound in that batch that had to be re-rolled. They
## still want listening to. Pinned anyway because the alternative is a stray
## `--force` re-billing rolls that are already right, and because a
## re-shape is free either way: `--relevel` works THROUGH a pin, since it
## spends nothing and changes no performance. Delete an entry to deliberately
## buy a new one.
KEEP = {
	("player", "swing"): "picked by ear from 4 - air, no metal; steel made a tune",
	("player", "swing2"): "rises, and reads longer and brighter than swing",
	("player", "charge"): "mid 0.49, hi/lo 2.0x - a bed, not a plateau (2 rolls)",
	("player", "heavy"): "picked by ear from 4 - accelerates; weight lands late",
	("player", "wildfire"): "picked by ear from 4 - crackle clears heavy + hit",
	("player", "hit"): "picked by ear from 4 - stylised crunch, gone immediately",
	("player", "hurt"): "breathy, neutral, one syllable, no competing thud",
	("player", "die"): "one event; two earlier rolls had a hole in the middle",
	("player", "dodge"): "picked by ear from 8 in the Roll Sound Lab - dive, take 2",
}
