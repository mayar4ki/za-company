# Big Mo

Deep dive for `game/bosses/big_mo/`: the RHYTHM of the three fights. The rules
every boss shares are `game/bosses/CLAUDE.md`.

`big_mo/` is the second boss, and he breaks two of Ahmed's assumptions on
purpose. Both are load-bearing, so read them before touching his art.

- **He is drawn FRONT ON.** Every other boss is a profile. A boxer squares up
  to you, and that is the pose. It costs nothing against the side-only rule
  (game/bosses/CLAUDE.md): the figure is symmetric enough that the `flip_h` the
  base uses to turn him is invisible - only the lit forearm swaps sides, which
  is what Ahmed's does too. No override was needed anywhere; `_face()` and
  `_apply_animation` are untouched and his rows are still named `*_side`.
- **He is drawn at 2x DENSITY.** 70 source rows across 35 world px, where Ahmed
  spends 35 rows on the same 35 px. His cell is therefore `128` in roster.gd
  and his scene halves it back with `scale 0.5` and `offset -48`, so the two
  bosses stand the same height in the room and only Big Mo's pixels are finer.
  The cost is real: his pixels do not line up with the room's at odd window
  scales. It was chosen deliberately, because the style pass that shaped him
  had no range to work in at 1x - a 35px-tall body gives a head-width slider
  four usable steps.

His pieces:

- **`poses.gd` is measurements, not a picture.** Where Ahmed's is body ASCII
  with an arm drawn over it, Big Mo's is thirteen numbers (head, shoulders,
  taper, torso, glove, shorts, legs, boots) plus a per-frame pose: body and
  head offsets, leg offsets, stance, and two arms each given as an elbow and a
  glove. That is what let him be shaped with sliders, and it is why a new frame
  here is six numbers rather than seventy rows. The **vertical stack those
  measurements add up to** lives there too, `BOOT_TOP` up to `HEAD_TOP`, and
  with it `SHOULDER` - the row every pose's `ey`/`gy` is measured down from.
  The painter reads them rather than deriving its own, because the moment a
  second thing draws a glove from pose data there must be one shoulder line
  and not two.
- **`tools/bosses/big_mo.gd` paints from those measurements.** Same seed-once
  contract as Ahmed's. The canvas lands at a FIXED offset in the cell, never
  centred per frame, or the body jitters between frames of a row.
- **A RHYTHM rather than a menu** (`big_mo.gd`): jab, jab, then the big one,
  then `breath_seconds`. The corner rush breaks the pattern for a player who
  kites - and the dash is the back of its wind-up, with the blow on the last
  running frame, so he connects on arrival rather than swinging halfway there.
  There is no STRIKE phase to hang travel on: enemy_base fires the blow at the
  end of WINDUP and goes straight to RECOVER.
- **The rush's crouch is a TELL, and he does not move during it.** He used to
  run from the first frame, so the blow was 0.36 s from a standing start -
  under a reaction plus the walk out of a 27 px reach, which made it
  unavoidable by anything but a lucky roll. Now he crouches where he stands for
  `Poses.tell_of("rush")` (0.50 s), then runs two 0.15 s strides at
  `rush_speed` 225, still about 68 px, so whoever stays on his line is reached
  from anywhere in it. The answer is the uppercut's: step ASIDE. A player who
  starts moving up to 0.40 s after the crouch begins gets clear, either way,
  and test_big_mo_moves.gd's `rush_up` / `rush_down` stages measure exactly
  that. The Bell's speed lines start with the run, not the crouch. Note the
  margin is thinner than the arithmetic says: `_strike` reads the Touch
  area's overlap from the PREVIOUS physics frame, so a body clear of his
  reach by one frame's walk still counts as hit.
- **Commit is per attack.** `COMMIT` sets `commit_fraction` as each attack
  begins - the base has one dial. Read the dial the right way round: it is how
  much of the wind-up can STILL be interrupted, so 0.0 is committed from the
  first frame and 1.0 is interruptible the whole way. The jab and the rush sit
  at 1.0 under an older comment calling them uninterruptible; they are short
  enough that it rarely shows, but the number says the opposite of the note.

## The reads - what was added after the first fight was played

