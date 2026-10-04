"""Silverman's voice: the recipe. What he sounds like, cue by cue.

The mechanism is `cut.py`; this is the data, the same split every generated
thing in this project uses. `taunts.gd` holds WHAT he says and is read straight
off disk by cut.py, so this file never repeats a line - it only says how each
cue is delivered.

## He is cut in two languages and it costs nothing

Every line in `taunts.gd` is Swedish, a newline, then the same thing in
English, and that is ONE generation. v3 changes language mid-read without being
told to, so there is no second request, no second clip, no join to get wrong,
and the pause between the halves is the model's own breath rather than
something this file had to time. `cut.py` turns the `\\n` into a real break on
its way out; nothing else in the pipeline knows.

The consequence to watch is LENGTH. His lines run about twice Ahmed's, and the
subtitle holds for as long as the clip does, so a line that is merely a bit
long in English is a speech by the time it has been said twice. That is a
writing constraint in `taunts.gd`, not a setting here.

## Whose voice

A Swedish voice reading English, deliberately, rather than an English voice
attempting Swedish. It is the same decision Ivan's accent was: the Swedish half
has to be a native's or the conceit collapses on the first line, and what the
English half then inherits - an accent, and the unhurried vowels that come with
it - is free characterisation for a man who has all the time in the building.

The voice was picked from three auditioned on one line
("Jag vantade mig inte att du skulle na hit."), not from the label on it.

## Tags, not sliders

Eleven v3 takes an inline delivery tag and acts on it. A cue's character lives
in TAGS below as a piece of direction ("[calm, measured]") rather than as a
number nobody can read back later. The tag is stripped from the audio by the
model; `cut.py --verify` transcribes every clip back and compares it to the
line it was cut from, which is what proves that rather than trusting it.

His stabilities run HIGH where Ahmed's run at zero. Ahmed is a man losing
control and the wobble is the performance; this one never raises his voice
once in twenty lines, and an unstable read of "Intressant." is a different
character.

## Levelled with the others, not under them

-19 dBFS, the same as Ahmed and Big Mo, even though he is the quiet one. His
quiet is in the delivery and in the words; putting it in the fader as well
gives the last fight in the game a boss you cannot hear over his own glare,
which is a bug wearing a characterisation.

## Approved takes are frozen

`KEEP` names the takes that were listened to and approved. Text-to-speech is
not deterministic - the same text, voice and settings give a different
performance every time - so re-running this script must not re-cut them, or it
ships a read nobody chose. Delete a KEEP entry to deliberately re-cut one.
"""

# Adam Composer - Stockholm, middle-aged, resonant and smooth.
VOICE_ID = "x0u3EW21dbrORJzOq1m9"
MODEL = "eleven_v3"

## Where the recordings land. `sfx/` is what the game loads, `src/` keeps the
## untouched export beside it - the same split the other two bosses and the
## music are on, and what makes `--relevel` free.
OUT = "game/bosses/silverman/sfx/voice"
RAW = "game/bosses/silverman/src/voice"
LINES = "game/bosses/silverman/taunts.gd"

TARGET_RMS_DB = -19.0
PEAK_CEILING_DB = -3.0

## Five characters across nine cues. Not one of them is loud, which is the
## whole brief: the difference between them is what he is being polite ABOUT.
_WARM = ("[calm, warm, genuinely impressed]", 0.55)
_PATIENT = ("[calm, measured, unhurried]", 0.6)
_DRY = ("[quiet, dry, amused]", 0.5)
_CHAIR = ("[formal, level, opening a meeting]", 0.65)
_FINAL = ("[quiet, sincere, final]", 0.6)

TAGS = {
    # He is pleased to meet you and he means it.
    "spot": _WARM,
    "hurt": _WARM,
    # He has the rest of the decade free and the taunt is him saying so.
    "taunt": _PATIENT,
    # Three attacks and an interrupt: brief, and faintly entertained.
    "glare": _DRY,
    "split": _DRY,
    "ceiling": _DRY,
    "stagger": _DRY,
    # A phase arriving is a man calling a room to order.
    "meeting": _CHAIR,
    "review": _CHAIR,
    # The last line of the last fight in the game.
    "concede": _FINAL,
}

SIMILARITY = 0.75
SPEAKER_BOOST = True

## (cue, text) -> the take that was approved for it. See the header. Pin a take
## the moment it is listened to and kept, or a later --force re-bills it and
## ships a read nobody chose. The twenty lines cut before the glass ceiling are
## still unpinned, so --force on this recipe re-records all of them.
KEEP = {
    ("ceiling", "Det finns ett tak.\nThere is a ceiling."):
        "approved 2026-10-04: take 2 of 3 (3.66 s), auditioned over the live attack",
}

## Transcript variants that are the transcriber, not the take. Empty, and that
## is a measured result rather than an omission: all twenty clips read back
## clean on the first --verify. Scribe writes "2031" as digits on both sides of
## the comparison, and the å/ä/ö are stripped from both before it, so the one
## thing that looked like it would need a rule here needed none. Ahmed carries
## two; this man has better diction.
SPELLINGS = {}
