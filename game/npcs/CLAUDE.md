# NPCs - the two people in the building who are pleased to see you

Deep dive for `game/npcs/`. The root CLAUDE.md says WHERE these files sit and
what regenerates them; DESIGN.md says what each NPC is FOR. This file is how
one is shaped, why it is shaped that way, and what to know before adding a
third.

There are three: **Dominique**, the guide at the front desk, **Ivan**, the
healer in the cafeteria, and **HR**, who has no floor yet. All three are
friendly, all three are enormous, and all three are built by the same
three-step pipeline.

HR is the one with no first name, and that is the joke: everyone else in the
building has one and she is a department. Light pink hair past the shoulders
over a belted white dress. She is also the first of the three to be placed and
the first to have anything to say - she stands in the lobby and inducts you.

## Friendly is a matter of which groups it is in

An NPC is in the `npcs` group and in NEITHER `player` nor `enemies`.

That is the whole of it, and it works because nothing in this game reaches
anything by type: enemies find their target through the `player` group, the
player's sword finds its targets through `enemies`. An NPC is therefore
invisible to both by construction rather than by a flag someone has to
remember to set, and it cannot be made hostile by accident - it would take
adding it to a group on purpose. A third friendly face is a scene in this
folder and nothing else.

The corollary is the thing to actually watch: an NPC IS a `CharacterBody2D`
with a collision shape, so it is solid, and enemies have no pathfinding and
slide off whatever they hit. The same rule that governs furniture governs a
person - **do not stand an NPC on the line an enemy walks from its post to the
middle of the room**, or the enemy grinds along it forever. A corner and a desk
are where these two belong for reasons of story, and it is lucky the reasons
agree.

## A white garment is the one that can vanish

Dominique's teal and Ivan's red hold their silhouette against any floor in the
game. HR's white dress does not: the lobby ramp ends at `f2f5f9` and the
marble hall's at pure white, and on either of those the only thing separating
her from the tile is the 1px black outline every NPC gets for free.

It reads - it is the same margin the pale characters in the cast already
survive a hot floor band on, which is why `floor_band` stops short of a ramp's
top in the first place. But it is the reason to look at a floor before putting
her on it, and the reason she is belted: the hemp cord breaks the dress into
two blocks, so even where the hem loses its edge the waist still reads.

## Twice the player's height, in a robe the player's width

That brief is the reason this folder has an art pipeline of its own rather
than a row in the cast's roster, and three things fall out of it.

**A 32px cell cannot hold one.** The cast is 14-15px tall in a 32px cell.
Doubled that is 28-30px, which with the clearance a sprite needs under its feet
does not fit. So NPC sheets are cut at **64px** - the size the bosses already
slice at, and `character_art.slice()` has taken a cell size since the first
boss, so nothing in the pipeline had to learn anything.

**The ground line is unchanged.** `npc_art.gd` preserves the clearance between
the feet and the bottom of the cell, so a 64px NPC stands on exactly the line a
32px enemy stands on. The only thing that knows the cell got bigger is the
scene's sprite offset: `Vector2(0, -24)` against an enemy's `Vector2(0, -8)`.
Get that number wrong and the NPC floats or sinks; it is checked against a
real enemy scene rather than written down twice.

**The robe is measured, not drawn.** It is one column exactly the width of that
direction's IDLE frame, held constant across all four columns of a walk. That
is what "no wider than the player" means in practice - measuring per frame
instead would let a swinging arm bulge the robe on frame two.

## Three steps, and the order of the middle one matters

`tools/build_npcs.gd` seeds a sheet once and slices it forever after, exactly
as `build_enemies.gd` does. Seeding is:

1. `character_art.restyle()` recolours and reshapes the **cast** body per the
   roster recipe - the cast's living sheet, not the enemies' frozen copy,
   because an NPC is a colleague drawn to the proportions of the people the
   player recognises.
