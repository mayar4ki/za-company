extends SceneTree
## Lays out each level scene and every scene that level owns.
## Run: godot --headless --path . --script res://tools/build_levels.gd
## Requires tools/build_biomes.gd to have produced the tileset first.
##
## A level's folder is split by what the files ARE, not by their type:
##
##   <biome>/                the room, and it never grows
##     <biome>.tscn          the level
##     tileset.tres          its floors and walls      <- build_biomes.gd
##     doorway_out/back.tres its passages              <- build_biomes.gd
##     door.tscn             how it connects
##     props/                everything STANDING in the room, one scene each,
##                           on the same shelves as tools/props/ - fixtures/
##                           (column, torch, health_item) plus whichever of
##                           furniture/, hardware/, signs/ the biome places
##
## Every level gets its own door and its own copy of each prop it uses, free to
## diverge in art, collision and structure. Only the _base.gd scripts are
## shared, because game.gd and the player have to talk to every door, hazard and
## pickup the same way.
##
## **Each prop scene carries its own picture, embedded.** The texture is painted
## here (by tools/props.gd) and handed to the Sprite2D unsaved, so it has no
## resource_path and PackedScene bakes it in as a sub-resource - exactly as the
## collision box already was. There used to be a matching <prop>_art.tres beside
## every prop scene, and each of those had precisely one consumer: its sibling.
## Sixteen of them buried the five files that say what a level actually is.
##
## The consequence to know: re-palettizing a prop now means running THIS script,
## not just build_biomes.gd. That is the trade, and it is a cheap one because
## everything here is written from data in tools/biomes.gd.
##
## Unlike the other generators, what this writes is a STARTING POINT: anything
## hand-tuned in the level scene afterwards - a nudged tile, a moved instance -
## is lost on the next run. Run it to reset a level or to add a new one to
## CHAIN, and prefer moving positions into biomes.gd over nudging them here.

const Biomes := preload("res://tools/biomes.gd")
const Props := preload("res://tools/props.gd")
const StableIds := preload("res://tools/stable_ids.gd")
## The room's own shape - how big, what is cut out of it, where its doors are
## and which tile every cell takes. A floor plan is a subject of its own, so
## it is a file of its own; this one only paints what it is told.
const Plan := preload("res://tools/plan.gd")

const LEVEL_SCRIPT := "res://game/levels/level.gd"
const DOOR_SCRIPT := "res://game/levels/door_base.gd"
const HAZARD_SCRIPT := "res://game/levels/hazard_base.gd"
const PICKUP_SCRIPT := "res://game/levels/pickup_base.gd"

const TILE := Plan.TILE


## The colonnade flanks a central runner. Offset so no pillar lands on the
## centre line - the straight walk between the two doors has to stay clear.
## A biome overrides either list with a `columns` dictionary, because a room
## that is furnished needs the floor a full colonnade would take up.
const COLUMN_ROWS := [5, 13]
const COLUMN_XS := [4, 9, 14, 19, 24, 29]


## The starting-point dressing for health: a heart to heal on, and - on the
## floors whose biome asks for one - a hazard to hurt on, either side of the
## room, both clear of the door line and the colonnade so the straight walk
## between the doors stays safe.
##
## Both are where a stand goes in the room every floor is by default, so both
## are overridable per biome (`hazard_at`, `heart_at`): a shaped floor can have
## no floor at all at the spot a rectangle would have put one, and a copier
## standing in a wall is the kind of thing only a screenshot finds.
const TORCH_POS := Vector2(120, 152)
const HEALTH_POS := Vector2(424, 152)

