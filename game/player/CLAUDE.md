# Player - characters, health, combat

Deep dive for `game/player/` and the HUD it feeds. The contract the world
presses on the player (blow / drain / status, group + has_method) is restated
in the root CLAUDE.md; the enemies these numbers are tuned against are
`game/enemies/CLAUDE.md`.

## Characters

Play goes menu -> `ui/character_select/` -> game. Every character shares the
same body and animation set; the differences are cosmetic (hair, clothes, eyes)
plus at most a one-pixel build tweak, all palette-swapped from the CC0 sheet in
`game/player/src/` the way biome art is swapped from the dungeon sheet.

The cast sharing one sheet is deliberate and permanent - they all play the same
game with the same moves, so a new animation drawn once should land on all ten
at no cost. Adding one is two edits: draw the row into
`game/player/src/character_cc0.png`, then add it to `CAST_LAYOUT` in
tools/build_characters.gd. Nothing outside the cast can see either change.

**Enemies deliberately do NOT work this way**: each owns its own sheet and is
seeded from a frozen copy of the body, because each is heading somewhere
different and the cast's sheet is going to keep moving. See
game/enemies/CLAUDE.md.

`game/player/characters/roster.gd` is the single source of truth: id, display
name, frames path, and the `recipe` tools/build_characters.gd bakes into that
character's `<id>_frames.tres` (textures embedded as
PortableCompressedTexture2D, so a rebuild works headless with no --import).
Mayar's frames double as the player scene's default look. Adding a character:
one roster entry, run build_characters.gd; the select screen builds its
portraits from the roster at runtime. It lays them out five to a row, because
ten 72px portraits in one row are 774px against a 640px viewport, and
test_menu.gd checks the column still clears the footer hint - an eleventh
character starts a third row and needs that check to keep passing.

The choice is saved through `Settings` (section `player`, key `character`) only
when the player actually picks someone, and player.gd swaps its SpriteFrames to
match on `_ready`; an unknown saved id keeps the default look.

## Health

The player owns its health (player.gd): `MAX_HEALTH`, `take_damage()`,
`drain()`, `heal()`, `apply_slow()`, and a grace window after each hit during
which the sprite blinks and further damage is ignored. Hazards, pickups and
enemies reach the player by the `player` group + `has_method`, never by type.

**Four ways the world reaches the player, and the splits between them are the
thing to get right.** A *blow* (`take_damage()`) is metered by the grace window
and opens a fresh one - and misses outright a body in the untouchable stretch
of a roll, the one way a blow can be beaten by timing (*The dodge*, below). That window is the only rate limiter for blows anywhere
in the game, and it is per-difficulty (`Difficulty.grace_seconds()`, read once
at spawn) because it is secretly the CROWD dial: a guard's full attack cycle is
0.8s, so a grace of 0.8 (EASY) swallows every extra guard's strikes and N
enemies hit like one, 0.5 (MEDIUM) lets a pair interleave, and 0.4
(HARD) lets a third find gaps too. Retuning it retunes every hazard and enemy
at once. A
*drain* (`drain()`) is continuous harm that already knows its own rate - an
aura, a poison - and sits outside the grace window in both directions: never
blocked by one, never opens one. Routing a drain through `take_damage()` is the
obvious first move and is wrong twice over: an unrelated torch clip would
swallow a second of it, and the sprite would blink as though the player were
being struck once a second. Both funnel into `_lose_health()`, so death fires
identically whichever killed you.

A *status* (`apply_slow()`) is the third thing: not harm that happens and is
over in the same frame, but something the player **carries** and that expires on
its own. Outside the grace window for the same reason a drain is. Statuses are
read off two public vars (`slow_factor`, `slow_seconds`) so a HUD icon can
render one later without new API; they refresh rather than compound - the
strongest in force wins and the timer extends, so two wardens keep you slow for
longer but never make you slower; `MIN_SLOW_FACTOR` floors how far any
combination can reach; and `revive()` clears them, because respawning into a
room still crippled by whatever killed you is a second punishment for one
death. Freeze lands here when it comes - the shape is meant to take it. A slow
scales the walk animation as well as the speed, since a slowed walk played at
full rate reads as skating, but deliberately not the swing: it takes your legs,
not your sword.

