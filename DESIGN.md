# THE NEW HIRE — design plan

Source of truth for the company-game content build. Mechanics live in CLAUDE.md;
this file says WHAT to build with them. The shareable pretty version of this
plan is a Claude artifact (ask Mayar for the link); when the two disagree,
this file wins.

Status legend: [ ] not started · [x] done. Update statuses as steps land.

## Premise

First day at the company. Your laptop connects to nothing: the WiFi password
changes weekly and only Silverman (top floor, calendar booked until 2031) knows
it. You climb the building floor by floor. Tone is affectionate workplace
comedy — these are real colleagues; jokes stay warm, never mean.

Story is delivered as one-line quips by Dominique at doors. No cutscenes until
the ending.

## Enemies — three reskins, and one new archetype

The three company teams map 1:1 onto the existing enemy types. Mechanics,
numbers and scripts are UNCHANGED — new sheets, names and telegraph flavor
only. Each gets its own folder + sheet seeded from the frozen body via
`game/enemies/roster.gd`, per the existing rule.

| id            | built on         | HP | flavor |
|---------------|------------------|----|--------|
| `office_boy`  | regular (guard)  | 24 | the people who FIX things here: company-teal polo under a dark apron, dark work trousers; wind-up = a wrench thrust along the facing, carried in hand while idle and walking |
| `social_media`| wraith           | 17 | phone glow, ring-light white while draining; faint floating "+1" tick |
| `call_center` | warden           | 36 | headset; charge ring reads as a spreading "on hold" circle |

HP stays on combo breakpoints (3 / 3 / 5 hits on the 5 + 7 + 12 cycle) — difficulty never scales HP.

### The fourth archetype — `security`

The one enemy in the bestiary that is NOT a reskin of something, and the
exception is earned rather than allowed: three archetypes threaten with damage,
drain and denial, and a floor is built by mixing kinds of threat. Adding more of
any of those three makes rooms longer, not different.

| id         | built on           | HP | flavor |
|------------|--------------------|----|--------|
| `security` | *new* — the brute  | 48 | the building's night shift: the company uniform gone dark, charcoal over black, twice everyone else's height. Winds up for the better part of a second and slams the floor — a ring around his own feet that costs 20 and THROWS you out of it |

**He takes your POSITION**, which no enemy did before: the push is `shove()`, the
fourth way the world reaches the player, built for the hub's floor scrubbers and
until now used by nothing that fights back. The two now bracket the same
mechanic from either end — a scrubber is 6 damage and all push with no
telegraph, and this is a full blow, the same push, and nearly a second of
warning.

Two numbers carry the design and neither is round:

- **48 HP** is the sixth rung of the combo (two full cycles) and *exactly two heavies*. He is the
  one body in the game the charged spin was built for and still cannot one-shot,
  which is what makes the heavy the right answer to him rather than the only
  one. `tests/test_slam.gd` reads both off `player.gd` so retuning either side
  fails there.
- **90 px sight**, which buys him his own placement band around the door lane
  (x ≤ 156 or x ≥ 390) and, more to the point, keeps him slow AND short-sighted.
  At speed 35 against the player's 90 he is always outrunnable: the threat is
  that he is standing in the way, not that he catches you.

He is the first enemy drawn at **64px**, the cell the bosses and the NPCs
already use. That cost one `frame` key in the roster and one seeder
(`tools/enemy_art.gd`); 1.5× was considered and dropped, because
nearest-neighbour 1.5 wrecks the 1px outline that is the whole silhouette.

