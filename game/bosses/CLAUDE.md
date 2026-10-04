# Bosses - the rules they share, and the art they don't

Deep dive for `game/bosses/`. The root CLAUDE.md has the one-paragraph
version; `game/enemies/CLAUDE.md` has the cycle every boss runs on.

## The bosses

Three, and the three fights are three different SHAPES on the one cycle. Each
keeps his own fight, art, sounds and lines in a CLAUDE.md beside his scene, so
touching one boss does not load the other two; this file keeps what all three
obey.

- **Ahmed** - a MENU: the attack suits the range. `game/bosses/ahmed/CLAUDE.md`
- **Big Mo** - a RHYTHM: jab, jab, then a hook OR an uppercut, which want
  opposite answers. `game/bosses/big_mo/CLAUDE.md`
- **Silverman** - a LADDER: three phases, each adding a mechanic, the
  interrupts narrowing to none. `game/bosses/silverman/CLAUDE.md`

Some rules every boss keeps were written up where the first boss to need them
is, and stay there: the hit-stop (`froze`) in Ahmed's; in Big Mo's, the camera
shake (`shook`), CanvasLayer 1 and the two-scales trap (*The Bell*), an effect
on fixed seconds agreeing with its frames only on frame boundaries (*The
Rage*), and one fire with a ramp per boss (*brush.gd, and the second fire in
the game*); in Silverman's opening, the wind-up tint a greyscale palette has
to refuse.

## What a boss is

A boss is an enemy with more than one attack that concedes instead of dying.
`boss_base.gd` extends `enemy_base.gd` and changes exactly three things:

- **Contact picks an attack.** Where the base enters WINDUP on touch, the boss
  asks `_pick_attack()` for an id and `_begin_attack()` loads that attack's
  wind-up, recover and damage into the base's own dials. The cycle itself is
  untouched, so `commit_fraction` and `interrupt_cooldown` mean what they
  always meant: a boss can be staggered out of a wind-up once, then not for
  1.2 s.
- **The attack's animation is the whole cycle.** `<attack>_side` runs from the
  first wind-up frame to the last recover frame, and its per-frame durations
  come from the same pose list the boss script derives `windup_seconds` and
  `recover_seconds` from (`Poses.windup_of()` - everything before the frame
  marked `impact`). The picture and the timer cannot drift. Because of that,
  `_apply_animation` holds a finished attack animation on its last frame
  instead of restarting it the way the base does, and `_contact_state()` is
  `idle` - a boss sheet has no plain `attack` row.
- **Zero health is a concede.** `has_conceded` goes true, the boss leaves the
  `enemies` group (so "is the room clear" checks stay honest) but stays in
  `bosses` and in the tree, plays `concede_side`, and emits `conceded`. It is
  never freed: he is still kneeling there when you walk out. A boss who should
  keep MOVING after that hands off to a looping row himself, off
  `animation_finished` in his own script (Ahmed does; see his `beaten`) - the
  base plays the concede once and stops there, because one animation cannot
  loop only its last two frames.

Bosses face **side only**. `_face()` never picks up or down, so a boss sheet
draws one profile and the game flips it. Four attacks in three directions was
twelve rows of art for a fight that reads perfectly well sideways.

## Nothing is shared between bosses but the rules

Each boss folder holds everything that is his: scene, script, `poses.gd`,
`src/<id>.png`, `<id>_frames.tres`, and any effect script. `roster.gd` lists
them, and each entry names its own painter and cell size. There is no shared
body, no shared sheet, no shared layout - the three bosses are heading three
different places.

## Sheets: seed once, slice always

`tools/build_bosses.gd` is build_enemies.gd's contract with a different seed:
an enemy is recoloured from the frozen CC0 body, a boss is painted by its own
`tools/bosses/<id>.gd`. Only when the PNG is missing. From then on
`src/<id>.png` is hand-owned art - draw into it, rebuild, only the frames
change. Delete it to start over from the painter.