2. `npc_art.gd` rebuilds each frame at double height in a robe, at 64px.
3. `character_art.slice()` cuts it, with `NpcArt.CELL` as the cell size.

Inside step 2, **the robe goes down first and the head is blended over it**.
This is the one ordering that matters: Dominique's hair falls past the
shoulders, and a head pasted down first is buried by the robe - losing the one
feature that look was designed around. In the right order the hair lies on the
cloth, and from behind Dominique reads as a blonde curtain over teal.

A floor-length robe has no legs, so a walking NPC would otherwise glide. The
hem drifts a pixel across the four columns instead - cloth, not footsteps - and
the hands are kept where the source frame put them, so the arms still swing. An
`ankle` hem is the alternative: it keeps the cast's real feet and real stepping.

## The head is doubled, and that is a known debt

All three use `head_scale: 2`, which doubles the head along with the body and
keeps the cast's chibi proportions at twice the size. It also doubles the
head's **outline to 2px** while the robe's stays 1px. It reads fine at a glance
and wrong up close.

This was chosen with the trade-off on the table. The fix is not a code change -
it is drawing the head by hand at 64px into the NPC's own sheet, which the
pipeline is already built for: `src/<id>.png` is hand-owned art from the moment
it exists, and a rebuild slices whatever is on disk without ever consulting the
recipe again. Redraw the head, re-run `build_npcs.gd`, nothing else moves.

## Speed

`npc_base.gd`'s `speed` is **45.0, half the player's 90** - the one number here
that is a ratio rather than a measurement, and written as a plain number
anyway, exactly as the enemies' speeds are. Coupling every NPC to
`player.gd`'s `SPEED` would mean a movement tweak silently restaging every
scripted walk in the game. If the player's speed moves and an NPC should follow
it, that is an edit here, on purpose.

All three are stationary - Dominique is behind a desk, Ivan is in a corner,
HR is not on a floor at all - so nothing calls `walk_to()` yet. It exists because an NPC that never moves is one
script change away from being an NPC that walks somewhere once, and a sheet
that already holds a walk cycle should not need a new script to use it.

## Talking, and the three things an NPC owns of it

All three carry a conversation and none of them runs one. What lives here is
the trigger and nothing else:

- a **`TalkArea`**, radius 30. Measured against a body twice as tall as
  anything it will be compared to, and deliberately wider than the escort's
  `TRAIL`: a guide who walks you somewhere and stops must leave you inside the
  ring, or the tour ends with the prompt already gone.
- a **`Prompt`** - the E keycap over the head, at y -60, which is above a 64px
  cell's hair rather than an enemy's. Up only while the player is in range,
  the NPC has something to say, and nothing is being said.
- a **`Nameplate`** - the name, always up, from the frame the room is built.
  See below.
- **`conversation`**, `speaker` and `greets`, all exports, all set from biome
  data when the level is built.

Then `talk_requested`, and that is the end of this folder's involvement.
game.gd wires it to the director. See game/dialogue/CLAUDE.md for the beat
format and the escort.