A *shove* (`shove(direction, force)`) is the fourth, and it arrived on exactly
the terms this section promised push would: it is shaped like a status, not like
a blow. Something the player carries for half a second and which decays on its
own, outside the grace window in both directions - a torch clip must not swallow
it, and being pushed must not buy immunity from the guard winding up behind you.
Overlapping shoves refresh rather than compound, the same rule a slow keeps: the
strongest push wins and the clock resets, so two machines catching somebody
between them cannot add up to a launch. The hub's floor scrubbers are what asked
for it (game/levels/CLAUDE.md's *The machines*); where one also wants to hurt it
calls `take_damage()` too, and the two meter themselves independently, which is
correct - the damage is a blow and the push is not.

Three things about it are load-bearing:

- **It is never added to `velocity`.** Velocity is carried between frames and
  only bled off at `FRICTION`, so adding a push to it every frame COMPOUNDS: a
  70 px/s shove held for half a second reaches several hundred and then coasts
  the player across the room long after the shove is over. It goes through its
  own `move_and_collide()` after the ordinary move instead, which leaves the
  state the stick owns alone.
- **The room stops it.** Because it is a real move rather than a teleport, walls
  and furniture bound it; and `MAX_SHOVE` (70) is under the walking speed of 90,
  so one physics frame is about 1.2 px and nothing can be posted through a
  16 px tile.
- **It rides on top of whatever the player was doing.** Walking, sliding through
  a light attack, rooted in the heavy - all pushed the same amount, because
  being rooted is not being bolted down, and a push you cannot walk against is a
  cutscene rather than a stumble. `MAX_SHOVE` and `SHOVE_SECONDS` together are
  the whole feel: half a second off a 70 ceiling is about 17 px, which is a tile.

**A blow that lands shows its amount.** `take_damage()` spawns
`game/player/damage_number.gd` past the grace check: "-18" in a 3x5 pixel font
with a dark outline, red, rising 14 px a second from 30 px over the origin,
solid for half a second and gone at 0.8. It was lifted verbatim off the
Silverman attack preview, where it was drawn to make the hit checks readable.
Three things about it are decisions:

- **After the grace check, not before.** A blow the window swallowed cost
  nothing, and a number for it would say otherwise.
- **A drain shows too, but its ticks share one number.** It used to show
  nothing, on the reasoning that keeps a drain silent, and that read as a bug:
  the wraiths, the social media team and Silverman's cold room took health
  with no number on it. A drain lands a point at a time, several a second, so
  a number per tick is a pile of "-1"s - instead a tick lands on the newest
  drain number while it is still solid (`absorbs()`, under `FADE_FROM`) and
  its total climbs; after that the next tick starts a fresh one. A drain reads
  as a steady trickle of small totals. Its SOUND is still silent, for the
  reason under The noise - the eye can take a trickle that the ear cannot.
- **`top_level`, parented to the player.** It stays where the blow landed while
  the player walks out from under it, and it goes wherever the player's world
  goes - a door swaps the level, never the player. `z_index` 50 keeps a prop
  from hiding it. test_flow.gd's blow section checks the
  number, two drain ticks adding up on one, the blow's number gone by the next
  blow, and a fading drain number refusing a later tick.

**The lives are NOT the player's: they are the party's, one pool** (`lives` and
`MAX_LIVES` 3 on game.gd), because a party shares them (DESIGN.md's
Multiplayer). The body only says it fell (`died`); game.gd decides what that
costs. ALONE, each death spends one, and with lives left the room fades back to
the current level's `start` spawn at full health - losing a room. The last
death raises the pause overlay as a death screen (`show_game_over()`): heading
YOU DIED, CONTINUE disabled, Escape swallowed (nothing to resume back into),
the room frozen and visible behind the dim. MAIN MENU and QUIT are the only
exits, and a new run builds a fresh party, so lives reset by construction.

**In company a death stops nobody else's game**, so it is not a fade: the body
goes DOWN where it fell (`knock_down()`) - it falls and LIES there (the
`fall` rows, held on their last frame, in a darker solid `DOWN_TINT`) - physics
and collision off, and - the whole trick - OUT of the `player` group. Everything in
the world reaches the player through that group, so leaving it is leaving the
fight: enemies stop picking the body, hazards, drains and pickups stop touching
it, a door stops waiting for it and game/heads.gd stops counting it, and none
of them had to learn what down means. The pool pays a life at once, and the
body gets up at the room's `start` door `GET_UP_SECONDS` (3) later through the
same `revive()` a solo respawn uses, which puts it back in the group. With the
pool empty it stays down until a teammate revives it (*Picking somebody up*,
below), and the run ends when nobody is standing and nobody is about to be. `is_down()` is the readout - a flag of its own, not the group,
because online a body can be out of the fight without being down: AWAY, when
the machine that moves it has gone silent (`away`, `set_away()`, game/sync/
CLAUDE.md's M6). `_belong()` is the one rule for the group and the collision
shape: in the fight while neither down nor away.

**Down is a seat in the stands, not a frozen screen** (the 2026-10-03
playtest). While this machine's player is down, game.gd's `_watch()` points
the camera at somebody still standing - first whoever is nearest the fall, so
it goes to the fight that was going on - and the HUD says WATCHING and their
name along the bottom. The pick sticks; the attack button moves it on to the
next one standing; the one watched going down moves it on by itself; with
nobody standing it stays put; and getting up takes it straight back. It
follows the body's PICTURE (`drawn_at()`), which on a remote body glides a beat
behind its newest step, so the camera glides with what is drawn rather than
stepping with the wire. Nothing about it crosses the wire: every machine
already draws every body. `tests/test_watch.gd` owns it. While somebody is
reviving them, the line says who instead ("ANAS IS GETTING YOU UP").

## Picking somebody up - the revive

Option A, **Steady hands**, picked from the Revive Lab preview (2026-10-04)
with the owner's three changes - green, plus signs, and the one reviving stays
standing - and shipped as previewed. The rules are game/revive.gd's header;
the shape of it:

- **Anyone standing, on anyone down, as often as it takes, and the pool never
  hears of it.** Stand within `REVIVE_RANGE` (16 px) and HOLD interact (E):
  `_fallen_in_reach()` finds the nearest body in the `fallen` group, and while
  it is held the player stands still turned to them, the stick and the attack
  button ignored - `_reviving`, asked of the hands every physics frame, so
  letting go, a roll, a conversation or a death ends it. Nothing new is drawn
  for the one reviving: it is the idle frame.
- **4 seconds of holding** (`SECONDS`), no faster with two. Letting go runs it
  back down at the same speed; every blow the one reviving takes knocks 1
  second off (`BLOW_COST`), decided where blows are, on `reached`.
- **Up where they lay** (`get_up()`), at 50 health with a 1 second grace
  window, turned to whoever got them up, rooted for `RISE_SECONDS` (0.36)
  while `rise` plays. A wait at the door that was running is overtaken, as a
  door overtakes one. With hearts left the door's 3 seconds usually win, so in
  practice a revive is what the party does once the hearts are gone.
- **On screen**, every one of them drawn as the page drew it, pixel stepping
  and all: the green ring on the floor round the body (`revive_ring.gd`, dark
  green whole, green filled with a pale head, red for a moment when a blow
  knocks some off, dimmer while it runs down), green plus signs rising off the
  filled part (`heal_plus.gd`), and when it closes a flare, a crown of plus
  signs and a green +50 (`damage_number.gd`'s `spawn_healed()`); and over a
  body this machine's player could revive, a small E (`revive_prompt.gd`).
  The ring is `top_level` at the world's origin rather than at z -1 like the
  charge ring: a top-level node at -1 drew UNDER the floor tiles, while at y 0
  in the y-sorted room it draws after the floor and before anybody standing.
- **The frames are in no sheet on disk**, on the dodge's terms: rows 27-28
  (`fall_side`, `rise_side` - side-on only, flipped for the other way) are
  the side idle body moved about by `tools/revive_pose.gd`, the preview's
  generator ported line for line - lying is that frame turned a quarter
  anticlockwise, and the crouch and the sitting ball are the roll's - built
  after the roll from each RECOLOURED sheet. All ten were diffed against the
  page's own frames and are identical.
- **Online the host counts.** A body's step carries who it is reviving (a peer
  id); the host fills from that, and tells the guests whenever a revive starts
  or stops filling or loses a second (`revive_changed`) and when somebody is
  up (`revived`) - `WIRE` 5. A guest fills its own copy between two words, so
  its ring runs smoothly. A body that is down keeps THIS machine's fall rather
  than its owner's picture (net_draw), so every machine shows it lying the
  same way.

`tests/test_revive.gd` owns it on one machine and `tests/test_coop_revive.gd`
across two.

The HUD (`ui/hud/`, instanced by game.tscn) is deliberately dumb: game.gd wires
`health_changed` to it, pushes starting values and pushes the pool whenever it
moves, and it renders whatever it is fed - a bar with a percentage label, plus
one heart icon per possible life (spent ones dim rather than vanish, so max
lives stays readable). The big bar is THIS machine's player; the rest of a
party get a row each under the hearts (`set_party()`), a small bar and a name,
dimmed while they are down - and a party of one gets no rows, so solo the HUD
is what it always was. HUD heart icons are drawn at runtime in hud.gd from the
same 9x8 mask as build_biomes.gd's heal pickup - kept in step by hand. Since
game.gd never re-instantiates a party's bodies, health carries across door
transitions for free; and since levels ARE re-instantiated, a consumed heal
pickup is back on the next visit - rooms keep no state yet.

## The hands - an input source, not `Input`

The player never reads `Input`. It asks its `input_source` four things - where
the stick points, whether attack is held, whether attack went down THIS physics
frame, and whether the dodge did - and `game/player/input_source.gd`, the one it gets by default, answers
them off the keyboard exactly as player.gd used to itself. That is the seam a
party needed: two bodies in one room cannot both be driven by one keyboard, so
whatever answers those three questions can move a player -
`game/player/virtual_input.gd` (a stick and a button set by code: the suites'
second player) today, the wire later. game.gd hands a member its source, and
its `character` (a roster id; empty is the saved pick), before the body enters
the tree.

Two details carry the weight:

- **Asked live, never sampled once a frame.** The button is also read when an
  attack animation ends, which is an idle-frame callback, and an answer
  sampled at the last physics frame would be stale there - deciding wrongly
  whether a held button flows into the charge or a released one ends the
  combo. The keyboard source therefore asks `Input` at the moment of asking,
  which keeps solo exactly what it was.
- **A synthesized press is DATED.** `Input`'s just-pressed is true for the one
  physics frame after the key went down, even if it came back up first. So
  `virtual_input.hold(true)` only marks a press as owed, and `tick()` - called
  at the top of every physics frame - stamps it with that frame's number. A tap
  shorter than a frame still swings; a press made mid-charge is spent and gone,
  as a key's is.

**Online the wire did NOT become a third input source**, and that was the call
worth writing down. A remote body is driven by its OWNER's machine and drawn
everywhere else (`remote`): it runs none of the player, and stands and plays
what its owner last sent (`net_state()` / `apply_net_state()`). Replaying the
owner's keys on every machine instead would have given every machine its own
version of where that body walked, swung and charged, to be corrected forever;
sending what the owner's body DID has nothing to disagree about.

And one rule keeps a guest's world honest, which is the other half of the same
choice: **`_world_reaches()` - on a guest, `take_damage`, `drain`,
`apply_slow`, `shove` and `heal` are no-ops.** The guest runs the same rooms,
and its torches, fire and copies can touch its bodies all they like; only the
host's do anything, and what they did arrives as `net_health()` and
`net_reached()`. On the host, a blow on a remote body is metered by the HOST's
grace window and its health sent to everybody, while a slow or a shove is sent
to the owner, because only the owner moves the body (`reached`).

## Combat - four moves, one button

The player's side of the fight is four attacks on the one attack button. A
press starts the swing (`ATTACK_POWER` 5); pressing again during it, or within
`COMBO_GRACE_SECONDS` after, chains the second hit (`attack2` rows 9-11 of the
cast sheet, `THRUST_POWER` 7 - the name is historical, the move is now a rising
slash); a third press, on the same terms, chains the **arc** (`attack3` rows
21-23, `ARC_POWER` 12), and the arc ENDS the chain, so the press after it is a
fresh swing. `LIGHT_NEXT` is the chain written down once, and `_combo_next`
remembers which link a late press inside the grace window reaches. All three
share the swing's hitbox: the rising slash's arc covers the same reach, and the
jump in its art is its own movement. **A press mid-attack is buffered, never
dropped** - mashing walks swing-slash-arc cleanly, and a dropped press reads as
the game eating the button. Getting hit deliberately does NOT break the combo:
the game has no hitstun, so a silently swallowed buffer would read as dropped
input, and melee happens inside enemy contact where hits are constant - a later
hit's cost is commitment (animations facing one way), not a hidden reset.

**The arc is the combo's crowd answer, and it is the cycle's arithmetic that
makes it legal.** 5 + 7 + 12 is 24: one full cycle is exactly a guard and
exactly the heavy, so every enemy HP in the game still dies on a whole hit -
guard 3, wraith 3, warden 5, security 6 (two cycles). When the third hit lands,
lightning jumps from each body the blade reached to the nearest enemy within
`ARC_JUMP_RANGE` (40 px) that this attack has not touched, and once more from
there (`ARC_JUMPS` 2), for `ARC_JUMP_POWER` 5 each - a SWING's worth, so a body
the bolt reached stays on the same 5 / 7 / 12 lattice as one the blade did.
Retune the jump and the breakpoints walk. The ledger is `_swing_hits`, which is
what keeps the bolt from doubling back onto the body it left and the hitbox
from landing a second 12 on a body the bolt already reached for 5. A conceded
boss is skipped rather than jumped to. The bolt itself is `game/player/arc.gd`,
drawn live for the reason a boss draws his fire live - a line between two
bodies has no fixed shape a sheet could hold - and in the character's spark
colour, which is now `Roster.spark_hex()` so the sheet's sparks and the live
bolt read one rule. It was picked from four previewed candidates and shipped as
previewed (`_nearest_enemy`, the 40 px, the two jumps, the 0.3 s flicker); the
other three - a blink through a lane, a ring slam that shoves enemies, a thrown
blade with a lockout - were each rejected for bending a rule this file states.

**Light attacks steer and slide, the heavy roots.** While the swing or the
second hit plays, a held direction moves the body at `ATTACK_SLIDE` (0.35) of
walking speed AND turns it: `_turn_attack()` re-faces, re-parks the hitbox and
swaps the sprite to the new facing's row of the same attack at the same frame
and progress, so the swing keeps its timing while it follows the stick. The hit
ledger is untouched, so one swing still lands once per enemy however far it
turns. The
fraction is a step-in, not an escape: a guard's finish still lands on a player
who tries to walk out of it, which is what the grace window and the interrupt
tuning assume. The charge stance, the heavy and the wildfire brake to a stop as
before - the heavy's rooted seconds are part of its damage maths. Damage goes through a Hitbox Area2D that `_start_attack()` parks
one step ahead of the body in the facing direction; it stays live for the whole
animation but a ledger (`_swing_hits`) lands each attack once per enemy - so a
24 HP guard dies to one full mash cycle (5+7+12). The spark colour every
character carries comes from `_spark_hex` in character_art.gd: the hair colour
raised to flash intensity (near-black hair would vanish on dark floors),
`SRC_SPARK` gold where a bald head has none; it tints the swing, the charge
sparks and the wildfire. Per-character health and attack
stats are planned; they will join the roster recipe the way looks did.

The swing's art is **Lightning Edge** (rows 6-8 of the sheet): the old outlined
crescent is gone, and the blade is a one-pixel white line trailing a jagged
arc that cools and breaks into dashes, with a bloom at the hitbox centre on the
third frame. It is drawn blue in the sheet (the `SRC_VOLT_*` constants in
character_art.gd) and **recoloured per character the way the old sparks were**:
the white core stays, the arc becomes the spark colour, the tail and fade the
spark darkened - so Mayar swings violet, Anas gold. Everything stays inside the
32px frame; on the down row the bloom sits 3px above the hitbox centre because
the centre itself is on the frame's last row.

The second hit's art is **Rising Dragon** (rows 9-11): a launcher. Crouch in a
wide stance with the blade low, an uppercut slash that lifts the body three then
five pixels with a shadow painted on the floor beneath, blade straight overhead
at the apex, then a landing squat with dust. The bodies are NEW poses, not
reused frames: a pose kit takes the idle body's head, torso and legs, draws the
arms fresh for each frame and regenerates the outline. Its blues (`SRC_THRUST_*`)
are deliberately fixed for every character - the swing reads as the character's
own colour, the launcher as the weapon's - and sit one step off the volt values
so the recolour, which goes by exact hex, can tell them apart. The floor shadow
(`SRC_SHADOW`) is translucent: restyle() keeps each pixel's alpha when it
recolours, where it used to rebuild the pixel opaque.

Both were baked by a script from the pristine CC0 rows rather than drawn by
hand, so `character.aseprite` no longer matches the PNG; the PNG is the truth.

**The heavy is the hold, and the hold is now just holding.** A press always
swings first - waiting to see whether the press is a hold would lag every basic
attack - and a button still held when an attack ends (with nothing buffered)
flows into the `charge` stance: rooted, looping the wind-up while sparks spiral
inward. At `CHARGE_SECONDS` (0.75) it fires `heavy` **by itself** - the spin -
which always erupts into `wildfire`, and the pair deals `HEAVY_POWER` (24)
through the Spinbox, a 17 px circle on player.tscn, to EVERY enemy inside it,
once per enemy across both animations (the ledger is not cleared between them).
Letting go early just returns to idle - the press's swing already happened, so
a tap stays a tap, mashing stays the combo, and holding is the heavy: four
moves, one button.

**Three things changed together, and they are one fix for one complaint - the
hold was hard to do.** Each was a separate way of charging the player for the
same second:

- **The count starts at the PRESS, not at the swing's end** (`_hold`, which
  `_charge` is seeded from when the stance opens). It used to be 1.0s that only
  began once the opening swing had finished, so the real price was 1.3s; now
  the swing is inside the charge rather than a tax before it. `_hold` needs no
  reset of its own, because a press can only follow a release and a release
  zeroes it.
- **It fires itself.** There is no release to time, which is the whole of what
  made it hard: the old stance asked for a release judged against a cue nobody
  could see, and a release a fraction early threw the entire hold away with no
  sign it had been close. Hold, and it happens.
- **The cue moved off the eyes and onto the FLOOR.** It used to be the charge
  animation doubling speed at the ready point - two pixels on a 32 px body, in
  a room with four enemies in it, which is a cue only for somebody already
  counting. `game/player/charge_ring.gd` is a ring at the feet that TIGHTENS as
  the charge fills (20 px to 7), brightens towards white, spins four sparks
  faster as it goes, and flares outward on the frame the heavy leaves. The
  stance's animation still winds up towards double speed, but as a ramp rather
  than a snap, so it is progress rather than an announcement. An early release
  DROPS the ring rather than flaring it: a flash on a cancelled charge says
  something happened when nothing did.

The ring takes the character's spark colour, which is `Roster.spark_hex()` for
the third time - the sheet's sparks, the arc's bolt and this ring are one rule.
Every exit from the stance goes through `_end_charge()`, including a
conversation taking the wheel and a death, so a ring can never outlive the
stance that built it.

`HEAVY_POWER` is **exactly a guard's health, and the equality is the design**:
an AoE that does not kill the basic enemy thins no crowd and never repays the
second it costs - at its original 15 it was strictly the wrong button, with
nothing dead at the end. At 24 it one-shots a guard and a wraith. The bound
that 0.75 had to respect is the same one 1.0 did, and it is a RATIO rather than
either number: press to wildfire is 0.75 + 0.29 + 0.29 = 1.32s, so the heavy's
single-target rate with its entry swing is (5 + 24) / 1.32 = 21.9/s against the
light combo's (5 + 7 + 12) / 0.86 = 28/s. The combo stays correct against one
enemy and the heavy against a crowd, which is the invariant - not the seconds.
Difficulty must never scale either side of that equality. The wildfire's ember
tone is `SRC_FIRE`, recoloured to the spark colour darkened, so each
character's fire matches their sparks - violet for the black-haired, gold for
the bald. One test-side consequence: a synthesized Space left held is no longer
inert - a test's mash window must end on a release, or the player stands in
the charge stance for every later movement check.

## The hit feel - what a blow that lands now does

The attacks were correct and dull: a struck guard turned red for 0.15 s, and a
kill made it vanish on the frame it was freed. The fix was picked from the
Combo Lab preview (one option per attack, plus a set of toggles under all four,
every one taken) and shipped as previewed. **Not one damage number moved**, and
that is the constraint everything below was chosen under.

**Under every attack.** `_land()` is now the one place a player blow reaches
an enemy, and it does five things besides `take_damage`:

- **Hit-stop.** `HIT_STOP` per attack - 0.04 swing, 0.05 slash, 0.07 arc, 0.1
  heavy - asked once per FRAME something was struck (like `hit`), through a
  `froze` signal game.gd connects to its own `_freeze`, exactly as a boss asks.
  The stops slow both sides of the heavy/combo ratio and it still holds: about
  23.5/s for the combo (0.16 s of stops) against 20/s for the heavy with its
  swing (0.14 s - the heavy's two 0.1 stops land together and extend rather
  than stack).
- **White first.** enemy_base's `STRUCK_TINT` for 0.05 s before `HURT_TINT` -
  a modulate over 1, so the figure lifts towards white with its outline dark.
- **Recoil.** `recoil(away)`: the SPRITE jolts 2 px and settles over 0.12 s.
- **A number over the enemy.** damage_number.gd's `spawn_dealt()`: white for
  the blade, the spark colour for a jump, double size for the heavy, no minus
  sign, and parented to the body's PARENT, because the number that matters
  most is the killing one and that body is freed the same frame. It shows only
  if health moved, so a conceded boss in the swing says nothing.
- **Kill burst.** kill_burst.gd reads the frame the body was showing, on the
  frame it is freed, and throws every other opaque pixel of it.

**Static charge, on the light hits.** Each swing or slash that lands adds a
charge (two at most, 1.8 s) to the body - static_charge.gd, a CHILD of the
body, found by node name, invisible to enemy_base. The arc's jump prefers a
charged body anywhere inside its 40 px over a nearer uncharged one, and a
charged body the arc reaches discharges (spark_burst.gd). It is the one pick
that changes logic, and it changes only WHO the chain goes to. In a party a
charge is the player's who laid it (`by`): one body can carry one of each, and
an arc only prefers and sets off its own thrower's.

**The juggle, on the slash.** `launch()` pops the sprite up at 72 px/s against
330 of gravity - about 7 px and 0.44 s - with a shadow on the floor and dust on
landing (game/enemies/landing_dust.gd). It is enemy_base's because the enemy
owns its sprite.

**The rule under recoil and juggle both: they move the SPRITE, never the
body.** That is why no placement band, leash, steering or alert check changed,
and test_hit_feel.gd measures it. And **a boss never reels** - `_reels()`
beside `_leashes()`, false in boss_base - because he moves his own sprite
(Ahmed's leap writes `_sprite.position`), and a boss the slash can juggle is not
the boss. He still flashes white.

**The thunderclap, on the arc.** arc.gd grows forks and a 4 px glow and lives
0.36 s; player.gd adds the shake (2, 0.15), a flash (screen_flash.gd, at
CanvasLayer 1 so the HUD is never washed out) and shock.gd on every body the
bolt touched - the body's own current frame as a spark-coloured silhouette at
four offsets behind it, for 0.5 s.

**The supernova, on the heavy.** charge_ring.gd draws embers in while the
charge fills; when the heavy fires, player.gd freezes the room 0.1 s, shakes it
(3, 0.22), flashes it, and drops supernova.gd at the feet - two shockwaves and
nine cracks that cool from white to scars and fade by 1.8 s.

Two traps found on the way. **A name in enemy_base is a name in every boss**:
the juggle's height was first `_air`, which is Ahmed's air-fire node, and that
one collision stopped his script compiling - it showed up as "nonexistent
function take_damage" on a CharacterBody2D. And **a landed hit now costs
frames**: a suite that checks the end of an attack that lands, by frame number,
needs slack (test_arc.gd moved its later checks by 6).

### Online: the same feel on every machine (M4)

All of the above was one machine's until M4. Three rules carry it across:

- **The stop holds the picture, not the clock.** `froze` online asks game.gd's
  `_freeze`, which holds every animation and every effect above on THIS
  machine (game/picture_hold.gd) while the host's world runs on, then catches
  each animation up - so a swing still ends itself, on time. Only this
  machine's own blows ask; a teammate's swing is theirs to feel.
- **A blow and a bolt are MOMENTS** (`_tell`, game/sync/world.gd's *A player's
  moment*). `_land()` tells the party what a blow it dealt came to; a guest's
  `_land_for_host()` shows its blow at once and tells the host, which deals it
  and then tells everybody. Every other machine draws it with this body's
  `net_event()` - `_show_blow()`, the same function `_land()` draws with, in
  this body's spark colour, plus the static charge, the juggle and the `hit`
  sound (once a frame). The attacker only hears back whether it killed. The
  shake, the screen flash and the stop are never sent: they are the swinger's.
  Static charge stays PER PLAYER across machines: a teammate's charge is laid
  by their body's copy, so only their arc - on every machine - sets it off.
- **A remote body's own moves are read off its picture** (`net_draw()` ->
  `_drawn()`): the picture going into a swing is its air, into `charge` its hum
  and its ring (under the sprite, where the picture is), into `heavy` its
  noise and the supernova. Its blows on a player are seen everywhere too: the
  host draws the number and the grunt over a remote body it hurts, every guest
  draws them over a body somebody else owns (`net_seen()`), and `die` plays
  wherever health reaches 0 (`net_health()`).

And a remote body is HEARD from where it stands: player_audio.gd builds its
speakers positional, the one exception to that file's first line.

## The dodge - the tumble roll

The fifth move, and the first off the attack button: `dodge` is K, beside J
for the hand on the attack key, and Z under the little finger of the hand on
WASD, which can roll without letting go of the stick - the same two keys on
every build. It was Ctrl once, desktop only, because in a browser Ctrl+W closes
the tab and no page can stop it; one game on every platform won, and Z took its
place. Shift was never a candidate: five quick presses open Windows' Sticky
Keys box over the game. Picked from the Dodge Lab preview (option A of a roll, a volt dash and a
side hop, https://claude.ai/artifact/2ucqkdtJrk4VmSgKE3gLU6) and shipped as
previewed, frames and numbers both.

**A roll is a real move.** `DODGE_DISTANCE` (48) in a straight line over
`DODGE_SECONDS` (0.32) at a steady speed, the way the stick points - or
straight back, away from the facing, with the stick at rest, so whatever you
were swinging at stays in front of you. Its velocity is the roll's own every
frame rather than carried, so a desk, a wall or a body stops it short and
nothing it ran into is still pushing on the next frame; a slow takes the same
share of it that it takes of a walk; and it runs on into the walk
(`DODGE_EXIT`, 0.8 of walking speed in whatever is held) instead of stopping
dead.

**A blow misses it from `DODGE_SAFE_FROM` to `DODGE_SAFE_UNTIL` - 0.04 to
0.26 s in** - which is most of it, and is what made the roll the forgiving one
of the three. Blows only: `take_damage()` returns before the grace check, so a
blow that missed opens no window, while `drain()`, `apply_slow()` and
`shove()` reach a rolling body exactly as they reach a standing one - the
wraith's drain is the one harm designed to have no timing answer, and a roll
must not become one. The first frames are open on purpose: a roll pressed as
the blow lands is too late. **`DODGE_COOLDOWN` (0.45) runs from the END of a
roll**, because rolls that chain would be a second grace window, and the grace
window is the crowd dial (*Health*, above).

**What it does to the attack button.** It cuts a swing, a slash or an arc
short (what the blade already hit stays hit, and the combo's window closes),
and drops a charge the way letting go early does; it is refused from inside the
heavy and its wildfire, whose rooted seconds are part of the heavy's damage
maths. A press during a roll is owed rather than dropped - a dropped press
reads as the game eating the button - and swings the moment it ends.

**The frames are in no sheet on disk.** Rows 24-26 (`dodge_down/up/side`, four
frames at 12.5 a second, one per 0.08 s) are the idle body moved about by
`tools/roll_pose.gd`, the preview's own generator ported line for line: a
crouch, then the head-and-shirt ball going over - a quarter turn at a time in
its 12 x 12 box side-on, crown first toward or away from the camera, where a
ball cannot turn round. build_characters.gd builds them from each character's
sheet AFTER its recolour, on every run, and the order is the preview's for a
reason: the recolour reshapes as well as recolours (curls grow from the top of
the hair, a beard is found through the eyes), so a ball turned BEFORE it is not
the ball that was picked - 8 of the 10 came out 111 to 299 pixels different
that way. So a redrawn idle row brings its roll with it, and the roll is redrawn
by redrawing the idle, never in the PNG.

**The dust** is `roll_dust.gd`, the preview's puff - landing_dust.gd's twin
with a velocity of its own: two kicked up behind the roll as it starts, one left
under it every `DUST_EVERY` (0.09 s), and one thrown ahead as it stands.
Top-level in the body's parent, so it stays where it was kicked up and draws
over the bodies, as the page drew it.

**Online, the host trusts the roller.** A body's step (`net_state()`) carries
which way it is rolling and whether it is in the untouchable stretch, and on the
host `take_damage()` on a remote body reads that word (`_net_untouchable`) off
its NEWEST step. The host decides every blow from a position that is a little
old; without the flag a guest would roll clear on their own screen and be hit
on the host's. A teammate's picture going into a roll kicks up the same dust on
every other screen (`_drawn`). It is why `WIRE` is 4.

It plays silent for now. A `dodge` cue is still to be cut - an entry in
tools/sfx/player.py, `make.py player`, the stream in player.tscn, a `_sfx`
call in `_start_dodge()` and the name in test_player_sfx.gd's CUES - and a cue
fired with no file behind it is what that suite exists to catch.
`tests/test_dodge.gd` owns the rest.

## Scripted control - when the world has the wheel

`take_control()` / `release_control()` / `lead_to()` are how a cutscene moves
the player, and the split from the door transition's
`set_physics_process(false)` is the whole point of them. A frozen body cannot
be walked anywhere, and the first thing a conversation wanted was to walk the
player across a room behind somebody.

So scripted control keeps physics running and cuts the INPUT instead: the stick
is not read, the attack button is not read, and any swing, thrust, charge or
heavy in flight is dropped on the way in - a conversation that opens on frame
two of a combo must not play out over the top of it, hitbox and all. What
remains is `_scripted_step()`, which is the ordinary walk with its direction
coming from `_lead` instead of the keyboard: same SPEED, same ACCELERATION,
same animation, so being led looks exactly like walking because it is.

`_lead` is a point, not a target node, re-set every frame by whoever is leading.
That is what lets one mechanism serve both "walk to this mark" and "follow her",
and `LEAD_STOP` is a ring rather than a pixel because an escort's destination
MOVES - a tighter test makes the walk stutter every time the guide slows down.

Health, grace and slows are all untouched by it. **Being talked at is not a
safe room**: the tree is not paused during a conversation (the guide has to
walk while she talks), so the protection is where an NPC is placed. See
game/dialogue/CLAUDE.md.

## The noise

The player's sounds work exactly the way an enemy's do and for the same
reason: `player.tscn` carries an `Audio` child (`player_audio.gd`) holding
id -> stream, player.gd fires names at it through `_sfx` / `_sfx_loop` /
`_sfx_fade` / `_sfx_stop`, and a name with no file behind it is silence with
no branch anywhere. Eight cues - `swing`, `swing2`, `charge`, `heavy`,
`wildfire`, `hit`, `hurt`, `die` - and a cue arrives by having the WAV.

**One set for all ten characters.** That is the sheet rule from Characters
above applied to the other sense, and it is permanent for the identical
reason: they play the same game with the same moves, so a swing cut once
should land on all ten at no cost. It has one consequence that had to be
designed for rather than discovered - **the hurt cue cannot commit to a
gender.** Nine of the ten are not whoever the clip sounds like, and a plainly
male grunt out of a character who is not male is the animation telling the
truth while the audio lies. So `hurt` and `die` are carried by air rather than
by tone: breathy, one syllable, neutral in pitch.

### Why this is not `enemy_audio.gd`

The placement rule would bubble a file shared by two features up to `game/`,
and this one is not shared - it does a neighbouring job with a different first
line. An enemy is SOMEWHERE. A room holds up to seven of them and which corner
a wind-up came from is the whole of what panning is for, so `enemy_audio.gd`
is an `AudioStreamPlayer2D` with a flattened attenuation curve. The player is
never anywhere: the camera is on them, so their pan is 0 on every frame of
every room, and a positional node here buys a distance calculation to produce
silence's exact twin.

So `player_audio.gd` is a plain `Node` of plain `AudioStreamPlayer`s, and it
is SMALLER than its counterpart rather than a copy of it. It drops
`play_detached` outright - that exists because an enemy plays `die` on the
frame it is `queue_free`d and takes its own speakers down with it, and the
player is revived rather than freed, so a death here outlives itself for free.
What it keeps is the `loop_end` fix, which is the third copy of that one in
the project (`enemy_audio.loop`, `music._seal`) and is worth having three
times: a forward loop sealed to frame 0 plays exact silence with its flag set.

The four wrapper names on player.gd are `enemy_base`'s verbatim on purpose.
They are not the same code, but nobody reading both should have to learn two
vocabularies for one idea.

### Three splits, and two are the enemies' rules from the other side

**A swing is air; `hit` is a blow that landed.** The two lights announce
themselves in `_start_attack` - the frame the swing STARTS, when nothing has
been struck - and `hit` fires from `_strike()` only on a frame something was
actually reached. That is game/enemies/CLAUDE.md's rule pointed back at the
player: an impact over empty air teaches you that the sound does not mean you
connected. It fires once for the FRAME rather than once per enemy, because a
heavy landing on four bodies is one impact, and four copies of one clip
started on one frame is a click rather than four hits.

**`drain()` is deliberately silent**, and it is the one absence somebody will
file as a bug. A drain runs every physics frame and already knows its own rate
(see Health above); a gasp on each of those is sixty a second, and routing it
through the grace window to thin them out is precisely the mistake `drain()`
exists to not make. The thing draining you is already making the noise - the
wraith's own `drain` loop - so the information is on the bus already, coming
from the right direction. A DEATH is a different matter and is not a drain
tick, so `die` lives in `_lose_health()` rather than in `take_damage()`: a
drain that kills you has to kill you as audibly as a blow does.

`hurt` is metered for free, because `take_damage()` already is - the grace
window stops a crowd stacking gasps without a line of audio code. It fires
only on a blow that was SURVIVED, since `_lose_health` plays `die` at zero and
a gasp laid over the death breath in one frame is one muddy sound rather than
two clear ones.

**The charge is the one loop here**, and it stayed one after the stance grew an
end. It was first specced as a one-shot capped at `CHARGE_SECONDS` so that the
clip running out would be the ready cue, and that was wrong on its own terms -
a sound that stops before the heavy is available actively misinforms. It is
still wrong now that the stance DOES end at a known moment, because the stance
has an end without having a LENGTH: it runs for `CHARGE_SECONDS` minus however
much of the opening swing the player had already held through, which differs
every time, and an early release can cut it anywhere. The ready cue is the ring
at the feet (see Combat), not the hum and not the eyes. The hum is faded
on release (an early release loses nothing, so it must not sound like something
broke) and CUT by `take_control()` and `revive()`, where the move itself was
cancelled and a hum trailing into the first line of a conversation would be the
cutscene starting on top of the combat it just dropped.

### Making them

`python tools/sfx/make.py player`, off `tools/sfx/player.py` - the bestiary's
pipeline with a second recipe, which is why the engine's dict is `CAST` rather
than `ENEMIES`. The levels sit ABOVE the bosses and the enemies rather than
under them, on the same arithmetic upside down: a room holds seven enemies and
one player, so the sound that says YOU are losing must never be won by a crowd.
`--relevel` re-shapes from `game/player/src/sfx/` and costs nothing; only a new
performance costs credits, and all eight are pinned in `KEEP` so a stray
`--force` cannot re-bill them. The prompts, the levels and the reasoning behind
both are in that file.
