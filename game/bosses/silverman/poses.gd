extends RefCounted
## Silverman's body and every frame of it, as data. Read by two things that
## must agree pixel for pixel: tools/bosses/silverman.gd, which PAINTS the
## sheet from it, and smear.gd, which draws his dash trail live from the row
## this file reserves for it.
##
## He is the one boss whose shape NEVER CHANGES. Ahmed's poses are an arm and
## an axe moved around a torso; Big Mo's are thirteen measurements restruck
## per frame. Silverman's are one body and two numbers - how high he is
## floating and how far down the ramp he has gone - because he is a man made of
## silver who does not walk, and a liquid that deforms while it travels reads
## as a cartoon rather than as a threat. That was tried, looked at and dropped.
##
## What follows from that is the cheap part: a row here is the SAME PICTURE at
## a different height, and `dash` is a single frame. The travel is the boss
## moving under an unchanging sprite, and the speed is drawn by smear.gd.
##
## Coordinates are BODY coordinates: column 0..17 across, row 0..34 down, his
## toes ending on row 32 - the two empty rows under them are the hover, and
## they are why he never appears to stand on anything.

## The metal, dark to bright. No hue anywhere in it: the penthouse has none
## either, which is what leaves the city on the far side of the glass as the
## only coloured thing in the room.
const PAL := {
	"#": "07080c",  # outline - the only thing keeping him off the city window
	"K": "2b3140",
	"M": "545d6e",
	"S": "8c97a8",
	"L": "c3ccd8",
	"W": "eef4fb",
}

## One step down the ramp, which is what a trailing copy of him is painted in.
## The outline never dulls, or the ghosts lose their edges before their fill.
const DULL := {"#": "#", "W": "S", "L": "S", "S": "M", "M": "K", "K": "K"}

## Poured, not dressed. No suit, no seams, no face; arms longer than a man's,
## a slight forward hang, and legs that taper to a single bright pixel. 35
## rows, the same 1x density as Ahmed - the sheet is 64 px cells and the
## scene's offset of -24 puts row 34 on his origin.
const BODY := [
	".......####.......",
	"......#SLLW#......",
	".....#SLLLLW#.....",
	".....#SLLLLL#.....",
	".....#SSLLLL#.....",
	"......#SSLL#......",
	".......#SS#.......",
	".....##MSSM##.....",
	"...##MSLLLLSM##...",
	"..#MMSLLWWLLSMM#..",
	".#MMSSLLWWLLSSMM#.",
	".#MSMSLLWWLLSMSM#.",
	".#MS#MSLWWLSM#SM#.",
	".#MS#MSLWWLSM#SM#.",
	".#MS#MSLWWLSM#SM#.",
	".#MS#.#SLWLS#.#SM#",
	".#MS#.#SLLLS#.#SM#",
	".#MS#.#SSLSS#.#SM#",
	".#ML#..#SLS#..#LM#",
	".#SL#..#SLS#..#LS#",
	".#SW#.#SSLSS#.#WS#",
	".#LW#.#SLLLS#.#WL#",
	"..##.#SSLLLSS#.##.",
	".....#SLLLLLS#....",
	".....#SLL#LLS#....",
	".....#SL#.#LS#....",
	".....#SL#.#LS#....",
	".....#SL#.#LS#....",
	".....#SW#.#WS#....",
	".....#SW#.#WS#....",
	"......#S#.#S#.....",
	"......#S#.#S#.....",
	".......#..#.......",
	"..................",
	"..................",
]

## Sheet order, one row per animation.
##
## `glare`, `split` and `prism` are his three attacks on the cycle, and they
## are the rule above proving itself: an attack row here is the same eighteen
## columns of ASCII as the idle, at a different height and a different rung.
## Everything that makes one legible is drawn live beside him - glare.gd,
## copy.gd and prism.gd - which is why three attacks cost three rows of
## nothing.
##
## `ghost` is the odd one out and is deliberate: it is a row the boss NEVER
## plays. It holds the dash pose painted one step down the ramp, and smear.gd
## pulls its texture straight out of the SpriteFrames to stamp the trail. The
## alternative was dulling a live copy with a modulate, which is a multiply
## and lands between two rungs of the ramp; a boss whose whole look is six
## exact values does not get to approximate one of them. A picture the effect
## needs is a picture, so it lives on the sheet with the others.
##
## `prism` is LAST rather than beside the other attacks, and that is the one
## rule for adding a row to a sheet that already exists: build_bosses.gd paints
## only the rows a hand-owned PNG is too short to hold, so a new row goes on
## the end or it lands on top of one somebody may have drawn into. `ceiling`
## came after `flash` on the same rule.
const ORDER := ["idle", "walk", "dash", "ghost", "glare", "split", "concede",
	"beaten", "prism", "flash", "ceiling"]

