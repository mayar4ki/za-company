extends RefCounted
## The floor plan of the game: which levels exist, in what order, and the
## helpers every generator reads them through. Editor-side only - nothing under
## res://game or res://tests loads this.
##
## THE DATA LIVES IN tools/biomes/<level>.gd, ONE FILE PER FLOOR. You design a
## room as a room, so everything about one floor - palette, furniture, enemies,
## and the comments about which lanes must stay clear - sits in one small file
## you can hold in one screen. Adding a floor is a new file there plus its name
## in CHAIN below, then a run of build_biomes.gd and build_levels.gd (and its
## NEIGHBOURS in build_levels.gd too, if it was inserted mid-chain - their door
## targets bake in).
##
## ## The keys a floor's BIOME dictionary can carry
##
## Value ramps run darkest first. Source pixels from the shared dungeon sheet
## are mapped onto a ramp by luminance; `gamma` bends that mapping (above 1.0
## pushes mid-tones down while leaving highlights hot) and `floor_band` then
## confines floors to a slice of the ramp, because a floor that reaches the hot
## end of the hellfire ramp turns into gold flooring the player cannot be seen
## against.
##
## `shape` is what the room IS, and a floor without it is the 34 x 19 rectangle
## eleven of the twelve are: `{cols, rows, cut, mask, doors}`, read by
## tools/plan.gd, which is where the vocabulary and the reasoning live. The call
## floor is the one that uses it - a hall with an arm off its corner - and two
## keys travel with it. `lane` is that floor's own walk between its doors, a
## list of Rect2 legs overlapping at the corners, written into the level scene
## as an export beside the title and answered by level.gd to anything that asks;
## a floor that names none gets the straight band x 246-300 the building keeps.
## `hazard_at` and `heart_at` move the two stands, which default to where a
## stand goes in the rectangle - and on a shaped floor that can be masonry.
##
## `title` is the name the room announces itself by on arrival, written into
## the level scene as an export. It is authored rather than derived from
## `node`, because "THE MARBLE HALL" is not a transformation of "MarbleHall"
## that any rule gets right for every room ("HELLFIRE" takes no article).
##
## `music` is a track this floor plays, and a floor without the key plays
## Music.DEFAULT like the other ten. It is written into the level scene as an
## export beside `title` and read by game.gd, which is what makes it a fact
## about the ROOM rather than about anybody standing in it: a boss's theme
## lives on the boss, starts when his bar goes up and leaves when he concedes,
## and could therefore never cover the floor below his. The last two floors
## share one file for exactly that reason - the executive floor and the
## penthouse both name it, so the music crosses the door between them without
## restarting (Music.play is idempotent on the path) and the building plays one
## unbroken piece from the lift doors to the end of the game.
##
## `enemies` is what build_levels.gd dresses a fresh level with: a type (a
## folder under game/enemies/) and a position in level pixels. Composition is
## most of what makes one room feel unlike the next. Positions are chosen so no
## enemy's sight reaches the door line, the spawns or the hazard and heart
## stands: the straight walk between the two doors stays safe in every biome.
##
## `boss` is the same shape for one boss - {type, at}, the type a folder under
## game/bosses/ - and having one also shuts the floor's north door until the
## boss concedes (game/levels/boss_door.gd). A boss is an arena's whole
## population: the enemies list on such a floor stays empty.
##
## `reinforcements` is the ONE thing here that is not a placement, and the
## difference is the point: `[{after_kills, from, enemies}]`, where `enemies` is
## bare type names and `from` is a spawn marker ("start" is the south door).
## They have no `at` because they walk in rather than stand somewhere, which is
## also why they are the only enemies in the game that can be scaled by how many
## players are in the room. Finite, authored, and once each - a room is an
## ARRANGEMENT, not a population, and a floor gets a beat only where its lesson
## is worth restating. The rationale in full, and the reason this is not waves,
## is in game/levels/reinforcements.gd.
##
## `per_head` is the other half of a beat's `enemies`: the base group arrives
## whatever the head count, and `per_head` is added once per head BEYOND the
## first. Multiplying one list instead gave every extra player a copy of every
## type, which on a boss floor means a second `call_center` - and two of those
## do not stack a slow, they refresh it, so the player is slowed permanently and
## a telegraph they could sidestep stops being dodgeable. **`call_center` is
## therefore in no floor's `per_head`**, and the rule a beat obeys is the one
## Difficulty obeys: more bodies, never a worse one.
##
## A BOSS floor's beat is cued by `at_boss_fraction` instead of `after_kills` -
## the share of his max health he has to be down to, a fraction because his
## health grows per head (boss_base.gd's `health_per_head`) - because `after_kills` cannot reach any
## number but zero there: a boss is in the `enemies` group and is never freed,
## so he never counts as a kill. An add arriving at a threshold is a PHASE of
## the fight; the same add placed under `enemies` is furniture standing in the
## arena from the first frame, which is what "one fight is enough to read at a
## time" was protecting. So a boss floor's adds go here, not there.
##
## `relief` is the floor's THIRD beat, and the only one that is not a fight:
## `{npc, from, at, say}` - who walks in once the room is finally clear, through
## which spawn marker, to which spot, carrying which lines. It is Ivan, on the
## six floors that have earned him, and from floor 2 up he and `reward` below
## are the only healing in the game.
##
## It is an arrival rather than a placement for the same reason a reinforcement
## is: standing him in the room from the first frame puts a solid 64px body in
## an arrangement whose positions were chosen against sight radii and clear
## lanes, and puts a heart on offer while the fight the floor is FOR is still
## standing. His healing is a lifeline because it arrives after the cost is
## paid. So he has an authored DESTINATION and no authored position, and the
## furniture rule applies to `at` alone - the room is empty by the time he
## reaches it, so the only thing that spot has to clear is the scenery and the
## door line.
##
## He hands out one heart per HEAD, which is the other half of `per_head`'s
## rule read in the other direction: a party of four meeting four times the
## bodies and sharing one heart is the same unfairness twice. Both numbers come
## out of game/heads.gd. The cue and the rest of the reasoning are in
## game/levels/relief.gd.
##
## `reward` is the plain version of the same thing: `true`, and when the room is
## clear on the same cue, the last body down leaves one heart per head where it
## fell. Nobody walks in and nothing is said, so it carries no spot - the fight
## decides where it ended, which is the one place certain to be on screen. The
## innovation lab has it: three floors ran without a heal into Big Mo, and its S
## hides any authored spot two halls from wherever the fight finished. See
## game/levels/reward.gd.
##
## `npcs` places the friendly faces: `[{id, at, facing, face_left, conversation,
## greets}]`, where `id` is a folder under game/npcs/ and `conversation` a .gd
## holding the lines (game/dialogue/dialogue_director.gd has the format). An NPC
## is a solid body like any other, so it obeys the furniture rule twice over:
## off the door line, and off the line an enemy walks from its post to the
## middle of the room, or the enemy grinds along it forever.
##
## `spawns` is `{name: position}` and exists only to serve the above: a beat
## names a marker rather than carrying a position, so a beat arriving anywhere
## but the two doors needs a name to arrive at. The executive floor's
## `chokepoint` is the first and shows why it earns a key - the gap it arrives
## at is ON the door line, where nothing may be placed, so a beat is the only
## legal way to put a body there at all.
##
## `props` is the same idea for furniture - a type from tools/props/ and a
## position - and it is what dresses a room as somewhere rather than as a
## rectangle. Keys that go with it, all optional and all defaulted so the two
## demo biomes need none of them:
##
##   props    furniture: [{type, at, turn}]. `turn` rotates the instance about
##            its pin, which is how the banner hangs crooked.
##   column   which architecture the level's pillar is - "classical" (the
##            fluted stone default), "pillar" (glazed steel) or "divider"
##            (cubicle partition).
##   columns  {rows, xs} overriding the generator's colonnade, because a
##            furnished room needs the floor a full colonnade takes up. Both
##            lists EMPTY means no colonnade at all, and then the level has no
##            column scene either - DESIGN.md's gym is a tight arena with
##            nothing in it to hide behind.
##   hazard   which hazard art the level gets - "torch", "polisher",
##            "power_strip", "fallen_light" or "copier", or "none" for a floor
##            with nothing on it to hurt you. Omitted means "torch": a floor
##            that has no hazard says so, rather than the absence of a key
##            deciding it.
##   studio   {take, rest, lead} in seconds - the floor's CLOCK, and the one
##            key here that is a rhythm rather than a thing. A take rolls, the
##            room's hazards go live, and between takes they are furniture. It
##            carries no position because a rhythm is not anywhere. Everything
##            that reads it finds it through the `studio` group and a floor
##            without the key simply has nobody to find, so the props that can
##            react to it stay exactly the props they were on every other
##            floor - see game/levels/studio.gd. The content studio is the
##            first and so far only floor that runs one.
##   dolly    {from, to, speed, damage} - the one hazard in the game that
##            MOVES, running between two points while a take is rolling and
##            parked at `from` between them. A fixture like the torch: the
##            level places it, not the props list. Two rules bind it, and the
##            second is the one to check before authoring another: a rail must
##            be drawn under it (the `rail` prop, authored to the same span,
##            because a moving threat has to be legible before it arrives), and
##            its span must not reach the door lane at x 246-300, which is the
##            first thing in this game that could threaten that lane without
##            ever being PLACED in it.
##   surge    {speed, period, charge, damage, runs: [{from, to, after}]} - the
##            OTHER moving hazard, and the one that comes in fours. A short
##            racing a run of cable trunking: the conduit lies dull, flares end
##            to end for `charge` seconds, then puts a head down its length at
##            `speed`. Unlike everything else a level places it has no art -
##            each node draws its own conduit AND its own spark from the two
##            points it is given, so the lane the player reads and the lane that
##            hurts cannot come apart, which is the thing that would otherwise
##            need policing across six authored pairs. `after` staggers the runs
##            and is the only per-run number that is not geometry. It obeys the
##            dolly's rule too: no run may reach x 246-300. The call floor is
##            the first and so far only one that is wired.
##   scrubbers [{at, within, speed, damage, push, turn_seconds}] - the THIRD
##            moving hazard, and the only one with no route: a floor scrubber
##            that picks a heading, runs until the room stops it, and picks
##            another. It is a solid BODY rather than a trigger (being in the
##            way is half of what it is), it takes the player's POSITION rather
##            than much of their health, and nothing about where it goes is
##            authored - the furniture decides. `within` is the rectangle it may
##            not leave, and it is how a routeless hazard keeps the same promise
##            the other two keep by geometry: no pen may reach x 246-300. The
##            hub is the first and so far only floor with any.
##   heart    true to stand a heal pickup in the room. Omitted means NO, and
##            that default is the rule rather than a convenience - only the
##            lobby hands one out, and from floor 2 up healing is EARNED: Ivan
##            after a fight, or a `reward` drop at the end of one.
##   runner   how far the central floor band is tinted towards the accent, i.e.
##            whether that band is carpet or just more of the same stone.

