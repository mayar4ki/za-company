# Autoloads - the singletons that outlive a scene

`tools/setup_project.gd` registers them, and owns their order - see the root
CLAUDE.md's *Settings*, which also covers `Settings`, `Display` and
`Difficulty`. The three that need more room than the root can give them are
here.

## Music

`autoload/music.gd` (`Music`) is an autoload for one reason: the front end is
THREE scenes - main menu, character select, and back out of a finished run -
and `change_scene_to_file` frees the old one. A player living in main_menu.tscn
would restart the track the moment PLAY is pressed, which is the one seam a
menu loop exists to hide. Above the tree, it simply keeps playing.

`play(path)` is **idempotent on the track**, and that is the whole trick: every
front-end screen asks for the same track in its `_ready` without knowing which
screen ran before it, and only the first ask starts anything. No screen has to
know whether music is already playing. The no-op is decided on the path Music
itself holds and **never on `AudioStreamPlayer.playing`** - under a dummy audio
driver, which is every headless run and every test, `playing` is false even
while a stream is assigned and looping, so a guard that trusted it would
restart the track on every scene change in exactly the situation nobody can
hear. `track()` is the readout, for callers and tests alike. game.gd calls
`fade_out()` in `_ready`, so the menu carries over the load and goes out under
the first room's fade-in.

**Every floor plays something, and a boss is the only thing that interrupts
it.** `Music.DEFAULT` (`assets/music/level_loop.wav`) is the bed, and game.gd
asks for it in exactly the place it used to ask for silence: after the hunt for
a boss with a `music` on him, where a floor with no boss and a boss floor whose
boss has already conceded both land. A conceded boss hands it back on the same
signal that used to take his theme away - the fight ending is not the floor
ending, and Ivan walks in on half of those rooms.

The ask is `fade_to()` rather than `play()`, and it is the same idempotence
trick one level up: **a door between two ordinary floors must not restart the
bed**, so asking for the track already playing is a no-op and the music crosses
the building with the player. What `fade_to` adds is the handoff - there is ONE
player, so no crossfade is possible, and a track that is on its way out has to
finish leaving before the next one starts. That queue is why the first room
does not cut the menu off mid-fade: `_ready` asks the menu to leave, the lobby
asks for the bed, and the bed comes up when the fade lands. An explicit `play()`
or `stop()` always beats a queued handoff.

The loop flag is set on the stream in code, not trusted to the `.import`, for
the same reason `game/enemies/enemy_audio.gd` sets it - and unlike a boss's
sounds, which are HIS and live in his scene, the track paths are a short
catalogue of constants on Music, because a path spelled out in three screens is
the one that goes stale when a file moves.

**Three floors are the exception to all of that, and a floor's track is not a
boss's.** A biome may carry a `music` key, which the generator writes into the
level scene beside its title and game.gd reads where it used to say
`Music.DEFAULT`. Two of the three are the end: the executive floor and the
penthouse both name `finale_loop.wav`, so the finale comes up as the lift doors
open on floor 11 and is still playing through the last fight. It had to hang on the
floor and not on Silverman for the reason a theme is HIS: a boss's track starts
where his bar goes up and leaves where it clears, so it can never cover the
floor below him, and one on him here would interrupt this twice in the last
four minutes of the game. He therefore declares no `music` at all - the one
boss in the building who doesn't - and `tests/test_music.gd` checks that
absence, because nothing else would notice a line being added to his scene.
Crossing the door costs nothing because `fade_to` is idempotent on the path,
which is the same trick the bed already relied on, one level up.

**The third is floor 1, and it is the same mechanism used for the opposite
reason.** The lobby names `lobby_loop.wav`, which is the slower of the two beds
- the building above runs on a hard 128 BPM thing, and floor 1 is where a
player is still finding out which key swings. Music that insists on a pace is
music arguing with the room. It costs one line in `tools/biomes/lobby.gd` and
nothing anywhere else, which is the whole point of the key existing.

What it DOES cost is the one door in the first half of the chain that is a real
handoff: there is one player, so the lobby's track has to finish leaving before
the bed can start, and the bed is therefore still coming up when the studio is
already standing. Anything checking the bed at the studio's own door is
checking it a fade too early - `tests/test_chain.gd` reads it a floor further
on, and its no-restart pair moved to the hub's door, where the bed has been
playing since Ahmed gave in. Every other ordinary door in the building is
still the no-op it always was.