## `dy` floats the whole body; negative is up, and it is the ONLY thing that
## varies between the frames of a row. `dull` is how many steps down the ramp
## the frame is painted. There is no scale, no lean and no leg swap anywhere
## in this file - see the header.
const ANIMS := {
	# The hover. Two pixels over about a second, which is as much hurry as he
	# has ever shown.
	"idle": [
		{"dur": 0.16, "dy": 0},
		{"dur": 0.16, "dy": -1},
		{"dur": 0.16, "dy": -2},
		{"dur": 0.16, "dy": -2},
		{"dur": 0.16, "dy": -1},
		{"dur": 0.16, "dy": 0},
	],
	# The glide. The same bob taken faster, because he has nothing else to do
	# with travel - there is no walk cycle on this boss and never will be.
	"walk": [
		{"dur": 0.1, "dy": 0},
		{"dur": 0.1, "dy": -1},
		{"dur": 0.1, "dy": -2},
		{"dur": 0.1, "dy": -2},
		{"dur": 0.1, "dy": -1},
		{"dur": 0.1, "dy": 0},
	],
	# ONE FRAME, and that is the whole point of the dash. He rises a pixel and
	# holds it for the entire 0.5 s crossing; silverman.gd moves him along the
	# beats and smear.gd draws what is behind him.
	"dash": [
		{"dur": 0.5, "dy": -2},
	],
	# Never played. The dash pose, one step down the ramp - see ORDER.
	"ghost": [
		{"dur": 0.5, "dy": -2, "dull": 1},
	],
	# THE GLARE. He rises and DIMS - drawing the shine inward, two rungs of it -
	# and spends the whole lot in one frame on `impact`, where he is back at
	# full brightness and at the top of his rise. Then he settles.
	#
	# The dimming is the telegraph and it is on the sheet, which is the only
	# place it can be: his resting `dull` is already 0, so he has no room to
	# flare on a blow and nowhere to go but darker on the way to one. See
	# silverman.gd's `_windup_tint`, which is what stops the base tinting an
	# amber wind-up over a body that has no hue in it.
	#
	# 0.80 wind-up, 0.70 recover, and the band crosses the room during the
	# recover - which is why the recover is the long half.
	"glare": [
		{"dur": 0.26, "dy": -2, "dull": 1},
		{"dur": 0.27, "dy": -3, "dull": 2},
		{"dur": 0.27, "dy": -3, "dull": 2},
		{"dur": 0.20, "dy": -4, "impact": true},
		{"dur": 0.25, "dy": -3},
		{"dur": 0.25, "dy": -2},
	],
	# THE SPLIT. He does not move a pixel while he divides - no rise, no drift,
	# just two rungs of shine going out of him and coming back - because a man
	# who never hurries does not lean into becoming two of himself. The copy
	# leaves on `impact` and copy.gd carries it from there.
	"split": [
		{"dur": 0.20, "dy": -2, "dull": 1},
		{"dur": 0.20, "dy": -2, "dull": 1},
		{"dur": 0.20, "dy": -2, "dull": 2},
		{"dur": 0.20, "dy": -2, "impact": true},
		{"dur": 0.20, "dy": -1},
		{"dur": 0.20, "dy": -2},
	],
	# THE PRISM. The glare's own telegraph - he rises and dims, two rungs - taken
	# a little slower, because what follows is the longest thing he does. Then
	# the impact frame is HELD: he is at full shine for the whole 1.4 s the beam
	# sweeps, since the beam is that shine leaving him, and a body that dulled
	# back down mid-sweep would be a light switched off while it is still on.
	#
	# 1.00 wind-up, 1.90 recover. The sweep is the first 1.4 s of the recover
	# (silverman.gd's PRISM_SWEEP), the last two frames are him settling.
	"prism": [
		{"dur": 0.30, "dy": -2, "dull": 1},
		{"dur": 0.35, "dy": -3, "dull": 2},
		{"dur": 0.35, "dy": -3, "dull": 2},
		{"dur": 1.40, "dy": -4, "impact": true},
		{"dur": 0.25, "dy": -3},
		{"dur": 0.25, "dy": -2},
	],
	# Never played, like `ghost`: the glare's impact pose with every pixel his
	# brightest rung, outline included - the instant his whole body goes white
	# as the light leaves him. glare.gd stamps it over the real sprite and fades
	# it out. A white-out is a picture rather than a modulate, which can only
	# darken, so it lives on the sheet with the others.
	"flash": [
		{"dur": 0.5, "dy": -4, "white": true},
	],
	# THE GLASS CEILING, picked off the second attack preview. He looks up: the
	# glare's rise and dim taken all the way to the top of his height and HELD
	# there, two rungs down, while the shadows of the panes darken on the floor.
	# The impact is the first wave landing, and he holds full shine for exactly
	# the gap between the two waves, so the second one falls as he lets it go
	# (ceiling.gd's `falls()` reads both moments off this row). Then he settles.
	#
	# 0.95 wind-up, 1.20 recover, and both waves land on frame boundaries.
	"ceiling": [
		{"dur": 0.15, "dy": -2, "dull": 1},
		{"dur": 0.15, "dy": -3, "dull": 2},
		{"dur": 0.65, "dy": -4, "dull": 2},
		{"dur": 0.70, "dy": -4, "impact": true},
		{"dur": 0.25, "dy": -3},
		{"dur": 0.25, "dy": -2},
	],
	# Defeat, and for a man of metal it is the obvious one: he loses flight.
	# He settles the two pixels onto the floor he has never touched and the
	# shine goes out of him on the way down.
	"concede": [
		{"dur": 0.14, "dy": -2},
		{"dur": 0.14, "dy": -1},
		{"dur": 0.16, "dy": 0},
		{"dur": 0.18, "dy": 1},
		{"dur": 0.24, "dy": 2, "dull": 1},
		{"dur": 0.34, "dy": 2, "dull": 1},
	],
	# What is left in the room for the rest of the run. Standing on the floor,
	# gone dull, cooling - the two levels alternate slowly so he is a statue
	# that is still losing heat rather than a statue.
	"beaten": [
		{"dur": 0.5, "dy": 2, "dull": 1},
		{"dur": 0.5, "dy": 2, "dull": 2},
		{"dur": 0.5, "dy": 2, "dull": 2},
		{"dur": 0.5, "dy": 2, "dull": 1},
	],
}

