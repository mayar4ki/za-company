# Levels - how a room works

Deep dive for `game/levels/` and game.gd's hosting of it. The cross-cutting
rules (regeneration semantics, the no-room-state rule, preload-not-class_name)
live in the root CLAUDE.md; the generators and biome data that write these
folders are documented in `tools/CLAUDE.md`.

## The host and the room

`game/game.tscn` is a host, not a room: it owns the party, camera, HUD, fade
and pause menu, and swaps one `Level` child underneath them. A level owns only
its own tiles, props and spawn markers, and answers three questions -
`bounds()` for how much world there is, `spawn_position(name)` for where to
stand, and `title()` for what to call itself. Nothing in game.gd names a
specific map beyond `START_LEVEL`.

**Arriving somewhere announces it.** `ui/level_title/` is a card game.tscn
instances on its own CanvasLayer, fed one string by game.gd at the end of
`_enter_level` and dumb about everything else, exactly like the HUD: three
seconds at full opacity, then it fades itself out over 0.4s, and a second call
cuts the first off rather than queueing behind it, so stepping straight back
through a door reads the room you are now in. It sits at layer 6 - above the
transition fade so the name is already legible on the black with the room
appearing behind it, below the pause menu's 10 so a death screen still covers
it. The name is authored per biome as `title` in tools/biomes.gd and written
into the level scene as the `display_name` export, with `title()` falling back
to the node name; it is authored rather than derived because "THE MARBLE HALL"
is not a transformation of "MarbleHall" that any rule gets right everywhere
("HELLFIRE" takes no article). Being called from `_enter_level` is what makes
the start of a run announce the lobby too, and what keeps a respawn silent -
dying and getting up in the same room is not arriving somewhere.

**The party is spawned, not placed.** game.tscn holds no player: game.gd builds
one body per member from `next_party` - a party of one, the saved pick on the
keyboard, unless something says otherwise - and the first is THIS machine's,
named `Player` as the one fixed child used to be. Each is moved into the tree
straight after the background, where that child sat, so the y-sort breaks ties
against the room as it always has. A door or a spawn stands the party in a row
across the marker, `PARTY_SPACING` (12 px) apart, which is nothing at all for a
party of one. The lives are the party's single pool on game.gd, and a death in
company is a body DOWN rather than a fade - see game/player/CLAUDE.md's Health.
`tests/test_party.gd` owns all of it.

The camera lives on game.tscn, not on the player, and game.gd decides per axis:
it follows THIS machine's player where the level is bigger than the screen -
whoever else is in the room - and centres on
the level where it already fits, showing the room whole. Camera2D's own limits
are deliberately unused - they cannot express the second case, and asked to keep
a 544 px room inside a 640 px view they contradict themselves and jam the camera
against one edge. At zoom 1 the base viewport is 640x360, so a level up to that
size is seen entire, and the screen left over around a smaller room is void.
That void is deliberate - filling it with the level's own rock was tried and
looked worse than black.

## Online: every room is the host's

Every machine builds the same level, and the HOST's runs it (DESIGN.md's
Multiplayer, M3). What a room does besides its enemies reaches a guest by the
same one snapshot the enemies do (`game/sync/world.gd`: each thing joins the
`synced` group and answers `net_state()` / `apply_net_state()`), and splits two
ways by whether a guest can work it out for itself:

- **A CLOCK runs everywhere and is only put right.** The studio's take, the
  dolly on its rail and every run of wiring are timers counting the same
  seconds on both machines, so a guest counts its own and takes the host's only
  when the two have come apart by more than a `DRIFT`. Taking every snapshot
  would drag the room back by the trip each one took, twenty times a second,
  which is a stutter; the two clocks agree anyway.
- **DICE are the host's alone.** A scrubber's turns are thrown on the host, so
  a guest draws it where the host says - a tenth of a second behind, rolled
  along the line between two snapshots and its scanner swung with it
  (`net_between()`, M4), through nothing.