Rows are `Poses.ORDER` (idle, walk, chop, sweep, slam, wave, concede, beaten),
one row per animation, frames left to right, padded to the widest (nine). The slice
runs at `Poses.FPS` (10) with each frame's `dur` as a duration multiplier, so
the sheet carries the attack's own timing; `character_art.slice()` grew a
cell-size argument and `durations` for exactly this, defaulting to the 32 px
CC0 behaviour everything else relies on.

**A row added after the seed goes on the END**, and the builder paints only
that. `build_bosses.gd` asks the painter for the whole sheet every run and, if
the painted sheet is taller than the PNG on disk, blits ONLY the missing rows
onto the bottom - every row already there is left exactly as it is, drawn into
or not. That is the cast's `arc_pose.gd` rule arriving here, and it is what
let Silverman gain `prism` without a redraw or a re-seed. The one rule it puts
on `ORDER` is that a new animation is appended, never inserted: anywhere else
it would land on a row somebody may have drawn into.

If you hand-draw a frame, keep the body where the painter put it: the fire is
drawn from the poses, not from the pixels, so a hand-moved axe leaves its
flame behind.

## Boss floors

A floor gets its boss from `tools/biomes/<level>.gd` under `boss`
(`{type, at}`), the same shape as one `enemies` entry. build_levels.gd
instances it as `Props/Boss`, the name a health-cued beat asks.