## Which animations loop. The dash holds its single frame; the concede holds
## its last and hands off to `beaten`, which loops for good.
const LOOPS := {"idle": true, "walk": true, "beaten": true}

## Base speed the sheet is sliced at; each frame's `dur` becomes a duration
## multiplier on it.
const FPS := 10.0


## A palette key taken `steps` down the ramp. The painter uses it for the
## ghost row and for the concede; nothing else in the game dulls metal.
static func dulled(key: String, steps: int) -> String:
	var k := key
	for _i in steps:
		k = DULL[k]
	return k


## Body column/row to the boss's local space: origin between his feet, one
## unit one game pixel. Row 34 is the floor he is hovering over.
static func local(c: float, r: float) -> Vector2:
	return Vector2(c - 9.0, r - 34.0)


static func length_of(anim: String) -> float:
	var total := 0.0
	for frame in ANIMS[anim]:
		total += frame["dur"]
	return total


## Everything before the frame marked `impact`: the telegraph the boss script
## runs its WINDUP on. Ahmed's convention, unchanged - the sheet carries the
## timing, so the picture and the timer are one thing and neither can drift.
static func windup_of(anim: String) -> float:
	var total := 0.0
	for frame in ANIMS[anim]:
		if frame.get("impact", false):
			return total
		total += frame["dur"]
	return total


## Everything from the blow onwards, the impact frame included.
static func recover_of(anim: String) -> float:
	return length_of(anim) - windup_of(anim)


## Seconds into `anim` at the start of frame `idx`. What an effect drawing
## itself against the telegraph needs, and it is summed off the same `dur`
## list as the two above.
static func into(anim: String, idx: int) -> float:
	var total := 0.0
	var frames: Array = ANIMS[anim]
	for i in mini(idx, frames.size()):
		total += frames[i]["dur"]
	return total
