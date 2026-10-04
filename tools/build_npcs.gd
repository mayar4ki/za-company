extends SceneTree
## Generates SpriteFrames for the NPCs - one <id>_frames.tres per entry, cut
## from THAT NPC'S OWN sheet in game/npcs/<id>/src/<id>.png.
##
## Seed once, slice always - the same two steps, in the same order, as
## build_enemies.gd:
##
## - **Seeding** writes the source sheet, and only ever when it is missing. It
##   restyles the cast body per the roster recipe, then hands the result to
##   npc_art.gd, which rebuilds it at double height in a robe and returns a
##   64px sheet.
## - **Slicing** happens every run, on whatever sheet is actually on disk.
##
## So from the moment it exists the sheet is HAND-OWNED ART, and the recipe
## never touches it again. Deleting an NPC's PNG and re-running is how you start
## that NPC's art over from the cast body.
##
## The seed comes from the CAST sheet, not the enemies' frozen body copy, and
## that is deliberate: an NPC is a colleague, drawn to the same proportions as
## the people the player recognises, and a new cast animation is one an NPC
## could plausibly want. Enemies are the opposite case, which is why they have
## their own frozen seed.
##
## It also writes THE LOOSE HEART - `game/heart.tscn`, the pickup Ivan throws
## and a cleared room drops (game/levels/reward.gd). It sits at game/ because
## those two share it, and it is written here because Ivan's was the first,
## which is the one place this generator crosses into territory build_levels.gd
## otherwise owns. A room's own heart is dressing on a stand and takes the
## room's palette with it; a loose one is the same red on every floor, so there
## is one file rather than a copy in every level folder. The art is the same painter the lobby's heart uses (tools/props/),
## which has no palette input - a heart is a heart.
##
## Run: godot --headless --path . --script res://tools/build_npcs.gd

const Art := preload("res://tools/character_art.gd")
const Props := preload("res://tools/props.gd")
const StableIds := preload("res://tools/stable_ids.gd")
const NpcArt := preload("res://tools/npc_art.gd")
const Roster := preload("res://game/npcs/roster.gd")

## The cast's own living sheet. An NPC is seeded from the same body the seven
## characters share - see the note above.
const SEED_SRC := "res://game/player/src/character_cc0.png"

## The loose heal pickup - Ivan's throw, a cleared room's drop - and the script it runs on - the same one every
## level's own heart uses, because the player heals by walking onto a thing and
## it should not matter whose thing it is.
const HEART_SCENE := "res://game/heart.tscn"
const PICKUP_SCRIPT := "res://game/levels/pickup_base.gd"


func _initialize() -> void:
	var failed := false
	for entry in Roster.NPCS:
		if not _build(entry):
			failed = true
	if _write_heart():
		failed = true
	quit(1 if failed else 0)


## The loose heart: the shared pickup_base.gd with the shared heart art, and
## nothing else. Deliberately identical in shape to a level's own health item
## (tools/build_levels.gd's `_write_health_scene`) so the player cannot tell
## which hand a heart came out of - what differs is who put it there.
##
## `monitoring` is left ON here and turned OFF by the throw for the length of
## the flight (game/npcs/ivan/hearts.gd): a heart is a thing you walk onto, and
## one that could be collected mid-air would be collected out of Ivan's hand.
func _write_heart() -> bool:
	var root := Area2D.new()
	root.name = "Heart"
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

	var packed := PackedScene.new()
	var err := packed.pack(root)
	var kept_uid := StableIds.uid_of(HEART_SCENE)
	if err == OK:
		err = ResourceSaver.save(packed, HEART_SCENE)
	if err == OK:
		StableIds.stabilize(HEART_SCENE, kept_uid)
	print("  ", HEART_SCENE, " -> ", error_string(err))
	root.free()
	return err != OK


func _build(entry: Dictionary) -> bool:
	var id: String = entry["id"]
	var src: String = entry["src"]
	print(id, ":")

	if not FileAccess.file_exists(src):
		if not entry.has("recipe"):
			printerr("  no sheet at %s and no recipe to seed one from" % src)
			return false
		var styled := Art.restyle(SEED_SRC, entry["recipe"])
		if styled == null:
			printerr("  could not load the seed body ", SEED_SRC)
			return false
		var seeded := NpcArt.build(styled, entry["recipe"], entry.get("robe", {}))
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(src.get_base_dir()))
		var wrote := seeded.save_png(ProjectSettings.globalize_path(src))
		if wrote != OK:
			printerr("  could not write ", src, " -> ", error_string(wrote))
			return false
		print("  seeded ", src, " (hand-owned from here on)")

	# Always from the file on disk, never from the recipe: whatever has been
	# drawn into that sheet since it was seeded is what the NPC looks like.
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(src))
	if sheet == null:
		printerr("  could not read ", src)
		return false
	sheet.convert(Image.FORMAT_RGBA8)

	var frames := Art.slice(sheet,
		entry.get("layout", Roster.LAYOUT),
		entry.get("specs", Roster.SPECS),
		NpcArt.CELL)
	var out: String = entry["frames"]
	var err := ResourceSaver.save(frames, out)
	print("  ", out, " -> ", error_string(err))
	return err == OK
