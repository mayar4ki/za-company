# za-company

Godot 4.7 top-down 2D pixel-art game (GL Compatibility renderer, 640x360 base
viewport, 1x camera zoom, pixel snapping on).

The game being built is THE NEW HIRE — see `DESIGN.md` for the content plan
(story, floors, enemy reskins, NPCs, bosses, ending) and its build-order
checklist. This file says HOW things work; DESIGN.md says WHAT to build.

## Structure: feature folders + shared pools

- `ui/<screen>/` - one folder per screen; scene + script together
- `game/` - gameplay; `game/<entity>/` owns its scene, script, art, frames
- `game/bosses/` - the bosses; each owns its scene, script, poses, sheet and
  effects and shares NOTHING with the others but the rules (`boss_base.gd`)
- `game/npcs/` - the friendly faces; each owns its scene and sheet, and they
  share one script (`npc_base.gd`) because none of them fights
- `assets/` - ONLY files shared across features (fonts, tilesets, audio), plus
  source art no feature owns yet; it moves into the feature that claims it
- `autoload/` - global singletons registered in project.godot
- `tools/` - editor-side generator scripts run headless; never game code.
  `tools/voice/` is the one corner of it that is python rather than GDScript,
  because it talks to a web API; what it writes is ordinary art the game loads
  like any other file
- `addons/` - editor plugins and engine extensions, and there are two:
  `za_build`, which puts the `tools/` generators on the Project > Tools menu
  (see Workflow), and `webrtc_native`, the official GDExtension that gives
  desktop Godot WebRTC for online co-op - vendored, desktop libraries only
  (CREDITS.md). A new GDExtension is only loaded once `.godot/
  extension_list.cfg` names it, which the editor's scan or an `--import` pass
  writes - so a fresh checkout needs one of those before headless runs see it
