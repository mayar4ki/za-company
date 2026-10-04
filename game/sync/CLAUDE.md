# Sync - one run on several machines

The party is put together by `Net` (autoload/CLAUDE.md's *Net*) and the lobby
(ui/lobby/CLAUDE.md); this is what keeps it one game once the host presses
START. The plan it builds is DESIGN.md's *Multiplayer*.

**In the run, `game/sync/` keeps the machines in step (M3)**, built by game.gd
as `Sync` on every machine so both ends sit at one path, and inert offline.
The host is the truth for everything but where a body is:

- **A body is its owner's**: a member whose `peer` is not this machine's is
  REMOTE (player.gd's `remote`) - it runs none of the player, and stands where
  its owner says, thirty times a second (`net_state()` / `apply_net_state()`,
  `game/sync/bodies.gd`), relayed by the host. Its PICTURE is drawn a beat
  behind that (below).
- **The world reaches nobody on a guest** - player.gd's `_world_reaches()`,
  which makes `take_damage`, `drain`, `apply_slow`, `shove` and `heal` no-ops
  anywhere but the host. It is the one rule that lets a guest run a room's
  effects for the look of them without any landing twice. On the host a blow
  on a remote body is decided there and its health sent to everybody; a slow
  or a shove is sent to the owner, who carries it (`reached` ->
  `net_reached()`).
- **The run is the host's**: deaths, the pool, getting up, the doors (a
  guest's count but never go) and the end of the run, told to the guests and
  run there by game.gd's `net_*` functions. Every arrival is a ROOM the host
  counts, carried on everything only true in one, so a step from the last
  floor is never drawn on the next.
- **When to speak**: two machines load at their own speed, so a guest's game
  tells the host it is up through `Net.arrived()` - Net being the one node both
  ends always have - and the host opens with a welcome holding the floor, the
  room, the pool, every body's health and who is down.
- **Nothing pauses online**: the pause menu and the death screen open over a
  running game, and game.gd hands this machine's player still hands while one
  is up. The true hit-stop (`Engine.time_scale`) is solo-only: online the stop
  holds the PICTURE instead (below).
- **A guest leaving takes their body with them** (`net_left`), and their row.
- **The room is ONE snapshot** (`game/sync/world.gd`): twenty times a second,
  compressed, every `synced` thing in it by its path - an enemy, a boss - and
  what it looks like. A guest draws each one where the host says
  (game/enemies/CLAUDE.md's *Online*), and the same message is the only word
  on what EXISTS: an entry the guest lacks was spawned on the host and carries
  its scene, so the guest makes one at that path; a thing the guest has and
  the snapshot lacks is gone, and goes. No spawn or despawn message to lose,
  arrive out of order or be missed by a guest still fading in. A guest's
  swing is reported by the attacker (a player's moment, below) and dealt on
  the host; a beat (`reinforcements.gd`) is the host's alone.
- **A room's own moving parts ride the same snapshot** (game/levels/CLAUDE.md's
  *Online*): a CLOCK - the studio, the dolly, the wiring - runs everywhere and
  is put right only when it drifts, DICE - the scrubbers - are the host's and
  drawn, and the host alone walks Ivan and Dominique in, throws the hearts and
  spends a pickup.
- **A MOMENT is told, not pictured**: what a snapshot cannot carry because it
  is over by the next one - a boss's line, his every sound and shake, a fire he
  throws, Silverman's copy and his prism's fan - the host `_tell()`s, and the
  same thing on each guest hears it in `net_event()` (game/bosses/CLAUDE.md's
  *Online*). The host picks a line and tells WHICH, so every machine reads the
  same words and plays the same clip.
- **Whoever presses the key talks** (game/sync/talk.gd): their machine runs the
  conversation and leads the NPC - lent to them for its length, so HR's tour
  works with a guest at its front - it is busy for everybody else, and they
  read the lines along on the subtitle.

**And it FEELS like one game (M4)**, which is three things on top of M3:

- **One clock, the host's, a tenth of a second ago.** Every message about the
  run carries the host's time; a guest reads that clock off the fastest trip it
  has seen (`game/sync/clock.gd`), and the host turns each guest's stamps into
  its own. What is DRAWN is drawn `Sync.DELAY` (0.1 s) behind it, gliding
  between the states either side (`game/sync/timeline.gd`) instead of stepping
  twenty or thirty times a second: the room's bodies answer `net_between()`,
  everybody else's player `net_draw()`. **A remote player is in two places on
  purpose**: its BODY stands at the newest step - that is what the host decides
  blows, doors and pickups with, so a guest who stepped out of a swing is out
  of it as soon as the wire allows - and its PICTURE (the sprite's offset) is a
  beat behind. **A step that arrives moves the body and NOT the picture**
  (player.gd's `apply_net_state()` takes the offset back by what the body
  moved): steps land in the network poll, after the physics frame that drew
  the picture and before the screen, so a sprite riding on the body was put on
  screen a step ahead and pulled back next frame - the playtest's "their
  movement lags", measured at 21 frames in 72 drawn backwards, and caught now
  by test_coop_feel.gd sampling on `process_frame`, the one moment after the
  poll. What the host says ABOUT the room - a blow on you, health,
  down, up, lives, the end, every boss moment - waits for the same moment of
  the same clock (`Sync.later()`), so a number comes up as the drawn sword
  lands; only the welcome and the order to travel are acted on when heard, and
  travelling plays out everything still waiting first. **A CLOCK is not drawn
  behind**: the studio, the dolly and the wiring answer no `net_between()` and
  take their state when heard, or every correction would set a hazard late.
  Anything faster than 600 px/s between two states JUMPED and is held, not
  slid.
- **The stop holds the picture** (`game/picture_hold.gd`): online a blow that
  lands disables every `AnimatedSprite2D` and every hit-feel effect on THAT
  machine for the stop and leaves the world running, then catches each
  animation up by the time it was held - a boss's sprite is his telegraph, and
  a swing must still end itself (`animation_finished`). Asked by this
  machine's own blows and by a boss's, whose `froze` is told like his shake;
  somebody else's blow holds nothing here. And it never holds somebody ELSE'S
  player, or anything drawn on it: that picture is its owner's and goes on
  gliding through the stop, so holding its sprite slid a teammate across the
  floor on frozen legs every time this machine landed a blow.
- **Every blow is seen everywhere.** A blow and a bolt are a player's MOMENTS,
  told by whoever moves that player and passed through the host
  (`World.from_player`, player.gd's `_tell` / `net_event`): the host deals a
  guest's reported blow FIRST, then every other machine draws it with the
  attacker's body - number, flash, jolt, juggle, static charge, the pieces on a
  kill, the bolt and its crackle, the impact sound - and the attacker hears
  back only whether it killed. A blow or a drain on a player is seen on every
  machine with its grunt (`net_seen()`), and `die` plays wherever health
  reaches 0. A remote body's own moves are read off its picture: the swing's
  air, the charge's hum and ring, the heavy's supernova - never the stop, the
  shake or the flash, which are the attacker's to feel. A remote body's sounds
  are POSITIONAL (player_audio.gd), because a teammate is somewhere. And static
  charge is PER PLAYER (the owner's call): your swings set up only your own
  arc, a body two players have tagged carries one charge of each, in each
  one's colour, and an arc prefers and sets off only its thrower's.

The game's own `WIRE` is 3 from here: a build from before the run was stamped
with the host's time is refused rather than let into one.

**And the connection is ON SCREEN (M5)**, each piece picked from the Ping On
Screen preview (https://claude.ai/artifact/CHLaYkvrXqXBwJMB3jj1YA) and built
from the preview's own construction code, pixel-identical to it. Nothing new
crosses the wire: every number is the ping the host already measures once a
second and sends round with the roster, and game.gd's `_show_connection()`
puts it up only when the run is online, so a solo HUD is what it always was.

- **The corner** (option A, the number): this machine's distance to the host
  top right in the HUD's font and DESIGN.md's colours - `ui/ping.gd`, shared
  with the lobby's seats - and HOST on the host's own screen, refreshed on
  every `Net.roster_changed`.
- **The scoreboard** (option A, the table): `ui/scoreboard/`, on its own
  CanvasLayer 7 and up only while the `scoreboard` action (Tab) is held, which
  setup_project.gd adds like every other key. One row per player - the
  character's idle frame, name, character, ping and route - with this
  machine's marked YOU. Dumb, like the HUD: game.gd hands it Net's roster.
- **The relay line**: a guest whose own row says RELAY as its run starts is
  told so across the top for five seconds (the HUD's `notice()`), in the
  lobby's words. The owner's call was the line and NOT a RELAY tag on the HUD
  rows; the scoreboard's route column is where anybody else sees it.
- **Somebody leaving** (option A): the same strip says "IVO LEFT THE GAME"
  for three seconds, in the name their row called them, from `net_left()` on
  every machine still in the run.
- **The host leaving** (option B, the panel): `ui/host_left/`, a panel on
  CanvasLayer 10 saying THE HOST LEFT and whose game it was, over a frozen
  room. It wears the death screen's manners - Escape swallowed before the
  pause menu can hear it, focus on its one button - and MAIN MENU is the only
  way out. game.gd keeps the host's name from the party it was built from,
  because Net has forgotten everybody by the time it says `host_left`.

**And it holds at THE CRACKS (M6)** - the moments two machines' pictures of
one run could come apart, each made to happen on purpose in
tests/test_coop_cracks.gd. Three already held as built: a death mid-fade (the
host carries the body through and stands it up on the far side, and the
guest's `_down` and `_up` play in stamp order around its own fade), a door
fired a second time mid-fade (`_travel` is latched, so the party arrives once),
and a boss conceding to a guest whose machine hitched (the snapshot carries
`has_conceded`, and a swing that arrives after it finds him out of `enemies`).
Two did not:

- **Two people talk to one NPC at once.** A guest never waits on the host to
  begin a conversation, so two presses on one frame began two, and the NPC
  stayed lent to the guest for good. Now the HOST's word decides
  (talk.gd's *Two at once*): whoever reached it first - its own press, or a
  guest's word - and a guest who lost is told `_refused`, its conversation
  closes (game.gd's `net_refused`) and the NPC is busy on its screen. Only
  whoever leads an NPC can hand it back, so the refused guest's goodbye frees
  nothing.
- **A guest dropping mid-fight.** A crashed guest says nothing, its body stood
  frozen in the fight, the guard beat it down and the POOL paid for somebody
  who was not there - and the line itself was never given up on. Now a body
  not heard from for a second is AWAY (bodies.gd, player.gd's `away`): out of
  the `player` group exactly as a body that is down, so nothing targets it,
  nothing lands on it and no door waits for it - but it is not down, so no life
  is spent and the run is not over while only somebody away is standing
  (game.gd's `_nobody_standing()`, which asks the bodies, not the group). It
  is drawn see-through in its own colours (`AWAY_TINT`), and back the moment
  its owner is heard. Counted in this machine's physics frames, so a hitch
  here never makes anybody else away, and a new room restarts every count. And
  Net gives a dead line up (autoload/CLAUDE.md's *Net*): dropped after
  `DROP_SECONDS` of silence, exactly as if they had left. `is_down()` is a flag
  of its own now, because the group answers "in the fight", which away is
  not.

A new room also forgets the last room's steps (`Bodies.new_room()`), so a
remote picture never glides across the room from where its body stood
downstairs. And the export presets were found already carrying the plugin -
the DLL beside the exe, the framework in the .app - which release.yml now
checks inside every build (tools/release/check_plugin.sh).