## Floor order, and it is the order a run walks: south door goes back down
## the list, north door goes up it. The building is DESIGN.md's ten floors in
## its own order, and the two demo biomes are dealt INTO it - the marble hall
## between the hub and the innovation lab, hellfire between asset recovery
## and the executive floor - so a run still walks through both of them and
## ends where the story ends, in Silverman's office.
const CHAIN := ["lobby", "content_studio", "call_center", "ahmed_office",
		"the_hub", "marble_hall", "innovation_lab", "conflict_resolution",
		"asset_recovery", "hellfire", "executive_floor", "silverman_office"]

## Assembled from the per-floor files at load, keyed by CHAIN name, so every
## existing `Biomes.BIOMES[level]` read works exactly as it did when this was
## one hand-written dictionary.
static var BIOMES: Dictionary = _collect()


static func _collect() -> Dictionary:
	var all := {}
	for level in CHAIN:
		var script := load("res://tools/biomes/%s.gd" % level) as GDScript
		if script == null:
			push_error("no tools/biomes/%s.gd for CHAIN entry '%s'" % [level, level])
			continue
		all[level] = script.get_script_constant_map()["BIOME"]
	return all


static func dir(level: String) -> String:
	return "res://game/levels/%s" % level


## Where a level keeps the scenes for the things standing in it. Split out from
## the level's own folder because those two groups behave completely
## differently: the room is a handful of files that never grow (the level scene,
## its tileset, its door and one doorway per neighbour), while this holds one
## scene per prop the biome uses and grows every time a floor wants a new piece
## of furniture. Asset recovery wanted sixteen, which buried the five files that
## actually say what the level IS. Inside it, build_levels.gd shelves each
## scene the way its painter is shelved in tools/props/ (Props.shelf_of()),
## plus fixtures/ for the level-placed column, torch and health item.
static func props_dir(level: String) -> String:
	return "%s/props" % dir(level)