## Enemies are the one prop a level does NOT own a copy of: types are shared
## from game/enemies/<type>/, and which ones a room gets is per-biome data in
## tools/biomes.gd. A level that wants a variant swaps the instance by hand.
const ENEMY_SCENE := "res://game/enemies/%s/%s.tscn"
## The friendly faces, placed from a biome's `npcs` key. Same shape as an
## enemy's scene path because an NPC is the same kind of thing standing in the
## same kind of room - it just happens to be pleased to see you.
const NPC_SCENE := "res://game/npcs/%s/%s.tscn"
## A boss floor names its boss the same way - a type under game/bosses/ and a
## position - under `boss`. The instance is called "Boss", which is the name
## the floor's north door looks for: having a boss swaps that door's script for
## the lock, shut until he concedes.
const BOSS_SCENE := "res://game/bosses/%s/%s.tscn"
const BOSS_DOOR := "res://game/levels/boss_door.gd"
## A floor's second beat, under `reinforcements`: unlike `enemies` these carry
## no position - they name a spawn marker and walk in through it - so the whole
## list travels into the scene as one export on one node, and a floor without
## the key gets no node at all.
const REINFORCEMENTS_SCRIPT := "res://game/levels/reinforcements.gd"
## A floor's THIRD beat, under `relief`: the healer who walks in once the room
## is clear. Carries a destination rather than a position for the same reason a
## reinforcement carries neither - you cannot walk in at a spot - so it travels
## into the scene as one node beside the second beat, not as a placed instance.
##
## It is also the FOURTH, under `briefing`: the guide who comes DOWN the stairs
## on the floor below a boss to say what is at the top of them. Same script,
## because relief.gd names nobody - the two beats differ by which door, which
## NPC and which lines, and none of that is code. They are named by ROLE, the
## way the prop shelves are, so a room's scene says which arrival is which.
const RELIEF_SCRIPT := "res://game/levels/relief.gd"
## A cleared room's reward, under `reward`: one heart per head left where the
## last body fell. Nobody arrives, so it is its own script rather than a third
## role for relief.gd, and it carries nothing - the spot is wherever the fight
## ended.
const REWARD_SCRIPT := "res://game/levels/reward.gd"
## A floor's CLOCK, under `studio`: one node counting take / cue / rest, which
## everything on that floor that can hurt you reads. It carries no position -
## a rhythm is not anywhere - so like the two beats it travels into the scene as
## a single node with its numbers as exports, and a floor without the key gets
## no node and no rhythm. See game/levels/studio.gd.
const STUDIO_SCRIPT := "res://game/levels/studio.gd"
## The one hazard in the game that moves, under `dolly`: a rig running a rail
## while a take is rolling. A fixture rather than a prop, exactly like the
## torch, because a level places its own hazards; the rail it runs on is
## ordinary furniture (`rail` on the markings shelf) and the two are authored
## next to each other.
const DOLLY_SCRIPT := "res://game/levels/dolly.gd"
## The other moving hazard, under `surge`: a short racing the cable trunking.
## Unlike every other thing a level places, it has NO art file - it draws its
## own conduit and its own spark from the two points it is authored with, which
## is what keeps the lane a player reads and the lane that hurts from ever
## coming apart. So there is no scene to write and nothing to delete; the nodes
## are built straight into the level.
const SURGE_SCRIPT := "res://game/levels/surge.gd"
## The THIRD moving hazard, under `scrubbers`, and the only one with no route:
## a floor scrubber that picks a heading, runs until the room stops it, and
## picks another. It is a solid body rather than an area - being in the way is
## half of what it is - so unlike the other two it is a CharacterBody2D, and
## what keeps it off the door lane is the `within` pen rather than an authored
## span. See game/levels/scrubber.gd.
const SCRUBBER_SCRIPT := "res://game/levels/scrubber.gd"
## How dark the conduit is on the room's own ramp. A piece of the building, so
## it takes the building's metal - only what FIRES is fixed.
const CONDUIT_TONE := 0.22


## Names passed after `--` build only those levels. Since a re-run overwrites
## hand-dressing, adding one floor to a chain of eight must not mean re-rolling
## the seven that are already dressed:
##   godot --headless --path . --script res://tools/build_levels.gd -- lobby
func _initialize() -> void:
	var only := OS.get_cmdline_user_args()
	var failed := false
	for level in Biomes.CHAIN:
		if not only.is_empty() and not only.has(level):
			continue
		print(level, ":")
		failed = _build(level) or failed
	for name in only:
		if not Biomes.CHAIN.has(name):
			printerr("unknown level '%s' - not in Biomes.CHAIN" % name)
			failed = true
	quit(1 if failed else 0)


func _build(level: String) -> bool:
	var spec: Dictionary = Biomes.BIOMES[level]
	var dir: String = Biomes.dir(level)
	var props: String = Biomes.props_dir(level)
	var tileset := load("%s/tileset.tres" % dir) as TileSet
	if tileset == null:
		printerr("  missing %s/tileset.tres - run tools/build_biomes.gd first" % dir)
		return true
	DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path("%s/fixtures" % props))

	# The room's own files stay at the level's root - the level scene, its door,
	# and the tileset and doorways build_biomes.gd wrote. Everything that STANDS
	# in the room goes in props/, one scene each with its picture baked in.
	var bad := false
	bad = _write_door_scene(dir) or bad
	if Biomes.has_columns(level):
		bad = _write_column_scene(props, spec) or bad
	else:
		_drop("%s/fixtures/column.tscn" % props)
	if Biomes.has_hazard(level):
		bad = _write_torch_scene(props, spec) or bad
	else:
		# A floor that stops having a hazard stops having the scene for one:
		# otherwise the level folder keeps a torch nothing points at, and the
		# next reader has to open the biome to find out which is the truth.
		_drop("%s/fixtures/torch.tscn" % props)
	if Biomes.has_heart(level):
		bad = _write_health_scene(props, spec) or bad
	else:
		_drop("%s/fixtures/health_item.tscn" % props)
	# The moving hazard, on the same terms as the two standing ones: written
	# where the biome asks for it and DELETED where it does not, so a level
	# folder never keeps a rig nothing points at.
	if not spec.get("dolly", {}).is_empty():
		bad = _write_dolly_scene(props, spec) or bad
	else:
		_drop("%s/fixtures/dolly.tscn" % props)
	# The wandering one. Same terms again: written where the biome asks and
	# deleted where it does not.
	if not spec.get("scrubbers", []).is_empty():
		bad = _write_scrubber_scene(props, spec) or bad
	else:
		_drop("%s/fixtures/scrubber.tscn" % props)
	for type in Biomes.prop_types(level):
		bad = _write_prop_scene(props, type, spec) or bad
	bad = _write_level_scene(level, dir, props, tileset) or bad
	return bad