And the RULE is now three floors rather than two: `tests/test_music.gd` reads
the whole chain off disk and fails if any other floor names a track, if the
finale's two are not the LAST two, or if the lobby's is not floor 1.

The tracks themselves - where they live, the 24 kHz import, why a generated loop
does not loop and how to level one under a voice - are assets/music/CLAUDE.md.

## Menu sound

`autoload/ui_sound.gd` (`UiSound`) is the menu's own noise: `move` when focus
steps between options, `press` when one is chosen, `back` when you leave. An
autoload for Music's two reasons, both of which bite - the front end is three
scenes, so a press started by PLAY would be freed by `change_scene_to_file` in
the frame it began (`enemy_audio.gd`'s `play_detached` trap, arriving in a
menu), and the pause menu runs with the tree PAUSED, which stops a player that
is not `PROCESS_MODE_ALWAYS`. The files live at `ui/sfx/` rather than in
`assets/`, on the placement rule: four screens under `ui/` share them, so they
bubble up exactly one level, to where `ui/theme/` already is.

**Nothing wires itself to it, and the reason it can get away with that is a
fact worth stating outright: nothing outside the four menu screens ever takes
focus.** The dialogue box draws its choices as Labels and picks them with its
own index, the HUD is not focusable, and no room holds a Control. So
`gui_focus_changed` on the root viewport - with no filter on it at all - is
already exactly the menus, and `node_added` hooking every `BaseButton` on its
way into the tree covers the presses. A screen added next month makes noise
without knowing this file exists.

Three splits are the whole design:

- **Focus GRANTED is not focus moved.** Focus also changes when a screen opens
  and hands it to its first control, when a panel closes and hands it back, and
  when a dialog pops - none of which the player did, and a menu that chimes at
  itself on the way in is the first thing anybody reports. So `move` fires only
  where focus changed on a frame the player pressed a navigation key, which is
  precise where "had something else been focused?" is a guess.
- **`back` is the one cue that is NOT automatic**, and it is `hit` firing only
  on a blow that LANDED, arriving from the other side of the game. A global
  handler on `ui_cancel` would look right - one key doing one job everywhere -
  but the death screen swallows Escape, and a chime on a press that did nothing
  teaches the player the sound does not mean anything happened. Only the screen
  handling the press knows it was consumed, so the three that handle it say
  `UiSound.back()` where they act on it.
- **The cue is named after what the PLAYER did, not what the screen did**,
  which is why the Back BUTTON plays `press` while Escape plays `back`. Same
  outcome, different inputs; one sound per key is the version that cannot
  drift, and the alternative is this file guessing forever which buttons
  "mean" back, by name.