**Online the prompt is THIS machine's** - it answers only to a body that is not
`remote`, because it is a hint to whoever is at this keyboard, and somebody
else's player standing beside HR is no reason to put it up on your screen. And
an NPC is drawn where the host says, except while somebody is talking to it:
`led_by` names the peer whose machine walks it for the length of the
conversation (game/dialogue/CLAUDE.md's *Online*).

`speaker_name()` falls back to the ROSTER's name rather than to the export,
and derives which roster entry it is from the frames the scene was built with -
a display name typed twice is a display name that drifts, and a scene pointing
at Ivan's sheet while calling itself Dominique is a bug rather than a
configuration.

## Ivan heals, and it is the only thing any of them does beyond talking

`ivan.gd` is the one NPC script in the folder, and it is twenty lines: everything
else about him IS npc_base. Dominique and HR still have no script, which is the
measure of whether this stayed small.

- **The conversation tells him.** The director calls `set_talking()` on both
  edges of a talk, so the falling edge is "he has finished saying it" - no new
  signal, no beat key that spawns a pickup, and nothing in the dialogue system
  learns that hearts exist. The last word of every one of his conversations is
  DESIGN.md's one line for him, "Eat.", and the hearts land on it.
- **One heart per head**, counted by `game/heads.gd` - the same function a
  floor's second beat scales its arrivals by, read in the other direction. A
  party of four meeting four times the bodies and sharing one heart is the same
  unfairness twice, and the two reading one function is the point of that file.
- **Once per visit.** Talk to him again and he says it again and hands over
  nothing: a room that can be farmed for health is a room with no fight in it.
  "Once" resets when the level does, because rooms are re-instantiated on entry
  - the same forgetfulness a consumed pickup already has.
- **He throws rather than hands over** (`hearts.gd`): a short arc each, fanned,
  staggered, live when they land. The fan is aimed at the person he is talking
  to, which points it at open floor by construction - a fan all the way round
  him would land in the scenery, because the safe corners he stands in are the
  ones nothing else wanted.
- **The heart is the loose one** - `game/heart.tscn`, written by
  `tools/build_npcs.gd` on the same `pickup_base.gd` every level's own heart
  uses. A room's heart is dressing and takes the room's palette; a loose one is
  the same red on every floor, so there is one file rather than a copy per
  level. It was his alone until a cleared room started dropping it too
  (game/levels/reward.gd), which is why it sits at game/ and not in his folder.
  From floor 2 up those two are the only healing in the game.

Where he turns up, and the cue he waits for, is a floor's business and not his:
`relief` in biome data, `game/levels/relief.gd`. He does not know he is a beat.

## Everyone is wearing a name badge

Every NPC carries its name over its head from the moment the room is built, and
it never goes away - there is no state in it, so there is nothing to get wrong.
Three things about the label are decisions rather than defaults:

- **The text is written from `speaker_name()` in `_ready`**, not read from the
  scene. The string sitting in each `.tscn` is only there so the editor shows
  something over the head; the roster is what ships. A floating name and a
  subtitle name that disagree would be exactly the drift `speaker_name()`
  exists to stop, so they come from the one call.
- **Where it sits is dictated by the two things already over an NPC's head.**
  The body is 28px of a 64px cell with 8px of clearance under the feet, so with
  the scene's `-24` sprite offset the hair tops out at y -28 and the E keycap
  spans -67 to -53. The plate takes the gap between them, -52 to -29, so a name
  and a prompt are never in the same pixels and neither has to move when the
  other appears. That box is 23px rather than the font's 16, because a Label
  grows to the font's line height whatever the offsets say - written out in the
  scene so the file states what actually renders.
- **Gold text with a 1px dark outline, not a plate.** The gold is the
  subtitles' speaker colour, so the name over the head and the name in front of
  the line are visibly the same label. A backing plate was the alternative and
  it loses: a plate has to be as wide as the longest name, and HR's white dress
  against the marble hall is the case that settles it - an outline reads on any
  floor, in any garment, at any name length, which is the same argument that
  put a 1px outline on her dress in the first place. `outline_size` is 2, which
  is one game pixel, matching the sprites' own outline weight; 4 reads as a
  sticker.

The label is 96px wide and centred, which fits every name the roster has and
the longest one it plausibly grows - a name wide enough to overflow that would
be too wide to stand under anyway.

**Which conversation an NPC is carrying is placement, not identity.** It sits
in `tools/biomes/<level>.gd` beside where she stands, so the same person can
greet you on one floor and warn you on another with no second scene. `greets`
is the same kind of choice: it starts the conversation the moment the player is
in range instead of waiting for the key, and HR does NOT have it on - a tour
that starts itself takes the wheel off a player who has pressed nothing yet.

## Still to build

- **All three are now placed and all three talk.** HR stands in the lobby
  (`tools/biomes/lobby.gd`) with `hr_lady/welcome.gd`, Ivan arrives on six
  floors with a conversation per floor (`ivan/after_<floor>.gd`), and Dominique
  arrives on the three
  under a boss with one file of lines each
  (`dominique/before_<boss>.gd`) - the signpost the plan asked for, built as a
  beat rather than a placement so the warning lands while the fight is still
  ahead. Placement is biome data like everything else a room is dressed with -
  see tools/CLAUDE.md.
- **Ivan now says a different three on each of the six**, which is what
  `conversation` being placement was always for: six files
  (`ivan/after_<floor>.gd`) and no code. He used to say one set everywhere, and
  the reason that had to go is in `after_call_center.gd`'s header - a man who
  arrives after a fight and says something that fits no fight in particular is a
  vending machine with a voice, and by the fourth floor the player has heard it
  three times and reads none of it. What holds the six together is a routine
  rather than a script: he talks about the room he just walked into, he knows
  everybody in it by what they order, and the last word is always "Eat.".
- **A conversation cannot be remembered.** HR will induct you again every time
  you walk back into the lobby, because rooms keep no state. That is the same
  decision as a respawned pickup, and it gets fixed when saves do.

## Their voices

**She is also VOICED** - twenty-three clips out of the same `tools/voice/`
Ahmed's barks come from - and, as with him, nothing was rewritten to allow it:
a beat always carried its clip path, and the dialogue box always took one. What
the clip buys is the TYPING RATE, which is now the line's length over the
clip's, so the subtitle finishes as she stops rather than racing her. A beat
with no clip, or one not yet imported, is silent and types at the flat rate, so
every unwritten conversation in this game still reads. Dialogue:
game/dialogue/CLAUDE.md.

**He is VOICED too** - eighteen clips out of the same `tools/voice/`, three per
floor, in English with an Eastern-European accent, which is the only direction
his lines needed: he is the one man in the building who is glad to see you, and
he is heard over a room the player has just finished fighting in, so an accent
that ever costs a word would cost the moment it was written for. His clip names
are namespaced by floor (`call_eat`, `ahmed_axe`) because all six conversations
cut into one folder and nothing dedupes across them - and every floor really
does end on the same word.

## Ivan says a different thing on every floor

**He says a different thing on every one of those six floors**, and that cost
six files and no code: `conversation` is placement, so each floor's biome names
its own (`game/npcs/ivan/after_<floor>.gd`). One shared set of lines was the
first version and it was wrong in a way only repetition shows - a man who walks
in after a fight and says something that fits no fight in particular reads as a
vending machine with a voice, and a player who has heard it three times has
stopped reading the box he cannot skip. What keeps six files one character is a
ROUTINE rather than a script: he talks about the room he has just walked into,
he knows everybody in it by what they order - Ahmed complains about his soup,
the office boys fix his ovens - and the last word is "Eat." every time, because
that is the word ivan.gd's gift lands on. The rest, including why the finale
names nobody, is `after_call_center.gd`'s header.

## Dominique is the fourth beat

**Dominique is the FOURTH beat, and the only one that hands over information.**
A floor with `briefing` in its biome walks him in once the room is clear to say
what is standing on the floor above - and it is the three floors that sit under
a boss, which is the rule rather than the list: `tests/test_dominique.gd` reads
the whole chain off disk and fails if a boss ever gets one without a warning
under it. He comes down the NORTH door, the one the player is about to go up,
where Ivan comes up the south one - two of the three floors have both, and one
doorway cannot take two 64px bodies on one cue. It is the same
`game/levels/relief.gd` doing both, because that file has never named anybody:
the beats are told apart by node name and biome key, the way the prop shelves
are told apart by role. His lines are one file per boss
(`game/npcs/dominique/before_<boss>.gd`) and he is voiced too - twelve clips,
bold and Slavic and impatient, deliberately not Ivan's warmth: he is glad to see
you, and Dominique has given this speech before to people who did not come back.