## The level's own pillar, art baked in. No script: a column has no behaviour to
## share, and a level that wants one adds it here without affecting any other.
func _write_column_scene(dir: String, spec: Dictionary) -> bool:
	var root := StaticBody2D.new()
	root.name = "Column"

	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.centered = false
	# Origin at the foot of the column: that is what Y-sorting reads to decide
	# whether the player draws in front of it or behind it.
	sprite.position = Vector2(-8, -48)
	sprite.texture = Props.texture(Props.column(spec))
	root.add_child(sprite)
	sprite.owner = root

	var body := CollisionShape2D.new()
	body.name = "CollisionShape2D"
	body.position = Vector2(0, -3)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(11, 6)
	body.shape = shape
	root.add_child(body)
	body.owner = root

	return _pack(root, "%s/fixtures/column.tscn" % dir)


## One piece of furniture, art baked in, in the level's own folder like every
## other prop a level owns. A solid prop blocks only its base - the same trick
## the column uses, so the player passes behind its upper half and Y-sorting
## draws the two in the right order. Decor gets a bare Node2D: a banner nailed
## to a wall has nothing to walk into, and a body with no shape is a lie.
##
## Furniture mostly has no behaviour to share, and gets no script. The ones that
## grow some say so themselves, in two optional constants on their painter, and
## the studio's lighting is the first to use either:
##
##   SCRIPT   goes on the prop, for a thing that changes what it looks like -
##            the neon sign reading the floor's clock.
##   BURNS    adds a `Burn` Area2D at the foot carrying BURN_SCRIPT, for a thing
##            that hurts - the ring lights going hot during a take.
##
## They are separate nodes because they are separate sizes: a lamp BLOCKS with
## its tripod and BURNS across a patch of floor several times wider, and one
## node cannot be a solid body and a trigger at two sizes. A prop declaring
## neither is written exactly as it always was.
func _write_prop_scene(dir: String, type: String, spec: Dictionary) -> bool:
	# The friendly failure: a biome placing a type tools/props/ has no file for
	# should say so, not die inside a null texture three calls later.
	if not Props.known(type):
		printerr("  nothing in tools/props/ draws '%s'" % type)
		return true
	var blocks := Props.blocks(type)
	var solid := blocks != Vector2.ZERO
	var root: Node2D = StaticBody2D.new() if solid else Node2D.new()
	root.name = type.to_pascal_case()
	# Before any child, so a script that reaches for one in _ready finds the
	# finished prop rather than half of it.
	var behaviour := Props.script_of(type)
	if behaviour != "":
		root.set_script(load(behaviour))

	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.centered = false
	# Props.offset() puts the art's foot on the origin, which is the pixel
	# Y-sorting reads and the pixel the biome's position refers to.
	sprite.position = Props.offset(type)
	sprite.texture = Props.texture(Props.paint(type, spec))
	root.add_child(sprite)
	sprite.owner = root

	if solid:
		var body := CollisionShape2D.new()
		body.name = "CollisionShape2D"
		body.position = Vector2(0, -blocks.y / 2.0)
		var shape := RectangleShape2D.new()
		shape.size = blocks
		body.shape = shape
		root.add_child(body)
		body.owner = root

	# The heat, where the prop declares any. Centred ON the placement position
	# rather than sitting above it like the torch's box: this is a pool of light
	# lying on the floor, and the foot is its middle.
	var burns := Props.burns(type)
	if burns != Vector2.ZERO:
		var burn := Area2D.new()
		burn.name = "Burn"
		burn.monitorable = false
		burn.set_script(load(Props.burn_script(type)))
		root.add_child(burn)
		burn.owner = root
		var burn_shape := CollisionShape2D.new()
		burn_shape.name = "CollisionShape2D"
		var burn_rect := RectangleShape2D.new()
		burn_rect.size = burns
		burn_shape.shape = burn_rect
		burn.add_child(burn_shape)
		burn_shape.owner = root

	# The scene lands on the same shelf its painter sits on in tools/props/,
	# so finding a prop in a level is the same walk as finding its brush.
	var shelf := Props.shelf_of(type)
	DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path("%s/%s" % [dir, shelf]))
	return _pack(root, "%s/%s/%s.tscn" % [dir, shelf, type])