The fight as first built was one string thrown forever, and a recording of it
showed the whole of it in six seconds: step back from the hook, hit him in the
breath, repeat. Four additions changed that, picked from an artifact that
recorded the real fight and previewed each candidate with his real painter.
**Every damage number on the original three attacks is unchanged**, and so is
his health: the additions are questions, not numbers.

- **Hook OR uppercut.** The third beat is a slot `_finisher()` fills, random
  but never more than `FINISHER_RUN` (2) of one running. Same 0.70 s, same 18,
  same commit, so neither guess is the safe one - and opposite ANSWERS: the
  hook is his `Touch` circle (wide and short, step BACK), the uppercut is a
  lane straight out the way he faces (`UPPERCUT_REACH` 44 by
  `UPPERCUT_HALF_WIDTH` 8 - narrow and long, step ASIDE). The tell is the rear
  glove (up and out, or down to the hip with a sink) and the Bell: a ring on
  the floor and side chevrons for the hook, a LANE on the floor and chevrons
  arriving from top and bottom, in bone rather than hot white, for the
  uppercut. The lane the Bell draws is read off the boss's own constants.
- **Shell Up**, for mashing. `SHELL_HITS` (3) hits inside `SHELL_WINDOW` (1.2
  s), landed while he is not mid-wind-up, and he covers for `SHELL_SECONDS`
  (0.8). A hit on the shell never reaches boss_base - no health, no flash, no
  stagger - throws `block_spark.gd`, and starts the **counter**: a hook cut to
  a 0.15 s wind-up, its own row, 12, commit 0.0. A shell nobody hits drops his
  guard for `OPEN_SECONDS`, rooted and hittable. `SHELL_COOLDOWN` 6 s. Shell
  and open are STANCES, not attacks - `attack` is "" through both, which is
  why the interrupt economy never sees them and the Bell stays dark. He says
  a `shell` line if he has one and borrows `hurt` ("Noted.") until he does.
- **Clinch & Throw**, for standing on him. Feet within `CLINCH_RANGE` (14 px,
  closer than any punch needs) for `CLINCH_AFTER` (0.8 s) and the next beat is
  the clinch: arms thrown wide is the 0.30 s tell, 8 damage, commit 0.0. The
  timer keeps counting THROUGH his punches, because his breath alone is
  shorter than 0.8 s and a hug that only counted between strings could never
  be caught. The throw is a shove HELD for `THROW_SECONDS` rather than one
  shove, because player.gd caps one push at 70 (about 17 px) and refreshes
  rather than stacks - held, it is about 45 px, clear of his reach.
- **Burning Flurry**, raging only. Every other string is five straight
  punches `FLURRY_GAP` (0.2 s) apart, each one a frame boundary in poses.gd:
  the first lands on the impact frame like any blow and `_run_flurry` lands
  the other four through the recover while he marches at `FLURRY_MARCH` (55 -
  faster than his walk, or he punches himself out of reach by the third). Each
  shoves you back; the grace window decides how many of the 4s hurt. Then the
  big one with no breath between, and the breath itself drops to
  `RAGE_BREATH` (0.4) - the lever the rage note always named. No hit-stop on
  the flurry: five holds in a second would slide the punches off their frames.

