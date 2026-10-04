# Silverman

Deep dive for `game/bosses/silverman/`: the LADDER of the three fights. The
rules every boss shares are `game/bosses/CLAUDE.md`.

`silverman/` is the third boss and the last man in the building. He breaks the
other two the same way they broke each other, and the break is the whole
character: **his body never changes shape.**

- **One picture, moved around.** Ahmed's poses are an arm and an axe swung
  about a torso; Big Mo's are thirteen measurements restruck per frame.
  Silverman's are one block of ASCII and two numbers per frame - `dy`, how
  high he is floating, and `dull`, how many steps down the ramp he is painted.
  There is no scale, no lean, no clip and no leg variant anywhere in his
  `poses.gd`. A deforming version was drawn, looked at and dropped: a liquid
  that stretches while it travels reads as a cartoon, and this one is the
  final boss.
- **He does not walk, and he has no melee.** `walk_side` is the hover taken
  faster, because gliding is all the travel he has. He owns five things and not
  one of them is thrown with a hand: he crosses through you, blinds you,
  divides, sweeps the room with light, and freezes the air near him. A player
  standing on him is answered by the glare, whose band starts inside its own
  reach.
- **His telegraph is DRAWN, and it can only ever dim him.** His idle already
  rests at `dull 0`, the brightest rung he has, so there is nowhere to go but
  darker on the way to a blow: an attack row takes two rungs out of him and
  spends the lot on the impact frame, where he snaps back to full. That is also
  why `silverman.gd` overrides `_windup_tint()` to plain white - the base fades
  a winding enemy towards amber, and a multiply on a body of six exact
  greyscale values lands between two rungs of the only thing he is made of.
- **1x, like Ahmed.** Cell 64, sprite unscaled, offset -24. He was drawn,
  shown and picked at 35 rows, and the approved picture is the spec -
  redrawing him at Big Mo's density to gain ramp headroom would be shipping a
  different character. He needs it least of the three anyway: every frame of
  every row is the same pixels at a different height.
- **His toes end on row 32.** The two empty rows under them are the hover, and
  they are why he never looks like he has landed. The concede spends them: he
  settles the two pixels onto the floor he has never touched, and the shine
  goes out of him on the way down. Losing flight IS the defeat. Then `beaten`
  loops two dull levels slowly, so what is left in the room is a statue still
  cooling rather than a statue.

## The dash, and why it is one frame

His one piece of real locomotion. `DASH` in `silverman.gd` is a **position
curve** - six beats over half a second, out to 72 px - and that is all it is.
The sprite holds `dash_side`'s single frame for the whole crossing.

That single frame is the consequence of the rule above, and it is worth
stating because it looks like a mistake otherwise: if the body never changes,
the sheet has nothing to hold but one pose, so the travel is the boss moving
under an unchanging sprite and the speed is drawn by `smear.gd`. The trail can
be retuned later without repainting anything.

**The smear is seven copies six pixels apart**, each a step down the ramp and
fading back, so they overlap into one continuous length of metal with the real
Silverman at the bright end. Six apart rather than fourteen is what makes it a
smear instead of three afterimages: at that spacing the eye gets a band rather
than a count.

`ghost` is a sheet row the boss **never plays**. It holds the dash pose painted
one step down the ramp, and `smear.gd` pulls its texture straight out of the
SpriteFrames. The alternative was dulling a live copy with a modulate, which is
a multiply and lands between two rungs; a boss whose whole look is six exact
values does not get to approximate one of them. A picture the effect needs is a
picture, so it lives on the sheet.

Three beats of the six are travel - `moving` - and the first and last two are
the coil and the arrival: three pixels back before he goes, two past the mark
on the way in. That is the only anticipation he has, and it is position, so his
shape is still never touched. The trail draws on the travel beats only.

The cue is **distance alone**, and `dash_range` is the number that matters.
`_can_advance()` is false while crossing, or the base's own walking fights the
curve, and the dash drives `velocity` rather than assigning position so the
arena's walls still stop him.

It is now **locomotion that hurts** - the pass-through - and converting it cost
exactly what this file promised: `hit` on the three travel beats, a flag to keep
it to one blow, and nothing else moved. Two things had to be fixed to make it
true, and both are the kind that only surface once a gap-closer starts dealing
damage:

- **`dash_range` came down from 96 to 40.** He triggered at 96 and travels 72,
  so he always stopped 24 px short and could never once pass through anybody. A
  gap-closer may stop short; a blow may not. At 40 the bands are: inside 40 he
  glares, 40 to ~86 he crosses THROUGH you, and past that he crosses and lands
  short - which is the old locomotion, still doing its old job.