A dropdown is the one place that needed its own wiring: a `PopupMenu` is not a
Control and never takes focus, so its `id_focused` and `index_pressed` are
hooked too, or the settings page goes silent exactly where it has the most
options. A cue fires at most once per frame (`player.gd`'s rule for `hit`),
which makes every honest double-up - a panel and the pause menu behind it both
seeing one Escape - harmless. A missing or unimported WAV is silence with no
branch anywhere, so a fresh checkout has quiet menus rather than broken ones.

The sounds are `tools/sfx/ui.py` and are the one generator here that costs
nothing and returns the same bytes twice - see tools/CLAUDE.md's *What every
generator writes*. Levels are
baked per cue (`move` -22 dBFS, `press` -18, `back` -20) and pitched to sit
under the menu bed; `VOLUME_DB` stays 0 because there is still no bus layout,
so a file's own level IS the mix. Too quiet or too loud is ONE number in the
recipe and a free re-run.

## Net

`autoload/net.gd` (`Net`) is online co-op's one door to the network
(DESIGN.md's Multiplayer, M2): host a room, join one by its code, leave, and
keep the party's ROSTER - peer, name, character, route, ping, and `taken` while
a guest sits on a character they did not ask for - until the host starts the
run. It is the ONE place the transport is chosen: online is WebRTC
introduced through our signaling service, with the spike's three pieces under
`autoload/net/` (`signal_client.gd`, `rtc_link.gd` - direct first, relay as
the fallback, and which one it got - and `ping.gd`, the host's own heartbeat);
`host_local()` / `join_local()` are ENet on a port, which is the same
MultiplayerAPI with none of the internet in it and what the suites run on;
offline is Godot's OfflineMultiplayerPeer, a host with no guests.

Seven things are load-bearing:

- **The host is the truth.** A guest is in the party once the host has its
  hello, and the host sends the whole roster to everybody IN it on every
  change and once a second besides, pings included - to the roster's rows, not
  to every peer on the line, which a guest being cut off still is for a while.
  The hello carries `WIRE`, the game's
  own protocol: two builds that do not speak the same game are refused with
  `version`, the way the signaling service refuses another `PROTOCOL`.
- **The refusal only works while an older build can still be READ.** Godot
  numbers a node's RPCs in the order of their names, so a new `@rpc` that
  sorts before an old one renumbers it, and an older build's `_hello` lands on
  some other method and is never refused - it just hangs. So `_hello` and
  `_refused` keep their exact signatures forever (the hello still carries a
  name nobody reads), and a new RPC takes a name that sorts after every older
  one (`_want`, after `_roster`). `test_net.gd`'s wrong-wire step is the same
  build saying another number, so it cannot catch this: check it by reading.
- **Who plays whom: nobody types a name.** A player is called what their
  character is called (`name_of()`), and no two in a party play the same
  character, so no two share a name. The host keeps it so in `_hello`: a guest
  asking for a character somebody already plays is seated anyway, on the next
  one round the cast nobody does (`_first_free()`), with what they asked for
  on their row as `taken` - never refused. A guest may move to any free one
  while waiting (`choose()`, granted by the host's `_want`, which clears
  `taken`); a taken or unknown one is simply never granted. Only rows that
  have said hello hold a character, so of two asking for the same one, the
  second hello moves on. The host keeps its own, because the list of games
  shows it.
- **Joined in the lobby, never mid-run.** `start_run()` sends the signaling
  service `start`, which refuses every later `join` with `started`, and a
  hello after the start is refused with `started` too.
- **It changes no scene and spawns nothing.** `run_started` hands the rows to
  whoever listens, and nothing in it reaches for the tree's root
  MultiplayerAPI by name - which is what lets two of it live in one process,
  each in a SubViewport with an API of its own (tests/test_net.gd).
- **A line that goes dead is given up on by the game, not the transport**
  (M6). A guest whose game crashed says nothing on its way out, and ENet and
  WebRTC each take their own long while to notice. So `ping.gd`'s heartbeat
  doubles as a watchdog (`silent()`): the host drops a guest it has not heard
  for `drop_seconds()` (`DROP_SECONDS`, 15) exactly as if they had left -
  asking the transport to let go the way a refusal does, never forced, which
  would leave the MultiplayerAPI still sending to them - and a guest that has
  not heard the host for as long ends its party with `host_left`. Long on
  purpose: a browser stops a hidden tab's game dead, and looking away to
  answer a message is not leaving. The wait costs the run nothing, because
  game/sync/bodies.gd takes a silent body out of the fight after a second. A
  suite shortens it with `za/test/drop_seconds`.
- **Which service is one function, `signaling_url()`**: `--signal=URL`, then
  a web build's own page host, then the LIVE service for a release desktop
  build (`packaged` and not `dev`), and dev's own for everything else - dev
  builds and the editor, which is develop.

**The list of games is the signaling service's** (its protocol 3,
server/signaling/rooms.py's header): EVERY room on the asker's `WIRE`, public
or private, waiting, full or started, each with a status - `open`, `private`,
`full`, `playing` - and never a code. A row is joined by an opaque id
(`Net.join_listed()`): a PUBLIC room lets anybody in that way, a private one
wants its code as well (`wrong_code`), which is the whole of what private
means. A code alone still joins any room, so the join link and copies of the
game from before the list keep working: the service still speaks protocol 2,
and a room that named no wire is never listed. Anybody may look without being
in a room (`Net.browse()`, `autoload/net/room_list.gd`, its own socket, asked
again every 3 s); the host chooses public at `host()` and may change it in
the lobby (`set_public()`), and may `kick()` a guest there, which also refuses
that guest's address the room for good. **There is no hidden-address option**:
it was built and taken out on the owner's word - a guest connects straight to
the host and falls back to the relay only when no direct route exists. And
**no suite ever asks the real service for a list**: tests/helpers.gd holds
`za/test/no_room_list` on in memory, so `browse()` does nothing there, and a
suite that wants a list hands it to `rooms_listed` itself.

The screens a player reaches it through are ui/lobby/CLAUDE.md; keeping a run
in step once it has started is game/sync/CLAUDE.md.