Still to build: his own sheet drawn past the seed (the slam wants an overhead
raise, not the seed's sword swing), his sounds, and the ORIGINAL he is a reskin
of — `bailiff`, for hellfire and up, by the rule below.

### Who stands on which floor

Two rules decide it, and together they tell the building's story: **the reskins
are the company's staff and hold floors 2–9; the originals appear only from
hellfire up**, where the building stops pretending to be an office and the
people in it stop looking like colleagues. A floor's `enemies` list is its
opening ARRANGEMENT, in chain order (`CHAIN` positions, so the two demo biomes
are counted in):

| # | level | count | composition |
|---|-------|-------|-------------|
| 1 | lobby | 0 | the tutorial, and it stays empty |
| 2 | content_studio | 7 | 4 `social_media` + 3 `office_boy` |
| 3 | call_center | 9 | 2 `call_center` + 7 `office_boy` |
| 4 | ahmed_office | 0 | boss arena - his adds are a beat, see below |
| 5 | the_hub | 8 | 1 `call_center` + 4 `office_boy` + 3 `social_media` |
| 6 | marble_hall | 9 | 8 `office_boy`, two gangs of four + 1 `security` at the heart of the east gang |
| 7 | innovation_lab | 9 | 5 `office_boy` + 3 `social_media` + 1 `call_center` |
| 8 | conflict_resolution | 0 | boss arena - his adds are a beat, see below |
| 9 | asset_recovery | 10 | 10 `office_boy`, four knots |
| 10 | hellfire | 10 | 6 `regular` + 3 `wraith` + 1 `warden` (placed) |
| 11 | executive_floor | 11 | 7 `regular` + 2 `wraith` + 2 `warden` (placed) |
| 12 | silverman_office | 0 | final boss arena - SILVERMAN placed, beat live |

Three of those are decisions rather than transcriptions of the floor list above.
**The innovation lab, which had no mechanic assigned, becomes the first
one-of-each mix** — which earns the executive floor for free: the exam is the
same fight one rank bigger with the masks off. And **the executive floor's
eleven are the originals**, not the reskins its entry names, by the rule above.

The third is the SHAPE of every row, and it is worth more than any count here.
These bodies stand in overlapping GROUPS, not spread across a floor: every
ordinary room now has a spot where four or five of them can see the player at
once, where the old arrangements topped out at one or two. Four enemies one to
a corner is not a crowd, it is four duels with a walk between them - and a room
of duels has no use for the heavy, no use for positioning, and no reason for a
player to ever retreat. The count going up is what makes a floor last; the
grouping is what makes it a fight.

One known wrinkle, ordering rather than composition: floor 3 still out-weighs
the floors just above it (trim one office boy if it bites, never a
`call_center` — the pair IS the lesson). Hellfire no longer out-weighs the exam
it precedes: the executive floor is now the heaviest room in the building,
which is what an exam should be.

**Floor 1 stays crossable without a fight.** Two office boys and a beat were
tried here and reverted: the lobby is where a new player finds out what walking
and healing are, and a tutorial that has to be fought through is not one. It is
the only floor with no `reinforcements` key either, and that follows rather than
being a second choice — a beat is cued by kills, so a room with nobody in it can
never reach one.

### Reinforcements — the second beat

Not waves. A room here is an ARRANGEMENT, not a population: the studio is three
overlapping drain fields, asset recovery is four boys behind a colonnade, the
executive floor is one 64px gap — fights made of WHERE the enemies are, and a
stream of respawns flattens all three into the same fight. So a floor may have
one finite authored beat: a named group walking in through a named door at a
known cue — kills, or a boss's remaining health — once, after which the room
clears and stays clear.

- [x] **F8 asset recovery** — 2 `office_boy` at 3 kills, in by the south door.
      Built: `reinforcements` in the biome, `game/levels/reinforcements.gd`,
      `tests/test_reinforcements.gd`. This floor first because it is the crowd
      floor and the one that teaches the heavy: a floor whose whole job is to
      say "two of them are following you and the sword is the wrong answer" can
      afford to say it twice.
- [x] **F11 executive floor** — 1 `warden` at 4 kills, through the glass gap.
      Built: a `spawns` key in biome data and a `chokepoint` marker south of
      the glass, because an arrival on the far side of the partitioning would
      grind along it rather than come through the gap. This is the beat that
      shows why the mechanism earns its keep — **the gap is on the door line,
      where nothing may be placed, so a beat is the only legal way to put a
      body at the floor's own idea at all.**
- [x] **Boss floors get adds, and they get them as beats.** Reversed from "never
      on a boss floor": the arena rule that mattered was *one fight is enough to
      read at a time*, and a body arriving at a health threshold is a PHASE of
      the one fight, where the same body placed in the arena is furniture
      standing in it from the first frame. So a boss floor's `enemies` list
      stays empty and its adds are cued by `at_boss_fraction` — which needed a
      second cue in `reinforcements.gd`, because `after_kills` cannot reach any
      number but zero on a floor whose whole population is a boss who never
      dies.
      - **F4 Ahmed** — 1 `office_boy` at 64 HP and again at 32, in by the south
        door. This is DESIGN.md's own "SECURITY!" summon, arrived at without a
        summon hook.
      - **F8 Big Mo** — 1 `office_boy` at 96 HP and again at 48. It lands on
        the floor's own idea: the corner rush already makes the edges dangerous,
        and a body arriving mid-rhythm is a body you have to fit into a rhythm.
      - **F12 Silverman** — held until he exists. His three phases already fold in
        a `call_center` slow pulse and `social_media` drain, so whether real
        bodies would say the same thing twice is a question for the built fight.
- [x] **Every floor but the lobby has a beat.** Reversed from "nowhere else
      without a reason", and the reason it is not a walking back of "not
      waves": what
      that forbids is a floor answering a kill with a respawn forever, and what
      each floor has is one authored group, of known types, at a known cue,
      once. The test is unchanged — a beat must restate the floor's own lesson
      rather than add bodies to it — which is why the studio's is drains and
      not boys, why the call floor's adds no slower to the two already there,
      and why F6 and F10 come in by the NORTH door, from the direction the
      player has stopped watching. The full grid is in
      `game/levels/CLAUDE.md`.
- [x] **`per_head`: what a crowd brings, and what it never brings.** A beat's
      `enemies` is a base group that never scales and `per_head` is added once
      per head beyond the first, so `bodies = len(enemies) + (heads-1) *
      len(per_head)`. The split exists because multiplying one list gave every
      extra player a second `call_center`, and two slowers do not stack a slow,
      they REFRESH it — a permanently slowed player cannot sidestep a telegraph,
      which is the one thing here that reads unfair rather than hard. So
      `call_center` is in no floor's `per_head`, and head count now matters
      MORE, not less: a beat can hand a solo player the arrangement it was
      tuned for and still answer a party of four.
- [x] **The boss pair is `social_media` + `call_center`, and the annoyance is
      the point.** What makes a boss fight hard is reading one telegraph, and
      these two attack the reading rather than the health bar: the drain has NO
      wind-up to interrupt, so it cannot be answered with the timing the boss
      is teaching, and the slow takes the dodge away — Ahmed's fire wave is a
      sidestep and nothing else. Every boss floor runs drain, then the slow at
      the halfway point, then drain again, one slower per threshold. Big Mo's
      final quarter is the one place two can be alive at once, the deliberate
      peak, and the first thing to check in play.
- [x] **A boss's health scales with head count — by ADDING, never
      multiplying.** This reverses the first version of this item, which held
      that adds alone were the honest dial: two players are two sets of swings
      on one body, so a fight tuned for one ended in half the wall-clock
      whatever walked in meanwhile. Each head beyond the first adds the boss's
      `health_per_head` — a third of him, in whole combos: Ahmed 144 + 48,
      Big Mo 216 + 72, Silverman 288 + 96 — so he still dies on a whole
      combo, which is the only thing the fractional-multiplier objection was
      protecting. Difficulty still never touches it. The beats moved from
      `at_boss_health` to `at_boss_fraction` in the same change, because an
      absolute threshold would fire on a party's boss at the opening bell.
      The solo numbers went up at the same time (from 96 / 144 / 192): every
      boss floor held less HP than the ordinary floor below it.

**Still missing, and it is the next thing this wants: a beat has no telegraph.**
The staggered single-file walk-in through a known door carries it for now.

## NPCs — two new small systems

- **Dominique** (guide, front desk): a talking signpost. New `npc_base.gd` +
  one-line dialogue box (`ui/dialogue/`): proximity trigger, one line per
  visit, advance with the attack key. No branching, no quest log. Placed on
  floors 1, 4, 7, 10 - the tutorial, and then one before each boss.
  **The box was built with branching after all**, because HR's induction needed
  it and a box that can ask a question can also just not ask one. Dominique's
  signpost lines cost a data file and nothing else now.
- **Ivan** (healer, cafeteria): **built, and the cooldown became a cue.** The
  plan was a heart lobbed every ~10s from a safe corner; what shipped is a heart
  per HEAD thrown once, when the room is clear, by a man who walks in to do it.
  A timer would have had him standing in the fight with healing on offer, which
  is the one thing that stops a heal reading as relief - so he is a beat
  (`relief` in biome data, `game/levels/relief.gd`) rather than furniture, and
  the "max one on the floor" rule became "once per visit". The arc, the
  `pickup_base.gd` heart and "Eat." as his last word all survived intact.
  Present on floors 3, 4, 7, 8, 9, 10. From floor 2 up he is the ONLY healing in
  the game but one: the floors themselves carry no heart, so the lobby's is the
  last one handed out for free. The one is the innovation lab, where the last
  body down drops a heart per head once the room is clear (`reward`,
  game/levels/reward.gd) - the hub and the marble hall feed nobody, and the S
  would put him two halls from the fight.
  **And he says a different thing on every one of them.** He shipped with one
  set of three lines for all six floors, which was wrong the moment anybody
  played more than one of them: the whole point of a man who walks in after a
  fight is that he saw THAT fight, and a line that fits none of them in
  particular reads as a vending machine with a voice. Six conversations now
  (`game/npcs/ivan/after_<floor>.gd`), one per floor, and it cost no code -
  `conversation` was always placement. He introduces himself on the call floor,
  complains that Ahmed says the soup needs salt, knows that Big Mo eats two
  plates standing up, tells you the office boys fix his ovens and that somebody
  upstairs pointed them at you, notices on the executive floor that those ones
  have never stood in his lunch queue, and on the top floor says there is
  nothing above you now. Every one of them still ends on "Eat." - the refrain
  the hearts land on. Voiced, eighteen clips, same pipeline.

Both are friendly: no `player`-group targeting of them, enemies ignore them.
They are in the `npcs` group and in neither `player` nor `enemies`, which is
all it takes — nothing in this game reaches anything by type.

**Both are twice the player's height, in a robe no wider than the player.**
Settled after a preview round; the picks were Dominique's long blonde hair over
a teal robe and Ivan's cropped black curls over a red one, both with a hemp
waist cord and a floor-length hem. It is the one deliberately uncanny thing
about the only two people in the building who are kind to you: a colleague you
have to look up at. It also does a job the writing cannot — from floor 2 up
Ivan is nearly all the healing in the game, and at double height he is the tallest
thing in any room he is in, which finds him in a crowd without a marker.

Mechanically it costs a 64 px cell (the bosses' size, already supported) and
buys nothing else: same ground line, same collision footprint, same everything.
They walk at **45**, half the player's 90 — though both stand still, so that
number only matters the day one of them is asked to go somewhere.

**Built so far**: `game/npcs/` with all three NPCs' art, scenes, roster and
`npc_base.gd`, plus the whole dialogue system (`game/dialogue/`,
`ui/dialogue/`), HR standing in the lobby with an induction to deliver, and Ivan
arriving on six floors with a heart per head.

**Built since: Dominique, and the signpost became a BEAT.** The plan was one
line per visit on floors 1/4/7/10; what shipped is four beats on each of the
three floors that sit under a boss, arriving the way Ivan does once the room is
clear - because a warning is only information while the fight is still ahead,
and a signpost standing in the room during the fight is furniture. Each briefing
names the boss and ends on that fight's actual tell: sidestep Ahmed's wave,
break Big Mo's third punch, spend everything before Silverman's last phase.
He comes down the north door while Ivan comes up the south one. Voiced, twelve
clips, in the same pipeline as the other three mouths. `tests/test_dominique.gd`
holds the rule that put him on exactly those three floors.

## HR's induction — the first conversation in the game

She is in the lobby, off the door line and out of the fight lanes, with a
prompt over her head rather than a cutscene that starts itself. Press E and she
welcomes you, then walks the room — sign-in, the front desk, the water cooler —
towing you along behind her, one stop per thing she has an opinion about, and
returns to her post.

Then the contract. **It cannot be refused**, and that is the joke rather than a
limitation: REFUSE does not end the conversation, it gets "Oh, it's so simple.
Just sign it." and a fresh offer, and the third offer loops to itself forever.
Asking to READ it raises the agreement — an English header, an English
signature line, and five clauses of randomly generated consonants. She is not
hiding the terms. There are no terms. Signing is the only way out of the room,
which is the first thing the building teaches you about itself.

## Floors — 10 levels

Elevator is out of order. South door = down, north door = up. Every room is
sealed until it is beaten - both doors, until nobody hostile is standing and no
beat is still to come (game/levels/room_clear.gd) - so a boss floor is a gate
until the boss falls, and the lobby, with nobody in it, is open. Existing
placement rules apply everywhere: no enemy's sight reaches the door line, the
spawns, or whichever of the hazard and heart stands that floor has; the
straight door-to-door walk stays safe.

**This list is in chain order.** `tools/biomes.gd`'s `CHAIN` is the floor plan
the game actually walks, and the numbers below match it: lobby ->
content_studio -> call_center -> ahmed_office -> the_hub -> innovation_lab ->
conflict_resolution -> asset_recovery -> executive_floor -> silverman_office.
The two demo biomes are dealt into that order rather than parked on the end
of it - `marble_hall` sits between F5 and F6, `hellfire` between F8 and F9 -
and they are deliberately not in this list, because they are placeholders
rather than floors of the building. Reordering is one edit to `CHAIN` plus a
build_levels.gd run naming every level whose neighbours moved, since each
door target is baked into a level scene.

One consequence of this order worth knowing, because it is a choice rather
than an accident: Ahmed, the teaching boss, arrives fourth, and the
four-on-one on asset recovery - which is where the heavy attack is taught -
lands seventh, after both bosses. If that reads wrong in play, the fix is
the CHAIN edit above, not a rewrite of any room.

Each floor announces itself by name for three seconds on arrival, so every
biome entry needs a `title` - the floor name in caps, as listed below (e.g.
"ASSET RECOVERY"). Floor numbers are deliberately not in the card: the card
names the room, and the fiction carries which floor it is.

- [x] **F1 The Lobby** (tutorial): glass-and-steel reception, cool blue-grey
  marble, over-lit. Now `CHAIN[0]` and `game.gd`'s `START_LEVEL`: a run begins
  here. Built: biome palette, tileset, north door to the content studio, the
  heart, and
  the room deliberately empty of enemies - floor 1 is where a new player learns
  to walk, safely, and test_flow asserts it stays empty. **Dressed**: reception
  counter (Dominique's spot, and Y-sorting already puts them behind it), the dead
  plant at the end of it, water cooler and a living plant on the far wall, a
  waiting area of sofa and coffee table, two sign-in workstations with chairs,
  the "WELCOME NEW HIRES" banner hanging crooked off one corner, a carpet
  runner down the middle, and the classical colonnade replaced by four glazed
  steel pillars. Floor 1 has no hazard at all - the sparking floor polisher was
  cut, because the one thing a room where a new player learns to walk must not
  have is a way to lose health by walking into the scenery. All of it is
  per-biome data in `tools/biomes.gd` drawn by `tools/props.gd`, so it survives
  a regeneration and floors 2-9 can reuse the catalogue. Dominique + the 2 office
  boys land with steps 2-3.
  Two lanes are kept deliberately clear of furniture and must stay that way:
  the door line (x 246-300) and the central band (y 122-200, x 86-352).
  tests/test_combat.gd fights in this room, because floor 1 is the empty one.
- [x] **F2 The Content Studio** (drain): dark room + neon, ring lights,
  "LIVE LAUGH ENGAGE" wall. 3 social_media with overlapping sight radii
  (routing level — standing central costs 6-9 HP/s), 1 office boy by the exit
  forcing one fight inside the field. Hazard: scalding ring light on a fallen
  tripod.
  **Built**: the room, and it is the first genuinely DARK floor in the game -
  the ramp never reaches white, so the brightest things in it are the lights
  standing on the floor and the sign on the wall. Neon violet accent: the media
  team's magenta pushed to the end of the tube, and the first floor to carry
  it - the hub further up says the same colour more quietly. Dressed
  as a working studio: a paper sweep with the interview couch and the plant
  that is in every shot in front of it, a light either side, a camera looking
  at the lot of it, the stream station in the far corner, a green room of couch
  and table in the dark one, and cable and litter everywhere. The wall sign is
  real neon - tubing and bloom, no board - reading LIVE / LAUGH / ENGAGE. Four
  glazed pillars rather than a colonnade, for the reason below. Three new props
  (`ring_light`, `backdrop`, `neon`) and a fourth hazard style, `fallen_light`:
  DESIGN's ring light knocked over and still at full output, which is the same
  object as the `ring_light` standing next to it - once as the furniture that
  makes this a studio and once as the thing on the floor that hurts.
  The middle of this room is the emptiest floor in the game, and deliberately:
  three drain fields that OVERLAP need floor to overlap on, and a column is a
  sight-line breaker, which is the one thing that would undo the lesson. All the
  kit is in the four quadrants and against the walls.
  The floor band starts high on a low ramp (0.32-0.68) rather than going as dark
  as the room wants - checked with three of the cast standing on it, because a
  dark-haired cast on a near-black floor is a floor you cannot see anybody on.
  The room reads dark because the WALLS are near-black, not the floor.
  **Still to add**: its people, being placed by hand - 3 social_media across the
  middle plus 1 office boy by the north door.
  **And it now runs on a CLOCK**, which is the first room in the game that is
  not the same room on every frame. A take rolls for 4.5s, the room rests for
  5, and a 1.5s cue sits between them; three things read it and nothing else in
  the building does yet. The reason was not that the floor was too easy - it was
  that every threat on it stood where it was placed, so a routing floor is a
  puzzle solved exactly once and walked from memory afterwards. A clock adds a
  reason to be somewhere at a MOMENT, which a fixed arrangement cannot have.
  - The five standing ring lights **go hot** during a take, opening a visible
    pool of light at each foot through the cue and burning in exactly that
    footprint once it rolls. Nothing new was drawn: this floor's hazard was
    already a ring light knocked over at full output, and the room said "these
    things burn" five times while meaning it once.
  - A **camera dolly** runs a painted rail across the set - the first thing in
    the game that hurts you and moves. It tracks the WEST HALF only, which
    keeps the door lane (x 246-300) walkable the way every floor keeps it, and
    charges exactly the ground the floor already makes expensive: the two
    overlapping drain fields with the fallen light between them. It is slower
    than a walk on purpose, so being hit is always a consequence of standing
    still. Between takes it slides back to its mark, harmlessly, which is the
    earliest warning the room gives.
  - The LIVE / LAUGH / ENGAGE neon is the **tally light**: the tubes drop to a
    third between takes and come back over the cue, so the brightest object on
    a near-black wall says what the floor is about to do.
  Two new props (`rail` on the markings shelf, `dolly` on fixtures) and a small
  extension to the prop catalogue - a painter can now declare a `SCRIPT` and a
  `BURNS` box, which is how furniture grows behaviour without every other floor
  learning about it. `tests/test_studio.gd` owns the rhythm.
- [x] **F3 The Call Center** (denial): cubicle maze, densest columns.
  2 call_center planted at chokepoints, 3 office boys between them. The
  lesson: a slow near guards is lethal. Ivan. Hazard: jammed photocopier.
  **Built**: the room, and it is the densest one in the game - eighteen
  dividers in three rows, half again asset recovery's full colonnade, which is
  what makes it a maze rather than an open plan. Ten identical stations in the
  pockets the dividers leave, in three ranks, with the middle rank thinned to
  two against the side walls: this floor's lesson only lands in a room you were
  trying to cross, so the band at y 128-176 keeps the floor a routing fight
  needs. Fluorescent green-grey - the only green floor in the game, landing
  between the studio's near-black and Ahmed's dark marble, so walking in here
  is walking into the lights being ON - with a cold cyan accent, the colour of
  being asked to hold. The wallboard on the north wall reads CALLS / WAITING /
  142 with the number in red, and it is the prop that made the 5x5 pixel font
  learn digits. An OUT OF ORDER notice next to it, and both a `printer` (a
  machine nobody can use) and the new `copier` hazard (a machine nobody should
  touch), which is DESIGN's jammed photocopier: lid up, paper crumpled out of
  the slot, fuser still going.
  The divider xs are 72 / 152 / 232 / 312 / 392 / 472 and every enemy must stay
  off them - an enemy on a divider's x and above its foot is invisible, and
  this floor has eighteen chances to make that mistake instead of six.
  **Still to add**: its people, being placed by hand - 2 call_center at the
  chokepoints, 3 office boys between them.
  **And the floor is now WIRED.** Four runs of cable trunking down the aisles at
  y 128 and y 224, each one dull until it flares end to end for half a second
  and then puts something very fast and very bright down its length. On a 2.4s
  cycle with the four staggered, so a spark goes off roughly every six tenths of
  a second and two are usually in flight at once - the room never stops moving.
  It is deliberately the opposite of the studio's dolly one floor down. That rig
  is slow and heavy and what it asks for is patience, which is exactly the wrong
  question on the floor whose whole lesson is that your movement gets taken
  away: a threat you beat by standing still is a threat a slow makes easier. So
  this one is small, fast, and comes in fours.
  - It **draws its own conduit** - the trunking and the spark come off the same
    two authored points, so the lane the player reads and the lane that hurts
    cannot come apart. It is the only thing in the game that hurts you and has
    no art file at all.
  - The **whole run charges**, not one end of it, so the warning does not also
    have to teach a direction.
  - **One pass is one hit**: the head crosses a standing player in about a tenth
    of a second against a grace window six times that, so a surge is a tax on
    crossing at the wrong moment and never a lane you are trapped inside. That
    is the whole argument for four of them, and why the damage (8) sits under
    the copier's 10 - the copier is a place you chose to stand in.
  - Every run stops clear of the door lane (x 246-300), which is not a
    compromise: cutting each aisle in two at the lane is what made four runs out
    of two, and it is also what keeps the arrival at (272, 240) safe while the
    first line is already charging.
  `tests/test_surge.gd` owns it.
- [ ] **F4 Ahmed's Corner Office** (BOSS): oversized office, golf putter,
  framed family photo. Small arena, no adds at rest. Ivan + Dominique.
  **Built**: the room, and it is the marble hall's room - the same stone and
  the same classical colonnade, because this is the floor where the building
  stops pretending to be an office - taken down out of the white. Every stop
  on the ramp is pulled darker, the hall's gold is brassier, gamma goes above
  1.0 so mid-tones sit down instead of lifting, and the floor band stops at
  0.70 rather than the hall's 1.00, which is the number that actually makes a
  room darker. Two things it deliberately has NOT got: a hazard
  (`"hazard": "none"` - the only thing in here meant to hurt is Ahmed, and one
  fight is enough to read at a time) and any enemies, since Ahmed is step 6
  and the design gives this floor no adds at rest.
  **Built since**: Ahmed, standing north of centre with the north door shut
  behind him until he concedes (see Bosses).
  **Still to add**: the dressing named above - the oversized desk,
  the putter and the framed photo are props nobody has drawn yet.
- [x] **F5 The Hub** (breather): one room, two teams, neither of whom
  asked to share it - and the floor where the two teams whose own floors you
  have just walked through are crammed into one room. The WEST half is the call
  floor: two
  rows of identical stations, cubicle dividers between them, a desk phone and
  a queue of calls on every screen, a printer, a cooler and a break corner
  nobody sits in, under a wallboard reading SMILE / THEY CAN / HEAR IT. The
  EAST half is the media team's, walled into two glass-fronted offices you
  walk into through a gap in the glass, each with a lit edit bay in it - a
  timeline on one screen and the shot on the other - plus cable, a render
  tower, a camera still up on its tripod, and a poster reading FIX IT /
  IN POST. Grey-violet against the brown of asset recovery, magenta accent:
  the media team's colour, which the call floor inherited when the two were
  moved in together. Built: biome, six new props (`call_desk`, `edit_desk`,
  `partition`, `whiteboard`, `poster`, `camera_rig`) and the room.
  The generator's two clear lanes ARE the floor plan here: the door line
  (x 246-300) runs down between the two halves and the runner band
  (y 128-176) crosses it, so the dressing goes in the four quadrants and the
  cross is a pair of office corridors for free. Both stay clear - the power
  strip stands at (120, 152) on the call side and the heart at (424, 152) on
  the media side, and that band is the lane a fight will use.
  The glass is a PROP, not a column style, and that is the one decision to
  know here: a run of `partition` segments 32 px apart with one left out of
  the list is a wall with a door in it, which the colonnade's rows-by-columns
  layout cannot describe. Its glazing is translucent so that an office is
  somewhere you can be SEEN standing - the same lesson the dividers on asset
  recovery taught the hard way.
  **Still to add**: its people. `call_center` and `social_media` are both
  build step 2, so the room is deliberately empty of enemies and test_chain
  asserts that it stays that way until they exist. When they land they should
  stay light: this floor lands just past Ahmed and before the innovation
  lab, and its job is to be a breather rather than a test of anything.
  **And it WANDERS.** Two floor scrubbers left running, one penned into each
  half, trundling about at 60 px/s and turning whenever they hit something.
  It is the third moving hazard in the building and deliberately the third
  SHAPE: the studio's dolly runs a rail and the call floor's surges run four
  fixed lines, so both are learned as geometry - find the danger, then time it -
  and a third fixed path would have been that lesson a third time. **Nothing
  about where these go is authored.** What decides the route is the furniture,
  which is exactly why they belong here and nowhere else: this is the room with
  two completely different interiors, so the west machine ricochets down cubicle
  rows while the east one crosses open carpet and now and then finds a 32 px
  office door. Same machine, two behaviours, neither written down.
  - It takes your **position**, not your health - a low 6 and a real `shove()`,
    which is a fourth way for the world to reach the player and lands on exactly
    the terms game/player/CLAUDE.md had already reserved for one: shaped like a
    status, carried, decaying, refreshing rather than stacking. On a floor whose
    drains sit inside the glass offices, being moved a tile is worth more than
    the six points.
  - It is the first hazard in the game that is **not fire or sparks**, and its
    scanner is cold for that reason. The player gets a rule rather than a list:
    warm burns, cold moves you.
  - It is a solid **body** rather than a trigger, because being in the way is the
    other half of being an obstacle - the only hazard here that is not an Area2D.
  - Random, but **penned**: `within` is what keeps the door lane walkable when a
    hazard has no route to inspect, and what stops the two halves bleeding into
    one.
  `tests/test_scrubber.gd` owns it, and one new fixture painter (`scrubber`).
- [x] **F6 The Innovation Lab** (light relief): where the software gets
  written, and the brightest room in the building after the lobby. Warm
  off-white and pale wood, the floor the company spent the refurbishment
  budget on - the exact opposite of the content studio four floors down, and
  that contrast is doing work rather than just being pretty: nothing else in
  the building is this bright, so the screens on these desks are the DARKEST
  things in the room instead of the lightest, which is how a floor full of
  monitors reads as a floor full of monitors. Editor blue for an accent, the
  one colour no other floor has.
  **Built**: seven workstations - two along the north wall, three across the
  south, one either side of the east - the whiteboard, the build screen, the
  service wall (racks, tower, coffee, water) and a breakout of sofa, table and
  plants. Four new props:
  - `dev_desk`, the fourth desk in the catalogue and the only one with a
    monitor turned on its SIDE. That is the whole silhouette - nobody else in
    the building rotates a screen - and next to it a mechanical keyboard, a
    mug, and a rubber duck to explain the bug to, in fixed yellow for the same
    reason the cooler's water is fixed blue.
  - `diagram`, the whiteboard, whose joke is DRAWN rather than written: four
    boxes, arrows between them, one arrow that goes back where it came from,
    and DO NOT ERASE along the bottom in red pen.
  - `build_board`, the screen telling the whole floor the build is failing,
    with the run history under it - green, green, green, then nine reds nobody
    has fixed.
  - `coffee`, the filter machine, stewed since the morning, and the second
    prop in the catalogue whose colour is not the room's.
  Hazard: the power strip again, and it needs no excuse on this floor - seven
  workstations, each with two monitors and a machine under the desk, all fed
  from whatever was already plugged in.
  One placement note worth keeping: the pillars sit on rows 6 and 12 rather
  than the usual 5 and 13. A pillar's art is 48 px above its foot, so the
  default rows put one across y 48-96, which is exactly where north-wall
  furniture stands; two tiles down, the whole north wall is free for the
  whiteboard and the first pod.
  **Still to add**: its people, and the lesson that comes with them - this
  floor has no mechanic assigned to it yet.
- [x] **F7 Conflict Resolution** (BOSS): company gym, boxing ring painted on
  the floor, poster: "TALK IT OUT" crossed out, "GLOVE IT OUT" under it.
  Tight arena, no columns. Big Mo. Ivan.
  **Built**: the room, and it is the only room in the game with no colour in
  it. Every other floor has a cast - the lobby blue, asset recovery brown, the
  call floor green - and this one is plain concrete and rubber, so the single
  warm thing in it is the paint on the floor: grey room, red ring. The ring
  is DESIGN's, painted rather than built, and it is the first prop in the
  catalogue that is a MARKING rather than a thing - a new `markings/` shelf,
  because paint is neither furniture, hardware nor a sign. It blocks nothing
  (you fight on it) and it pins its top-left corner rather than its foot,
  which is what puts it under everybody standing on it; pinned at its foot it
  would paint over the fighters. A wash of the accent across the inside is
  what makes it read as a surface rather than a rectangle drawn on the ground.
  Also new: `motto`, the poster with the correction on it - the strike-through
  is drawing code, one stroke through the first line of TEXT - plus
  `heavy_bag` and `weight_rack` for the walls.
  This is the first floor with NO colonnade, which the design asks for
  outright, and a biome says so by handing in an empty `columns` layout. It
  gets no column scene in its folder either, the same rule the hazard and the
  heart already follow. Nothing solid stands inside the ring: a rhythm fight
  that steps in and out of range - and the corner rush, which needs corners to
  rush into - has the whole 232x148 of it. The kit is all against the walls.
  No hazard, for the same reason Ahmed's office has none: one fight is enough
  to read at a time, and a boss room that also burns you is a boss room where
  the death was the floor's fault.
  **Still to add**: Big Mo stands in the middle of the ring at
  (272, 138), and his room stays sealed until he concedes, like every room
  until it is beaten. His adds are a beat rather than placements - one
  office boy at 96 HP and again at 48 - which is also what keeps the ring
  clear: an arrival carries no `at`, so it cannot be parked inside it.
- [x] **F8 Asset Recovery** (crowd): the office boys' OWN floor - the back of
  house where the company's broken hardware goes and mostly stays, under a
  sign about recovering value from it. Dim warm brown against every other
  floor in the building, amber accent, dividers as columns (the full
  colonnade of twelve, which is what breaks the sight lines that let four
  boys be pulled one at a time). Built: biome, `office_boy` (step 2's first
  reskin), and the room - a server bank along the top wall with one red light,
  e-waste heaped down both side walls, a photocopier with an OUT OF ORDER
  notice taped up beside it, toolboxes and half-stripped towers on the way in,
  three open-plan desks along the bottom, and loose litter over the middle.
  Hazard: the arcing power strip, as planned.
  10 office boys in four KNOTS - three to each western corner, two to each
  eastern one. Teaches the heavy, and the grouping is HOW: one boy per quadrant
  left no point in the room inside two sight radii, so the sword was always the
  right answer and the heavy never repaid the second it costs.
  The junk is a thick PERIMETER around a clear arena (about x 200-350,
  y 110-200): a four-on-one fight and an AoE both need floor, so the only thing
  that goes in the middle is `debris`, which blocks nothing. Two placement
  rules bite here and are commented in `tools/biomes.gd` - nothing solid on the
  straight line an office boy walks to the middle (they slide off obstacles and
  have no pathfinding), and no enemy parked on a divider's x, or the divider's
  48px art hides it completely.
  Ivan arrives at the west wall (80, 180) once the room is clear - the
  heaviest `per_head` in the game is the one that most deserves the heal to
  scale too.
- [x] **F9 The Executive Floor** (mix/exam): dark wood, glass walls, awards
  cabinet. 3 office boys + 2 social_media + 1 call_center (center chokepoint).
  Every prize requires stepping into a radius on purpose. Ivan.
  **Built**: mahogany walls and a brass accent - the darkest warm room in the
  building, and deliberately the lobby's opposite number: floor 1 is over-lit
  and cheap, floor 9 is under-lit and expensive. It is also the only OFFICE
  floor with the fluted classical colonnade, which is the joke rather than an
  oversight - the columns are what made the lobby read as a temple, and this is
  the one floor entitled to the pretence.
  The chokepoint is DRAWN. A run of fourteen glass bays crosses the whole
  floor with a single 64 px gap on the door line, so the boardroom and the
  trophy wall behind it are reached through one opening in the middle of the
  room - which is what makes "every prize requires stepping into a radius"
  mean anything. North of the glass: the boardroom (the table, six chairs, the
  drinks trolley) west of the gap, four awards cabinets and a bench east of it.
  South of it: the gallery you arrive into, a carpet corridor along the glass
  and a rug under two couches. Five new props:
  - `awards_cabinet`, the tallest piece of furniture in the catalogue, with
    three lit shelves of cups and stars behind a glass door. The trophies are
    a fixed gold for the same reason fire and hearts are fixed - take them off
    the biome's ramp and hellfire hands out iron cups.
  - `boardroom_table`, the widest prop in the catalogue at 96 px: a polished
    top with a brass inlay, six places set with pads nobody has written on,
    and one speakerphone.
  - `bar_cart`, the drinks trolley, whose decanter is the catalogue's fourth
    fixed colour after water, coffee and gold.
  - `portrait`, the founder in oils under a brass FOUNDER plaque - the only
    sign in the game that is a picture with a caption rather than a caption.
    Painted in varnish rather than in skin, which is both what a hundred-year
    -old commissioned portrait looks like and a way of making no claim about
    whose face it is.
  - `rug`, the second thing on the markings shelf after the boxing ring, and
    the same two tricks: it blocks nothing and it pins its top-left corner so
    everybody walks on top of it.
  Hazard: the floor polisher, back from the lobby that dropped it, and this is
  the floor it was always for - the only one in the building whose wood is
  actually polished.
  No debris anywhere on this floor, and the absence is deliberate: every floor
  below it has litter because every floor below it is used.
  **Built since**: its six, and they are the ORIGINALS - two `wraith` behind
  the glass, one per north half, so every awards cabinet sits inside a drain
  field and "every prize requires stepping into a radius" is drawn rather than
  described; a `warden` and three `regular` in the gallery you arrive into.
  Both drains are IN the north half because an enemy on the far side of the
  partitioning grinds along it instead of coming round through the gap. Plus
  the floor's late beat - one more `warden` at 4 kills, arriving at the
  chokepoint, which is the only legal way to put a body there.
  Ivan arrives at (324, 196) once the room is clear.
- [x] **F10 Silverman's Office** (FINAL): penthouse, city window, one desk, one
  face-down sticky note. Wide open arena. South door seals behind you.
  Dominique waits outside ("Whatever happens up there… CC me."). Ivan.
  **Built**: the only ramp in the game with no warmth anywhere in it -
  charcoal and glass up to a blue-white - and a platinum accent, which is not
  a colour so much as the absence of one. That is the gym's argument made the
  other way round: the gym is grey so its red paint is the only warm thing in
  it, and this room is grey so the CITY is. Everything with a colour in here
  is on the far side of the glass.
  The second floor to hand in an empty `columns` layout, after the gym, and
  the third to take no hazard, after Ahmed's office and the gym. Nothing solid
  stands anywhere in the middle: the arena is x 150-400 by y 150-280 and the
  only thing in it is the rug, which blocks nothing. Three new props:
  - `city_window`, which opens a shelf. `openings/` exists because a window is
    none of the other four things a prop can be - not furniture, hardware, a
    sign or paint on the floor, but a hole cut through the building's shell -
    and the boxing ring opened `markings/` on exactly that argument. It runs
    480 px unbroken, wall to wall, and it can only do that because the
    penthouse is the END of the chain: a level with a floor above it has a
    doorway cut through its north wall, and a panoramic window drawn across
    that doorway would glaze the way out. It carried a 96 px hole for exactly
    that reason until Silverman's office became the last room. The sky and the
    city are fixed colours; only the frame and the sill take the room's.
  - `exec_desk`, and the point of it is what is NOT on it: every other desk in
    the building is buried, and this one is a mirror-polished slab with a pen
    laid square to the edge. A man who does no work in the room where the work
    is decided.
  - `sticky_note`, face down, shelved with the signs because it IS one - the
    only one in the game turned over. It is a prop of its own rather than a
    detail painted into the desk because the ending turns it over and needs a
    node to find, and `StickyNote1` is that node. Its canvas is 30 px tall
    with the note in the top ten, which is how anything lying ON a desk is
    placed at all: given a foot two pixels south of the desk's it sorts after
    it, and its art, twenty pixels up, lands on the desktop.
  The rug and the drinks trolley are the executive floor's, one storey down,
  which is the catalogue working as intended - in a room with no hue in it the
  rug comes out platinum on slate.
  Ivan arrives at (400, 176) once the room is clear - though on this floor
  "clear" waits on a boss who does not exist yet.
  **Still to add**: Silverman. The south door sealing behind you needed no
  script of this level's own in the end: every room is sealed until it is
  beaten, so the stair back down is shut while he stands.

## Bosses — overrides on enemy_base.gd's cycle, built in this order

HP values are exact combo breakpoints (the 5 / 7 / 12 cycle) AND multiples of the
heavy's 24. Difficulty scales their damage only, never HP. All three concede
instead of dying (no queue_free): defeat -> concede animation -> north door
unlocks.

- [x] **AHMED — 144 HP solo (+48 a head), F4.** The relative; teaching boss, and the one who
  brought an axe to a performance review. 2.5x the player and thin as a coat
  rack: black curls going grey, black beard, white shirt with the sleeves
  shoved up, black trousers. The axe burns. Five attacks on the guard's cycle,
  chosen by range and by how the player is behaving (game/bosses/ahmed/),
  reworked 2026-10-01 from an animated preview because the first four all
  asked the same question - are you next to him or not:
  CHOP 16 and SWEEP 12 alternate in reach. The chop is a FISSURE - a crack
  runs on ahead and pillars burst out of it, 8 more, so backing straight off
  is wrong; the sweep SHOVES you out of reach and in front of him, into the
  wave. Every third swing - or sooner, if he is hit twice inside 2 s - is the
  SLAM, now a LEAP onto where you stood (a ring marks it), 20 to EVERYONE in
  40 px, office boys included; out of reach it is also how he follows you. A
  player in front of him and out of reach gets the THREE-WAY WAVE, 14 per
  lane, safe between two of them. And three seconds of keeping away brings out
  THE ENORMOUS CHAIR: he spins it up, rolls at you until he hits something
  (18), and sits there dizzy - the punish. Standard interrupt economy; every
  impact has a hit-stop, a shake and a flash. Every attack has fire on it,
  drawn live over a clean sheet. The chair has no sound or voice line yet.
  **Built**: the boss, his fire, the locked north door, tests/test_bosses.gd.
  **Built since**: the "SECURITY!" summon, and it needed no summon hook on him
  at all - it is a `reinforcements` beat cued by `at_boss_fraction`, one office
  boy at 64 and again at 32, in by the south door. One at a time rather than a
  cap of two alive: a duel with a crowd in it is neither, and the slam still
  knows what to do with whoever is standing in the ring.
  **Built since**: his mouth. He shouts through the fight - a hello, a taunt
  when you keep out of his reach ("Get over here!", "Come here, coward!"), a
  line on the wind-up of a swing, one for being hit and a different one for
  being interrupted, and "I'm telling Big Mo." as he kneels. Subtitles AND voice:
  all twenty-three lines are cut with ElevenLabs v3, the read tagged per cue
  rather than tuned on a slider, and the subtitle holds for as long as the
  recording runs. `ahmed/taunts.gd` is the
  whole of what he says; `game/enemies/enemy_lines.gd` decides when, and no
  other boss has lines yet.
  **Built since**: the enormous chair, as his fifth attack (above).
- [x] **BIG MO — 216 HP solo (+72 a head), F7.** Boxing rhythm fight; his attack is the cycle
  run 3x back-to-back:
  - Jab, jab: 0.25s wind-ups, 6 dmg each, commit_fraction ~1.0
    (effectively uninterruptible; they're swings — step out, they whiff).
  - Hook: 0.7s wind-up, 18 dmg, interruptible early. The one read.
  - Corner rush: dash gap-closer if the player kites to the ring edge.
  - Defeated: takes the gloves off, nods once, points at the ceiling.
  **Built**: all of the above except the concede, plus two things that are
  his alone and are documented in game/bosses/big_mo/CLAUDE.md. He is the one boss
  drawn FRONT ON — a boxer squares up to you — which costs nothing against
  boss_base's side-only facing because the figure is symmetric enough that
  `flip_h` is invisible on it. And he is drawn at 2x DENSITY: 70 source rows
  across the same 35 world px Ahmed spends 35 on, cell 128, halved back by
  `scale 0.5` in the scene. The style pass that shaped him needed the range.
  Commit is per attack (`COMMIT` in big_mo.gd), which is what makes the jabs
  uninterruptible and the hook not — the base has one dial, so he sets it as
  each attack begins.
  He also **goes up at 72** — half health, once, and never back down. A 0.95 s
  eruption (two sinks, a blast out of the crouch, a column he stands up
  through) and then he burns for the rest of the fight: skirt, orbiting flame,
  both gloves alight, a rim on his silhouette. Crimson and white, deliberately
  not Ahmed's amber. It lands on the floor's existing `at_boss_fraction: 0.5`
  beat, so the fire and the south door open together. **No number changed** —
  the rage burns without biting; `breath_seconds` is the lever if it should do
  both. `rage.gd` + `bell.gd` over the shared `brush.gd`.
  **Still to add**: the concede. The animation described above was drawn and
  rejected in review, so the row is a single placeholder frame — he stops and
  his hands come down. boss_base plays `concede_side` at zero health and the
  row has to exist; replacing it is adding frames to poses.gd and nothing
  else.
- [ ] **SILVERMAN — 288 HP solo (+96 a head), F10.** Smooth = never hurries; each phase announced by
  adjusting his cuffs:
  - P1 "The Handshake" (192→128): single strikes, 0.8s telegraph, 20 dmg,
    gliding movement. Standard interrupts. The fair phase.
  - P2 "The Meeting" (128→64): adds a call_center slow pulse on a cycle
    ("Sit. Stay a while."). Interrupt cooldown stretches — you get one.
  - P3 "The Performance Review" (64→0): adds social_media drain while near,
    becomes fully uninterruptible. Ivan's hearts + the heavy are the answer.
  - Defeated: never falls. Straightens his cuffs and concedes.
  **Built, on SILVERMAN, and unplaced.** The three phases above are implemented
  verbatim on `game/bosses/silverman/` - 192 HP, a cumulative ladder at 128 and
  64, a slow pulse in phase two and a drain in phase three, uninterruptible in
  phase three - with the mechanics chosen from a preview rather than from this
  list: the glare (the penthouse window turned on you), the split (he divides;
  the copy walks at you), the cold room (proximity drains, outside the grace
  window) and the crossing (his dash, which now passes through you). His
  announcement is not cuffs - he has none - but a rung of his own shine spent on
  the room. `tests/test_silverman.gd` fights him. Two more joined his last phase
  later, each picked off an attack preview: the prism (a white beam swept
  across the room) and the glass ceiling (2026-10-04: panes come down round you
  in a checkerboard, half and then the other half).
  **Placed on F12, the penthouse**, at (272, 140) - centred, because his glare
  and his crossing both run along x and centred is the only spot that gives him
  the room's full width both ways. His floor's beat (144 / 96 / 48) was authored
  against an assumed 192 and is now confirmed against the scene, and those
  thresholds sit off his phase boundaries on purpose so an arrival and a phase
  change never land together. It is the one boss floor with no door to lock: the
  penthouse ends the chain, so there is no north wall to cut and beating him
  opens nothing.
  **Settled: he is Silverman, and it is his office.** There is no boss above
  him and no rename coming. The floor announces itself as SILVERMAN'S OFFICE,
  his bar says SILVERMAN, and the two never meet in code - `title()` reads the
  scene's filename and the floor card reads the biome, so neither had to learn
  about the other. What he is to the other two is never said; it is the rule
  they already follow, that a name passed up the stairs is the whole threat and
  the blood is never spelled out. Big Mo escalates "to Silverman", the player
  walks into SILVERMAN'S OFFICE, and the man waiting there does not introduce
  himself.
  **He talks, and he says everything twice** - Swedish, then the same thing in
  English. Twenty-one lines across ten cues in `silverman/taunts.gd`, voiced by a
  Swedish voice reading both halves in one take. He is the gracious one: he
  compliments you for arriving, thanks you for hitting him, and there is not
  one insult in the file. Two cues are his own, `meeting` and `review`, said as
  he crosses into phases two and three - the phase names above, spoken. His
  concede is "Du har jobbet. Det har du haft hela tiden. / You have the job.
  You always did.", which is the handoff into the ending below: the job was
  never the thing being fought over. See game/bosses/silverman/CLAUDE.md's
  *He says everything twice*.

## Ending — two codes, two jobs

Silverman's concession speech, then:

1. **WiFi password** (closes the story; the sticky note):
   `ZA-C0MPANY-Wi-Fi!2026` — fictional, part of the joke.
2. **Discount code** (the real reward): "The WiFi gets you connected. This —
   this is because you impressed me." A REAL redeemable discount code for the
   company's product, shown only on beating the game. Placeholder
   `SILVERMAN-APPROVED`; keep it as ONE constant in the ending scene so marketing
   can rotate it without touching anything else.

Smash cut: desk, laptop connected, notification "Welcome to the team 🎉 —
Silverman". Dominique: "Password changes Monday. The discount doesn't." Credits.

## Multiplayer — online co-op, one player hosts

Decided 2026-10-02. Online play over the internet, a party of up to
`MAX_PARTY` (4 today, and ONE constant: nothing else in the game may write a
party size down), with the whole run played together.

**What was already safe, by accident of a good rule.** Everything the world does
to the player goes through the `player` group plus `has_method` — `take_damage()`,
`drain()`, `apply_slow()`, `shove()`. None of it knows a type or a singleton, so a
torch, a drain field and a guard's strike already hit two players correctly. And
everything that scales with a crowd already reads one number, `game/heads.gd`:
boss health adds `health_per_head`, a beat adds its `per_head`, Ivan throws a
heart per head. It returns 1 today because game.tscn holds one player, and it
starts telling the truth the day it holds two. **More bodies, never tougher
ones** — 24/17/36/48 are exact combo breakpoints.

### The shape of the network

- **One player HOSTS and plays; the others connect to the host only** (a star,
  not a mesh). The host's machine runs the real world. Its cost is accepted:
  the host leaving ends the session for everybody.
- **Direct first, relay only as the fallback.** WebRTC (the official
  `webrtc-native` GDExtension, since desktop Godot does not ship it) finds a
  direct route on the same network or through the router, and a TURN relay on
  our own server carries the traffic only when no direct route exists.
- **Our server runs two small things and never the game**: a *signaling*
  service (a WebSocket that introduces a guest to a host and hands out join
  codes) and *coturn* (the STUN that finds the direct route, and the TURN that
  relays). TURN credentials are time-limited and issued by the signaling
  service, or the relay is a free open proxy for the whole internet.
- **A relayed connection says so.** Godot's WebRTC API reports neither which
  route ICE picked nor a round-trip time, so the route is found by asking
  twice: connect with STUN only, and if nothing connects inside ~6 s, connect
  again with TURN added. A guest who only got in on the second try is relayed
  — they see "Connected through relay — expect higher ping", the host sees it
  against their name in the lobby, and in the run the scoreboard tags them
  RELAY (M5: no tag on the HUD rows, the owner's call).
- **The game never knows which wire it is on.** Everything above the transport
  talks to Godot's `MultiplayerAPI`; the transport is chosen in ONE place
  (`autoload/net.gd`). The suites run on ENet over localhost, which is the
  same API with none of the internet in it.

### Who decides what

Co-op against the computer: nobody gains from cheating, so every split is the
one that FEELS best rather than the one that is safest.

| Thing | Decided by | Why |
|---|---|---|
| Your own movement, facing, swings and the charge | **your machine** | zero input lag; a 0.04 s hit-stop is shorter than most pings |
| "My swing reached enemy X" | **your machine reports it, the host applies it** | the attacker gets the benefit of the doubt |
| Enemies, bosses, hazards, the studio's clock, the wiring, the scrubbers, every beat, Ivan, Dominique, pickups | **host** | one real room |
| A blow on a player, health, the shared lives, doors, which floor we are on | **host** | everybody has to agree |
| Slow and shove on YOUR body | **host decides, your machine applies** | they move a body, and only its owner moves it |
| Numbers, flashes, sparks, bursts, shake, sound | **every machine, on the host's word** | cosmetic: nothing to keep in step |

### The rules of a party

- **Lives are ONE shared pool of `MAX_LIVES` (3).** A player who dies gets up at
  the room's door after a short wait and spends one. With the pool empty a death
  leaves that player down, watching, and the run ends when nobody is standing.
  Watching is literal: a player who is down has their camera on somebody still
  standing, and the attack button moves it on to the next.
- **Anyone down can be revived.** A teammate stands over them and holds the
  interact key for 4 seconds; they get up where they lie at 50% health. As often
  as it takes, and it never touches the pool - so once the hearts are gone the
  run is only over when nobody is left standing to pick anybody up. Each blow
  on the one reviving costs a second, and letting go runs it back down.
- **A door waits for the party.** It fires only when every STANDING player is
  in the doorway, and says so meanwhile ("1/2"); a downed player is carried
  through. Travel is the host's call, and every machine loads the floor it
  names.
- **An enemy goes for the nearest player, and sticks.** It changes target only
  when another player is clearly closer (by a margin, so two players at the
  same distance do not make it twitch). One function in enemy_base answers
  "who am I after", and every one of the fifteen
  `get_first_node_in_group("player")` lookups in the bosses and enemies goes
  through it.
- **Each machine's camera follows its own player**, at its own zoom. Nothing
  frames two people, so no floor is too big for a party.
- **The room alert is anyone's**: the first player more than `ALERT_RADIUS` from
  where they came in wakes the room for all of them.
- **Nothing pauses online.** The pause menu and the death screen become
  overlays; `get_tree().paused` is a solo-only thing.
- **Join in the lobby, not mid-run** — for now.
- **The list of games** (built 2026-10-03, before M4, from the Open Games
  preview): the main menu's HOST ONLINE and JOIN ONLINE replace ONLINE, and the
  difficulty moves into Settings and onto the host screen. JOIN ONLINE is the
  list and nothing else - every game on your version, public, private, full or
  started, each saying which - and a private game is in it for everybody to
  see, joined only with its code. A host opens PUBLIC by default and can switch
  in the room, and can KICK a guest, who cannot come back to that room. No
  hidden-address option: guests connect straight to the host, the relay only
  when there is no direct route.

### Ping, the Counter-Strike way

- **Hold Tab for the scoreboard**: one row per player — name, character, ping in
  ms, and the route (HOST / DIRECT / RELAY). A new `scoreboard` action, added in
  tools/setup_project.gd like every other key.
- **Your own ping sits in a corner** for the whole online run, green under
  60 ms, amber under 120, red above.
- **Ping is measured by the game, not read off the transport**, since WebRTC
  will not say: the host pings each guest once a second on the unreliable
  channel, keeps a rolling average, and sends the table round. Every number is
  a player's distance to the HOST, exactly as Counter-Strike shows distance to
  the server; the host's row reads HOST.
- The player NAME is asked on the character select, on the way online only,
  saved under Settings section `online` — not on the settings panel, whose
  fourth row went to the difficulty.

### Rules that keep it honest

- **Solo is a party of one and plays exactly as it does today.** Offline is a
  host with no guests. All the suites stay green at every step below, and the
  true hit-stop (`Engine.time_scale`) stays in solo — online it would stall the
  host's whole world for everybody else's hits, so there it holds only the
  sprites and the effects still.
- **Anything that appears mid-room is SPAWNED by the host** (reinforcements,
  Ivan and Dominique walking in, the hearts, Silverman's copy) through a
  `MultiplayerSpawner`. Anything a level places shares its node path on every
  machine already, because every machine loads the same scene.
- **Gameplay dice are rolled on the host only** (the scrubbers, the surge's
  stagger, Silverman's picks, a pickup's choice); cosmetic dice (sparks, bursts)
  stay local.
- **A guest leaving takes their body with them**; the pool is untouched. The
  host leaving puts everyone back on the menu with "the host left". A guest
  whose line goes dead without a word is AWAY a second into the silence - out
  of the fight, costing nothing - and gone once the line is given up on (M6).

### Still to decide, with the default until then

- **Talking**: whoever presses interact is the one talking and the one HR tows;
  everyone else keeps their hands and reads along. **Built that way in M3**,
  and two pressing at once is the host's to settle: whoever reached it first
  (M6).
  Whether HR's induction and the contract are the whole party's, or the first
  player's, is still open: today they are whoever talked to her.
- **Reconnecting** to a run after a drop: not in the first version.

### Build order — each step leaves solo exactly as it was

- [x] M0. **Spike, thrown away afterwards.** `webrtc-native` on 4.7, two
        machines on two networks, through signaling + coturn on our server:
        connects direct, falls back to relay when direct is blocked, and the
        two-stage ask really tells them apart. If the plugin does not hold up,
        the fallback is ENet with punch-through and a relay of our own — the
        layers above do not change. Deliverable: the server stack running.
        **Built and proved on one machine (2026-10-02)**: `server/` (signaling
        + coturn + optional Caddy, in Docker, 12 checks green) and
        `ui/net_spike/` (moved from tools/ to ship in the web build behind
        `#nettest` / `#join=CODE`, so a phone can be the second machine). The
        plugin runs on 4.7.2; two processes meet by
        code and connect DIRECT with a measured ping; a forced relay with no
        TURN running FAILS, as it must. That last check caught the design's
        one mistake: filtering only the guest's candidates is not enough,
        because ICE learns a peer-reflexive address from the first check that
        arrives, so it now filters both ends (rtc_link.gd's header).
        **Signed off 2026-10-02** against the live server
        (za-company.mayar-deeb.dev): all four of server/README.md's checks -
        the same Wi-Fi and two networks with an editor host and a phone
        joining by link, the forced relay, and leaving both ways - plus a
        desktop host on the plugin and a browser guest talking to each other.
        **The plugin holds up, so ENet is not needed.** The spike stays until
        M2 takes its three pieces into the `Net` autoload, then goes.
- [x] M1. **A party on ONE machine, no network.** The player reads an *input
        source* instead of `Input` (yours is the keyboard; later, the wire);
        game.gd spawns one player per member instead of owning `$Player`;
        the sticky nearest target; the shared pool; the waiting door; the room
        alert per player; a HUD for N. `heads.gd` starts counting for real.
        New suite `test_party.gd`, two players driven by synthesized sources.
        **Done 2026-10-02**, with all thirty suites green: game.gd's
        `next_party` (one member when nothing says otherwise, which is solo),
        `game/player/input_source.gd` and `virtual_input.gd`, enemy_base's
        `target()` (nearest, `RETARGET_MARGIN` 24 px) behind all fifteen
        lookups, `lives` on game.gd, `door_count.gd`'s "1/2", the HUD's party
        rows, and `MAX_PARTY` moved into heads.gd as the one constant. Two
        rules came out of building it. **A body that is DOWN leaves the
        `player` group**, which is the whole of how the world stops seeing it:
        enemies, hazards, pickups, doors and the head count all already went
        through that group, so none of them learned what "down" is. And an
        AREA is not a target: Silverman's cold room and crossing and Big Mo's
        heave reach everyone standing in them. Down is dimmed and gets up at
        the door after 3 s; a door that goes while someone waits to get up
        stands them up on the far side. Who TALKS stays this machine's player,
        the default under *Still to decide*.
- [ ] M2. **The `Net` autoload and the lobby.** Host, join by code, leave;
        the party roster (peer, name, character); the ping heartbeat. ONLINE
        on the main menu opens `ui/lobby/`: the host's code, the players and
        their pings, START for the host. New suite `test_net.gd` runs a host
        and a guest in one process, each in its own SubViewport so the two
        copies of a room do not collide with each other, over ENet localhost.
        **First**, give dev its own signaling and its own server deploy
        (docs/environments.md, #1 and #2): M2 changes the protocol, and dev
        cannot test that against production's service.
        **Progress (2026-10-02)**: dev's own signaling is built (v0.1.2
        carried it; `server-dev` in deploy.sh, port 8766, `ok dev` on its
        /healthz, the `dev` feature on dev builds). `autoload/net.gd` is
        built: host, join by code, leave, the roster with names, characters,
        routes and pings, `WIRE` checked in the hello, and START, which is
        signaling protocol 2's `start` shutting the room. `test_net.gd`
        (21 checks) runs it over ENet; the WebRTC road was proved against a
        local signaling service. **Then the lobby**: option A of the lobby
        preview, FOUR SEATS (`ui/lobby/`, picked 2026-10-02), behind ONLINE on
        the main menu and the character select it reuses; `#join=CODE` opens
        it on the web; START turns the roster into the party and loads the
        game, where everybody but this machine's player stands still until
        M3. The spike is deleted. `test_lobby.gd` (41 checks). What is left
        of M2 is playing it: a deploy to dev, then two machines through
        dev's own signaling.
- [x] M3. **The world in step.** Players from their owners; enemies, bosses,
        hazards and beats from the host; the damage flow in the table above;
        spawners for what arrives mid-room; travel, health, lives, the boss bar
        and the floor's music all following the host.
        In five steps, each leaving solo as it was: (1) the party, (2) the
        enemies, (3) the rooms - hazards, pickups, Ivan and Dominique, (4) the
        bosses, (5) talking.
        **Step 1 done (2026-10-02), the party**: `game/sync/` (built by game.gd
        as `Sync` on every machine, inert offline); each body drawn from its
        owner (`remote`, `net_state`); the host deciding health, the pool, down
        and up, the doors and the end, told to the guests through game.gd's
        `net_*`; a ROOM count so nothing from the last floor is drawn on the
        next; `Net.arrived()` so the host speaks to a guest's game only once it
        is up; nothing pausing online; a guest's body leaving with them. One
        rule makes a guest's world harmless however much of it runs:
        player.gd's `_world_reaches()` - on a guest the world hurts, heals,
        slows and shoves nobody, and the host's word arrives instead.
        `tests/test_coop.gd` is two processes (29 checks).
        **Step 2 done (2026-10-02), the enemies**: on a guest an enemy is the
        host's, drawn (`_in_charge()`, `_drawn_step()`), with the phase and
        how far into it carried, so every type's own telegraph - a warden's
        field, a brute's ring, a wraith's aura - fills there as on the host.
        ONE snapshot of the room's `synced` things is the whole truth of what
        exists (`game/sync/world.gd`): an entry the guest lacks was spawned on
        the host and carries its scene, and a thing the snapshot lacks is gone
        - so there is no spawn or despawn message to lose. Compressed, because
        hellfire's room was already one byte past a packet. A guest's swing is
        reported and dealt on the host, and shown at once on the attacker's
        screen. A boss is drawn too, with his bar and his concede; his
        attacks are step 4. `tests/test_coop_world.gd` (17 checks).
        **Step 3 done (2026-10-02), the rooms**: everything a floor does
        besides its enemies rides the same snapshot, split by whether a guest
        can work it out: a CLOCK (the studio, the dolly, the wiring) runs on
        both and is put right only past a `DRIFT`, since taking every snapshot
        drags the room back by the trip; DICE (the scrubbers) are the host's
        and drawn. The host alone walks Ivan and Dominique in, throws the
        hearts and spends a pickup; an NPC stands and walks where the host's
        does. `tests/test_coop_rooms.gd` (21 checks).
        **Step 4 done (2026-10-02), the bosses**: drawn like any enemy, with his
        bar, concede and theme following, and what each boss's effects read off
        him in his own snapshot. What a snapshot cannot carry is a MOMENT, told
        by the host and heard on each guest (`_tell` / `net_event`): his lines
        (the host picks, and tells which, so every machine plays the same clip),
        his sounds and shakes, Ahmed's every effect through `_spawn_fx` - which
        carries the attack it belongs to, so an effect that ends with its
        attack does not end on a guest still a snapshot behind - Big Mo's spark,
        Silverman's copy and prism. `tests/test_coop_bosses.gd` (23 checks).
        **Step 5 done (2026-10-02), talking - and M3 with it**: whoever presses
        interact talks, on their own machine as ever; the NPC is LENT to them
        for its length (npc_base.gd's `led_by`), so HR's tour walks with a
        guest at its front; it is busy for everybody else, who read its lines
        along on the subtitle; a prompt is the player at that keyboard's, never
        somebody else's body's; and Ivan's gift stays the host's to throw.
        `WIRE` went to 2: a build from before this would join a run and not
        follow it. `tests/test_coop_talk.gd` (18 checks). Five two-machine
        suites now stand behind M3, 108 checks between them. What M4 inherited:
        bodies drawn at their last word (twenty or thirty a second, no
        interpolation), the hit-stop off online, and a third machine seeing
        another's numbers and kill bursts only where M3 already put them.
- [x] M4. **The feel.** Remote bodies drawn ~100 ms behind and interpolated;
        the hit-stop visual-only online; effects, numbers and sounds fired
        locally on the host's word.
        **Done (2026-10-03)**, in three parts, solo untouched:
        (1) **One clock, the host's.** Every message about the run carries the
        host's time (`WIRE` 3); a guest reads that clock off the fastest trip
        it has seen (`game/sync/clock.gd`), and the host turns each guest's
        stamps into its own. What is DRAWN is drawn `DELAY` (0.1 s) behind it,
        gliding between the states either side (`game/sync/timeline.gd`):
        the room's bodies through `net_between()`, everybody else's player
        through `net_draw()`. A remote player is in two places on purpose -
        its BODY at the newest step, which is what the host decides blows,
        doors and pickups with, and its PICTURE a beat behind - so a guest who
        steps out of a swing is out of it on the host as soon as the wire
        allows. What the host says about the room (a blow on you, health,
        down, up, lives, the end, every boss moment) is played at the same
        moment of the same clock (`Sync.later()`), so the number comes up as
        the drawn sword lands; the welcome and the order to travel are acted
        on when heard. A CLOCK (studio, dolly, wiring) is not drawn behind:
        it takes its state when heard, or every correction would set a hazard
        late. A jump faster than 600 px/s is held, not slid.
        (2) **The stop holds the picture** (`game/picture_hold.gd`): online a
        blow that lands disables every animation and every hit-feel effect on
        that machine for the stop and leaves the world running, then CATCHES
        UP each animation by the time it was held - a boss's sprite is his
        telegraph, and a swing must still end itself. Asked by this machine's
        own blows and by a boss's, which is now told like his shake.
        (3) **Every blow seen everywhere.** A blow and a bolt are a player's
        MOMENTS, told through the host (`World.from_player`): the host deals a
        guest's reported blow first, then every other machine draws it with
        the attacker's body - number, flash, jolt, juggle, static charge,
        pieces on a kill, the bolt and its crackle, the impact sound - and the
        attacker is told back only whether it killed. A blow or drain on a
        player is seen on every machine with its grunt; `die` plays where
        health reaches 0. A remote body's own moves are read off its picture:
        the swing's air, the charge's hum and ring, the heavy's supernova -
        never the stop, shake or flash, which are the attacker's. A remote
        body's sounds are positional. Static charge is per player, on the
        owner's word after playing it: your swings set up only your own arc.
        `tests/test_coop_feel.gd` (40 checks), and the stop told in
        test_coop_bosses.gd.
- [x] M5. **Ping and the connection, on screen.** The Tab scoreboard, the
        corner ping, the relay warning, "player left" / "host left".
        **Done (2026-10-03)**, every piece picked from the Ping On Screen
        preview (https://claude.ai/artifact/CHLaYkvrXqXBwJMB3jj1YA) and
        built from its own construction code, pixel-identical to it: the
        scoreboard is the TABLE (`ui/scoreboard/`, CanvasLayer 7, held on the
        new `scoreboard` action, Tab); the corner is the NUMBER alone, HOST on
        the host's screen; a relayed guest gets the lobby's warning across the
        top for five seconds - and, the owner's call, no RELAY tag on the HUD
        rows, so the host sees a relay in the scoreboard's route column rather
        than against the name; somebody leaving is the same strip for three
        seconds ("IVO LEFT THE GAME"); and the host leaving is a PANEL with
        one button (`ui/host_left/`) over a frozen room, the death screen's
        manners, MAIN MENU the way out. Nothing new on the wire: the numbers
        are the ping the host already measures. The ping colours moved up to
        `ui/ping.gd`, shared with the lobby's seats. `tests/
        test_coop_screen.gd` (20 checks), the panel in test_lobby.gd, and
        test_party.gd proving a game offline shows none of it.
- [x] M6. **The cracks.** A guest dropping mid-fight, dying during a fade,
        two players reaching a door during one, a boss conceding to a lagging
        guest, an NPC talked to by two people at once; and the export presets
        carrying the plugin's binaries.
        **Done (2026-10-03)**, each crack made to happen on purpose in
        `tests/test_coop_cracks.gd` (a lagging guest is its whole machine
        held still): three held as built and two did not.
        **Held**: a death mid-fade is one life and up on the far side on both
        machines, a guest frozen through the door whose body dies there
        included; a door fired again mid-fade still moves the party once; and
        a boss finished by a hitching guest concedes once on both, the swings
        still arriving after nothing to him.
        **Two at one NPC** began two conversations and left the NPC lent to
        the guest for good: the host's word now decides who got there first,
        and the loser's conversation closes with the NPC busy on its screen.
        **A guest dropping** left a frozen body in the fight that the room
        beat down - the shared pool paying for somebody not there - and a
        line the transport could take half a minute to give up. Now a body
        unheard for a second is AWAY: out of the fight like a body that is
        down (nobody's target, nothing lands, no door waits) but not down -
        no life, and the run not over - drawn see-through, and back when its
        owner is heard; and Net drops a guest unheard for `DROP_SECONDS` (15:
        a hidden browser tab stops dead, and looking away is not leaving),
        while a guest unheard-from host ends the party as "host left". The
        presets already carried the plugin - the DLL beside the exe, the
        framework inside the .app, both checked in the dev build - and
        release.yml now looks inside every build for it. A macOS build has
        still never played online on a real Mac.

## Build order — each step ships playable

- [ ] 1. Floors as biomes: 10 entries in `tools/biomes.gd` (office palettes),
        run build_biomes + build_levels. Per-floor enemy placement AND
        furniture are per-biome data, so a floor is data plus whatever new
        props it needs in `tools/props.gd` - a regenerate rebuilds the dressed
        room rather than resetting it. **ALL TEN ROOMS EXIST**, in chain
        order: F1 the lobby, F2 the content studio, F3 the call center, F5 the
        hub, F6 the innovation lab, F7 the gym, F8 asset recovery, F9 the
        executive floor and F10 Silverman's office are dressed, and F4 Ahmed's
        office is a room waiting for its boss. Every one of them is empty of
        enemies except F8, which has its four office boys - the cast goes in
        by hand, floor by floor.
        The two demo biomes are not on the end of the chain any more - they
        are dealt INTO the building, `marble_hall` between F5 and F6 and
        `hellfire` between F8 and F9, so a run walks all ten floors in
        DESIGN.md's own order and ends where the story ends, in Silverman's
        office. Both are still demo rooms and both still hold the only fights
        above asset recovery, which is what keeps the chain suite's enemy checks
        somewhere real while the reskins are unbuilt.
        Moving hellfire mid-chain cost it a placement: it gained a north door,
        and its enemies had been lined along the north wall on the assumption
        that nobody ever walked past them. They now clear the door lane at
        x 246-300 by each type's own sight radius, like every office floor's
        do.
        Regenerate one floor at a time: `build_levels.gd -- <level>`, and note
        that inserting a floor changes its NEIGHBOURS' door targets, so
        rebuild those too.
- [x] 2. Reskin enemies: office_boy / social_media / call_center roster
        entries seeded from the frozen body; run build_enemies.
        All three exist, each a roster entry, a seeded sheet and a scene with
        no script of its own: `office_boy` on enemy_base.gd, `social_media` on
        wraith_base.gd (violet-haired, wearing the studio's own neon),
        `call_center` on warden_base.gd (grey shirt, because a pale neutral
        takes the violet charge tint hardest). Reskinning the wraith and the
        warden bubbled their scripts and effects up to `game/enemies/`, per the
        placement rule; the six sheets are 9 rows for the three that swing and
        6 for the three that never do.
        **Still to place**: nobody stands in a room yet - the floors' `enemies`
        lists are the next step, and "Who stands on which floor" above is the
        agreed roster to place from, floor by floor.
- [ ] 2b. Reinforcements: a floor's second beat, `reinforcements` in its biome.
        Built and covered by `tests/test_reinforcements.gd`: the machinery in
        `game/levels/reinforcements.gd`, asset recovery's pair, the executive
        floor's late warden (with the `spawns` key its chokepoint needed) and
        both boss floors' health-cued adds. **Every beat's telegraph is still to
        come, and it is the only thing this is missing** - the staggered
        single-file walk-in through a known door carries it for now. See
        "Reinforcements - the second beat" above for why this is not waves, and
        why almost no floor gets one.
- [x] 3. Dialogue. **Built**, and built past what this step asked for: the
        subtitle box (`ui/dialogue/`), the proximity trigger and prompt on
        npc_base, and a conversation runner that also branches, walks the NPC
        and tows the player along behind her (`game/dialogue/`). Conversations
        are data - a .gd of beats, named per NPC in biome data - and every beat
        already carries a `voice` path for the day there is audio. Covered by
        `tests/test_dialogue.gd`. **Dominique and Ivan still have no lines and
        are still not on a floor**; HR is, and hers is the first induction.
- [x] 4. Ivan. **Built**, and the cooldown turned into a cue: he is a floor's
        THIRD beat (`relief`, game/levels/relief.gd), walking in through the
        door the player came by once the room is clear, crossing to an authored
        spot, and throwing one heart per head at the end of his three lines -
        once per visit. The head count is game/heads.gd, shared with a second
        beat's `per_head`. His heart is his own scene (tools/build_npcs.gd), so
        no floor but the lobby carries one. Covered by `tests/test_ivan.gd`.
        **Built since**: a conversation per floor rather than one for all six,
        voiced - see his entry under NPCs for why one set of lines could not
        survive being heard six times.
- [x] 5. Boss plumbing: locked doors (done: every room is sealed until it is
        beaten, game/levels/room_clear.gd - it began as boss_door.gd),
        defeat -> concede -> unlock (done: boss_base.gd), boss HP bar on HUD
        (done: ui/hud/boss_bar.gd, found by group so every boss gets one).
- [ ] 6. Bosses in order Ahmed -> Big Mo -> Silverman (each adds one idea:
        summons; multi-hit rhythm; phases). Ahmed is built, less his summon.
- [ ] 7. Ending: sticky-note screen, discount code constant, credits.
- [x] 8. Tests: new `tests/test_bosses.gd` suite (one suite = one world);
        test_chain checks every room's doors shut and then open, conceding
        Ahmed to walk on; tests/test_lock.gd fights the lock for real.
- [ ] 9. Online co-op: M0-M6 under Multiplayer above.