- **He needs a collision exception to pass through at all.** Two solid bodies do
  not interpenetrate, so his own `move_and_slide()` hit the player and halted
  him 11 px out: the pass-through was a boss walking into you and stopping.
  `add_collision_exception_with()` on the one body he is crossing, dropped on
  arrival and on a concede mid-flight - an exception rather than a collision
  mask precisely because the walls must still stop him.

The sprite is switched to `dash` in `_consider_dash` rather than waiting for the
next `_dash_step`, or he spends one frame crossing the room in his idle pose.

## The fight: a ladder, not a menu and not a rhythm

Ahmed is a menu (the attack suits the range) and Big Mo is a rhythm (jab, jab,
hook). Silverman had to be a third thing or the last fight in the building is
one you have already had twice, so he is **cumulative**: three phases, each
ADDING a mechanic and removing nothing, the interrupt window narrowing on every
step. The fight gets more crowded rather than faster, which is the only
escalation available to a man who never hurries.

`tier()` is the phase, taken off fractions of his own max health rather than the
literal 192 and 96, so retuning his HP - or a party adding to it - moves the
phases with it (solo numbers below):

| phase | HP | adds | interrupts |
|---|---|---|---|
| The Handshake | 288-192 | the crossing, the glare | standard (`commit` 0.65) |
| The Meeting | 192-96 | the split | one, then 3 s (`commit` 0.40) |
| The Performance Review | 96-0 | the prism, the cold room | none (`commit` 0.0) |

`COMMIT` and `LOCKOUT` are set per phase as each attack begins, because the base
has one dial for each and that is the only place they can narrow over a fight -
Big Mo's per-attack trick, applied per phase instead. **`commit_fraction` 0.0
is never interruptible, not always**: `_interruptible()` asks whether the
wind-up's progress is still BELOW it, so a lower number is a more committed
boss, and 0.0 is DESIGN.md's "fully uninterruptible" with no special case
anywhere to make it so.

A phase is announced by `herald`, a countdown glare.gd draws as two pulses of
the room. He has no cuffs to adjust, so what he spends on the announcement is a
rung of his own shine. Crossing a threshold also clears every attack cooldown,
so an escalation ARRIVES rather than being something you notice a few seconds
later - which is why the prism is the first thing he does in his last phase.

**How hard he hits was retuned on the 2026-10-03 playtest**, which found the
last fight in the building the easiest of the three. The damage went up by
about half - every big blow (glare, prism, crossing) is now a heavy's 24, the copy
18, the cold room 5 a second - but the cooldowns were the real fault. Each
starts on the blow, so the glare's old 3.2 s left him hovering, doing nothing,
for 2.5 of every 4 s you stood on him: 4 damage a second, against a player
taking 28 off him. Now he glares every 2.4 s and the gap is his own recover
again. **The wind-ups did not move**, on purpose: they are on the sheet, every
effect is drawn against them, and a boss who hits harder and more often owes
you the same time to read each blow coming. The old numbers, if it overshoots:
glare 16 / 3.2 s, split 12 / 5 s, prism 16 / 6 s, crossing 18 / 2.4 s, cold
room 3.0/s.

**The five attacks, and what each is made of:**

- **the glare** (24, 0.80/0.70, 1.6 s cooldown) - the room whites out and the light leaves him
  as a CROSS: a 20 px lane along the floor the way he faces, out to 140, and
  two arms straight up and down, out to 80 (`GLARE_ARM`), all travelling
  through his recover on Ahmed's wave contract. One glare is still one hit,
  whichever arm finds you - every arm shares `_glare_hit`. You step off both
  lines, so diagonal to him is the only safe place near him; you cannot
  outrun it. The cross and its look were picked off a four-way preview
  ("Crossfire" on "Mirror flash") and shipped as previewed: light spiralling
  into him while he dims, a star off his chest and his whole body flashing
  white as it fires, each arm a wall of light with a dithered wake, flare
  spikes, floor reflection and dust, sparks where each runs out. `glare.gd`
  is three parts split by SPACE like the Bell: `band` under the body in world
  pixels (the walls), `air` over everything at z 1 (the spiral, the star, the
  flash and the particles) and `screen` on a CanvasLayer at layer 1 in
  viewport pixels. The white flash is the `flash` row on his sheet - his
  impact pose with every pixel his brightest rung, never played, the `ghost`
  row's arrangement - because a modulate can only darken. **Every arm draws
  exactly its hitbox** - the band's front is the boss's own `glare_front()`
  and the arms' is `glare_arm_front()`, the functions `Band`, `BandUp` and
  `BandDown` are moved with, because a sweep you are asked to step out of has
  to be a sweep whose edges you can see. `pixels.gd` holds the one-pixel
  drawing both glare.gd and prism.gd were previewed in.
