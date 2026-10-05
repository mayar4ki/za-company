# The lobby - the way into online play

It is a view of `Net`, which is autoload/CLAUDE.md's *Net*; the run it starts is
kept in step by game/sync/CLAUDE.md.

**The way in is the main menu's HOST ONLINE and JOIN ONLINE**, under PLAY, as
the Open Games preview drew it (https://claude.ai/artifact/PTQxvCxkJ1tkncGw2K6bbb):
the same character select, told by its `next_scene` to go on to the lobby -
asking no name, because online you are called what your character is called
(autoload/CLAUDE.md's *Net*, who plays whom) - then `ui/lobby/`, three screens
on one scene, which `ui/lobby/opening.gd` says to open on. `lobby.gd` only routes - which screen is up, which one a refusal is
said on, START into the run - and each screen is a script of its own:

- **Join a game** (`join_view.gd`) is the list and NOTHING else: one row per
  game (`game_row.gd` - the host's character, name, seats as pips, time zone,
  STATUS), open first then private, full and playing, nearest time zone first,
  and one line under it saying what Enter will do with the picked game or why
  it cannot. Rows are kept by game id across each answer, so the picked game
  stays picked as the list moves; full and playing rows are disabled buttons,
  pickable but silent. A private game opens `code_box.gd` for its code.
- **Host a game** (`host_view.gd`): ROOM: PUBLIC / PRIVATE (public by default,
  remembered under `online`/`public`), DIFFICULTY, OPEN THE ROOM.
- **The room** (`room_view.gd`) - option A of the lobby preview, FOUR SEATS:
  its code and join link (C copies it), one seat per `MAX_PARTY` in the
  character select's own cards (`seat.gd` - your seat walks and is marked YOU,
  an empty one is dashed, somebody still connecting is a silhouette), the ping
  in DESIGN.md's colours with the route under it, the relay warning, START,
  the host's ROOM: PUBLIC / PRIVATE switch between START and LEAVE, and KICK
  on every guest's seat - it asks once (KICK?) and goes on a second press
  inside 3 s. **A guest's own seat has an arrow either side of the sprite**
  instead, stepping to the next character nobody else plays: left and right
  on the keyboard PRESS those arrows (`room_view.gd`'s `_input`, before the
  focus sees the key - a guest's room has nothing beside LEAVE to move to),
  so a key and a click are one path and sound the same. A guest seated on a
  character they did not ask for, because somebody had it, is told so on the
  waiting line ("REEM WAS TAKEN, SO YOU'RE ISMEEL - ARROWS TO CHANGE"). A
  change made there is saved as the player's pick, the way the character
  select saves one; the host has no arrows, since the list shows its
  character.

The lobby is a VIEW of Net and holds no party state; START is Net's `run_started`, and the lobby turns the
rows into game.gd's `next_party`: this machine's member marked `local` on the
keyboard, everybody else's carrying its owner's `peer`. The main menu leaves
any party it finds on arrival, and a party ending under a run (`host_left`)
takes that machine back to the menu.