## The level's own door. Origin sits at the centre of the gap in the wall ring,
## so a south door is the same scene rotated half a turn.
func _write_door_scene(dir: String) -> bool:
	var root := Area2D.new()
	root.name = "Door"
	root.monitorable = false
	root.set_script(load(DOOR_SCRIPT))
	root.add_to_group("door", true)

	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.centered = false
	sprite.position = Vector2(-16, -8)
	root.add_child(sprite)
	sprite.owner = root

	# Closes the gap the doorway was cut into. The map stays sealed whether or
	# not the transition fires, and a locked door keeps this body while its art
	# goes dark.
	var seal := StaticBody2D.new()
	seal.name = "Seal"
	root.add_child(seal)
	seal.owner = root
	var seal_shape := CollisionShape2D.new()
	seal_shape.name = "CollisionShape2D"
	var seal_rect := RectangleShape2D.new()
	seal_rect.size = Vector2(TILE * 2, TILE)
	seal_shape.shape = seal_rect
	seal.add_child(seal_shape)
	seal_shape.owner = root

	# The threshold you actually walk onto, on the floor just inside the arch.
	# Snug against the seal: further out and the player can scrape past the
	# trigger along the wall. This was tuned by hand in the dressed doors and the
	# generator used to write 38, so regenerating a door silently undid it.
	var trigger := CollisionShape2D.new()
	trigger.name = "CollisionShape2D"
	trigger.position = Vector2(0, 13)
	var trigger_rect := RectangleShape2D.new()
	trigger_rect.size = Vector2(26, 10)
	trigger.shape = trigger_rect
	root.add_child(trigger)
	trigger.owner = root

	return _pack(root, "%s/door.tscn" % dir)


## The level's own standing torch: walking into the fire hurts. Behaviour is
## the shared hazard_base.gd; the art, shape and anything extra are this
## level's to change.
func _write_torch_scene(dir: String, spec: Dictionary) -> bool:
	var root := Area2D.new()
	root.name = "Torch"
	root.monitorable = false
	root.set_script(load(HAZARD_SCRIPT))

	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.centered = false
	# Foot origin, like the column: what Y-sorting reads.
	sprite.position = Vector2(-8, -24)
	sprite.texture = Props.texture(Props.hazard(spec))
	root.add_child(sprite)
	sprite.owner = root

	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	shape.position = Vector2(0, -3)
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 6)
	shape.shape = rect
	root.add_child(shape)
	shape.owner = root

	return _pack(root, "%s/fixtures/torch.tscn" % dir)


## The level's own camera dolly: the one hazard in the game that MOVES. Written
## exactly like the torch - the level's own art, the level's own scene, shared
## behaviour - because it is the same kind of thing. What differs is that its
## script carries the two ends of the rail and a speed, handed in from the biome
## where the scene is placed rather than baked in here, so the rig and the rail
## painted under it are authored as one pair of numbers.
func _write_dolly_scene(dir: String, spec: Dictionary) -> bool:
	var root := Area2D.new()
	root.name = "Dolly"
	root.monitorable = false
	root.set_script(load(DOLLY_SCRIPT))

	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.centered = false
	# The painter pins its own foot - the wheels, which have to land on the
	# rail - so the offset comes from the art rather than from a number here.
	sprite.position = Props.offset("dolly")
	sprite.texture = Props.texture(Props.dolly(spec))
	root.add_child(sprite)
	sprite.owner = root

	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	# Over the platform rather than over the whole rig: the camera head is at
	# eye height and passes over anybody standing on the track, and what would
	# actually hit them is the base going past their shins.
	shape.position = Vector2(0, -7)
	var rect := RectangleShape2D.new()
	rect.size = Vector2(22, 14)
	shape.shape = rect
	root.add_child(shape)
	shape.owner = root

	return _pack(root, "%s/fixtures/dolly.tscn" % dir)


## The level's own floor scrubber. The one hazard in the game that is a BODY
## rather than a trigger: being in the way is half of what it does, so the
## player walks into it and it walks into the furniture, which is also the only
## thing deciding where it goes.
func _write_scrubber_scene(dir: String, spec: Dictionary) -> bool:
	var root := CharacterBody2D.new()
	root.name = "Scrubber"
	root.set_script(load(SCRUBBER_SCRIPT))
	# Straight into whatever it hits, with no sliding along it: a slide would
	# let the machine skim a wall for half a room, and what makes its route
	# unpredictable is turning at every contact instead.
	root.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	root.wall_min_slide_angle = PI
	# Everything solid, on the one layer the whole game shares. Nothing about
	# where this machine goes is authored - the furniture decides - so anything
	# it could drive straight through would be furniture that had been taken
	# out of the room.

	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.centered = false
	sprite.position = Props.offset("scrubber")
	sprite.texture = Props.texture(Props.scrubber(spec))
	root.add_child(sprite)
	sprite.owner = root

	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	# Centred on the shell rather than sitting above the foot like a torch's
	# box: this thing has no upper half to walk behind, it is all base.
	shape.position = Vector2(0, -5)
	# A rectangle under a round shell, like every other solid body here. A disc
	# would be truer to the picture and worse to play against: axis-aligned
	# contact normals are what make a bounce off a desk read as a bounce off
	# that desk, where a circle glancing a corner turns by some angle nobody can
	# see a reason for. The shape is Props.blocks() so the painter still owns it.
	var disc := RectangleShape2D.new()
	disc.size = Props.blocks("scrubber")
	shape.shape = disc
	root.add_child(shape)
	shape.owner = root

	return _pack(root, "%s/fixtures/scrubber.tscn" % dir)