- **the split** (18, 0.60 wind-up, 3 s cooldown) - he divides, and the copy walks at you while
  he stands still. `copy.gd` draws the `ghost` row - the dulled body already on
  the sheet for the smear - so a copy of him is a copy of him by construction
  and costs **no art at all**. It is deliberately not an add: no group, no
  health, no bar, no collision, gone in 1.8 s. A boss floor's real adds arrive
  on `at_boss_fraction`, and two systems that put fighters in a room is one too
  many, so this one puts a THREAT in the room instead.
- **the prism** (24, 1.00/1.90, third phase only, 4 s cooldown) - he draws the
  city's light in off the window and sweeps it across the room as a white
  beam: 140 degrees in 1.4 s, opening 0.35 rad behind the player on the side
  it comes from, alternating direction every cast. Picked from a four-way
  preview and shipped as previewed, with one change asked for: the preview's
  beam split into a rainbow, and the shipped one is white, his own ramp. Three
  things about it are load-bearing:
  - **The fan is the fairness.** For the full second of the wind-up a dithered
    fan on the floor shows exactly the arc that will sweep, so the arc is FIXED
    the moment the cast begins (`_aim_prism`) and nothing about it may move.
    At 100 degrees a second the beam crosses a body 50 px out at about walking
    speed, so outrunning it at range fails; the answer is the 220 degrees the
    fan never covers.
  - **One length function, three consumers.** The arc is raycast against the
    walls once per cast (48 samples) and `prism_length()` reads it, so the
    fan, the beam and the hitbox stop at one wall. Furniture and bodies share
    the walls' collision layer, so the ray skips anything that is not the
    walls' TileMapLayer: the light goes over a desk the way the band does, and
    the fan draws over one for the same reason.
  - **It is a blow every frame it touches you**, metered by the grace window
    as in the preview - which is one hit for a beam that crosses a body in a
    tenth of a second, and a second hit for a player who runs WITH it.
  `prism.gd` is three parts split by space like the glare: `floor` (the fan,
  under him at z 0, because a negative z draws under the Floor tilemap),
  `air` (threads off the window, the chest point, the beam with its
  afterimage and wall sparks, at z 1 over everything standing in the room) and
  `screen` (one white flash, on his layer 1 under the HUD). Its row is the
  glare's dim-and-rise with the impact frame HELD for the sweep, because the
  beam is his shine leaving him.
- **the cold room** (5.0/s inside r 34, third phase only) - an aura, not an
  attack, on the wraith's `drain()` path: it knows its own rate, and the grace
  window neither blocks it nor is opened by it. `chill.gd` draws the EDGE
  brightest, at exactly the radius the drain uses, because an aura with no
  telegraph is only fair if you can see how far it reaches.
- **the crossing** (24, 1.4 s cooldown) - above.

**Every reach he owns used to point along x, so he had to be given one that
does not** - and the crossfire's arms are now a second answer, at range. The band is a 20 px lane through his chest, the crossing only travels
along x, and the split will not fire closer than 34 - so a player standing
directly north or south of him at arm's length was missed by the lane on BOTH
axes, slid past by the crossing, and not worth a split. Phases one and two
landed nothing at all on them, and the last fight in the game was free to
anyone who hugged him. `_flash_at_source()` is the answer: the glare bursts off
HIM before it sets out and catches anyone inside `Touch` whatever line they
stand on, sharing `_glare_hit` with the band so one glare cannot hit twice. It
needed no new number and no new shape, and standing in the source of the glare
being the worst place to be is the obvious reading of it. `tests/test_silverman.gd`
opens with that case, because it is the one a placement can never reveal.

Nothing about the ladder lives in the effects. `chill.gd` asks him `tier()`,
`glare.gd` reads `herald`, and both walk up to the `bosses` group to find him
the way `brush.gd` does - so an effect on a CanvasLayer is as able to reach him
as one under the body, and neither is told anything.

**Placed: floor 12, the penthouse**, at (272, 140) - the centre line, 100 px
north of where you walk in and inside his 130 sight, so he has seen you before
you have taken a step. x is `DOOR_CENTRE_X` and that is the load-bearing half:
his glare sweeps 140 px along x and his crossing travels 72 along x, so he is
the one boss whose attacks need the room's WIDTH, and centred is the only
placement that gives him all of it both ways.