## The distinct prop types a biome places, in the order it first places them.
## Derived rather than declared: build_levels.gd writes a scene for exactly
## this list, so a floor cannot carry scenes for furniture it never puts down.
static func prop_types(level: String) -> Array:
	var types: Array = []
	for entry in BIOMES[level].get("props", []):
		var type: String = entry["type"]
		if not types.has(type):
			types.append(type)
	return types


## Whether this floor stands a hazard in the room at all. The lobby is the
## reason it can say no: floor 1 is where a new player learns to walk, and the
## one thing a tutorial room must not have is a way to lose health by walking
## into the scenery. Ahmed's office says no for the opposite reason - the only
## thing in there that hurts is Ahmed.
static func has_hazard(level: String) -> bool:
	return BIOMES[level].get("hazard", "torch") != "none"


## Whether this floor puts a heart on its floor, and the default is NO - which
## is the whole of the rule. Healing is not something a room hands out: the
## lobby is the one floor that does, because floor 1 is where a player finds out
## what a heal even is, and from floor 2 up the supply is Ivan, who brings it to
## you (DESIGN.md, build step 4). A floor that wants one says `"heart": true`.
static func has_heart(level: String) -> bool:
	return BIOMES[level].get("heart", false)


## Whether this floor stands a colonnade at all. A biome hands in an empty
## `columns` layout to get none - DESIGN.md's gym is a tight arena with nothing
## in it to hide behind - and a floor that places no pillar does not carry the
## scene for one either. An absent `columns` key still means the generator's
## own six-by-two, which is what every floor built before this one relies on.
static func has_columns(level: String) -> bool:
	var layout: Dictionary = BIOMES[level].get("columns", {})
	return not layout.get("rows", [0]).is_empty() \
		and not layout.get("xs", [0]).is_empty()


## The level one step further along the chain, or "" at the end of it.
static func next_of(level: String) -> String:
	var i := CHAIN.find(level)
	return CHAIN[i + 1] if i >= 0 and i + 1 < CHAIN.size() else ""


## The level one step back along the chain, or "" at the start of it.
static func previous_of(level: String) -> String:
	var i := CHAIN.find(level)
	return CHAIN[i - 1] if i > 0 else ""


## Reads a biome's own ramp at `t` (0 = darkest stop, 1 = brightest), bent by
## that biome's gamma. The one place a shade is resolved: the tileset, the
## doorways and every prop are all lit by the same curve.
static func shade(spec: Dictionary, t: float) -> Color:
	return ramp(spec["ramp"], t, spec["gamma"])


static func ramp(stops: Array, t: float, gamma: float) -> Color:
	var scaled := pow(clampf(t, 0.0, 1.0), gamma) * float(stops.size() - 1)
	var i := int(floor(scaled))
	if i >= stops.size() - 1:
		return Color(stops[stops.size() - 1])
	return Color(stops[i]).lerp(Color(stops[i + 1]), scaled - float(i))