## The level's own heal pickup, on the shared pickup_base.gd.
func _write_health_scene(dir: String, spec: Dictionary) -> bool:
	var root := Area2D.new()
	root.name = "Health"
	root.monitorable = false
	root.set_script(load(PICKUP_SCRIPT))

	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.centered = false
	sprite.position = Vector2(-4, -8)
	sprite.texture = Props.texture(Props.heart())
	root.add_child(sprite)
	sprite.owner = root

	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	shape.position = Vector2(0, -4)
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	root.add_child(shape)
	shape.owner = root

	return _pack(root, "%s/fixtures/health_item.tscn" % dir)


func _write_level_scene(level: String, dir: String, props_dir: String, tileset: TileSet) -> bool:
	var root := Node2D.new()
	root.name = Biomes.BIOMES[level]["node"]
	root.y_sort_enabled = true
	root.set_script(load(LEVEL_SCRIPT))
	root.set("display_name", Biomes.BIOMES[level].get("title", ""))
	root.set("music", Biomes.BIOMES[level].get("music", ""))
	# The walk between the two doors, where it is not the straight one every
	# rectangular floor has. Written in beside the title for the same reason
	# that is: it is a fact about the ROOM, and the alternative was four test
	# suites agreeing with each other by hand about a shape only one floor has.
	var legs: Array[Rect2] = []
	for leg: Rect2 in Biomes.BIOMES[level].get("lane", []):
		legs.append(leg)
	root.set("lane", legs)

	var plan := Plan.new(Biomes.BIOMES[level].get("shape", {}))
	var floor_layer := _layer("Floor", tileset, root)
	var walls := _layer("Walls", tileset, root)
	walls.y_sort_enabled = true
	_paint(floor_layer, walls, plan)

	var props := Node2D.new()
	props.name = "Props"
	props.y_sort_enabled = true
	root.add_child(props)
	props.owner = root

	# The colonnade, unless this floor asked for none: DESIGN.md's gym is a
	# tight arena with nothing in it to hide behind, and a biome says so by
	# handing in an empty `columns` layout.
	if Biomes.has_columns(level):
		var layout: Dictionary = Biomes.BIOMES[level].get("columns", {})
		var column_rows: Array = layout.get("rows", COLUMN_ROWS)
		var column_xs: Array = layout.get("xs", COLUMN_XS)
		var column_scene := _reload("%s/fixtures/column.tscn" % props_dir)
		for row in column_rows:
			for col in column_xs:
				# A colonnade is a cross product, and on a shaped floor part of
				# one can land in the building rather than in the room. Skipped
				# rather than reported: the rows and xs are the rhythm the room
				# is dressed to, and a rhythm that has to dodge a corner is not
				# one anybody would want to author by hand.
				if plan.solid(col, row + 1):
					continue
				var column := column_scene.instantiate()
				column.name = "Column_%d_%d" % [col, row]
				column.position = Vector2(col * TILE + TILE / 2, (row + 1) * TILE)
				props.add_child(column)
				column.owner = root

	# The hazard is per-biome, and a room is allowed to have nothing in it that
	# hurts: see Biomes.has_hazard().
	if Biomes.has_hazard(level):
		var torch := _reload("%s/fixtures/torch.tscn" % props_dir).instantiate()
		torch.name = "Torch"
		torch.position = Biomes.BIOMES[level].get("hazard_at", TORCH_POS)
		props.add_child(torch)
		torch.owner = root

	# The moving hazard, parked at the end of its rail. Placed here rather than
	# from the props list because it is a fixture like the torch; what makes it
	# different from every other thing in this game that hurts is that `from`
	# and `to` are two positions instead of one, and it is somewhere between
	# them for most of a take.
	var dolly: Dictionary = Biomes.BIOMES[level].get("dolly", {})
	if not dolly.is_empty():
		var rig := _reload("%s/fixtures/dolly.tscn" % props_dir).instantiate()
		rig.name = "Dolly"
		rig.set("from", dolly["from"])
		rig.set("to", dolly["to"])
		_carry(rig, dolly, ["speed", "damage"])
		rig.position = dolly["from"]
		props.add_child(rig)
		rig.owner = root

	# The machines, where the floor runs any. They carry a starting position
	# like a placed prop and a PEN like nothing else does - `within` is what
	# keeps the door lane walkable on a floor whose hazard has no route to
	# inspect, and what stops the hub's two halves bleeding into each other.
	var machines: Array = Biomes.BIOMES[level].get("scrubbers", [])
	for i in machines.size():
		var machine: Dictionary = machines[i]
		var bot := _reload("%s/fixtures/scrubber.tscn" % props_dir).instantiate()
		bot.name = "Scrubber%d" % (i + 1)
		bot.position = machine["at"]
		bot.set("within", machine["within"])
		_carry(bot, machine, ["speed", "damage", "push", "turn_seconds"])
		props.add_child(bot)
		bot.owner = root

	# The faults in the wiring, where the floor has any. One node per run, built
	# here rather than instanced from a scene because a surge has no picture -
	# it draws its conduit and its spark from the same two points, so there is
	# nothing to bake and nothing to keep in step.
	var surge: Dictionary = Biomes.BIOMES[level].get("surge", {})
	var runs: Array = surge.get("runs", [])
	for i in runs.size():
		var run: Dictionary = runs[i]
		var fault := Area2D.new()
		fault.name = "Surge%d" % (i + 1)
		fault.monitorable = false
		# Under everybody. A short is in the floor, and a player crossing one
		# should have it pass beneath their feet rather than over their head.
		fault.z_index = -1
		fault.set_script(load(SURGE_SCRIPT))
		fault.set("from", run["from"])
		fault.set("to", run["to"])
		# The numbers a floor sets once for all its runs, and the one it sets
		# per run: `after` is what stops four lines from firing as one. Copied
		# across only where the biome names them, so a value the data does not
		# mention keeps whatever surge.gd declares - see _carry().
		_carry(fault, surge, ["speed", "period", "charge", "damage"])
		_carry(fault, run, ["after"])
		fault.set("conduit", Biomes.shade(Biomes.BIOMES[level], CONDUIT_TONE))
		props.add_child(fault)
		fault.owner = root
		var head := CollisionShape2D.new()
		head.name = "CollisionShape2D"
		var ball := CircleShape2D.new()
		# The head only. A surge is one hit as it passes, never a lane you are
		# caught inside - see game/levels/surge.gd.
		ball.radius = 6.0
		head.shape = ball
		fault.add_child(head)
		head.owner = root

	# Same as the hazard: a heart is per-biome, and almost no floor has one.
	if Biomes.has_heart(level):
		var health := _reload("%s/fixtures/health_item.tscn" % props_dir).instantiate()
		health.name = "Health"
		health.position = Biomes.BIOMES[level].get("heart_at", HEALTH_POS)
		props.add_child(health)
		health.owner = root

	# The biome's furniture, from the same list that decided which art to paint.
	# Suffixed by type the way enemies are numbered, so two desks are Desk1 and
	# Desk2 rather than a name collision the packer would silently rename.
	var placed := {}
	for spec in Biomes.BIOMES[level].get("props", []):
		var type: String = spec["type"]
		if not Props.known(type):
			continue   # _write_prop_scene already reported it; do not cascade
		placed[type] = placed.get(type, 0) + 1
		var prop := _reload("%s/%s/%s.tscn"
				% [props_dir, Props.shelf_of(type), type]).instantiate()
		prop.name = "%s%d" % [type.to_pascal_case(), placed[type]]
		prop.position = spec["at"]
		# Rotation is placement, not art: the banner is drawn square and hung
		# crooked, so the same cloth can hang straight somewhere else.
		prop.rotation = spec.get("turn", 0.0)
		props.add_child(prop)
		prop.owner = root

	var roster: Array = Biomes.BIOMES[level].get("enemies", [])
	for i in roster.size():
		var spec: Dictionary = roster[i]
		var type: String = spec["type"]
		var enemy := _reload(ENEMY_SCENE % [type, type]).instantiate()
		enemy.name = "Enemy%d" % (i + 1)
		enemy.position = spec["at"]
		props.add_child(enemy)
		enemy.owner = root

	# The NPCs. After the enemies so the two lists read in the order the room
	# is populated, and carrying their dialogue with them: which conversation
	# an NPC has is placement, exactly as which way it faces is - the same
	# person greets you on one floor and warns you on another.
	var people: Array = Biomes.BIOMES[level].get("npcs", [])
	for i in people.size():
		var spec: Dictionary = people[i]
		var npc_id: String = spec["id"]
		var npc := _reload(NPC_SCENE % [npc_id, npc_id]).instantiate()
		npc.name = npc_id.to_pascal_case()
		npc.position = spec["at"]
		npc.set("facing", spec.get("facing", "down"))
		npc.set("face_left", spec.get("face_left", false))
		npc.set("conversation", spec.get("conversation", ""))
		npc.set("greets", spec.get("greets", false))
		props.add_child(npc)
		npc.owner = root

	var boss: Dictionary = Biomes.BIOMES[level].get("boss", {})
	if not boss.is_empty():
		var boss_type: String = boss["type"]
		var boss_node := _reload(BOSS_SCENE % [boss_type, boss_type]).instantiate()
		boss_node.name = "Boss"
		boss_node.position = boss["at"]
		props.add_child(boss_node)
		boss_node.owner = root

	var door_scene := _reload("%s/door.tscn" % dir)
	var next: String = Biomes.next_of(level)
	if next != "":
		# A boss floor's way up is shut until the boss concedes.
		_add_door(props, root, door_scene, dir, "Exit", "out",
			plan.door_at(plan.out_col, 0), 0.0,
			next, &"start", BOSS_DOOR if not boss.is_empty() else "")
	var previous: String = Biomes.previous_of(level)
	if previous != "":
		# Half a turn puts the same scene's art, seal and threshold in the
		# south wall, facing back into the room.
		_add_door(props, root, door_scene, dir, "Return", "back",
			plan.door_at(plan.back_col, plan.rows - 1), PI,
			previous, &"returned")
	_cut_doorways(walls, plan, next != "", previous != "")

	var spawns := Node2D.new()
	spawns.name = "Spawns"
	root.add_child(spawns)
	spawns.owner = root
	# Each under its own door, which on a shaped floor are not in line with each
	# other: the call floor's way up is in an arm off the far end of the room,
	# so arriving back down it puts you there and not over the room you left by.
	_marker(spawns, root, "start", plan.start_at())
	_marker(spawns, root, "returned", plan.returned_at())
	# A floor may name markers of its own, and there is exactly one thing they
	# are for: a reinforcement names a marker instead of carrying a position, so
	# a beat that arrives anywhere but the two doors needs a name to arrive at.
	# The executive floor's chokepoint is the first, and it is also the case
	# that could not be an authored `at`: the gap is on the door line, where
	# nothing may be placed.
	var extra: Dictionary = Biomes.BIOMES[level].get("spawns", {})
	for spawn_name in extra:
		_marker(spawns, root, String(spawn_name), extra[spawn_name])

	# The floor's CLOCK, where its biome runs one. Written before the two beats
	# because it is not one: a beat fires once and is spent, and this is a
	# rhythm the room keeps for as long as the player is standing in it.
	#
	# It joins the `studio` group PERSISTENTLY, which is the load-bearing
	# detail: a persistent group is recorded in the scene and applied the moment
	# a node enters the tree, so every light, sign and rig in the room finds the
	# clock in its own _ready without anybody having to be built first.
	var clock: Dictionary = Biomes.BIOMES[level].get("studio", {})
	if not clock.is_empty():
		var studio := Node2D.new()
		studio.name = "Studio"
		studio.set_script(load(STUDIO_SCRIPT))
		studio.add_to_group("studio", true)
		_carry(studio, clock, ["take", "rest", "lead"])
		root.add_child(studio)
		studio.owner = root

	# The floor's second beat, where its biome asks for one. Written AFTER the
	# spawns because that is what it walks in through: a reinforcement names a
	# marker instead of carrying a position, which is the whole reason the list
	# fits on one node instead of needing an instance placed per enemy.
	var beats: Array = Biomes.BIOMES[level].get("reinforcements", [])
	if not beats.is_empty():
		var reinforcements := Node2D.new()
		reinforcements.name = "Reinforcements"
		reinforcements.set_script(load(REINFORCEMENTS_SCRIPT))
		reinforcements.set("waves", beats)
		root.add_child(reinforcements)
		reinforcements.owner = root

	# The beats that are not fights, and there are two of them now: Ivan walking
	# in with a heart per head once the room is finally empty, and Dominique
	# coming down the stairs on the floor below a boss to say what is waiting at
	# the top. One script serves both - relief.gd names nobody - so the pair is
	# two nodes named by ROLE rather than two scripts, and a floor can carry one,
	# the other, or both. Written after the second beat because both WAIT on it:
	# a room between two arrivals is quiet rather than clear.
	for beat: Array in [["relief", "Relief", "ivan"],
			["briefing", "Briefing", "dominique"]]:
		var arriving: Dictionary = Biomes.BIOMES[level].get(beat[0], {})
		if arriving.is_empty():
			continue
		var arrival := Node2D.new()
		arrival.name = beat[1]
		arrival.set_script(load(RELIEF_SCRIPT))
		arrival.set("npc", arriving.get("npc", beat[2]))
		arrival.set("from", StringName(arriving.get("from", "start")))
		arrival.set("at", arriving["at"])
		arrival.set("say", arriving.get("say", ""))
		root.add_child(arrival)
		arrival.owner = root

	# The plain version of the third beat: hearts on the floor once the room is
	# clear, with nobody bringing them. Written after the second beat for the
	# reason the arrivals are - it waits on it.
	if Biomes.BIOMES[level].get("reward", false):
		var reward := Node2D.new()
		reward.name = "Reward"
		reward.set_script(load(REWARD_SCRIPT))
		root.add_child(reward)
		reward.owner = root

	return _pack(root, "%s/%s.tscn" % [dir, level])