**His doors are every room's doors.** A room is sealed until it is beaten
(game/levels/room_clear.gd), and a boss counts as standing until he concedes -
`_concede()` takes him out of the `enemies` group, and the rule skips anybody
with `has_conceded` besides. So the arena is a gate with no door script of its
own: both ways out are shut while he stands, the way up and the stair back
down, and the penthouse's one door is the stair. `boss_door.gd` used to be
that gate, and was switched off for development; it is gone. A beat he never
called - burst past his threshold to nothing - does not hold the doors, because
`spent()` counts a health cue that can no longer come as spent
(game/levels/CLAUDE.md's *A room is sealed until it is beaten*).

Ahmed's sight reaches the south spawn on purpose. Every other floor keeps the
door-to-door walk out of every sight radius; a boss floor is an arena and the
walk goes through him. test_chain.gd concedes him the short way
(`take_damage` for 36, then the 108 left) to carry the chain on; the fight itself is
`tests/test_bosses.gd`'s, which places him in the empty lobby like
test_combat.gd does and records the order he attacks in rather than betting
on frames.

## The bar

Every boss puts his health on the HUD, and none of them knows it. `title()`
names him from his own SCENE path - `Props/Boss` is what build_levels.gd calls
the instance, so his node name would put BOSS on the bar - and `take_damage()`
emits `health_changed(health, max_health)`, the same signal in the same shape
the player already has. game.gd finds him through the `bosses` group when it
builds the room, feeds `Hud.set_boss()` once and wires the rest straight
through; the bar comes down on `conceded`, since he is never freed.

So a new boss gets a bar by existing. Nothing in `ui/hud/boss_bar.gd` names a
boss and nothing here names a bar.

The bar itself is ember, not the player's crimson - two red bars on one screen
is one bar the player has to identify first - and the pale block trailing the
fill is a hit's worth of ground, held and then drained. Both boss HP are
multiples of the heavy's 24, so a heavy is a visible chunk of a 240 px channel:
a quarter of Ahmed, a sixth of Big Mo.

## The noise

`game/enemies/enemy_audio.gd` is to sound what `enemy_base.gd` is to the
fight: the mechanism is shared, the files are not.

**It is in `game/enemies/` and it used to be `boss_audio.gd` here.** The plain
enemies wanted the identical node for the identical job, and a boss IS an
enemy - `boss_base.gd` extends `enemy_base.gd` - so it bubbled up one level
above both of them, which is the placement rule in the root CLAUDE.md rather
than a favour to anybody. `_sfx`, `_sfx_loop` and `_sfx_fade` went with it and
are inherited; what is still here is only WHERE a boss fires them, which is
the half that was ever boss-specific. Nothing about a boss's sound changed:
game/enemies/CLAUDE.md's The noise is the other half of this section now, and
the two traps listed there - a death that frees its own player, an impact
fired on a blow that missed - are both things a boss never had, because he
concedes instead of dying and names his impacts after his attacks.

A boss's scene gets an `Audio` child holding a
`sounds` dictionary of id -> stream, one `AudioStreamPlayer2D` is built per
entry at `_ready`, and **three ids are wired by the base for free** - `hurt`,
`stagger` and `concede`. A boss gets those by owning the files, the same deal
as the HUD bar; a boss who owns none stays silent with no branch anywhere but
`_sfx`.

Four things are load-bearing:

- **Every miss is legal.** An id the boss was never given, a boss with no
  `Audio` child, and a checkout whose WAVs have not been imported yet all
  land in the same null check and play nothing. That is not defensiveness for
  its own sake: the audio is the one part of the game that is NOT generated
  from data, so a fresh clone genuinely does have a scene pointing at five
  resources that do not exist until an `--import` pass has run, and the fight
  has to work anyway. test_bosses.gd passes with the sounds missing.
- **The stagger REPLACES the grunt.** A hit that interrupts a wind-up plays
  `stagger` and not `hurt`. The one thing the player needs off that hit is
  that the swing died, and two sounds on one frame is the fastest way to hear
  neither.
- **And a LINE replaces the grunt in turn**, now that he is voiced: a grunt is
  his voice and so is a line, so playing both is one mouth making two sounds.
  `_say()` returns whether he spoke and `hurt`, `stagger` and `concede` fall
  back to `_sfx` only when he did not - which is most hits, because most hits
  find the cue cooling down. His AXE does not stand down that way: a wind-up
  clip plays under a shout, because a man shouting as he swings is what he is
  supposed to sound like. The split is where the sound comes from, not how
  busy the frame is.
- **A loop's flag is set on the stream, not trusted to the .import.** Import
  settings are written by whoever first scanned the file, and a loop that
  quietly does not loop is very hard to notice inside a fight.
- **Levels are relative and baked into the files**, not left to the mixer:
  Ahmed's idle fire sits at -14 dBFS because it plays for the whole fight,
  his one-shots near -4 so a hit reads over it. There is no audio bus layout
  and no volume setting yet, so a file's own level IS the mix. Re-generating
  one sound means re-levelling it against the others.

Ahmed's and Big Mo's own sets, and how each was levelled, are in their own
files under *What he sounds like* - Ahmed's with the two only he has, the axe
that burns for as long as he holds it and the breath once he is down.

His sounds sit in `ahmed/sfx/`, and their untouched exports in `ahmed/src/`
next to his sheet - the same split `src/` means everywhere else in this repo.
An ElevenLabs export is padded to a full second whether or not the sound fills
one, so what lands in `sfx/` is always trimmed, summed to mono and levelled,
never the file that came out of the generator: his grunt had 0.35 s of silence
in front of it, which is a hit landing a third of a second late.

His eight attack sounds are a telegraph and an impact for each of chop, sweep,
slam and wave, split in two on purpose - a wind-up can be interrupted, so a
single clip covering the whole swing would play an impact that never happened.
Neither is wired by hand: the id IS the attack, so `boss_base._begin_attack`
asks for `<id>_windup` beside the bark it already says, and any boss gets
telegraphs the day he owns the files. The IMPACT is said in Ahmed's own
`_strike` rather than the base's, and that asymmetry is the fight's fault
rather than an oversight - the slam sweeps a ring, the wave hands its lanes to
a fan, the chair's blow is its crash; none calls `super()`, so the base never
sees three of his five blows land.

### The theme is not one of his sounds

A boss's MUSIC goes through `Music` (autoload/music.gd) and never touches
`enemy_audio.gd`, and the split is the same one that decides everything else in
here: his grunts are positional, because a boss crossing the room should pan,
and a track is not standing anywhere. So a theme is a plain path on
`boss_base` - `@export_file("*.wav") var music` - which `game.gd._watch_boss()`
plays when it finds him by group and fades when he emits `conceded`, on
exactly the two moments it raises and clears his HUD bar. Three consequences
worth knowing before adding a second theme:

- **A new boss needs no music code**, the same way he needs no HUD code. He
  names a file on his scene root and that is the whole of it.
- **Silence is a floor with no live boss**, decided in one place. `_watch_boss`
  fades whatever is playing when it finds nobody - which is every ordinary
  floor, and also a boss floor walked back through after he has conceded,
  since a conceded boss is skipped. No room says anything about music.
- **The track is declared on the boss, not in `Music`'s catalogue.** That
  catalogue exists for `MENU`, the one track three front-end screens ask for
  by name and would otherwise spell out three times. A boss theme has exactly
  one asker, so it lives on him - and a boss who names none simply fights on
  in silence.

`Music.fade_out()` deliberately does NOT restart a fade already running,
because these exits stack: conceding starts one and the door off his floor
asks for another while it is still going.

Each theme's own story is in its boss's file under *His theme*: Ahmed's seam,
and from Big Mo two things worth carrying to the next theme - a tempo chosen
against his cycle, one unbroken loop with no build - and why a theme is
levelled against HIS sounds and never against another boss's theme.

## The mouth

A boss can also TALK, and it is the third thing in this file built on the same
shape as the bar: `enemy_lines.gd` is the mechanism, his lines are not. A scene
gets a `Lines` child naming a `.gd` of them, `boss_base` already calls the
cues, and game.gd hands what comes out to `ui/subtitle/`. So a boss talks by
owning a file - the exact deal his bar, his theme and his grunts are on - and
a boss with no `Lines` child says nothing, with no branch anywhere but `_say`.

**It is in `game/enemies/` and it used to be `boss_lines.gd` here**, the same
move `enemy_audio.gd` made and on the same rule - except that this time the
second user needed the node completely unchanged. Two enemies mutter to
themselves while they work (game/enemies/CLAUDE.md, The mutters) and wanted
exactly what a boss already had: one line at a time, a cooldown per cue, never
the same line twice running, the clip loaded by path and played positionally.
`_lines` and `_say` are on `enemy_base` now.

What a boss still owns is the SUBTITLE. `_say` is overridden here to emit
`said` on top of the base's behaviour, and that split is worth stating: **a
boss is addressing the player, an enemy is being overheard.** An enemy's line
deliberately never reaches the box.

**All three talk now.** `ahmed/taunts.gd`, `big_mo/taunts.gd` and
`silverman/taunts.gd` sit beside their own poses and sheets, on the placement
rule an NPC's own conversation already follows: a line is owned by the mouth it
comes out of. There is no silent boss left in the building, and that cost
test_barks.gd a check it had been handing from one boss to the next - "a boss
with no lines says nothing" could only ever be asked of whoever had not been
written yet. It asks the better question now: it tears the `Lines` child OFF
Silverman, the boss who talks most, and checks he is still silent and still
fighting. That one cannot go stale.

### The cues, and where they are fired from

Seven, and the split is between the ones the CYCLE already knows about and the
two it does not:

- `hurt`, `stagger` and `concede` are fired exactly where the three sounds of
  the same names are, in `take_damage()` and `_concede()`. Being hurt and
  being interrupted stay two different things to say for the same reason they
  are two different sounds.
- **an attack's cue IS its id.** `_begin_attack()` says the id it was handed,
  so `chop`, `sweep`, `slam` and `wave` are Ahmed's cues because they are
  Ahmed's attacks. A boss with different attacks names different cues by
  having them, and neither file learns the other's vocabulary.
- `spot` and `taunt` are the two the cycle cannot name, because neither is an
  event, so `_watch_player()` in the base looks for them: the frame he first
  lays eyes on the player, and the player refusing to come near him.

**The taunt is measured off his REACH, not his sight**, and that is the whole
of what makes it read as a taunt rather than as a man muttering. At the far
edge of his sight radius he is walking towards you, and a man walking towards
you has nothing to complain about yet; it is standing just outside his swing
and STAYING there that earns "come here". So the timer runs on
`not touching_player`, resets on contact and on any attack, and `TAUNT_SECONDS`
is long enough that an honest walk-in never trips it.

### What the mechanism owns is WHEN, and the tuning is data

The lines are data; `enemy_lines.gd` is the policy that stops a man with twenty
of them from reading all twenty at once. One line at a time, so a subtitle is
never painted over part-read; a per-cue cooldown, because he has one line for
being hit and is hit sixteen times; never the same line twice running, so a
repeat means he has run out rather than that the dice went that way; and
`ALWAYS` - `spot` and `concede` - jumping the queue, because the two moments
that must land are the one he looks up on and the one he goes down on.

**The cooldowns are per cue on his scene, and the split in them is a
judgement rather than a number that fell out**: his swings are on 16 s and his
reactions on 4-6, because the animation IS the telegraph here (see the top of
this file) and a line on every swing is garnish that crowds out the lines that
are actually feedback. An attack cue that hogs the one line-at-a-time budget
leaves nothing to say about being interrupted, which is the more interesting
half. Tune by making the garnish rarer, never by letting two lines overlap.

### The subtitle is not the dialogue box, and that is the point

`ui/subtitle/` renders it, and it is dumb in the way the HUD and the level card
are: a name, a line, and how long to hold them. `ui/dialogue/dialogue_box.gd`
could not do this job at any price - it types its line out, it WAITS for a
keypress, and the player is under someone else's control the whole time it is
up. In a fight that is a bark that eats the attack key and gets you hit. So
this one types nothing, takes no input at all, goes away on a timer, and
carries no panel: a box at the bottom of the screen is the shape the player has
learned means "stop and read".

Two consequences worth knowing:

- **He is named off `title()`**, the same string the HUD bar uses, so the
  subtitle says AHMED. His node is called `Boss` - build_levels.gd names it
  that so the north door can find him - and a subtitle reading BOSS is the one
  thing it must not say.
- **A bark is dropped, never queued, while an NPC is talking.** game.gd checks
  `_dialogue.talking()` and throws it away: the dialogue box is at the bottom
  of the screen too and it holds the player's hands as well as their eyes.
  Nothing is lost, because a bark is only ever about the moment it was said in.

### He is voiced, and nothing had to change to make him so

Every line carries `voice`, a path to its recording, and all twenty-three are
cut. `enemy_lines.gd` loads the clip, plays it positionally like his grunts, and
returns its LENGTH as the line's hold - the one piece of arithmetic a subtitle
can never guess for itself, and the same bet `dialogue_box.gd` made for
conversations. That bet paid: the clips arrived as data and one key per line,
with no code written anywhere.

Every miss stayed legal on exactly the terms the rest of his audio is on - a
line with no clip, and a fresh checkout whose WAVs have not been imported yet,
both land in the same `ResourceLoader.exists()` check and play nothing while
the line still reads for as long as it takes to read. `test_barks.gd` asserts
the contract in that shape deliberately: when a clip IS on disk no line may
read faster than he says it, and when one is not the suite passes anyway.

Three things about the cutting are worth knowing before a second boss is
voiced, and they are all in `tools/voice/` (mechanism in `cut.py`, his own
direction in `ahmed.py`):

- **The read is TAGGED, not tuned.** Eleven v3 takes an inline direction -
  `[furious, roaring]` for a taunt, `[defeated, bitter, muttering]` for the
  last line - where the older model can only be made less stable and hoped at.
  Both were cut and compared before choosing. A cue's character is therefore a
  piece of direction anybody can read back, not a number nobody can.
- **An approved take is frozen.** Text-to-speech is not deterministic, so
  re-running the generator on a line somebody listened to and picked would
  ship a different performance. `KEEP` in `ahmed.py` names those.
- **Levelled on speech, not on peaks.** Peak-matching a roar and a mutter
  leaves them 13 dB apart in the only thing anybody hears, which is how the
  quietest and most important line in the fight gets buried.

How `cut.py` levels the speech itself, and `--relevel` carrying a boss cut
under an older leveller onto a newer one for nothing, was settled on Big Mo:
`game/bosses/big_mo/CLAUDE.md`'s *What he says*.

`tests/test_barks.gd` is the suite, and it has its own file for the reason
every suite here does: the headline cue needs a boss who never reaches anybody,
which is the exact opposite of the fight test_bosses.gd has to run.

## Online: drawn from the host, and told the moments

A boss is an enemy, so on a guest he is the host's, drawn (game/enemies/
CLAUDE.md's *Online*): his snapshot carries what any enemy's does, plus
whether he has conceded, his max health (it grew per head on the host) and the
attack in hand - so his bar, his concede, the door upstairs and his theme all
follow with nothing of their own. Everything a boss draws off his SPRITE (the
axe's fire, the Bell, the Rage, the Glare) is right on a guest for free,
because the sprite is the host's. What his own effects read off HIM goes in
his own snapshot after `NET_OWN`: Ahmed's height and chair, Big Mo's kept fire
and his hit-stop (his sprite's speed), Silverman's crossing and his herald.

What a snapshot cannot carry is a MOMENT, because by the next picture it is
over - so the host `_tell()`s it and his copy on each guest hears it in
`net_event()` (game/sync/world.gd's *A moment*):

- **Lines**: the host picks one and tells the guests WHICH, so every machine
  puts the same words up and plays the same clip (`enemy_lines.say_exact`). A
  guest's boss says nothing of his own accord.
- **Sounds and shakes**: every one of a boss's sounds is the host's to make and
  tell, because his moments are not phases a guest could read them off. The
  one exception is what he makes while he is still being BUILT - Ahmed's axe
  starts burning with him on every machine, before any guest is in the room to
  be told.
- **What he throws**: Ahmed's every effect goes through `_spawn_fx`, so that
  one call is the moment, and it carries the attack it belongs to - an effect
  that ends with its attack (the chair, the leap's mark) must not find a guest
  a snapshot behind and end on its first frame. The chair's launch and crash,
  Big Mo's block spark, Silverman's copy, the prism's fan (measured once, on
  the host, walls and all) and the glass ceiling's grid are moments of their own. What an effect thrown on a
  guest does to anybody is nothing - player.gd's rule - so only the host's
  burns.

Silverman's crossing needs one thing more on a guest:
`game/bosses/silverman/CLAUDE.md`'s *Online*.

Since M4 all of it happens a tenth of a second after the host (sync.gd's *One
clock*): his snapshots AND his moments wait for the same moment of the host's
clock, so a fire he throws still leaves the axe that is drawn throwing it.
Between two snapshots he walks rather than steps (enemy_base's
`net_between()`), and Ahmed's leap arcs with him - his height is blended too.
His STOP is a moment like his shake: `froze` is told, and on every machine it
holds the picture rather than the clock (game/picture_hold.gd). Big Mo's own
hit-stop is his sprite's speed and needs nothing: a picture hold catches a
sprite up at whatever speed it is playing at when the hold lets go, so the
two stops sit on top of each other without either undoing the other.

Adding a boss, then, adds to his snapshot what his effects read off him, and
`_tell`s any moment his effects need that the snapshot does not carry.

## Adding a boss

1. `game/bosses/<id>/poses.gd` - body ASCII, legs, `ORDER`, `ANIMS`, `LOOPS`.
2. `tools/bosses/<id>.gd` - a painter with `static func paint() -> Image`.
   Copy Ahmed's; only the poses it reads and its cell geometry change.
3. A roster entry in `game/bosses/roster.gd`.
4. `game/bosses/<id>/<id>.gd` over `boss_base.gd`: `_pick_attack()`,
   `_attack_spec()`, `_strike()` for anything that is not the axe on `Touch`.
5. `game/bosses/<id>/<id>.tscn` with the reaches it needs.
6. `"boss": {type, at}` in the floor's biome file, then
   `build_bosses.gd` and `build_levels.gd -- <level>`.
7. A section in `tests/test_bosses.gd` (one suite, one world: place him in the
   lobby and fight there).
8. `game/bosses/<id>/CLAUDE.md` for his own notes, and a line for him in The
   bosses above.

There is deliberately no step for the HUD bar: he is in the `bosses` group and
over `boss_base.gd`, which is all game.gd looks for. See The bar.

## Still to build

Nothing shared. What is left is per boss, at the end of his own file: Ahmed's
"SECURITY!" and Big Mo's concede.