**He is the one boss floor with no door to lock.** Every other shuts its north
door until the boss concedes; the penthouse is the end of the chain, so
build_levels.gd cuts nothing through that wall and the boss-door swap has
nothing to swap. Beating him opens no floor - what follows is the ending.

His floor's beat is quarters of whatever he opens at (`at_boss_fraction` 0.75 /
0.5 / 0.25), which solo is 216 / 144 / 72 of 288. They sit deliberately OFF his
phase boundaries (two thirds and a third), at any party size:
one thing to read at a time was the whole argument for the arena being empty,
and it applies just as much to two clocks running on the same health bar.

**He is Silverman, and it is his office.** That was the open question here and
it is closed: there is no boss above him and no rename coming. The bar says
SILVERMAN because `title()` reads the scene's filename, the floor card says
SILVERMAN'S OFFICE because it reads the biome, and Big Mo's concede passes you
up to him by the same name - three readers, one name, none of them told about
the others. What he is to the rest of the family nothing in his lines says, on
the rule Big Mo's file already set (game/bosses/big_mo/CLAUDE.md's What he
says).

## He says everything twice

Swedish first, then the same thing in English, and it is the cheapest character
in the building: **one `text`, one clip, and not a line of shared code.** The
two halves live in one string with a `\n` between them, so the subtitle draws
two rows and the recording runs straight through. `enemy_lines.gd` reads a
string, measures it and holds it for the clip's length, and has no opinion
about how many languages are in it.

That was the whole test of whether the idea was affordable. A second language
that wanted a second field, a second clip or a second timer would have been a
rewrite of a node three bosses and two enemies share, for one boss. It wanted
none of them, so it is a data file - and the one thing that did change is in
`cut.py`, which now turns that `\n` into a real break on its way to the API
rather than sending the two characters a backslash and an `n` actually are.

Three things follow, and the first two are the cost:

- **A line is twice as long, so he says fewer of them.** His clips run 2.7 to
  9.4 s against Ahmed's 1 to 3, and the subtitle holds for as long as the clip
  does. The answer is not shorter lines - it is his `Lines` child's
  `cue_seconds` at 12 against the default 9, and 14 on both attack cues, so a
  0.5 s wind-up cannot drag a seven-second speech across the fight that
  follows it. Anything added to his file has to be short in BOTH languages.
- **Three rows of subtitle, not two.** Speaker, Swedish, English. The block is
  pinned 46 px off the bottom and grows UPWARD, so it clears the boss bar the
  way it always did - the check in test_barks.gd that measures that is
  unaffected, because what moved is the top of the block.
- **Nothing on screen would notice him stopping.** An English-only line is
  legal everywhere: the node reads it, the clip is cut from whatever is
  written, the box draws one row. So test_barks.gd sweeps his file off disk -
  every line has two halves, the halves differ, every clip resolves, no two
  lines share one, and every cue he speaks on is a cue something fires.

The voice is a Swedish one reading English rather than an English one
attempting Swedish, which is Ivan's decision again: the Swedish half has to be
a native's or the conceit dies on the first line, and the accent the English
half inherits is free characterisation for a man who has all the time in the
building. Adam Composer, picked from three auditioned on one line rather than
from the label on it - `tools/voice/silverman.py` has the rest.

## What he says

Twenty lines across nine cues in `silverman/taunts.gd`, cut by
`tools/voice/cut.py silverman`. Two things about the set are decisions:

- **He is gracious, and that is what makes him the third boss.** Ahmed is
  entitled and loud and sure this is HR's fault; Big Mo is procedural, booking
  the room and noting your feedback; Silverman is PLEASED TO MEET YOU. He
  compliments you on arriving, he thanks you for hitting him, and he is going
  to kill you anyway. There is not one insult in the file and the only thing he
  ever says about himself is how much time he has. Two men of one family
  shouting would be one boss fought twice; three would be a shame.
- **`meeting` and `review` are cues he added himself**, said by `silverman.gd`
  as he crosses into phases two and three - DESIGN.md's own names for them.
  They are two cues rather than one `herald` cue holding two lines for the
  reason `_begin_attack` says the attack id: which rung just arrived is the
  only information in the line, and one cue would pick between them at random
  and throw it away. The crossing gets no cue at all - it never runs through
  `_begin_attack`, and a man who announces his own dash is hurrying.

## Online

On a guest he is drawn from the host and told his moments like every boss
(game/bosses/CLAUDE.md's *Online*), his crossing and his herald riding in his
own snapshot.

And Silverman crosses THROUGH the guest's player on the guest too: his drawn
body is moved there twenty times a second, and without the collision
exception the host gives him it would shoulder that player aside.