- `server/` - the online back end that runs on OUR server, never the game:
  a signaling service and coturn, in Docker. Python, `.gdignore`d so Godot
  never scans or exports it; deploying it is `server/README.md`. The plan it
  serves is DESIGN.md's *Multiplayer*. Its Caddy also SERVES the game's web
  build, on the same domain as the signaling: https://za-company.mayar-deeb.dev
  - and dev has a signaling service of its own beside it, built from
  `develop`, which the dev site and every dev build talk to (server/README.md's
  *Dev's signaling*)
- `docs/` - the images `README.md` shows, `.gdignore`d on `server/`'s terms:
  a screenshot is not a game asset, so Godot must never import or export one.
  They are real captures (a windowed run, `root.get_texture()`, 1280 x 720 =
  an exact 2x), never mockups. Beside them, `docs/environments.md`: what
  production and dev share (the server, Caddy, coturn, the deploy key) and
  how each one bites, and `docs/dev_prod_plan.md`: what was decided about
  each and the plan for what is left - read both before touching `server/`
  or the release workflow

Placement rules:
1. A file lives with the feature that owns it. Scripts sit next to their
   scenes with the same basename (`player.tscn` + `player.gd`).
2. The moment a second feature needs a file, it bubbles up one level above
   the features that share it (enemy_base.gd at enemies/, theme at ui/theme/).
3. snake_case for every file and folder. `addons/` stays reserved for plugins.
4. Don't pre-create empty folders - create one when its first real file exists.

**Deep documentation lives with its subject**, in nested CLAUDE.md files that
load when files there are touched:

- `game/levels/CLAUDE.md` - the host, the camera, room anatomy, doors and
  spawns, the moving hazards and the later beats
- `game/enemies/CLAUDE.md` - the attack cycle, the leash, the types, the noise
  and the enemy art pipeline
- `game/bosses/CLAUDE.md` - what every boss shares: several attacks on that
  cycle, conceding, boss floors, the bar, the noise and the mouth - and one
  file per fight beside his scene: `game/bosses/ahmed/CLAUDE.md` (the
  poses-painter-fire contract), `game/bosses/big_mo/CLAUDE.md`,
  `game/bosses/silverman/CLAUDE.md`
- `game/player/CLAUDE.md` - characters, health, the combo, the heavy and the
  hit feel
- `game/npcs/CLAUDE.md` - why an NPC is twice the player's height, the robe,
  the 64px cell, the ground line and their voices
- `game/dialogue/CLAUDE.md` - the beat format, why the runner holds no
  variables, the escort, and where audio plugs in
- `game/sync/CLAUDE.md` - one run on several machines (M3 to M6)
- `ui/lobby/CLAUDE.md` - the way into online play
- `autoload/CLAUDE.md` - `Music`, `UiSound` and `Net`
- `assets/music/CLAUDE.md` - the tracks, and what a generated one needs before
  it can loop
- `tools/CLAUDE.md` - furnishing rooms from data, the prop catalogue, adding a
  floor, and what every generator writes
- `tests/CLAUDE.md` - what every suite owns, and how to write a check

This file keeps what must be known BEFORE touching anything: the maps, the
invariants and the gotchas.

## Levels

`game/game.tscn` is a host, not a room: it owns the party, camera, HUD, fade
and pause menu, and swaps one `Level` child underneath them. A level owns only
its own tiles, props and spawn markers, and answers three questions -
`bounds()` for how much world there is, `spawn_position(name)` for where to
stand, and `title()` for what to call itself. Nothing in game.gd names a
specific map beyond `START_LEVEL`.

**The party is spawned, not placed: solo is a party of one.** game.tscn holds no
player - game.gd builds one body per member of `next_party` (one, the saved
pick on the keyboard, unless something says otherwise) and the first is THIS
machine's, still named `Player`: the camera follows it and the HUD's big bar is
its health, while anyone else gets a row under the hearts. Four rules make a
party, and each is a no-op for one (DESIGN.md's Multiplayer, M1):
**the lives are ONE pool** on game.gd, not the player's; **a death in company is
a body DOWN**, not a fade - out of the `player` group, which is how everything
in the world already stops seeing it - and it gets up at the door 3 s later on
the pool's life, or stays down with the pool empty, and the run ends when
nobody is standing (while down, that machine's camera follows somebody still
standing - `_watch()`, game/player/CLAUDE.md); **anyone down can be REVIVED**
where they lie by a teammate holding E over them for 4 s - as often as it takes,
up at 50 health, and the pool never hears of it (`game/revive.gd`); **a door
waits for everyone standing** and says "1/2"; and
**the room alert is anyone's**. The player reads an *input source* rather than
`Input` (game/player/CLAUDE.md's *The hands*), which is how a second body is
driven, and an enemy goes for the nearest player and sticks (`target()`,
game/enemies/CLAUDE.md). `game/heads.gd` counts the standing party and holds
`MAX_PARTY` (4), the only place a party size is written down.
`tests/test_party.gd` owns all of it.

Its **CanvasLayer stack is now stated rather than defaulted**, because things
below the HUD have started arriving: -1 background, 0 the world, **1 a boss's
own screen effects**, 2 HUD, 3 the dialogue box, **4 what a boss is
shouting**, 5 transition fade, 6 level title, **7 the online scoreboard**,
10 the pause menu and the host-left panel. Anything
full-screen a fight draws goes in at 1 - above the room, under the bars, since
a flash that washes out the health bar hides the number the player is reading
while it lands. game.gd also owns **camera shake**, applied as an offset so
`_camera_target()` stays the only thing framing a room; a boss asks for it by
emitting `shook` (see game/bosses/big_mo/CLAUDE.md's *The Bell*).

**A floor is a SHAPE, and most floors are not the 34 x 19 room** - never assume
it. A biome's `shape` key changes the size, CUTS rectangles out of it, or hands
in a floor plan drawn as ASCII, and everything else follows from that one
predicate: the wall ring is grown around whatever is left (only its one-tile
FACE is painted, so a cut leaves the same black void the camera leaves around a
small room), the shadow course hugs it, a doorway is cut where its column meets
the wall, and a colonnade skips the pillars that would land in masonry. It lives
in `tools/plan.gd`, so a shape nobody has drawn yet is a new key there and no
branch anywhere else. The call floor is a hall with an arm off its north-east
corner and its two doors out of line; the innovation lab is an S of three halls
joined at alternating ends, the biggest floor in the game at 512 x 1008. What
that cost, and the two things a shaped room can break that a rectangular one
cannot: game/levels/CLAUDE.md's *The shape of a floor*.

**A level owns everything in it**: its own tileset, doorway art, `door.tscn`
and its own copy of every prop it places, palette baked in - no level borrows
another's. Everything standing in a room lives in its `props/`, on the same
shelves as the painters in `tools/props/` (`fixtures/`, `furniture/`,
`hardware/`, `markings/`, `openings/`, `signs/`); the fixtures shelf is named
by ROLE, so hazard.gd paints `torch.tscn` and heart.gd paints
`health_item.tscn`.

**A room is furnished from data, not by hand**: a floor's palette, furniture
and enemies are one hand-edited file, `tools/biomes/<level>.gd`, so
`build_levels.gd -- lobby` reproduces the dressed room rather than resetting
it. What a re-run DOES overwrite is anything hand-nudged in the editor - prefer
moving positions into biomes data over nudging scenes.

Levels are re-instantiated per entry: a consumed pickup or a dead enemy is back
on the next visit - rooms keep no state yet. Doors are found through the `door`
group and levels are typed via `preload`, never `class_name`: global class
names live in an editor-written cache a fresh headless checkout does not have.

**Three floors have a hazard that MOVES, and the rules they share are the ones
to carry to a fourth** (game/levels/CLAUDE.md's *The clock*, *The wiring* and
*The machines*):

- **The content studio keeps a CLOCK** (`studio` key): one node counting rest /
  cue / take, read by its five ring lights, its camera dolly and its neon sign.
  One number (`heat()`) drives every consumer; the cue phase is visible and
  harmless, because a hazard that merely switches on is one you could not have
  avoided; and the `studio` group is the only way anything finds the clock, so
  on a floor without one those props are exactly the furniture they always
  were. The dolly's rail stops at x 228, off the door lane.
- **The call floor is WIRED** (`surge` key): four runs of cable trunking that
  charge end to end and then put a head down their length, staggered. It draws
  its own conduit from the same two points it burns along, so the lane the
  player reads and the lane that hurts cannot come apart, and one pass is
  exactly one hit, which is what makes four of them fair.
- **The hub WANDERS** (`scrubbers` key): two floor scrubbers with no authored
  route, which run until the room stops them, so the FURNITURE decides where
  they go. `within` pens each into its own half, which is how a routeless thing
  keeps the door lane clear. It takes your POSITION through a real `shove()`
  and its scanner is cold: warm burns, cold moves you. It is a solid body,
  because being in the way is half of what an obstacle is.

Adding a floor is a data file in `tools/biomes/` plus a `CHAIN` entry;
**inserting** one mid-chain also stales its NEIGHBOURS' baked door targets -
rebuild all three: `build_levels.gd -- <before> <new> <after>`. The full
recipe is in tools/CLAUDE.md; room anatomy in game/levels/CLAUDE.md.

## Characters and the player

Every playable character shares one body, one animation set and one sheet
(`game/player/src/character_cc0.png`) forever - a new animation drawn once
lands on all ten. `game/player/characters/roster.gd` is the single source of
truth; adding a character is one roster entry, then build_characters.gd - the
sheet row is the shared body, recoloured by the entry's recipe. Enemies deliberately do NOT share a sheet - each owns its
own, seeded once from a frozen body copy (see game/enemies/CLAUDE.md).

The player owns its health; the lives (`MAX_LIVES` 3) are the party's single
pool on game.gd. **Four ways the
world reaches it, and the splits are the thing to get right**: a *blow*
(`take_damage()`) is metered by the grace window and opens one - that window is
per-difficulty and is secretly the CROWD dial; a *drain* (`drain()`) knows its
own rate and sits outside the window in both directions - never blocked by one,
never opens one; a *status* (`apply_slow()`) is something the player carries
that expires on its own, refreshing rather than compounding; and a *shove*
(`shove()`) is the fourth, shaped like a status rather than like a blow - the
hub's machines take your POSITION rather than your health, and the push is
carried, decays on its own, and refreshes rather than stacking. It is
deliberately never added to `velocity`, which is carried between frames and
would compound it into a launch. Everything reaches
the player by the `player` group + `has_method`, never by type. A blow that
lands also throws its amount up off the head (`game/player/damage_number.gd`,
red, gone in 0.8 s); a drain does too, but its ticks add up on one number
while it is fresh rather than stacking a "-1" each.
Full rationale, the HUD, the combo and the heavy: game/player/CLAUDE.md.

**The heavy is a HOLD and nothing else.** `CHARGE_SECONDS` (0.75) counts from
the PRESS, so the opening swing is inside the charge, and the heavy fires
ITSELF at the end - there is no release to time. The cue is a ring at the feet
that tightens as the charge fills (`game/player/charge_ring.gd`). The number is
bounded by a RATIO and not by taste: the heavy's single-target rate must stay
under the light combo's, which at 0.75 is 21.9/s against 28/s.

**The dodge is a ROLL, on K - and on Ctrl, but never in a browser**, where
Ctrl+W closes the tab (input_source.gd drops it from a web build). 48 px in
0.32 s the way the stick points, backwards with it at rest; a blow MISSES the
body from 0.04 to 0.26 s in, while a drain, a slow and a shove still land; 0.45 s
to cool down after it ends; it cuts a light attack or a charge short but never
the heavy, and a swing pressed mid-roll goes off as it ends. Its frames are the
idle body moved about (`tools/roll_pose.gd`), built from each character's
RECOLOURED sheet at bake time, so they are in no PNG. Online a body's step says
it is rolling and the host trusts it (`WIRE` 4). Picked from the Dodge Lab
preview: game/player/CLAUDE.md's *The dodge*, tests/test_dodge.gd.

**A body that is down LIES down, and a teammate can pick it up.** It falls
(rows 27-28, `fall` and `rise`, side-on, from `tools/revive_pose.gd` on the
roll's terms) and joins the `fallen` group; holding E within 16 px of it for 4
seconds gets it up where it lay at 50 health - a green ring fills on the floor
round it, green plus signs rise off it, and each blow on the one reviving knocks
a second off. Never a life from the pool. The host counts it online (`WIRE` 5).
Picked from the Revive Lab preview: game/player/CLAUDE.md's *Picking somebody
up*, game/revive.gd.

**The combo is three hits and the third is the ARC.** Swing 5, rising slash 7,
then `attack3` - 12 to whatever the blade reaches, and lightning that jumps to
the nearest untouched enemy within 40 px and once more from there, 5 each
(`game/player/arc.gd`). 5 + 7 + 12 = 24, exactly a guard and exactly the heavy,
so the breakpoints below hold: guard 3 hits, wraith 3, warden 5, security 6.
`Roster.spark_hex()` is the one colour rule the sheet's sparks and the bolt both
read, because the game must never load a `tools/` script. The arc's sheet rows
(21-23) were seeded once by `tools/arc_pose.gd`; the PNG is the truth from then
on.

**A blow that lands FEELS like one, and not one damage number moved for it**:
the room holds still (`HIT_STOP`, asked of game.gd by a `froze` signal exactly
as a boss asks), the body flashes white and jolts, its amount goes up over it,
a body that dies breaks into its own pixels, and on top of that static charge
(which changes WHO the arc jumps to, never how much), the juggle, the
thunderclap and the supernova. Two rules hold it all up: everything that moves
a body moves only its SPRITE, which is why no placement band, leash or steering
check had to change; and a boss never reels (`_reels()`). Combat and *The hit
feel*: game/player/CLAUDE.md.

**The player makes noise on the bestiary's exact terms: by owning the files.**
An `Audio` child (`game/player/player_audio.gd` - a neighbour of
`enemy_audio.gd`, deliberately not it bubbled up) and eight cues: `swing`,
`swing2`, `charge`, `heavy`, `wildfire`, `hit`, `hurt`, `die`. One set serves
all ten characters, so `hurt` and `die` cannot commit to a gender. A swing is
air and `hit` is a blow that LANDED, once per frame rather than per enemy;
`drain()` is deliberately silent; and the charge is the one loop - the ring at
the feet, not the sound, is the ready cue. The sounds are `tools/sfx/make.py
player`; the reasons are game/player/CLAUDE.md's *The noise*.

## Enemies

`game/enemies/enemy_base.gd` runs every type: stand guard, close to
`stop_distance`, and hurt by FINISHING an attack (CHASE -> WINDUP -> STRIKE ->
RECOVER), never by mere contact. Damage interrupts a wind-up, bounded by
`commit_fraction` and `interrupt_cooldown`; the player is deliberately not
interruptible in return. game/enemies/CLAUDE.md has all of it - the cycle, the
leash, the furniture, the types, the noise, the mutters, the sheets and
placement - and game/bosses/ has the bosses: the shared rules in its CLAUDE.md,
each fight in a CLAUDE.md beside his scene. What must be known before
touching any of it:

**`sight_radius` is how an enemy NOTICES the player and nothing more, and that
is load-bearing**: every authored position is placed to keep it off the door
lane, so widening it breaks all twelve floors and two suites at once. What
happens AFTER seeing you is the leash - `patience_seconds` (2.5) keeps it
coming that long after losing sight, `leash_factor` (2.0) stops it following
further than that multiple of its sight FROM ITS POST, and then it walks back
and stands on its mark, because a room is an ARRANGEMENT. A boss opts out of
all of it (`_leashes()`); a reinforcement opts out of the POST only
(`unleash()`).

**The one other way to be noticed is the ROOM ALERT, once per visit**: the
first frame ANY player stands more than 48 px (`ALERT_RADIUS`) from where they
came in, game.gd calls `alert()` on every enemy in the room, and the leash
decides the rest. The doorway is the only safe ground; the walk between the
doors is not. A reinforcement walking in after the alert is told on arrival
(game.gd's `_on_node_added`) and keeps coming for the rest of the visit.

**There is no pathfinding, and an enemy still gets round the furniture**:
`_steer` commits to ONE side when it stops making ground, holds it until a ray
says the way is open, and after three fruitless tries a body with a POST gives
up and walks home. Putting small furniture on its own collision layer so
enemies could walk through it was tried and thrown out: an enemy walking
through a chair tells the player the room is a backdrop.

**Enemy HP (24 / 17 / 36 / 48) are exact breakpoints on the player's combo** -
"dies in exactly N hits" - and `HEAVY_POWER` equals a guard's health by design.
Never retune one side without the other, and difficulty must never scale any of
them. A reskin (`office_boy`, `social_media`, `call_center`) is a new sheet,
name and folder with the archetype's numbers and no script - nothing else, or
the interrupt tuning breaks. Each archetype's script lives at `game/enemies/`
beside `enemy_base.gd` (`wraith_base.gd`, `warden_base.gd`, `brute_base.gd`),
and a type's own folder holds only its sheet, frames and scene. The fourth
archetype, `security` (48 HP - two full combos and exactly two heavies - and a
ring around its feet that SHOVES), has no reskin yet and is the first enemy on
a 64 px cell. The reskins hold floors 1-9 and 12; the originals appear only
from hellfire up. Enemies are levelled UNDER the bosses, and that is
arithmetic: a boss floor holds one boss, hellfire holds seven bodies.

**Which enemies a room gets is per-biome data (type + position), and every
sight radius stays clear of the WALK**, the spawns and both stands - the way
between the doors stays safe in every biome, and the chain and combat
tests depend on it. On a floor that says nothing about its shape the walk is
the band x 246-300 at every y, and clearing its EDGE by the type's own radius
gives a hard band per archetype: a guard (80) needs x <= 166 or x >= 380, a
brute (90) x <= 156 or x >= 390, a wraith (120) x <= 126 or x >= 420, a warden
(130) x <= 116 or x >= 430. Four floors carry their own walk, so ASK the room
(`level.lane_clearance(at)`, `level.walk_lane()`) rather than writing 246 down
again. `tests/test_slam.gd` and `tests/test_dogleg.gd` sweep the whole chain
off disk for it. A boss floor is an arena: his sight reaching the spawn is the
one deliberate exception.

**Bosses** (`game/bosses/`) run the same cycle with several attacks and concede
instead of dying - never freed, so a boss never counts as a kill. A floor names
its boss under `boss` in its biome, which shuts that floor's north door until he
concedes (`game/levels/boss_door.gd`; the last floor has no north door to
shut). game.gd finds him by the `bosses` group and gives him a HUD bar, a
camera shake if he emits `shook`, and his theme if his scene root names a
`music` - so a new boss needs no HUD, camera or music work.

- **His health is the one enemy health that scales, and only with HEADS, only
  by adding**: solo Ahmed 144, Big Mo 216, Silverman 288, and every head beyond
  the first adds his `health_per_head` (a third of him), so he still dies on a
  whole combo. Everything keyed to how hurt he is is a FRACTION of
  `max_health`; an absolute threshold would fire on a party's boss at the start
  of the fight.
- **He draws his effects live from his poses**, and four lessons carry to the
  next boss: a full-screen effect draws at TWO scales (a piece of the FRAME is a
  fraction of the viewport, a thing in the ROOM is world pixels); an effect
  timed in seconds agrees with an animation only while every beat is a frame
  boundary; fire is shared in shape and the RAMP says whose it is; and the
  base's amber wind-up tint is wrong for a palette with no hue in it, which is
  why Silverman overrides `_windup_tint()`. The first three were learned on Big
  Mo (game/bosses/big_mo/CLAUDE.md's *The Bell*, *The Rage* and *brush.gd*),
  the last on Silverman.
- **The three fights are three SHAPES on the one cycle**: Ahmed a menu, Big Mo
  a rhythm, Silverman a ladder. All three talk and are voiced, and Silverman
  says every line twice, Swedish then English, in ONE clip - so anything added
  to his file has to be short in both languages
  (game/bosses/silverman/CLAUDE.md's *He says everything twice*).

**Sound and speech are OWNED, never wired.** An enemy or a boss makes noise by
carrying an `Audio` child (`game/enemies/enemy_audio.gd`) holding id -> stream,
so a cue arrives by having the WAV, and a missing or unimported one is silence
with no branch anywhere. Sound is per enemy, never per archetype. **A `.wav`
needs an import pass, and an import pass needs the editor CLOSED.** Two enemies
and every boss also carry a `Lines` child (`game/enemies/enemy_lines.gd`): a
boss is addressing you and goes on the subtitle, an enemy is being overheard
and never does.

**Every floor but the lobby has at least one later beat** - `reinforcements` in
its biome, a finite authored list of groups, each walking in through a named
door at a known cue. A beat fires ONCE and a cleared room stays clear: **a room
is an ARRANGEMENT, not a population**, so there are no respawns. A beat's
`enemies` never scales and `per_head` is added once per head beyond the first
(`call_center` is in no floor's `per_head` - two slows refresh rather than
stack); a boss floor's cue is `at_boss_fraction`, never `after_kills`; and a
beat is the only legal way to put a body on the door line. The third beat
(`relief`, Ivan) and the fourth (`briefing`, Dominique) are the NPCs'.
game/levels/CLAUDE.md has the rest.

## Names on screen are not the ids

Two characters were renamed for the player and kept their ids: `ivan` is
**Ivo** and `dominique` is **Domimi**. Folders, scenes, scripts, roster ids,
biome keys, clip names (`ivan/sfx/voice/call_eat.wav`) and these docs still
use the old names; what the player reads or hears - dialogue `name` fields,
the NPC name labels and every spoken line - uses the new ones. A line written
for either says the new name.

The third went all the way: the boss who was `mostafa` is `big_mo` in every
folder, file, id and doc as well as on screen. His bar still needs his own
`title()` override, because the base derives a title from the scene's file
name and `big_mo.tscn` would announce BIG_MO. Two voice recipes still spell
"mostafa" in `SPELLINGS`, and that is not a leftover: it maps how the
transcriber spells a spoken word, and is not a path.

## NPCs

Three friendly faces - **Dominique** (guide, front desk), **Ivan** (healer,
cafeteria) and **HR** (unplaced), who is deliberately the only one without a
first name. An NPC is in the `npcs` group and in NEITHER `player` nor
`enemies`, which is the whole of what makes it friendly: nothing in this game
reaches anything by type, so an NPC is invisible to both sides by construction
rather than by a flag anyone has to remember to set. It is still a solid body,
so the furniture rule applies to a person too - never stand one on the line an
enemy walks from its post to the middle of the room.

**All of them are twice the player's height in a robe no wider than the
player**, and that one brief is why NPCs have an art pipeline instead of a row
in the cast's roster. Doubling a 14px cast body does not fit a 32px cell, so NPC sheets are
cut at **64px**, the size the bosses already slice at. The feet keep their
clearance from the bottom of the cell, so a 64px NPC stands on the same ground
line as a 32px enemy, and the only thing that knows the cell grew is the
scene's sprite offset (`-24` against an enemy's `-8`).

HR's white dress is the one garment in the game that can lose its silhouette
to the floor - the lobby is blue-grey marble, the marble hall tops out at pure
white - so her 1px outline does the work the other two get from a saturated
robe. Worth a look at the floor before she is placed on one.

Each NPC owns its sheet on the enemies' exact terms - seeded once from
`game/npcs/roster.gd`'s recipe by way of `tools/npc_art.gd`, sliced from disk
forever after - so the doubled head's 2px outline, which is a known and
accepted debt, gets fixed by redrawing the head into that PNG rather than by
changing any code. `npc_base.gd`'s speed is 45, half the player's 90, written
as a plain number like every enemy's. All three stand still; `walk_to()` is
there for the day one doesn't. Dialogue and the thrown hearts are still to build.

**All three can talk, and none of them knows how.** An NPC carries a
`conversation` - a path to a .gd holding `const BEATS` - notices the player is
in range, puts a prompt over its head and emits `talk_requested`. game.gd wires
that to the director in game.tscn exactly as it wires a door's `travelled`, so
an NPC never learns that a subtitle box exists. HR stands in the lobby and her
induction is the first one built: a tour she walks and tows the player through,
ending in a contract that cannot be refused.

**All three are VOICED**, out of the same `tools/voice/` the bosses' barks come
from, and nothing was rewritten to allow it: a beat always carried its clip
path. What a clip buys is the typing rate - the line's length over the clip's -
so a beat with no clip, or one not yet imported, is silent and types at the
flat rate. Who sounds like what: game/npcs/CLAUDE.md's *Their voices*.

**Ivan heals, and he is the only healing in the game from floor 2 up.** He is
the third beat (`relief`): once the room is finally clear he walks in by the
door the player came by, crosses to an authored spot, and at the end of his
lines throws **one heart per head** (`game/heads.gd`), once per visit. Six
floors have him, and each names its own conversation
(`game/npcs/ivan/after_<floor>.gd`), because one shared set read as a vending
machine with a voice. Every one ends on "Eat.", the word his gift lands on.

**Dominique is the FOURTH beat** (`briefing`), and the only one that hands over
information: on the three floors under a boss he comes down the NORTH door once
the room is clear and says what is standing upstairs, one file per boss
(`game/npcs/dominique/before_<boss>.gd`). `tests/test_dominique.gd` reads the
chain off disk and fails if a boss ever ships without one.

The rest - the pipeline's three steps, why the robe goes down before the head,
and what a third NPC would need: game/npcs/CLAUDE.md; the two beats themselves:
game/levels/CLAUDE.md's *Relief* and *Briefing*.

## Generated resources - regenerate, don't hand-edit

Almost everything in the repo that is not a script was written by a generator
in `tools/` and is overwritten by its next run, so change the generator or its
data, never the output. The full table - every output, what writes it, and what
each one owns - is tools/CLAUDE.md's *What every generator writes*. In short:

- **Data, edited by hand**: the cast (`game/player/characters/roster.gd`), the
  bestiary (`game/enemies/roster.gd`), the NPCs (`game/npcs/roster.gd`), the
  chain order (`tools/biomes.gd`) and each floor's palette, furniture and
  enemies (`tools/biomes/<level>.gd`).
- **Frames**: every `*_frames.tres` under `game/player/characters/`,
  `game/enemies/`, `game/npcs/` and `game/bosses/`, from `build_characters.gd`,
  `build_enemies.gd`, `build_npcs.gd` and `build_bosses.gd`. Each SLICES the
  sheet on disk; a sheet under a `src/` folder is seeded ONCE when missing and
  is hand-owned art after that, never overwritten. The one exception is the
  cast's roll (rows 24-26), built from each recoloured sheet on every run and
  never on disk.
- **Rooms**: `game/levels/*/tileset.tres` and the doorways from
  `build_biomes.gd`; level scenes, doors and every prop scene from
  `build_levels.gd` (below), each prop painted by
  `tools/props/<shelf>/<type>.gd`.
- **The rest**: `ui/theme/menu_theme.tres` (`build_ui_theme.gd`), `icon.svg`
  and `splash.png` (`build_icon.gd`, from the default character's idle frame),
  project settings and the input map (`setup_project.gd`), and
  `tools/stable_ids.gd`, which keeps a re-run with unchanged data
  byte-identical.
- **Sound**: `ui/sfx/` from `tools/sfx/ui.py`, free and deterministic. The
  enemies' and the player's SFX (`tools/sfx/make.py`) and every voice clip
  (`tools/voice/cut.py`) COST money and are not deterministic: `--relevel`
  re-shapes from the untouched exports in `src/` for free, and approved takes
  are pinned in a recipe's `KEEP`.

Run: `<godot> --headless --path . --script res://tools/<script>.gd` - or, from
inside the editor, **Project > Tools > za-build**, which is the same commands
behind menu items (`addons/za_build/`, see Workflow).

Biome art is palette-swapped from `assets/tiles/dungeon.png`. Only a handful of
tiles in that sheet are modular - the rest are pre-composed room motifs that do
not repeat - so build_biomes.gd copies the verified-seamless ones by coordinate
and draws columns and doorways itself. Its textures are embedded in the `.tres`
as `PortableCompressedTexture2D` rather than written out as PNGs, so a
regenerated biome works headless immediately with no `--import` pass.

`tools/build_enemies.gd` is a partial exception: the `_frames.tres` it writes
are regenerate-freely, but `game/enemies/<id>/src/<id>.png` is hand-owned art it
only ever creates when missing. It will not overwrite a sheet you have drawn
into.

`tools/build_levels.gd` is the exception to "regenerate": what it writes - the
level scene and that level's own door, plus - where its biome asks for them -
its column, hazard and heart scenes - is a starting point meant to be dressed by
hand in the editor, and re-running it overwrites that work. Run it to reset a
level or to add a new one, and pass level names after `--` to build only those,
because a chain of twelve means adding a floor must not re-roll the eleven already
dressed:

```
<godot> --headless --path . --script res://tools/build_levels.gd -- lobby
```

The door trigger's hand-tuned y=13, snug against the seal, is now what the
generator writes, so regenerating a door no longer silently undoes it.

Anything a level is dressed with that CAN be expressed as data should be, for
the same reason: enemies and furniture both live in tools/biomes.gd, so
re-running the generator rebuilds a dressed room instead of resetting it. The
warning above is about what is left - tiles moved by hand, a prop nudged in the
inspector - and every position that moves out of the editor and into biomes.gd
is one less thing a regeneration can cost you.

## Difficulty

Three modes - EASY / MEDIUM / HARD - picked in two places that are one saved
choice: the DIFFICULTY row of Settings, and the button on the lobby's host
screen, which steps round the same mode (`Difficulty.cycle()`). The row is
HIDDEN, not greyed out, when Settings is opened from the pause menu (the pause
menu's panel has `offers_difficulty` off), because it is read once per run.
The choice persists through Settings (section `game`, key `difficulty`),
default MEDIUM, applied-but-never-saved like every default. **Online the
host's mode is the party's**: only the host's world reaches anybody
(player.gd's `_world_reaches()`), so a guest's own mode never lands.

`autoload/difficulty.gd` (`Difficulty`) owns the modes and their numbers.
**Difficulty scales what the world deals, never enemy health**: the HP numbers
(24 / 17 / 36) are exact breakpoints on the player's combo - three hits, three,
five, heavy one-shot - and a multiplier would shred them on two of three modes.
So a guard dies identically on every mode; the modes change what being slow
costs you. Two dials per mode:

- `damage_scale` (0.6 / 1.0 / 1.5) multiplies every blow and drain - guard
  strikes, torches, wraith drain.
- `grace_seconds` (0.8 / 0.5 / 0.4) is the player's grace window, i.e. the
  crowd dial - see game/player/CLAUDE.md's Health.

Consumers read their numbers ONCE, where they spawn, never live - the mode is
only choosable before a run, a new run builds a fresh player and fresh rooms,
so there is no mid-fight rescaling and deliberately no `changed` signal.
MEDIUM is the tuned baseline; every number in enemy scenes and in these docs is
a MEDIUM number.

## Music

`autoload/music.gd` (`Music`) plays the tracks, and it is an autoload because
the front end is three scenes and a track must carry across all of them. Three
things to know before touching it or adding a track:

- **`play()` and `fade_to()` are idempotent on the PATH Music holds, never on
  `AudioStreamPlayer.playing`**, which is false under the dummy driver every
  headless run uses. That one rule is why a door between two ordinary floors
  does not restart the bed.
- **Every floor plays something, and a boss is the only thing that interrupts
  it**: `Music.DEFAULT` is the bed, a boss's theme comes up with his bar and
  goes with it, and three floors name their own track with a `music` key in
  their biome - the lobby, and the finale on the last two floors.
  `tests/test_music.gd` reads that rule off disk.
- **A generated track does not loop, and is not levelled, until it has been
  made to**: a click at the seam, an export that fades or dries up at its end,
  and a theme that buries the boss talking over it. Every track and voice clip
  also imports at 24 kHz, which a NEW clip does not get by default.

How Music works: autoload/CLAUDE.md's *Music*. **Read assets/music/CLAUDE.md
before adding or replacing any track.**

## Menu sound

`autoload/ui_sound.gd` (`UiSound`) is the menu's own noise - `move`, `press`,
`back` - and nothing wires itself to it: it hooks focus changes on the root
viewport and every `BaseButton` entering the tree, which works only because
nothing outside the four menu screens ever takes focus. Keep it that way. The
one cue that is NOT automatic is `back`, which a screen says itself where it
acts on Escape. The files are `ui/sfx/`, made by `tools/sfx/ui.py`. Why each of
those holds: autoload/CLAUDE.md's *Menu sound*.

## Online

`autoload/net.gd` (`Net`) is online co-op's one door to the network
(DESIGN.md's Multiplayer): host a room, join one by its code or from the list
of games, leave, and keep the party's ROSTER until the host starts the run. It
is the ONE place the transport is chosen - WebRTC through our signaling service
online, ENet on a port for `host_local()` / `join_local()` (what the suites run
on), OfflineMultiplayerPeer offline. The rules that hold all of it up:

- **The host is the truth** - for the roster, and in a run for everything but
  where a body is. A body is its OWNER's, and **the world reaches nobody on a
  guest** (player.gd's `_world_reaches()`), which is what lets a guest run a
  room's effects for the look of them without any landing twice.
- **Joined in the lobby, never mid-run**, and a build on another `WIRE` is
  refused: two builds that do not speak the same game never meet.
- **Net changes no scene and spawns nothing**, and never reaches for the root
  MultiplayerAPI by name - which is what lets two of it live in one process
  (tests/test_net.gd).
- **No suite ever asks the real service for anything**: tests/helpers.gd holds
  `za/test/no_room_list` on, and a suite that wants a list hands it to
  `rooms_listed` itself.

Where the rest lives: Net itself, the list of games and which signaling service
a build talks to - autoload/CLAUDE.md's *Net*; the screens (HOST ONLINE, JOIN
ONLINE, the list, the room and its four seats) - ui/lobby/CLAUDE.md; keeping a
run in step (M3: snapshots, moments, who talks), making it feel like one
game (M4: one clock, the held picture, every blow seen) and putting the
connection on screen (M5: the corner ping, the Tab scoreboard, the relay line,
somebody leaving and the host-left panel) and holding at the cracks (M6: two
people at one NPC, and a guest whose line goes dead - AWAY, out of the fight
and costing nothing, a second into the silence, and dropped once Net gives the
line up) - game/sync/CLAUDE.md.

## Settings

Three autoloads, split by responsibility - `Music` above is a fourth,
`UiSound` a fifth and `Net` (Online, below) a sixth, and they are here rather
than there because they own no setting:

- `autoload/settings.gd` (`Settings`) owns `user://settings.cfg` and nothing
  else - sections, keys, write-through on change. A future audio or controls
  page adds a section without this script learning about it.
- `autoload/display.gd` (`Display`) applies window mode and windowed size, and
  persists through Settings. Every window change goes through it, F11 included,
  so a hotkey press is remembered exactly like a menu choice.
- `autoload/difficulty.gd` (`Difficulty`) owns the game modes - see Difficulty.

`Settings` must stay registered **before** `Display` and `Difficulty` - both
read their saved values during `_ready`. `Music`, `Net` and `UiSound` are
appended after all three; neither reads anything saved today, and a future volume row is
one more reader of Settings, not a new rule. `UiSound` goes last of all, and
the only thing its position has to satisfy is that it is ready before the first
SCENE is built - it hooks `node_added`, so a button that entered the tree ahead
of it would be the one button in the game with no sound. tools/setup_project.gd clears their entries
before re-adding them, which is what enforces that order.

**A default is applied but never saved.** Nothing is written until the player
actually picks something, so an untouched install keeps launching the way
project.godot says - and no headless run can quietly change that.

`ui/settings/settings_panel.tscn` is one overlay instanced by both the main menu
and the pause menu, rather than a screen of its own: the pause menu cannot leave
the scene, since the paused game is still sitting behind it. It runs
`PROCESS_MODE_ALWAYS` for the same reason. Escape backs out one step - both
menus skip their own Escape handling while the panel is open, and the panel
marks the event handled so the press cannot also unpause.

The page has three window rows and DIFFICULTY (see Difficulty - hidden when the
pause menu opens the panel), and the split between the last two window rows is
the thing to get right - it is the one players get wrong:

- **WINDOW MODE** - windowed or fullscreen. The game launches windowed at
  1920x1080, which is an exact 3x of the base viewport.
- **WINDOW SIZE** - deliberately not called a resolution. The game always
  renders at the 640x360 base viewport, so the window only decides how many
  screen pixels one game pixel becomes. Choices are whole multiples of the base
  (`Display.SCALES`), each labelled with its factor; at a fractional scale like
  2.5x some pixels land on three screen pixels and their neighbours on two, and
  the image crawls as the camera moves. Greys out in fullscreen rather than
  pretending to have an effect, while still remembering the choice.
- **ZOOM** - the one that changes *how much of the level is on screen*
  (`Display.ZOOMS`). At 1 a whole room fits and the camera sits still; above
  that the camera follows the player. Shown as a **percentage** - 100% / 125% /
  150% / 200% / 300% / 400% - which is the convention where a game exposes zoom
  at all, and the only labelling that stays true. The default is 150%. Names for the result were
  tried and dropped: "WHOLE ROOM" describes the zoom against the size of the
  room the player is standing in, so it becomes a lie the first time a level is
  bigger than the screen, and word ladders like ALMOST WHOLE / MOST OF ROOM do
  not tell a player which way is further. Percent describes the one thing the
  setting controls. The labels are derived from `ZOOMS` by
  `settings_panel._zoom_label()`, so adding a level is one edit.

  1.25 and 1.5 are the deliberate exception to whole numbers, since 1 to 2 is
  otherwise a jump straight from the whole room to a quarter of it. A fractional
  zoom does draw neighbouring source pixels at different sizes; both are
  quarters, so a 16px tile still lands on a whole 20 or 24px and the tile grid
  itself stays even. `Display.zoom()` returns a float and casts on read - a
  settings.cfg written before these existed holds a plain int.

Zoom is stored with the window settings but applied by game.gd, which is what
owns a camera; it re-applies on `Display.changed` and repositions immediately
rather than waiting for `_process`, because the tree is paused while the panel
is open. Two footer lines on the panel state the split outright.

The panel must fit the 640x360 design viewport - it is at 343px with four rows,
and test_menu.gd measures it so a fifth cannot quietly overflow. Four rows only
fit because a dropdown is 28px rather than a button's 34: the theme gives
OptionButton its own boxes, three pixels shorter top and bottom
(tools/build_ui_theme.gd), and a `custom_minimum_size` cannot do that, since
the boxes' margins outvote it.

## Workflow

- **Commit and push to `develop`; `main` takes a finished feature by merging
  `develop` into it.** A release is the `VERSION` file changing on `main` and
  nothing else - `.github/workflows/release.yml` then builds the Windows
  installer + portable zip and the macOS .dmg on GitHub's machines, tags
  `v<VERSION>` and publishes a GitHub Release carrying them. So never bump
  `VERSION` as a side effect of other work; it is the user's call. A push to
  `develop` touching the presets, the workflow or `tools/release/` is a dry
  run of all of it. **A deploy to dev** is that run started by hand on
  `develop` with its box ticked, and never automatic: the same gated builds,
  then the rolling `dev` pre-release (files always named `dev`, never
  "latest", so no player or update check is offered it), dev's own
  signaling rebuilt from `develop`'s `server/`, and
  https://dev.za-company.mayar-deeb.dev. Its builds carry the custom feature
  `dev` (stamped by tools/release/prepare.sh, never committed), which is how a
  dev desktop build knows to talk to dev's signaling. It never moves the live
  site, its signaling, Caddy, coturn or `VERSION`. The whole flow:
  `RELEASING.md`.
- **The Windows and macOS presets carry the custom feature `packaged`**, and
  two things hang off it: the game is called "The New Hire" there
  (`config/name.packaged`, from setup_project.gd) and the main menu asks
  GitHub for a newer release. **The name is also what names `user://`** - an
  exported game keeps its settings in `app_userdata/The New Hire`, while the
  editor and every suite use the bare `za-company`, which is why that one
  stays. Every preset lists `VERSION` in `include_filter`, which is how the
  menu's footer reads the real number; and the desktop presets exclude
  `addons/za_build/*` rather than the Web preset's `addons/*`, which would
  ship a game that cannot play online. `tests/test_release.gd` reads all of
  that off disk.
- **A deploy to dev builds a DIFFERENT app, "The New Hire (dev)"**, so a
  tester can have both and a dev build never overwrites the game, its
  settings or one day its saves. `tools/release/prepare.sh` adds the `dev`
  feature, renames every field holding the game's exact name and suffixes the
  macOS bundle id `.dev` - refusing the build if any of them has moved - and
  `installer.iss` takes `/DDev` for a second `AppId`. A dev build never asks
  GitHub for a release. It REPLACES the packaged name rather than adding a
  `config/name.dev` override, because a build carrying both features matches
  both and Godot takes whichever line comes first (measured, docs/
  environments.md #4). The plan for the rest of dev and production is
  `docs/dev_prod_plan.md`.
- **The in-game updater is built and switched OFF.** `ui/update/` downloads
  the release file for this OS, checks it against the release's
  `SHA256SUMS.txt` and installs it (Windows: the silent installer, which
  relaunches the game; macOS: still a stub). It stays behind `ENABLED` in
  `ui/update/updater.gd` until both platforms pass todo.md's real-machine test
  (Part D): "both platforms or neither" is the owner's rule, so while it is
  off every copy gets the browser link. A run started with
  `-- --update-feed=<release API URL>` reads that release instead of the
  latest and switches the updater on for that run - the only way to try it
  now. **The release file names are a contract**: each platform script's
  `ASSET_SUFFIX` must match what release.yml and installer.iss write, and
  `tests/test_updater.gd` reads both off disk. The plan, and who builds what,
  is `todo.md`.
- Godot binary (not on PATH):
  `~/OneDrive/Desktop/Godot_v4.7.2-stable_win64_console.exe`
- Quick check: `--headless --path . --quit-after 3`
- Full import pass: `--headless --import --path .` - ONLY while the editor
  is closed; two editor instances on one project corrupt each other's state.
- The Godot editor is usually open while Claude edits files as text.
  After renames/moves: Project > Reload Current Project. For migrations:
  close the editor first.
- **Project > Tools > za-build** runs the generators without a terminal.
  `addons/za_build/` is the project's one plugin, and every item in it spawns
  a headless child Godot running the same `tools/` script the command line
  would - it does NOT call the generator in the editor's process. That is the
  whole design: build_levels.gd rewrites `.tscn` files the editor may have
  open, and an editor holding a stale copy writes it back over the fresh one,
  which is how a deleted `health_item.tscn` keeps coming back. A child has its
  own resource cache and cannot do it; `scan()` afterwards is what makes the
  editor see the new files. **Close any level scene you have open before
  rebuilding it** - the plugin warns, but it cannot close a tab for you, and
  saving that tab is the failure it is warning about. "Rebuild levels..."
  opens a picker over `CHAIN` with **include neighbours** on by default,
  because a door's `target_level` is baked into the level scene.
- **Level select screen (dev)**, the last item on that menu, is a switch
  rather than a command: while it is ticked, picking a character opens
  `ui/level_select/` - every floor, found by walking the door targets from
  `START_LEVEL` - and the run starts on the one picked, once
  (`game.gd`'s `next_start`, spent on use). It is `za/dev/level_select` in
  project.godot, off by default (switching it off removes the line), never
  shown by a release export, and held off by `tests/helpers.gd` so a developer
  who left it on does not land every suite on a floor picker.
- **The game is playable in a browser** at https://za-company.mayar-deeb.dev:
  the "Web" preset in `export_presets.cfg`, served by the server's Caddy.
  A RELEASE puts it there and nothing else does: release.yml builds it beside
  Windows and macOS, tests the server, publishes, then its `deploy` job sends
  `server/` and the web build to `server/deploy.sh` with a key that can run
  that script and nothing else (RELEASING.md's *Deploying*), so the site is
  always the latest release. **Every deploy is rehearsed first**:
  `tools/release/rehearse_deploy.sh`, in the `server` job, plays the previous
  release's `deploy.sh` upgrading a throwaway runner to this commit at the
  server's real paths, then this commit's script again, checked through
  Caddy - and refuses to run anywhere but CI, because on a real box it would
  replace `/opt/za-company`. The server's checks live ONCE, in
  `.github/actions/server_checks/`: release.yml's `server` job runs them to
  gate a release or deploy to dev, and `.github/workflows/server.yml` runs
  them on every push touching `server/` (no game builds), because the dry
  run's push paths leave `server/` out. `deploy.sh server` is only a HAND-OFF to the
  copy it installs (`apply`), because a release is deployed by the PREVIOUS
  release's script (server/README.md, *How a release updates this script*). Never export
  headless from the project while the editor is open: `--export-release` is a
  second editor writing `.godot/`, so export from a copy. The build is
  single-threaded (no SharedArrayBuffer, so no special headers) and the
  WebRTC GDExtension excludes itself (`exclude_tags = ["web"]`), since a
  browser has WebRTC built in. QUIT is hidden on the main and pause menus
  there (`OS.has_feature("web")`), because quitting a tab freezes it on its
  last frame rather than closing it.
- **The web build boots `ui/web_entry/`, not the main menu**
  (`run/main_scene.web` in project.godot, an override desktop never reads),
  because a page has no command line and the ADDRESS is the only argument it
  gets: `#join=CODE` - the link a host's lobby hands out - opens the lobby
  (`ui/lobby/`), which joins that room on arrival, and everything else goes
  on to the main menu one frame later. It is how a phone joins, since a phone
  cannot type into the web build. M0's test screen, `ui/net_spike/`, used to
  answer `#nettest` here and is gone: the lobby replaced it in M2. Changing
  the game's first scene means changing it in BOTH places.
- **The loading screen is the icon.** The boot splash is `splash.png`,
  written by build_icon.gd beside `icon.svg` from the same picture at 4x,
  because a boot splash takes only a PNG and says so at startup
  (tools/setup_project.gd: real size, unfiltered, on the menu's `BG_DEEP`).
  On the web Godot's stock page shows it while the game downloads, and that
  page is styled rather than replaced: `html/head_include` in the preset is
  CSS that draws the bar in the menu theme's colours, which keeps Godot's own
  shell - and its updates - rather than a copy of it. A new icon is one run
  of build_icon.gd; the favicon follows `icon.svg` by itself.
- **Under the bar is the DOWNLOAD, not the bar's own number**: `8.0 / 22.9 MB`
  and the line's speed in MB/s, then `STARTING` while the engine boots, in
  the menu's Kenney Mini Square (embedded in the preset as base64, since the
  page cannot read the pack). Godot's bar counts UNPACKED bytes - fetch hands
  a gzipped body over already inflated - so it says 53.7 MB, and a speed taken
  from it reads 2.3x the line. The readout is a script in the same
  `head_include` that wraps `fetch` for the two files in `fileSizes`, counts
  each off a clone of its response, scales by that file's `Content-Length`
  (the gzipped size) against its unpacked size, and gives the game the
  browser's own `fetch` back once the page is gone. Served without the .gz
  files it says 53.7 MB, which is then the truth. Picked as option A from a
  preview and shipped verbatim: pixel-identical to it in the same simulated
  download.
- All third-party assets are CC0; sources and licenses live in CREDITS.md -
  update it whenever an asset is added.

## Testing

- `tests/` holds SceneTree-script tests: no framework, no dependencies. They
  drive the real game with synthesized input and exit 0/1, each suite
  extending `tests/helpers.gd` (checks, key synthesis, settings backup, node
  getters) and overriding `_tick(frame)`. **What every suite owns, and the
  gotchas of writing a check** - synthesized keys, looping sounds, `user://`,
  `current_scene`, `OptionButton` - are `tests/CLAUDE.md`: read it before
  adding a check or a suite.
- Run all after any change to scenes, input, or scene flow:
  `<godot> --headless --path . --script res://tests/run_all.gd`
  (or one suite with `--fixed-fps 60 --script res://tests/test_<area>.gd`).
- **One suite = one Godot process = one clean world.** That is the design, not
  a convenience: when everything was one smoke test, each section had to leave
  the game exactly as the next expected, and the failures that produced were in
  the test - a combo's lunge drifting the player out of a later section's
  geometry, an enemy spawned into a still-resolving swing. Keep new checks in
  the suite whose world they need; start a new suite rather than making one
  file's sections depend on each other.
- Autoloads are NOT identifiers in the script passed to `--script` - that file
  is compiled before the autoload list reaches the compiler. Reach them with
  `root.get_node("/root/Settings")` and `call()`. Ordinary game scripts, loaded
  later as part of a scene, use the names normally.
- `tests/` and `tools/` are excluded from every export preset, and so is every
  `.wav` under a `src/` folder - the untouched exports, 125 MB that nothing in
  the game loads. Of `addons/`, `za_build` is always excluded (it preloads
  `tools/`, so shipping one without the other breaks the build) and
  `webrtc_native` must ship on desktop or online play is gone: the Windows and
  macOS presets exclude `addons/za_build/*`, while the Web preset may drop all
  of `addons/*`, because a browser build gets WebRTC from the browser and
  that GDExtension declares no web library anyway. A new DESKTOP preset copies
  the Windows one's `exclude_filter`, never the Web one's.