The six new rows went on the END of `ORDER`, so build_bosses.gd painted rows
7-12 onto the sheet and left 0-6 alone. The new attacks have no sounds of
their own yet: his scene's `sounds` map points each new id at the nearest
existing clip (the uppercut at the hook's, the clinch at the rush's, the
flurry and the block at the jab's), which keeps every cue audible and
test_bosses.gd's "every attack has a telegraph and an impact" true without an
import pass. Bespoke takes are `tools/sfx/make.py`'s job and cost credits. The
same goes for lines: `uppercut`, `counter`, `clinch`, `flurry` and `shell` have
none and are silent, which is legal. `tests/test_big_mo_moves.gd` is the
suite.

One consequence worth knowing: the player's grace window is 0.5 s on MEDIUM
and his two jabs are closer together than that, so the second one is often
eaten. That is the crowd dial doing its job, not a bug - but it is why his
test asserts the ORDER he throws in rather than the health that comes off.

## The Bell - his punches, announced

`bell.gd`. Front on, a punch has no sideways travel to read: the jab's whole
animation is the glove growing `gs 5` to `gs 9` and back, four source pixels.
The Bell supplies what the camera angle takes away, and it does it at the scale
of the room rather than on his fist, because the fist is the one part that
cannot move on screen.

It is Ahmed's `axe_fire.gd` contract - a node that reads the sprite's
animation, frame and flip and draws from `poses.gd`, told nothing by anyone -
with one addition: it reads `frame_progress` too, so a chevron crossing the
screen has something smoother than ten frames a second to move on. Time into
the attack is summed from the same `dur` list the boss script derives
`windup_seconds` from, so **no timing moved to fit any of this** and none can
drift.

Three instances of the one script, and **the split is by SPACE**:

- **`BellGround`**, under the body: the floor ring tightening as he loads.
- **`BellBurst`**, over it: the ring and twelve spokes off the glove on impact,
  reaching ~54 px - three times his own height.
- **`BellScreen`**, on a CanvasLayer: the red vignette, the two chevrons that
  cross the screen through the wind-up, the flash, and the rush's speed lines.

That layer is `layer = 1`, which is why **game.tscn now states `layer = 2` on
the HUD**: a flash that washes out his own health bar hides the one number the
player is watching while it lands. The stack, explicit at last, is -1
background, 0 world, 1 his screen effects, 2 HUD, 5 transition, 6 title.

**The screen layer draws at TWO scales and getting this wrong is the whole
trap.** `chunk` is a piece of the frame (`view.x / CHUNK`, ~7 px at 640) and
builds the vignette, the chevrons and the jab's bar: furniture of the frame
sized in world pixels is a nine-pixel arrow on a 640-pixel screen, and it would
change size with the zoom, which is the one thing something pinned to the edge
of the screen must never do. `world` is a world pixel as seen, and places the
things that belong to the ROOM even when they span the frame - where the
chevrons MEET (his chest, 13 world px up) and where the rush's streaks sit.
The mockup this was ported from previewed at a zoom the game does not have, so
every number in it had to be read as one or the other.

Two dials beyond the drawing, both in `big_mo.gd`:

- **`HIT_STOP`** holds the sprite still for 0.08 s on the frame a blow lands
  (the hook gets half again), which is most of what tells a player the attack
  is OVER. It pauses the SPRITE only - `_phase_time` runs on, so the wind-up,
  the recover and the punish window are exactly what poses.gd says. The cost is
  the last 0.08 s of the recover animation being clipped, which is the right
  way round.
- **`SHAKE`** throws the camera, per attack, through `shook` on `boss_base` -
  a capability every boss now has and none has to implement. game.gd connects
  it in `_watch_boss()` beside the bar, and applies it as a camera OFFSET
  quantized to whole world pixels, so `_camera_target()` stays the only thing
  deciding framing and a shaken room does not crawl.

## The Rage - he goes up at half

`rage.gd`, and `big_mo.gd` decides when. At half health he catches fire, once,
and never comes back down. **Half was already a moment**: his floor cues
`at_boss_fraction: 0.5`, so a `call_center` and a `social_media` come in through
the south door on the same frame the fire does.

**One flip, not a ladder**, because DESIGN.md gives the ladder to Silverman and
two bosses making the same argument is one boss too many.

The eruption is 0.95 s and **every beat of the fire is a frame boundary** in
poses.gd - pulses at 0.16 / 0.40 / 0.62, the blast at 0.51. That is not a
coincidence to preserve by hand: `tests/test_rage.gd` asserts it, because
rage.gd fires on fixed seconds while poses.gd decides when frames change, and
retiming a `dur` would slide the fire off the picture with nothing else to warn
you.

What happens, in order: he plants and sinks TWICE, the second deeper than the
first - which is what sells the third as the one that gives - blows a ring out
of the crouch behind a white flash on an already-dark room, and comes up
through his own column with his arms flung open. Then the fire settles: a skirt
at his boots, eight flames orbiting him split front and back about the
ellipse, **both gloves burning**, embers, heat, smoke, and a crimson rim along
his whole silhouette.

Three things worth knowing before touching it:

- **The rim is read off the sheet's own alpha**, cached per cell, so it follows
  any frame he is ever drawn in and costs the art nothing. It is 16k pixel
  reads for a 128px cell: fine once, a framerate every frame, which is why
  `_rims` keeps them.
- **`is_raging` is public and the effect reads it.** Everything else in this
  folder is told nothing and works it out from the sprite, but the fire he
  KEEPS has to outlive the animation that started it - by then the sprite is
  back on `idle_side` and has nothing left to say.
- **He does not get stronger.** Not one number moved: 24 / 17 / 36 and the
  heavy's 24 are exact combo breakpoints. If the rage should bite as well as
  burn, the cheapest honest lever is `breath_seconds` - the combination he
  taught you, arriving with less room to answer it.

While it runs he is rooted, throws nothing, and cannot be staggered -
`_can_advance`, `_advance_phase` and `_interruptible` all defer to
`_erupting()` - but damage still lands, so the 0.95 s is a free window and the
reward for being close. The blast holds his sprite for 0.12 s and emits
`shook` at 6 px, harder than any punch he throws.

## brush.gd, and the second fire in the game

`bell.gd` and `rage.gd` share `brush.gd`: the boss and sprite lookup, `part`,
the anim clock, and the pixel and flame kit.

Ahmed keeps his own copy of most of those shapes inside `axe_fire.gd`, and that
stays deliberate. Nothing about the ART is shared between bosses, and a flame is
art: the shapes here are the same as his, because one game should have one
fire, but **the ramp is the whole point of drawing it twice** - Ahmed is yellow
and amber, fuel burning on an axe; Big Mo is crimson and white, a body
overheating. Nobody should have to check which boss they are fighting. A third
consumer is the moment these bubble up to `game/bosses/` as a kit taking a
ramp, and not before.

## His sheet grew a row

`ORDER` is now idle, walk, jab, hook, rush, **rage**, concede - seven rows, and
`src/big_mo.png` was re-seeded to get it. That was free, and the reason is
worth keeping: his PNG was still **exactly what the painter paints**, verified
by repainting and diffing all 896x768 before deleting it. Every old row came
back byte-identical and the concede moved down a row intact.

That is the seed-once contract working as intended rather than being bent: the
moment anyone hand-draws into that PNG, adding a row costs a redraw instead of
a rebuild.

## What he sounds like

Eleven sounds, and the shape of the set is the fight rather than a copy of
Ahmed's. He gets the same free telegraph - his `_begin_attack` calls `super`,
so `boss_base` asks for `<id>_windup` without him knowing - and says the impact
in his own `_strike`, before `super()` because that can clear `attack`.

**His timings are why he cannot borrow Ahmed's sound language.** The jab winds
up in 0.250 s and recovers in 0.280, so every file is truncated to fit under
the beat it plays on, with a 12 ms fade so the cut does not click. Ahmed swings
an axe and can ring out; this is a rhythm - jab, jab, hook - and a tail on any
of these smears the combination into mush. Dry, close, fast decay, no room.

**The punches carry no fire, on purpose.** He catches fire at half health and
never comes back down, but the same six files play on both sides of that line:
fire baked into a jab would be wrong for the first half of the fight and
redundant in the second. So the fire arrives as a LAYER instead - a `rage`
one-shot and a `fire` loop - which is exactly what the picture does. His
punches do not change; the man throwing them is on fire.

Two consequences worth keeping:

- **`rage` is cut so its loudest MOMENT lands on `RAGE_BLAST` (0.51 s)**, which
  is the same frame the blast holds him still and the camera shakes. Aligned by
  a 30 ms sliding RMS rather than by the peak sample: the peak is a transient
  0.12 s in, and aligning to it padded almost half a second of dead air in
  front of the eruption.
- **Nothing stops the fire.** Ahmed fades his axe on the concede because he
  drops the axe; Big Mo IS the fire, and he is still burning when he kneels.
  Its loop is crossfaded over a 0.5 s seam, because a bed that plays from half
  health to the end of a fight is heard looping many times.

Levels follow `DAMAGE` - mixed at 18 / 10 / 6, now 22 / 15 / 6, the same
order - so the fight sounds the way it hits:
`hook_hit` -16 RMS, `rush_hit` -18.5, `jab_hit` -20, each telegraph about 7 dB
under its own impact, and `hurt`/`stagger`/`concede` on Ahmed's exact numbers so
the two bosses live in one mix. The fire bed sits at -34, where Ahmed's idle axe
is.

## His theme

A boss's theme is one path on his scene root, and a new boss needs no music
code to have one (game/bosses/CLAUDE.md's *The theme is not one of his
sounds*).

Big Mo's is `assets/music/big_mo_theme_loop.wav`, and adding it was the
claim above being tested: one line on his scene root, no code anywhere. Two
things about it are worth carrying to the third theme. Its **tempo is chosen
against his cycle** rather than against the room - 120 BPM is a beat every 30
frames, so his 0.25 s jab is an eighth note and his combo sits on the grid
instead of drifting through it. And it is **one unbroken loop with no build**,
because a boss gets exactly one file: the theme starts where his bar goes up
and fades where it clears, and nothing switches at half health, so a track
that saves itself for a drop is a track that is quiet for the half of the
fight he spends on fire.

And the level a theme is mixed at is decided against HIS sounds, never against
the other theme. Big Mo's was first matched to Ahmed's loudness, which was the
wrong question - masking is per band, and his rage and his fire both live under
250 Hz where a techno track keeps its kick, so they were arriving level with
the bed while every one of his impacts had 16 dB of room. Three more dB off the
track fixed both without touching a single sound of his, which is the order to
do it in: `enemy_audio`'s ladder is hand-levelled and internally consistent
(a telegraph is quieter than the blow it warns about, on purpose), so the music
is what moves. The numbers are in CREDITS.md.

## What he says

Twenty-two lines across nine cues in `big_mo/taunts.gd`, cut by
`tools/voice/cut.py big_mo` off `tools/voice/big_mo.py`, exactly as Ahmed's
are. Three things about the set are decisions rather than transcription:

- **He is the answer to a line the floor below already set up.** Ahmed asks
  "Do you know who Big Mo is?" when hurt and goes down saying "I'm telling
  Big Mo", so the first thing this man says is "So you're the one who upset
  Ahmed" and the last is "I'm escalating this. To Silverman." The chain of
  command IS the boss order, and each concede hands you up it.

  **Nobody in the building ever says HOW they are related, and that is the
  rule rather than an omission.** Big Mo is Ahmed's uncle and Silverman is
  Big Mo's brother; the family tree is the reason the three of them are the
  three bosses, and stating it out loud turns a threat into a soap opera. A
  name passed up the stairs already says everything the player needs - that
  this man knows the next one and can reach him - so every line about another
  boss carries the NAME and nothing else. That holds for the NPCs too: no
  briefing and no kitchen story explains the blood.
- **He talks like the department he runs, and that is the whole contrast.**
  Ahmed is entitled and loud - seven of his nine cues are tagged furious or
  shouting. Big Mo runs CONFLICT RESOLUTION and speaks like it: avoidance is
  not a resolution, I've booked this room for an hour, meeting you halfway.
  Seven of HIS nine cues are tagged quiet, and he is cast as Edward against
  Ahmed's Jack - British both, because they are family, dark and low against
  loud. Two men of one family tagged the same way would be one boss fought
  twice.
- **`rage` is a cue he added himself**, said by `big_mo.gd` on the frame he
  catches fire - the base fires seven cues and none of them is "the moment the
  process stops". It has one line, like `concede`, because there is no second
  thing to say there; and it is the only cue in his file tagged like one of
  Ahmed's. The quiet everywhere else is what buys it.

`cut.py` levels the SPEECH to target and soft-limits what pokes through, rather
than capping the gain - which it used to do, and which let one plosive decide a
whole line's loudness. That barely showed on a man who shouts; it cost Big Mo
6.5 dB on his first line and his last, both tagged quiet and both therefore
holding the widest gap between a consonant and a speaking voice.

Ahmed got it too, and without risking a single take, because there is a third
thing `cut.py` can do: `--relevel` re-trims and re-levels the PLAYED files from
the untouched exports in `src/`, spending nothing and asking the API for
nothing. The performance lives in the export, so trimming and levelling it
again is not a new read - which is exactly what `src/` has been kept for since
the first grunt. His spread went from 1.2 dB to 0.3, and `concede_1`, his
quietest and most important line, stopped being pinned at the ceiling. That is
the way to carry a boss cut under an older leveller onto a better one.

## Still to build

Big Mo's concede is a single placeholder frame - the animation DESIGN.md
describes (gloves off, a nod, a point at the ceiling) was drawn and rejected in
review. `boss_base.gd` plays `concede_side` at zero health so the row has to
exist; replacing it is adding frames to his poses.gd and nothing else.