func _add_door(props: Node2D, root: Node2D, scene: PackedScene, dir: String,
		node_name: String, art: String, at: Vector2, turn: float,
		target: String, spawn: StringName, script_path := "") -> void:
	var door := scene.instantiate()
	# Swapped before any property is set: a new script starts from its own
	# defaults, so setting them first would only lose them.
	if script_path != "":
		door.set_script(load(script_path))
	door.name = node_name
	door.position = at
	door.rotation = turn
	door.art = load("%s/doorway_%s.tres" % [dir, art]) as Texture2D
	door.target_level = "%s/%s.tscn" % [Biomes.dir(target), target]
	door.target_spawn = spawn
	props.add_child(door)
	door.owner = root


## One tile of wall all the way round whatever shape the room is, with the
## floor pattern inside it. Which cell is which, and which of the three wall
## tiles it takes, is tools/plan.gd's - see there for why a room is a predicate
## rather than a list of cases.
##
## Only the FACE of the building is painted - `plan.drawn()` - so a cut comes
## out as a hole with the clear colour showing through it rather than as a slab
## of the level's own rock. That hole is the point: it is the void the camera
## already leaves around a small room, arriving in the middle of the map, and
## it is what the call floor's missing corner is meant to look like. On the
## eleven rectangular floors nothing is skipped, because every solid cell they
## have is that face.
func _paint(floor_layer: TileMapLayer, walls: TileMapLayer, plan: RefCounted) -> void:
	for row in plan.rows:
		for col in plan.cols:
			var at := Vector2i(col, row)
			if plan.solid(col, row):
				if plan.drawn(col, row):
					walls.set_cell(at, 0, plan.wall_tile(col, row))
			else:
				floor_layer.set_cell(at, 0, plan.floor_tile(col, row))


