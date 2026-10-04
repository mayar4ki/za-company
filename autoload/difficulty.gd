extends Node
## Which of the three modes the game is played at, and the numbers each mode
## means. Owns nothing else: the choice persists through Settings (section
## `game`, key `difficulty`) exactly the way Display persists window state, and
## like every setting a default is applied but never saved.
##
## **Difficulty scales how hard the world hits, never how much health enemies
## have.** Enemy HP (24 / 17 / 36 / 48) is a set of exact breakpoints on the
## player's 5 / 7 / 12 combo - a guard and a wraith die in three hits, a warden
## in five, security in six, and the heavy one-shots the first two - and a
## multiplier would shred those into remainders on two of the three modes. So a
## guard on HARD dies exactly like a guard on EASY; what changes is what it
## costs you to be slow about it:
##
## - `damage_scale` multiplies every blow and drain the world deals - guard
##   strikes, torches, wraith drain - applied once, where each spawns.
## - `grace_seconds` is the player's post-hit grace window, and it is the dial
##   that decides whether a CROWD is worse than one enemy. A guard's full attack
##   cycle is 0.8s; grace at 0.8 (EASY) means a second guard's strikes land
##   inside the first one's window and are swallowed - N guards hit like one.
##   At 0.5 (MEDIUM) two guards interleave and a crowd is a real threat, and at
##   0.4 (HARD) a third starts to find gaps too. MEDIUM was 0.65, which capped
##   a whole room's damage at about one guard's no matter how many were on you.
##
## Consumers read their numbers ONCE, where they spawn (enemies, hazards, the
## player) - never live. The mode is only choosable before a run - in Settings
## opened from the main menu (the pause menu's copy hides the row), or by a host
## on the lobby's host screen - and a new run instantiates a fresh player and
## fresh rooms, so a change always lands cleanly on the next run with no
## mid-fight rescaling to reason about. That is also why there is no `changed`
## signal. Online the host's mode is the party's: only the host's world reaches
## anybody (player.gd's `_world_reaches()`), so a guest's own mode never lands.
##
## Registered in project.godot AFTER Settings, for the same read-during-_ready
## reason as Display; tools/setup_project.gd enforces the order.

const SECTION := &"game"
const KEY := &"difficulty"
const DEFAULT_ID := "medium"

## MEDIUM is the tuned baseline - every number in the enemies' scenes and the
## balance notes in CLAUDE.md are its numbers, scaled by 1.
const MODES := [
	{"id": "easy", "name": "EASY", "damage_scale": 0.6, "grace_seconds": 0.8},
	{"id": "medium", "name": "MEDIUM", "damage_scale": 1.0, "grace_seconds": 0.5},
	{"id": "hard", "name": "HARD", "damage_scale": 1.5, "grace_seconds": 0.4},
]


## The saved choice, or the default; an unknown saved id falls back to the
## default rather than crashing, like an unknown character id keeps the look.
func mode_id() -> String:
	var saved: String = Settings.get_value(SECTION, KEY, DEFAULT_ID)
	return saved if _find(saved) >= 0 else DEFAULT_ID


func display_name() -> String:
	return MODES[_find(mode_id())]["name"]


func damage_scale() -> float:
	return MODES[_find(mode_id())]["damage_scale"]


func grace_seconds() -> float:
	return MODES[_find(mode_id())]["grace_seconds"]


## Saves - this is the player actually picking something.
func select(id: String) -> void:
	if _find(id) >= 0:
		Settings.set_value(SECTION, KEY, id)


## The host screen's button: step to the next mode, round the loop.
func cycle() -> void:
	select(MODES[(_find(mode_id()) + 1) % MODES.size()]["id"])


func _find(id: String) -> int:
	for i in MODES.size():
		if MODES[i]["id"] == id:
			return i
	return -1