The split decides one more thing since M4: **a clock is not drawn behind.**
Everything else a guest draws waits a tenth of a second for the host's word
(game/sync/sync.gd's *One clock*); a clock answers no `net_between()`, so it
takes the host's state the moment it is heard. Held back with the rest, every
correction would set it that much late, and a hazard drawn late is one that
hurts before it is seen.

And four things are the host's to DO: a beat walking anybody in
(`reinforcements.gd`, `relief.gd`), Ivan throwing his hearts, a pickup being
spent - a guest's heals nobody, by player.gd's rule - and a door going. What
they make appears in a guest's room on the next snapshot, made from its scene,
and what they spend is gone from it on the same one.

## The shape of a floor

Eight floors are a 34 x 19 rectangle - 544 x 304 px - and that was true of all
twelve until the call floor became a DOGLEG: a hall 40 tiles wide with an arm
off its north-east corner, 640 x 592 with the north-west corner cut out of it.
It is the only room in the game you cannot see the exit from.

The marble hall is the other one, and it is the cheap half of the same idea: no
cut at all, just the rectangle turned on its end. 26 x 40 - 416 x 640 - with
both doors at col 12 facing each other down its length, so the walk is one
straight leg 608 px long and the room is what stands either side of it. A shape
does not have to be clever to change a floor; this one is four numbers.

The innovation lab is the expensive half, and it is the only floor in the game
that is not ONE room: an S, 32 x 63 - 512 x 1008 px, the biggest floor there
is - built as three halls of 30 x 15 stacked up the building and joined at
alternating ends by two links six tiles wide. Two cuts make it, one per link,
each taking a 24-tile bar out of the plan and leaving the far end of it open.
The walk crosses each hall in the opposite direction to the last, so the floor
bends three times where the call floor bends once, and no hall can see either
of the others.

**Its size is arithmetic, not ambition, and the sum generalizes to any floor
shaped this way.** On a rectangle the walk is a vertical band and a body clears
it sideways, across the whole width of the room. Here the walk CROSSES a hall,
so the clearance budget is its DEPTH: a hall has to hold the 54 px band plus
the biggest sight radius standing off it, which is 130. Thirteen floor rows
leaves 154 px beside a wall-hugging band - inside the rule by 24 px, and one
nudge from outside it. Fifteen leaves 186. Two corollaries worth keeping:
every crossing hugs a wall, because a band down the middle of a hall halves it
twice over; and a body near a hall's north wall is close to the crossing in the
hall ABOVE, since sight is a radius and not a line of sight, so eight tiles of
masonry between them count for nothing.

Hellfire is the fourth, and its own shape is documented with its fight.

**The shape is data, and it lives in `tools/plan.gd` rather than in the
generator.** A biome's `shape` key carries `cols`, `rows`, `doors` and one of
two ways of saying where the room is not:

| form | what it says | for |
|------|--------------|-----|
| *(nothing)* | the 34 x 19 room | eight floors |
| `cut` | the room, minus a list of tile rectangles | L, neck, atrium - anything still rectangles |
| `mask` | the plan drawn out, `#` for masonry | the floor that is not rectangles at all |

Everything else falls out of ONE question - `solid(col, row)`, is this cell the
building or the room? The wall ring is grown around whatever is left, the
shadow course hugs it, a doorway is cut where its own column meets the wall,
and a colonnade skips the pillars that would land in masonry. So a shape nobody
has drawn yet is one new way of answering that question and no branch anywhere
else. The two forms differ in one way worth knowing: a `cut` grows its walls,
because it says where the ROOM is not; a `mask` is literal, because the hand
that drew a plan drew its walls, and growing a second ring inside theirs would
eat the drawing.

**A wall is one tile of FACE, and behind it there is nothing.** `plan.drawn()`
is `solid()` narrowed to the cells that have a piece of room next to them,
corners included, and build_levels.gd paints only those - so a cut comes out as
a HOLE showing the clear colour rather than as a slab of the level's own rock.
It says nothing about the eight rectangles, whose every solid cell is that
face already; on a shaped floor it is the whole look of the missing corner.
Filling it was the first version and it was wrong the same way filling the
screen around a small room was wrong: masonry with nothing happening in it
reads as a room the player has been shut out of, where black reads as the edge
of the picture. The hole is also the thing a regeneration would quietly undo,
so `tests/test_dogleg.gd` sweeps the whole chain for a wall tile with no floor
anywhere around it - 373 of them on the call floor the moment anybody fills it
back in.

**The doors need not be in line with each other.** `shape.doors` gives each its
own tile column, and the spawn markers follow - `start` under the south door,
`returned` under the north one - so coming back down the stairs on the call
floor puts the player at the top of the arm rather than over the hall they left
by. The camera needed nothing: it already followed the player on whichever axis
does not fit and centred on the one that does, and `bounds()` was always
measured off the tilemap rather than stored.

### The walk

The oldest rule in the project is that the way between the two doors stays
clear - no enemy's sight, no hazard, no prop. It was enforced from OUTSIDE the
game by four suites that each wrote down `x 246-300`, which was true while
every floor was the same rectangle. A shaped floor's walk has corners in it, so
the floor carries its own: `lane` in the biome, an export on the level scene
beside its title, and two questions on level.gd -

- `walk_lane()` - the legs, or the straight band for a floor that names none.
- `lane_clearance(at)` - how far a point is from the nearest leg, which is what
  the placement rule is actually measured in: a body clears the walk by its own
  sight radius.

They exist because the alternative was four test files agreeing with each
other by hand about a shape only one floor has, and because a rule this old
should be answerable by the room it is about. Nothing inside `game/` reads
them any more. game.gd's **room alert** used to - it fired when the player
stepped off the walk - and now does not: it fires the first frame ANY player
is more than `ALERT_RADIUS` (3 tiles, 48 px) from the spot they came in on, so
the doorway is the only safe ground and the walk between the doors
wakes the room like anywhere else. Every enemy in the room is `alert()`ed once
(game/enemies/CLAUDE.md, The leash), and every reinforcement that walks in
after that is alerted on its way in. `tests/test_alert.gd` owns it.

`tests/test_dogleg.gd` owns the two failures a shape can cause. One is a room
nobody can cross, swept across the whole chain: every floor's walk is sampled
against its own masonry, so a cut redrawn a tile lower fails there rather than
in play. The other is a body that cannot get round a corner - steering has no
pathfinding, and the thing between the arm and the hall is eight tiles of
building rather than a desk.

## A level owns everything in it

Its folder holds its own tileset, its own doorway art, its own `door.tscn` and
its own copy of every prop it places, each with that biome's palette baked in -
no level borrows another's. Levels are meant to diverge: different styles,
different props, different enemies, doors that lock.

```
game/levels/
  level.gd            base script every level scene runs
  door_base.gd        shared: how a door tells game.gd to swap levels
  hazard_base.gd      shared: presses take_damage() on the player it overlaps
  pickup_base.gd      shared: heal() on touch, consumed only if it healed
  <biome>/            THE ROOM - five files, and it never grows
    <biome>.tscn        the level
    tileset.tres        its floors and walls
    doorway_out.tres    its passage up, lit by the room beyond
    doorway_back.tres   its passage down
    door.tscn           how it connects
    props/            EVERYTHING STANDING IN IT - one scene each, on the
                      same shelves as tools/props/
      fixtures/         column.tscn, torch.tscn, health_item.tscn - each only
                        where the biome asks for it - the gym and the
                        penthouse ask for none
      furniture/        desk.tscn  chair.tscn ...      whatever it
      hardware/         server_rack.tscn  printer.tscn ...  places,
      markings/         boxing_ring.tscn  rug.tscn          by kind
      openings/         city_window.tscn                    of thing
      signs/            notice.tscn ...
```

**A level folder is split by what a file IS, not by its type,** and the split is
between two groups that behave completely differently. The room is a handful of
files that never grow. `props/` holds one scene per prop the biome uses and
grows every time a floor wants new furniture - asset recovery wanted sixteen, which
buried the five files that say what the level actually is. Inside `props/` the
scenes sit on the same shelves as their painters in `tools/props/` (the
generator asks `Props.shelf_of()` where to put each one), so finding a prop's
scene in a level is the same walk as finding its brush - with one renaming to
know: the fixtures shelf is named for the ROLE in the room, not the painter, so
hazard.gd paints `torch.tscn` and heart.gd paints `health_item.tscn`.

**Each prop scene carries its own picture, embedded** as a `[sub_resource]`
right beside its collision shape. There used to be a matching `<prop>_art.tres`
next to every prop scene, and every one of those had exactly one consumer: its
own sibling. That is precisely what a sub-resource is for, and the collision box
was already stored that way - the texture was the odd one out, for no reason.
Removing them halved a level folder (asset recovery 37 files to 21, lobby 28 to 16).

The two doorway textures are the exception and stay as files, because they are
the one texture assigned **per instance**: the level scene hands `doorway_out`
to its north door and `doorway_back` to its south one, so their consumer is the
level, not a prop scene.

Architecture and the hazard are per-biome **styles**, not one look for the whole
game: `column` picks the fluted classical stone, a glazed steel pillar or a
cubicle divider, and `hazard` picks the standing torch, a sparking floor
polisher, an arcing power strip, a ring light knocked over and left at full
output, a photocopier jammed with the fuser still going - or `"none"`, which is
a floor with nothing on it that hurts (the lobby, because a tutorial room must
not have one, and Ahmed's office, the gym and the penthouse, because a room
built around one fight is a room where a burn is the floor's fault). Every
style keeps the same canvas size and foot, so the scenes and collision boxes
are untouched by the choice - only the art differs. The split
exists because the classical column is most of what makes the marble hall read
as a hall, and it was also most of what made the office lobby read as a temple.
What a room uses to break up its floor is exactly what changes between a lobby
and a recovery floor. A biome can also override the colonnade's `columns` layout (a
furnished room needs the floor a full colonnade takes up), hand in an EMPTY one
for no colonnade at all (the gym: a tight arena with nothing in it to hide
behind, and no column scene in its folder either), and ask for a `runner`,
which tints the central floor band toward the accent so it reads as carpet
rather than as more of the same stone.

A room can also be divided by FURNITURE rather than by its column style, and
the hub is the case: its media half is walled into two glass-fronted
offices by a run of `partition` props, because a `columns` layout is rows
times columns and so cannot leave a gap where a door goes. The glass is
translucent on purpose - a wall is drawn upwards from its foot, so an opaque
one would hide anybody standing in the office. The executive floor takes the
same prop the other way: one run of it crosses the WHOLE room with a single
gap left on the door line, so a partition wall stops being furniture that
divides a half and becomes the chokepoint the room is fought at. See
tools/CLAUDE.md.

The `_base.gd` scripts are shared because each is one side of a handshake the
other party owns: game.gd performs the swap doors report, and the player owns
the take_damage()/heal() API hazards and pickups press. Everything else about a
door, torch or heart is the level's: override `can_travel()` in a level's own
script for a lock, or restructure that level's scenes freely. A column has no
shared behaviour at all and carries no script.

## A floor may also name its music

A biome key, `music`, written into the level scene as an export beside its
title and read by game.gd where it otherwise asks for `Music.DEFAULT`. A floor
without the key is every floor: the bed plays, and the only thing that ever
interrupts it is a boss, whose theme is HIS and leaves when the fight does.

Two floors have one - the executive floor and the penthouse, which name the
same file - and the reason it hangs on the ROOM rather than on the man standing
in it is the whole point of the feature. A boss's theme starts on the frame his
bar goes up, so it can never cover the floor below him; the finale has to begin
a floor early, which means it cannot be his. Silverman therefore declares no
`music` at all, and the door between the two rooms costs nothing because
`Music.fade_to` is idempotent on the path - the arriving floor asks for the
track that is already playing and is told it is already playing.

The order inside `_watch_boss` is what makes both true at once: a live boss's
theme still wins, and the floor's own track is what a room falls back to
instead of the bed - including on the frame a boss concedes, where the room
goes back to being an ordinary floor and an ordinary floor is still this one.
`tests/test_music.gd` holds all of it, including the absence on the boss.

## Doors and spawns

Each level has a door north to the next in `CHAIN` and a door south to the one
before, so the two ends of the chain have one door instead of two. Doorways sit
in a gap cut through the wall ring; the door scene carries its own `Seal` body
across that gap, so the map stays closed whether or not the transition fires -
and that is the body a locked door will keep. A south door is the same scene
rotated half a turn, which is why the doorway art is directional rather than
mirrored.

Spawns are named for how you arrived: `start` (in from the previous level, by
the south door) and `returned` (back from the next one, by the north door).
Both sit clear of a threshold so arriving never re-triggers the door.

**A door re-arms when the player steps off it**, and the case that needs it is
not the obvious one. `_used` is latched so a nudge back onto a threshold cannot
queue a second travel mid-fade, and physics is frozen on the player for that
whole fade, so nothing legitimately leaves a threshold while the latch matters.
But a level is swapped in while the arriving player still carries the position
they had when the LAST door fired - and since every level puts its doors in the
same place, that position is right on top of the new room's matching door. It
fires during the transition, where game.gd is still `_travelling` and drops it.
Without re-arming on `body_exited`, the door ahead of you is spent before you
ever walk to it and the chain dead-ends at the second room, which is invisible
in a two-level chain where nobody ever arrives and then walks on.

**A door waits for the party.** It goes only once every STANDING player is in
its threshold, and until then puts the count over it ("1/2", `door_count.gd`,
in the damage numbers' 3x5 digits and `top_level` so the south door's half
turn does not stand it on its head). Standing is the `player` group, which a
body that is down has left, so the door neither waits for one nor counts one -
game.gd carries everybody through, and whoever was waiting to get up gets up on
the far side. It asks every frame somebody is in it rather than only when
somebody arrives, because the party can become complete without anybody
moving: the one still out in the room goes down. Solo, one player is the whole
party and the door goes the moment they step in, as it always did. The one
thing the polling changes is a LOCKED door (`boss_door.gd` with `LOCKED` on): it
now opens on a player already standing in it when the boss concedes, rather
than waiting for them to step off and on again.

## Dressing

Both of a level's health fixtures are per-biome now, and both default the way
the game wants: a hazard unless the floor says `"hazard": "none"` (the lobby,
Ahmed's office, the gym, the penthouse and the marble hall say it), and NO
heart unless the floor says `"heart": true` - which only the lobby does. Floor
1 is where a player finds out what a heal is; from floor 2 up the supply is
meant to be earned - Ivan carrying one to you, or a cleared room's `reward`
(below) - not a room leaving one lying about from the start. A
declined fixture gets neither the instance nor the scene: the generator
deletes the stale `torch.tscn` or `health_item.tscn` rather than leave a level
folder holding a fixture nothing points at. Their art comes from
build_biomes.gd like everything else: the stand and plinth in the biome's own
ramp, the flame and the heart in fixed colours, because fire and health have
to read the same in every biome.

## The clock - a room that switches on

One floor no longer hurts you at a fixed set of addresses. The content studio
carries a `studio` key, and it buys one node, `Studio`
(`game/levels/studio.gd`), that counts three phases forever:

| phase | studio | what it means |
|-------|--------|---------------|
| REST | 5.0s | nothing in the room is hot |
| CUE | 1.5s | the lead-in. Nothing hurts, and everything about to says so |
| TAKE | 4.5s | rolling: the pools burn and the dolly runs |

**The problem it solves is not damage, it is memory.** Floor 2 teaches routing
and routing is a lesson a player solves exactly once, because every threat in
the room stands where it was placed - the second visit is the first visit walked
from memory. A clock does not add a threat; it adds a REASON TO BE SOMEWHERE AT
A MOMENT, which is the thing a static arrangement cannot have.

Four things about it generalize, and the second is the one to copy:

- **One number, not three timers.** Consumers ask `heat()`: 0 at rest, ramping
  0 to 1 across the cue, 1 for the whole take. A light multiplies its pool's
  alpha by it and the sign its brightness, so the telegraph and the danger are
  the same number seen twice - and a light therefore *cannot* draw a pool it
  does not then burn in. Three timers would have been three things for a player
  to read while two drains tick, which is a room that is merely noisy.
- **CUE is the whole of what makes it fair.** A hazard that switches on hits you
  for standing somewhere that was safe when you decided to stand there; a hazard
  that opens a visible pool for a second and a half first is a hazard you walked
  into. It is the enemies' wind-up applied to the ROOM, read the same way - by
  watching, not by counting. `rolling()` is deliberately false for every frame
  of it.
- **Consumers find it through the `studio` group, and a floor without one has
  nobody to find.** The group is PERSISTENT, written into the scene, so it is
  applied on tree entry and every light, sign and rig finds the clock in its own
  `_ready` without anybody having to be built first. `ring_light` is a catalogue
  prop any floor may stand; only a floor that also runs a clock makes it
  dangerous, with no branch anywhere - the same deal a missing sound gets.
- **Rooms keep no state, and here that is load-bearing.** Levels are
  re-instantiated per entry, so the clock starts at REST on every arrival and
  the player always gets a full rest to read the room. Walking back out and
  in again is therefore not an exploit worth having.

### What reads it

**The five ring lights go hot** (`game/levels/hot_light.gd`), and the point is
that nothing new was drawn. This floor's hazard art is a ring light knocked over
and left at full output, and standing beside it were five identical lights still
upright - the room said "these things burn" five times and meant it once. The
heat is a `Burn` child declared by the prop itself (see tools/CLAUDE.md), and
its pool is measured FROM the collision shape rather than from a constant, so
the footprint drawn and the footprint burned are the same rectangle. It is drawn
as an ellipse half as tall as it is wide, the same squash `rug.gd` puts on
anything lying flat, in scanline `draw_rect`s like every effect the bosses draw.
The pool being drawn OVER a player standing north of the lamp is not tolerated,
it is correct: that is what a lamp at floor level does to somebody in front of
it.

**The dolly runs its rail** (`game/levels/dolly.gd`) - the first thing in this
game that hurts you and MOVES. Everything else the world deals either stands
where it was placed or is a person who came looking for you, and a room whose
threats all have addresses is a room you solve by learning the addresses. Three
rules bind it, and the third is the one to check before authoring a second:

- **A rail is painted under it** (`rail` on the markings shelf), authored to the
  same span in the same biome file. A moving threat has to be legible before it
  arrives; a lane the player can see is a lane they time.
- **It is slower than a walk** - 78 against the player's 90. Being hit has to be
  a consequence of standing still, never of being run down from behind.
- **It stops short of the door lane.** Every floor keeps the walk between its
  doors clear - on this rectangular one, x 246-300 top to bottom - and a rig
  crossing the room would be the first thing ever to
  threaten that lane without being PLACED in it. The studio's runs the WEST HALF
  only, which is both the legal answer and the better one: a dolly belongs in
  front of the thing being filmed, and the set is where the two drain fields
  already overlap. Between takes it returns to its parked end and does NOT hurt,
  which is the floor's one rule seen from the other side - and is also the
  earliest warning the room gives.

**The neon sign says which it is** (`game/levels/on_air.gd`), and it is the only
consumer that hurts nobody. No new art: the tubes drop to a third between takes
and come back over the cue, so the brightest object on a near-black wall changes
value and a player who never consciously reads the sign still learns the room
off it.

`tests/test_studio.gd` owns the rhythm, and it is its own suite for one reason -
checking a rhythm means standing still in a room for eleven seconds, which is
the exact opposite of every other suite here. `tests/test_chain.gd` keeps only
that the dressing still carries the clock, because a biome that lost the key
would leave a room that looks right, passes every other check, and never
switches on.

## The wiring - a room that goes off

The call floor's `surge` key buys four `Surge` nodes
(`game/levels/surge.gd`), one per run of cable trunking. A run lies dull, flares
end to end for half a second, then puts a bright head down its length at
260 px/s and goes dull again - on a 2.4 s cycle, with the four staggered so
something in the room fires roughly every six tenths of a second.

**It is the studio's dolly turned inside out, and the contrast is the design.**
One slow rig crossing a room asks for patience: you watch, you wait, you go.
That is the wrong question on the DENIAL floor, where two slowers exist to take
the player's movement away - a threat you beat by waiting is a threat a slow
makes *easier*. So the call floor got the opposite shape: small, fast, frequent,
and four of them. 78 px/s and one rig is furniture with a schedule; 260 px/s and
four lines is a room you cross between beats.

Four things worth keeping:

- **It draws its own conduit.** The rail under the dolly is a separate painted
  marking authored to match the rig's two ends, with nothing checking the pair
  agrees - survivable for one rig, a liability at four or six. A surge draws the
  trunking AND the spark from the same two points, so the lane the player reads
  and the lane that hurts cannot come apart. It is the only thing in this game
  that hurts you and has **no art file at all**, which is also why it needs no
  scene: build_levels.gd builds the nodes directly.
- **The whole run charges, not one end of it.** A player standing anywhere along
  a line learns that *this* line is the one going off, without having to work
  out which direction it is coming from or how long they have. It is the
  studio's cue phase argued from the other side: there the room warms and the
  danger is a PLACE, here the lane flares and the danger is a MOMENT.
- **One pass is exactly one hit.** The head crosses a standing player in about a
  tenth of a second against a grace window six times that, so a run costs one
  blow however it catches you and can never be a lane you are trapped inside.
  That is the entire argument for having four, and it is why the damage (8) sits
  under the copier's 10 - the copier is one place you chose to stand in, these
  are four lanes you have to cross.
- **The lane rule again, and it now protects the arrival.** No run may reach
  the walk - which on this floor is three legs with two turns in it, not a band
  of x. That is not a compromise but the reason there are four runs instead of
  two: cutting the hall's aisle in half at the walk DOUBLED them. It also means
  a player walking in at (272, 480) cannot be hit while the first line is
  already charging. Two of the four run VERTICALLY up the arm, which is the
  shape answering the hazard - what a player is doing in a corridor is climbing
  rather than crossing, so those two punish drifting off the route instead of
  cutting it.

The conduit takes the room's own metal, handed in by the generator as a colour,
because it is a piece of the building; everything that FIRES is fixed white and
gold, on the rule that already fixes fire, sparks and the heart - a hazard that
took the room's palette would camouflage itself in it, and this one has 0.8 s to
be understood.

`tests/test_surge.gd` owns it, and the two checks that carry weight are the lane
swept across every run, and the drop being exactly the node's own scaled
`damage` rather than merely non-zero.

## The machines - a room that wanders

The hub's `scrubbers` key buys two floor scrubbers
(`game/levels/scrubber.gd`), one per half. Each picks a heading, runs until the
room stops it, stops, swings its scanner to wherever it has decided to go, and
drives off again. **Nothing about where they go is authored.**

That is the point, and it is the third SHAPE rather than a third hazard:

| floor | what is authored | what it asks |
|-------|------------------|--------------|
| F2 dolly | one rail | patience - watch it, wait, go |
| F3 surge | four lines | timing - cross between beats |
| F5 scrubber | **nothing** | awareness - you cannot learn where it is |

Two floors teaching "find out where the danger is, then time it" is one lesson
twice, and a third fixed path would have been it a third time. It is also why
this floor: the machine's route is decided by the FURNITURE, and the hub is the
one room with two completely different interiors - the west machine spends its
life ricocheting down cubicle rows, the east one crosses open carpet and
occasionally finds its way through a 32px office door. Same machine, two
behaviours, neither of them written down.

Five things are load-bearing:

- **It takes your POSITION, not your health.** A low `damage` and a real
  `shove()`, which is the fourth way anything in this game reaches the player
  (game/player/CLAUDE.md). On a floor whose two drain fields sit inside the
  glass offices and whose power strip sits in the middle corridor, being moved a
  tile is worth more than the six points. It is the first hazard in the game
  that is not fire, sparks or heat, and the scanner is COLD for that reason: the
  player gets a rule rather than a list - **warm burns, cold moves you.**
- **It is a solid BODY, not a trigger.** Being in the way is the other half of
  being an obstacle, so it is a `CharacterBody2D` and it can corner you the way
  furniture could if furniture moved. It is the only hazard here that is not an
  `Area2D`.
- **It cannot pin anybody.** The failure mode of a wandering solid is a machine
  that traps you against a wall and grinds. A bump always ends in a turn AWAY
  from whatever was bumped - the new heading is the old one reflected off the
  contact normal, and the player is a contact like any other - so it backs off
  by construction rather than by a rule about players.
- **Random, but PENNED.** `within` is the rectangle it may not leave, and it is
  how a routeless hazard keeps the promise the other two keep by geometry: the
  dolly and the surges are authored to stop short of their floor's walk, and a
  wanderer
  is fenced out of it. It is also what keeps the hub's two halves two halves.
- **The turn is the telegraph.** A bump does not snap the heading round; the
  machine stops, swings its scanner to the new one, and only then goes. You
  cannot be told where a random thing will be in three seconds; you can always
  be told where it is about to go next.

Everything solid stops it, chairs included - a machine routed by the furniture
that could drive through half of it would be a machine in a room that had had
the chairs taken out.

`tests/test_scrubber.gd` owns it, and every check there is a property rather
than a position - see the root CLAUDE.md's note on why the bump is staged.

## Reinforcements - a room's later beats

A floor with `reinforcements` in its biome gets one extra node,
`Reinforcements`, holding the list as an export; a floor without the key gets no
node at all, which today is the lobby alone. **Every other floor has at least
one, and the ordinary floors have two or three**, and the shape of a floor's
beats is the shape of its lesson restated:

| floor | cue | base group | `per_head` | in by |
|-------|-----|------------|-----------|-------|
| F1 lobby | — | *none: see below* | — | — |
| F2 content_studio | 2 kills | 2 `social_media` | +1 `social_media` | south |
| | 5 kills | boy + drain | +1 `social_media` | **north** |
| F3 call_center | 3 kills | 2 `office_boy` | +1 `office_boy` | south |
| | 7 kills | 2 `office_boy` | +1 `office_boy` | **north** |
| F4 ahmed_office | 0.75 / 0.5 / 0.25 of HP | drain+boy / **slow** / 2 drains | +drain / +boy / +drain | south |
| F5 the_hub | 2 kills | 2 `office_boy` | +1 `office_boy` | south |
| | 6 kills | drain + boy | +1 `office_boy` | **north** |
| F6 marble_hall | 3 kills | 2 `office_boy` | +1 `office_boy` | **north** |
| | 6 kills | 2 `office_boy` | +1 `office_boy` | south |
| F7 innovation_lab | 3 kills | one of each | +1 `office_boy` | south |
| | 7 kills | boy + drain | +1 `office_boy` | **north** |
| F8 conflict_resolution | 0.75 / 0.5 / 0.25 of HP | 2 drains / **slow**+drain / 2 drains+**slow** | +drain / +boy / +drain | south |
| F9 asset_recovery | 3 kills | 3 `office_boy` | +2 `office_boy` | south |
| | 8 kills | 2 `office_boy` | +2 `office_boy` | **north** |
| F10 hellfire | 3 kills | 2 `regular` + 1 `wraith` | +1 `regular` | **north** |
| | 7 kills | `regular` + **`warden`** | +1 `regular` | south |
| | 11 kills | `wraith` + `regular` | +1 `regular` | **north** |
| F11 executive_floor | 4 kills | 1 `warden` + 2 `regular` | +1 `regular` | chokepoint |
| | 9 kills | `regular` + drain | +1 `regular` | south |
| | 13 kills | 2 `regular` | +1 `regular` | chokepoint |
| F12 silverman_office | 0.75 / 0.5 / 0.25 of HP | 2 drains / **slow**+boy / 2 drains+boy | +drain / +boy / +drain | south |

Five of those rows carry something worth knowing:

- **F1 has no beat, and could not have one.** The lobby is deliberately the one
  room with nobody in it - the first thing a new player does is walk, and floor
  1 is where they learn that safely - so it has no kills to count and an
  `after_kills` there would never fire. The emptiness and the missing beat are
  one decision, not two.
- **F6 and F10 come in by the NORTH door** - the way out. Half the room is dead,
  the stairs are in sight, and the beat arrives from the direction the player
  has stopped watching. On hellfire it also says what the floor above is.
- **The boss rows are fractions, not health.** A boss's max grows by his
  `health_per_head` for every player beyond the first, so a beat written as
  "at 72" for a solo Ahmed would fire on a party's at the start of the fight.
  `at_boss_fraction` reads his own `max_health` and lands on the same quarter
  at any party size.
- **F9 has the heaviest `per_head` in the game** (+2 rather than +1), because
  the crowd floor is the one whose lesson IS the head count.
- **The ordinary floors carry two beats and the last two carry three, and they
  ALTERNATE DOORS.** One beat per floor meant one surprise per floor: the room
  spiked once and the player walked the rest of it knowing nothing else was
  coming. A second beat cued later, arriving from the door the first did not,
  is what stops a room being finished before it is over - and it costs nothing
  a beat did not already cost, because `waves` was always a list and `from` was
  always per-beat. F10 and F11 get a third because they are the last two
  ordinary rooms in the building and the exam should be the fight that refuses
  to end just before the one that has to. This is still not waves: every group
  is authored, finite, and fires once. What repeats is the CUE, never the room.

## `per_head` - what a crowd brings, and what it never brings

`enemies` is a beat's base group and never scales. `per_head` is added once per
head BEYOND the first, so `bodies = len(enemies) + (heads - 1) * len(per_head)`.

The split is not a convenience. Multiplying one list gave every extra player a
copy of every type in the beat - which on a boss floor means a second
`call_center`, and **two slowers do not stack a slow, they refresh it.** A
permanently slowed player cannot sidestep a telegraph, and being unable to
dodge is the one thing here that reads as unfair rather than hard. So
**`call_center` appears in no floor's `per_head`**, a rule
`tests/test_reinforcements.gd` checks against both boss floors' baked data.

It also makes head count matter MORE: a beat can hand a solo player the
arrangement it was tuned for and still answer a party of four, instead of every
number being a multiple of the solo one.

## Relief - a room's third beat

`game/levels/relief.gd` runs the two beats that are not fights, and this is
the first of them. The second is **Briefing**, below: same script, same cue,
different job - the file has never named Ivan outside its comments, so the
day a second arrival was wanted it cost a biome key and a node name and
nothing else.

A floor with `relief` in its biome gets one more node, `Relief`
(`game/levels/relief.gd`), and it is the only beat that is not a fight: when the
room is finally clear, **Ivan walks in through the door the player came by**,
crosses to an authored spot, and waits there with a heart per head. Six floors
have one:

| floor | he stands at | why that floor |
|-------|--------------|----------------|
| F3 call_center | (208, 400) | first floor where a slow near two guards kills; last before Ahmed |
| F4 ahmed_office | (180, 160) | after Ahmed concedes |
| F8 conflict_resolution | (412, 144) | ringside, after Big Mo |
| F9 asset_recovery | (80, 180) | the heaviest `per_head` in the game deserves the matching heal |
| F11 executive_floor | (324, 196) | the exam floor, last stop before the roof |
| F12 silverman_office | (400, 176) | the finale |

**He is an arrival, not a placement, and that is the whole design.** Standing him
in the room from the first frame would put a solid 64px body inside an
arrangement whose positions were picked against sight radii and clear lanes, and
put a heart on offer while the fight the floor is FOR is still standing. His
healing reads as a lifeline because it arrives after the cost has been paid. So
he has an authored DESTINATION and no authored position, exactly as a
reinforcement has neither - you cannot walk in at a spot. The furniture rule
applies to that destination alone: by the time he reaches it the room is empty,
so all it has to clear is the scenery and the door line.

He lives beside reinforcements.gd rather than inside it because the two ask
opposite questions of the same room - is the fight far enough along, and is it
over - and threading a friendly body through a script that spawns enemies would
cost both of them their one sentence.

"Over" has to mean over on both kinds of floor, and each of these was a way of
getting it wrong:

- **A conceded boss is not a hostile.** `_hostiles()` counts the `enemies` group
  and skips anybody who has given up, which is the one line that lets a boss
  floor reach this cue at all: a boss is in that group and is never freed, so
  counting the group alone can never reach zero on the four floors that have
  one.
- **He waits until he has seen a fight.** A room is clear on its first frame
  too, and an Ivan who walks in before anything has happened is a vending
  machine in a doorway. The cue is a room that has been EMPTIED.
- **He waits for the second beat to be spent.** A floor with reinforcements is
  quiet between the last kill of the opening arrangement and the group it cues,
  and quiet is not clear. He asks the sibling node (`spent()`), the same
  ask-don't-listen shape the boss door and the beats themselves use.

Two more things follow from him arriving late:

- **He does not greet.** `greets` fires on the talk radius being ENTERED, and a
  man walking across a room drags that radius over the player on the way, so a
  greeting would land mid-stride. The deeper reason is the lobby's: a
  conversation that starts itself takes the wheel off a player who has pressed
  nothing, and this one has just finished a fight.
- **game.gd wires NPCs as they arrive, not as a room is built.** Doors can be
  swept once, because a room has all the doors it will ever have; people it does
  not. `_on_node_added` is what keeps a late Ivan's prompt from being a key that
  does nothing - a failure that would be silent on all six floors.

The gift itself is `game/npcs/ivan/ivan.gd`: one heart per head from
`game/heads.gd`, thrown on the falling edge of the conversation, once per visit.
See game/npcs/CLAUDE.md.

## Briefing - a room's fourth beat

A floor with `briefing` in its biome gets a `Briefing` node, the same
`game/levels/relief.gd` on the same cue, and what walks in is **Dominique, down
the NORTH door - the one the player is about to go up** - to say what is waiting
at the top of it. Three floors have one, and they are exactly the three that sit
under a boss:

| floor | he stands at | what is upstairs |
|-------|---------------|------------------|
| F3 call_center | (568, 128) | F4 Ahmed - the axe, the slam, and the fire that answers running |
| F7 innovation_lab | (232, 120) | F8 Big Mo - two fast, one slow, and the fire at half |
| F11 executive_floor | (310, 97) | F12 Silverman - three phases, and no interrupts by the last |

**A briefing is only information while the fight is still ahead**, which is the
whole reason it is a beat on the floor BELOW rather than a line inside the boss
room. It is also why the cue is the room being emptied rather than merely being
quiet: a warning handed to somebody who has not yet fought is a warning about a
floor they have not reached.

**The north door is load-bearing twice.** Two of the three floors also have
Ivan, who arrives on the SAME cue through the south door - and two people
walking in at one threshold is two solid bodies in the same sixteen pixels,
shoving each other out of it. It also says the thing each of them is for
without a line of dialogue: he has come from where the player has been, and
he has come from where the player is going.

His spot obeys the furniture rule on `at` alone, exactly as Ivan's does - off
the walk that floor keeps clear, off the divider xs on the floors that have
them, and
far enough from Ivan's spot that the two are not standing on each other. The
lines live in `game/npcs/dominique/before_<boss>.gd`, one file per floor, and
`conversation` is placement: a floor names the warning it wants.

`tests/test_dominique.gd` checks the beat and then checks the RULE - a briefing
under every boss floor and under no other - by reading the whole chain off disk,
so a fourth boss added later fails there rather than shipping unannounced.

## Reward - a cleared room's hearts

A floor with `"reward": true` in its biome gets a `Reward` node
(`game/levels/reward.gd`), and it is Relief with nobody in it: on the same cue -
somebody was fought, nobody is standing, the second beat is spent - the last
body down leaves **one heart per head** (`game/heads.gd`) where it fell, once
per visit. The innovation lab is the floor that has it.

**The spot is wherever the fight ended, and that is the design.** An authored
spot is a spot the player may never walk back to - on the S, any of three halls
that cannot see each other - while the last kill is the one place certain to be
on screen, next to whoever made it, the moment the room is over. It is also why
the lab got this rather than Ivan: he would walk in at the south door, two halls
behind the fight, and he has no pathfinding to follow the bends. More than one
heart lies in a ring `SCATTER` (7 px) round the spot, small enough that a body
which fell against a wall does not put a heart through it.

The cue is relief.gd's three guards answering the same question, and its header
is where each one is argued. The heart is `game/heart.tscn`, the loose one Ivan
throws - shared, so it sits at game/ - and online it is the host's to drop: a
heart made mid-room reaches a guest on the next snapshot, made from its scene.
`tests/test_reward.gd` owns it.

## The pair that makes a boss fight annoying

Boss floors field `social_media` and `call_center` rather than boys, and the
choice is pointed at the thing a boss fight actually is - reading one telegraph:

- **`social_media` has no wind-up to interrupt.** Its harm is proximity, so it
  cannot be answered with the timing the boss is teaching. It just bleeds you
  while you watch him.
- **`call_center` takes the dodge away.** Ahmed's fire wave is a sidestep and
  nothing else; Big Mo's rush needs you to move. Slowed, neither is dodgeable.

So every boss floor runs drain, then the slow at the halfway point, then drain
again - the slower arriving as one distinct event rather than a state the player
lives in. ONE of him per threshold. Big Mo's final quarter is the single place
in the game where two can be alive at once, as the deliberate peak, and it is
the first thing to check in play: if it reads as a room you cannot move in
rather than a crescendo, that is the beat to thin.

**This is deliberately not waves, and the reason is the whole design.** A room
here is an ARRANGEMENT, not a population - the content studio is three
overlapping drain fields you route around, asset recovery is four boys behind a
colonnade you pull one at a time, the executive floor is one 64px gap you
choose to step through. Every one of those fights is made of WHERE the enemies
are, and a stream of respawns flattens all three into the same fight, because a
room's shape only matters while its enemies are placed. So a beat is finite,
authored and fires once; the room clears and stays clear.

**Every floor having one is not a walking back of that.** What "not waves"
forbids is a floor answering a kill with a respawn forever; what each floor has
is one authored group, of known types, at a known cue, once. The test of a beat
is still whether it restates the floor's own lesson rather than adding bodies to
it - which is why the studio's beat is drains and not boys, why the call floor's
adds no slower to the two already standing there, why the executive floor's
arrives at the chokepoint and nowhere else, and why the lobby has none at all.

Three things follow from that and are worth knowing before touching it:

- **A reinforcement has no position, and that is the point.** Everything in
  `enemies` is an authored `at`, picked against sight radii, the door line and
  the clear lanes - and you cannot multiply a spot. A beat names a spawn marker
  instead (`from`, default `start`) and asks the level for it through
  `has_method`, so the whole list fits on one node. A floor can name markers of
  its own under `spawns`, and the executive floor is why that key exists: its
  chokepoint is ON the door line, where nothing may be *placed*, so a beat is
  the only legal way to put a body at the floor's own idea. That marker sits
  SOUTH of the glass deliberately - enemies slide off what they hit and have no
  pathfinding, so a warden arriving on the far side of the partitioning would
  grind along it instead of coming through the gap. Having no position also
  means having no POST, which `_spawn` says out loud with `unleash()`: a placed
  enemy is held within 2x its sight of its mark and walks back to it
  (game/enemies/CLAUDE.md, The leash), and the only mark an arrival could be
  given is the doorway it came through. It still gives up on a player it has
  lost, unless the room alert has fired - then it keeps coming, because
  giving up would only leave it standing wherever it stopped.
- **Which makes it the one place head count can live.** The count is
  game/heads.gd's - every STANDING member of the party - read as the group sets
  off, and each head past the first adds the beat's `per_head`. It obeys the
  rule `Difficulty` already obeys - scale what the world sends, never what it is
  made of - so more players means more BODIES, never a tougher one, for the same
  reason no difficulty mode touches the 24/17/36 breakpoints.
- **Nothing signals it.** Enemies die by `queue_free()` in enemy_base.gd and
  there is no death signal; the node counts the `enemies` group instead, exactly
  as boss_door.gd asks its boss whether it has conceded. Ask-don't-listen is the
  shape the whole level layer uses, and this is not a workaround for a missing
  signal. The health cue is the same shape one step on - it ASKS `Props/Boss`
  what he has left - which is why it is ten lines in `_due()` rather than a
  summon hook on boss_base.gd: a summon would need its own release interval,
  doorway hold and head count, all of which already live here.

**A boss floor's beat is cued by `at_boss_fraction`, not `after_kills`,** and the
reason is not preference. A boss is in the `enemies` group and is never freed -
he is still standing in the room when you leave - so he inflates the population
by one and never subtracts, and `_killed()` reports only the adds. On a floor
whose whole population is him the only number it can reach is **0**, and a beat
cued at 0 is a placement that walks in through a door.

Which is also why a boss floor's adds belong in its beat rather than its
`enemies` list. An add *placed* in an arena stands in it from the first frame,
which is exactly what "one fight is enough to read at a time" was protecting; an
add arriving at a threshold is a PHASE of the one fight. The concede guard in
`_due()` is load-bearing to that: he concedes AT zero, which satisfies every
threshold at once, so without it the last beat of a fight lands on the frame the
fight ends.

One consequence worth seeing in play before trusting it: all of a boss floor's
add budget sits in its beat, so those floors are the most head-count-scalable in
the game. Two players fighting Ahmed get two boys per threshold; four get four.

Two rules keep an arrival from being unfair, and both are load-bearing.
Arrivals are single file, `RELEASE_INTERVAL` apart, because a doorway is single
file and two bodies in the same 16px of threshold is a stack rather than an
entrance. And an arrival HOLDS while a player is within `SAFE_RADIUS` of the
threshold - dropping an enemy on somebody is the one thing a spawn must never
do, and standing in the doorway is exactly where a player who has just cleared
three quarters of a room tends to be. The hold is indefinite and costs nothing.

The interval spaces arrivals within a beat and must never delay the start of
one: `_cooldown` is zeroed when a beat is queued, or a beat would silently
inherit the previous beat's wait before its own first body.

Still to come, and it is the next thing this wants: a beat has no TELEGRAPH.
The staggered walk-in through a known door carries it for now, and the door
that opens is the honest place to put one.
