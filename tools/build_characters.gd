extends SceneTree
## Generates SpriteFrames for the playable cast - one <id>_frames.tres per
## roster recipe, all restyled from the one pristine CC0 sheet in
## game/player/src/.
##
## The cast sharing a sheet is deliberate and permanent: every character plays
## the same game with the same moves, so they will always want the same
## animation set, and a new move drawn once lands on all ten at no cost.
## Enemies are the opposite case and have their own generator - see
## tools/build_enemies.gd.
##
## Run: godot --headless --path . --script res://tools/build_characters.gd

const Art := preload("res://tools/character_art.gd")
const Roster := preload("res://game/player/characters/roster.gd")

## The cast's sheet. Living art: unlike the frozen body enemies are seeded from
## (game/enemies/src/body_cc0.png), this one is meant to grow.
const SRC := "res://game/player/src/character_cc0.png"

## What the cast's sheet holds, and the ONE place to edit when it grows.
##
## Deliberately the cast's own copy rather than character_art.gd's CC0_LAYOUT,
## even though the two are identical today. They describe different things: that
## one is a fact about a frozen file, this one is a description of art under
## active development. Draw a new row into the sheet, add it here, and the ten
## characters pick it up with nothing else in the game moving - which is exactly
## what sharing one constant would have prevented.
const CAST_LAYOUT := {
	"down": {"idle": 0, "walk": 1, "attack": 6, "attack2": 9,
		"charge": 12, "heavy": 15, "wildfire": 18, "attack3": 21, "dodge": 24},
	"up": {"idle": 2, "walk": 3, "attack": 7, "attack2": 10,
		"charge": 13, "heavy": 16, "wildfire": 19, "attack3": 22, "dodge": 25},
	"side": {"idle": 4, "walk": 5, "attack": 8, "attack2": 11,
		"charge": 14, "heavy": 17, "wildfire": 20, "attack3": 23, "dodge": 26},
}
const CAST_SPECS := {
	"idle": {"frames": 1, "fps": 1.0, "loop": true},
	"walk": {"frames": 4, "fps": 10.0, "loop": true},
	"attack": {"frames": 4, "fps": 14.0, "loop": false},
	"attack2": {"frames": 4, "fps": 14.0, "loop": false},
	"attack3": {"frames": 4, "fps": 14.0, "loop": false},
	"charge": {"frames": 2, "fps": 5.0, "loop": true},
	"heavy": {"frames": 4, "fps": 14.0, "loop": false},
	"wildfire": {"frames": 4, "fps": 14.0, "loop": false},
	# The roll: four frames over player.gd's DODGE_SECONDS (0.32), 0.08 s each.
	"dodge": {"frames": 4, "fps": 12.5, "loop": false},
}

## The one row set this generator SEEDS rather than merely reads. The arc's
## three rows (21-23, `attack3`) were first drawn by tools/arc_pose.gd, and a
## sheet still too short to hold them gets them painted in and saved back
## ONCE. After that the PNG is the truth and the branch never runs again - the
## enemies' rule for their sheets, applied to the one row set of the cast's
## that was not drawn by hand. Crop the sheet back to 21 rows to re-seed.
const ArcPose := preload("res://tools/arc_pose.gd")

## The one row set that is in NO sheet on disk. The dodge's three rows (24-26,
## `dodge`) are the idle body moved about (tools/roll_pose.gd), built here from
## each character's sheet AFTER its recolour, because the recolour reshapes:
## curls and beards turned over with the ball are not the ones the Dodge Lab
## preview showed, and recolour-then-roll is what it showed, pixel for pixel,
## for all ten. Redraw an idle frame and its roll follows on the next run.
const RollPose := preload("res://tools/roll_pose.gd")


func _initialize() -> void:
	var failed := false
	if not _seed_arc():
		quit(1)
		return
	for entry in Roster.CHARACTERS:
		if not entry.has("recipe"):
			continue
		var sheet := Art.restyle(SRC, entry["recipe"])
		if sheet == null:
			printerr("Could not load ", SRC)
			quit(1)
			return
		sheet = RollPose.paint(sheet)
		var out: String = entry["frames"]
		var frames := Art.slice(sheet, CAST_LAYOUT, CAST_SPECS)
		var err := ResourceSaver.save(frames, out)
		print("saved ", out, " -> ", error_string(err))
		if err != OK:
			failed = true
	quit(1 if failed else 0)


## Paints the arc rows into the sheet if it does not have them yet. False only
## when the sheet could not be read or written.
func _seed_arc() -> bool:
	var path := ProjectSettings.globalize_path(SRC)
	var img := Image.load_from_file(path)
	if img == null:
		printerr("Could not load ", SRC)
		return false
	img.convert(Image.FORMAT_RGBA8)
	if img.get_height() >= ArcPose.ROWS_NEEDED * Art.FRAME:
		return true
	var seeded := ArcPose.seed(img)
	var err := seeded.save_png(path)
	print("seeded arc rows into ", SRC, " -> ", error_string(err))
	return err == OK