## Removes the wall tiles a doorway stands in, so the arch reads as a way
## through the border rather than something parked in front of it. The door
## scene's own Seal body keeps the hole closed.
func _cut_doorways(walls: TileMapLayer, plan: RefCounted,
		north: bool, south: bool) -> void:
	for pair in [[north, 0, plan.out_col], [south, plan.rows - 1, plan.back_col]]:
		if not pair[0]:
			continue
		for col in plan.doorway_cols(pair[2]):
			walls.erase_cell(Vector2i(col, pair[1]))


func _layer(name: String, tileset: TileSet, root: Node2D) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = name
	layer.tile_set = tileset
	root.add_child(layer)
	layer.owner = root
	return layer


func _marker(parent: Node2D, root: Node2D, name: String, at: Vector2) -> void:
	var marker := Marker2D.new()
	marker.name = name
	marker.position = at
	parent.add_child(marker)
	marker.owner = root


## Copies the keys a biome actually named onto a node it just built, and the
## keys it did not name are LEFT ALONE.
##
## The alternative was `node.set(key, data.get(key, 78.0))`, which quietly puts
## a second copy of every default in this file. Godot serializes only the
## properties that differ from a script's declared default, so a biome authoring
## the same number the script already declares writes nothing into the scene -
## and the day somebody retunes the script, every floor that had agreed with it
## follows along without its own data changing. Naming a default in exactly one
## place (the `@export` itself) is what makes that impossible.
func _carry(node: Node, data: Dictionary, keys: Array) -> void:
	for key: String in keys:
		if data.has(key):
			node.set(key, data[key])


## Reads a scene back off disk so the instance carries a scene_file_path -
## without one, pack() would inline its nodes instead of recording a reference.
func _reload(path: String) -> PackedScene:
	return ResourceLoader.load(path, "PackedScene",
		ResourceLoader.CACHE_MODE_REPLACE) as PackedScene


func _pack(root: Node, path: String) -> bool:
	var packed := PackedScene.new()
	var err := packed.pack(root)
	var kept_uid := StableIds.uid_of(path)
	if err == OK:
		err = ResourceSaver.save(packed, path)
	if err == OK:
		StableIds.stabilize(path, kept_uid)
	print("  ", path, " -> ", error_string(err))
	# This tree was never in the SceneTree, so nothing else will ever free it.
	root.free()
	return err != OK


## Removes a scene this level no longer has any use for. Only the fixtures can
## reach this - a floor that gives up its hazard - because they are the ones
## written unconditionally; a prop scene is written from the biome's own list,
## so it simply never appears.
func _drop(path: String) -> void:
	if FileAccess.file_exists(path):
		var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		print("  ", path, " -> removed, ", error_string(err))
