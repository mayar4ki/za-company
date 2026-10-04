extends RefCounted
## Big Mo's body and every pose he strikes, as data. Read by two things that
## must agree pixel for pixel: tools/bosses/big_mo.gd, which PAINTS the sheet
## from it, and the boss script, which derives each attack's wind-up and
## recover from the same frame list - so the telegraph and the timer cannot
## drift apart.
##
## He is the one boss drawn FRONT ON rather than in profile. A boxer squares up
## to you; that is the whole pose. It costs nothing against the side-only rule
## in boss_base.gd, because the figure is symmetric enough that the `flip_h`
## the base uses to turn him is invisible - only the lit forearm swaps sides.
##
## He is also 2x DENSITY: 70 source rows across 35 world px, where Ahmed is 35
## rows across 35. That is why his cell is 128 and his scene sets scale 0.5.
## The cost is that his pixels are finer than the room's, which shows a little
## at odd window scales; it was chosen deliberately, so the sliders that shaped
## him had range to work in.
##
## Coordinates are CANVAS coordinates: a 56x76 working frame with the centre
## column at CX and the soles on FOOT. The painter drops that frame into the
## 128px cell at a fixed offset, so every frame of every row lines up.

## Cell geometry. The canvas lands so CX -> cell x 64 and FOOT -> cell y 112,
## which is what the scene's offset of -48 turns into feet on the origin.
const CELL := 128
const W := 56
const H := 76
const CX := 28
const FOOT := 71

## The measurements the style pass settled on, in source px at 2x.
const HEAD_W := 21
const HEAD_H := 22
const HAIR := 8
const NECK := 2
const SHOULDERS := 41
const TAPER := 5
const TORSO := 22
const GLOVE := 11
const SHORTS := 12
const LEG := 4
const LEG_W := 13
const BOOTS := 6

## The vertical stack those measurements add up to, from the soles upward. The
## painter draws off these and the live effects read them, so there is one
## shoulder line rather than two that can drift apart - the reason his poses
## are the single source of truth for his shape in the first place.
const BOOT_TOP := FOOT - BOOTS + 1
const LEG_TOP := BOOT_TOP - LEG
const SHORTS_BOT := LEG_TOP - 1
const SHORTS_TOP := SHORTS_BOT - SHORTS + 1
const BAND_TOP := SHORTS_TOP - 2
const BAND_BOT := SHORTS_TOP - 1
const TORSO_BOT := BAND_TOP - 1
const TORSO_TOP := TORSO_BOT - TORSO + 1
const NECK_TOP := TORSO_TOP - NECK
const HEAD_BOT := NECK_TOP - 1
const HEAD_TOP := HEAD_BOT - HEAD_H + 1

## The row every pose's `ey` and `gy` below are measured DOWN from: where an
## arm leaves the torso. Anything drawing a glove from pose data - the painter,
## bell.gd - starts here.
const SHOULDER := TORSO_TOP + 3

const PAL := {
	"A": "0d0b0d",                    # outline, the cast's own
	"K": "1a1418", "k": "302832",     # hair and beard, crown sheen
	"E": "e8e2d8",                    # eye
	"S": "8a5a3a", "s": "63402a", "h": "a6714a",   # skin, shade, lit edge
	"R": "e0503c", "r": "a63424", "p": "f08a76",   # glove, underside, sheen
	"W": "f0eeea", "w": "c9c4bc",     # shorts, crease
	"T": "e0503c",                    # waistband - the ring's own red
	"B": "262626", "L": "f0eeea",     # boots, laces
}

## The guard he returns to between everything: both gloves at the cheekbones,
## elbows tucked to the ribs. `ex/ey` is the elbow and `gx/gy` the glove, both
## offsets from the centre column and the shoulder line.
const GUARD_L := {"ex": -17, "ey": 12, "gx": -15, "gy": -6}
const GUARD_R := {"ex": 17, "ey": 12, "gx": 15, "gy": -6}

## Sheet order: one row per animation. `rage` sits with the fight rather than
## with the ending - it is something he DOES at 72, not how he stops.
##
## Everything after `concede` arrived later and is LAST on purpose:
## tools/build_bosses.gd paints only the rows the PNG is too short to hold, so a
## new row anywhere else would land on a row somebody may have drawn into.
const ORDER := ["idle", "walk", "jab", "hook", "rush", "rage", "concede",
	"uppercut", "shell", "open", "counter", "clinch", "flurry"]

## A frame carries:
##   dur     seconds it holds
##   phase   "w" wind-up / "s" strike / "r" recover / "i" neither - the boss
##           script derives windup_seconds and recover_seconds from these
##   impact  true on the one frame the blow lands
##   dx/dy   the whole body shifts
##   hdx/hdy the head shifts on top of that - a tuck or a turn
##   legs    [left, right] vertical offsets; the thigh stretches from the hip
##   stance  how much wider than neutral the feet plant
##   blink   eyes closed
##   L/R     the two arms
const ANIMS := {
	# A boxer's bounce, not a breath: two rows of travel and a blink.
	"idle": [
		{"dur": 0.30, "L": GUARD_L, "R": GUARD_R},
		{"dur": 0.22, "dy": -1,
			"L": {"ex": -17, "ey": 12, "gx": -15, "gy": -7},
			"R": {"ex": 17, "ey": 12, "gx": 15, "gy": -7}},
		{"dur": 0.30, "L": GUARD_L, "R": GUARD_R},
		{"dur": 0.22, "dy": -1, "blink": true,
			"L": {"ex": -17, "ey": 12, "gx": -15, "gy": -7},
			"R": {"ex": 17, "ey": 12, "gx": 15, "gy": -7}},
	],
	"walk": [
		{"dur": 0.14, "legs": [0, 0], "stance": 1, "L": GUARD_L, "R": GUARD_R},
		{"dur": 0.14, "dy": -1, "legs": [-2, 1], "stance": 2,
			"L": {"ex": -17, "ey": 12, "gx": -15, "gy": -7},
			"R": {"ex": 17, "ey": 12, "gx": 15, "gy": -5}},
		{"dur": 0.14, "legs": [0, 0], "stance": 1, "L": GUARD_L, "R": GUARD_R},
		{"dur": 0.14, "dy": -1, "legs": [1, -2], "stance": 2,
			"L": {"ex": -17, "ey": 12, "gx": -15, "gy": -5},
			"R": {"ex": 17, "ey": 12, "gx": 15, "gy": -7}},
	],
	# JAB - 0.25 s wind-up, 6 damage. Front on it cannot travel sideways, so it
	# FORESHORTENS: the glove grows toward the camera and back again. That is
	# what `gs`, the glove radius, is doing on these frames.
	"jab": [
		{"dur": 0.13, "phase": "w",
			"L": {"ex": -17, "ey": 12, "gx": -13, "gy": -4, "gs": 5}, "R": GUARD_R},
		{"dur": 0.12, "phase": "w", "dx": -1,
			"L": {"ex": -17, "ey": 12, "gx": -11, "gy": -3, "gs": 5}, "R": GUARD_R},
		{"dur": 0.07, "phase": "s", "impact": true, "dx": 1,
			"L": {"ex": -12, "ey": 4, "gx": -6, "gy": -2, "gs": 9}, "R": GUARD_R},
		{"dur": 0.09, "phase": "r",
			"L": {"ex": -14, "ey": 8, "gx": -9, "gy": -3, "gs": 7}, "R": GUARD_R},
		{"dur": 0.12, "phase": "r", "L": GUARD_L, "R": GUARD_R},
	],
	# HOOK - 0.70 s wind-up, 18 damage. THE read. Two full frames with the rear
	# glove cocked high and wide and the body turned into it before anything
	# comes back; that is the window the player is being sold.
	"hook": [
		{"dur": 0.18, "phase": "w", "dx": 1,
			"L": GUARD_L, "R": {"ex": 19, "ey": 10, "gx": 18, "gy": -6}},
		{"dur": 0.26, "phase": "w", "dx": 2, "hdx": 1,
			"L": {"ex": -17, "ey": 12, "gx": -13, "gy": -6},
			"R": {"ex": 21, "ey": 8, "gx": 22, "gy": -9, "gs": 6}},
		{"dur": 0.26, "phase": "w", "dx": 3, "hdx": 1,
			"L": {"ex": -17, "ey": 12, "gx": -13, "gy": -6},
			"R": {"ex": 22, "ey": 7, "gx": 24, "gy": -11, "gs": 6}},
		{"dur": 0.08, "phase": "s", "impact": true, "dx": -2, "hdx": -1,
			"L": GUARD_L, "R": {"ex": 14, "ey": -2, "gx": -2, "gy": -8, "gs": 7}},
		{"dur": 0.14, "phase": "r", "dx": -2,
			"L": GUARD_L, "R": {"ex": 6, "ey": 2, "gx": -10, "gy": -4}},
		{"dur": 0.20, "phase": "r", "dx": -1,
			"L": GUARD_L, "R": {"ex": 17, "ey": 12, "gx": 10, "gy": -2}},
		{"dur": 0.16, "phase": "r", "L": GUARD_L, "R": GUARD_R},
	],
	# CORNER RUSH - the gap-closer for a player who kites to the ring edge.
	# He pitches forward, tucks his head and runs; the strike frames are the
	# ones that carry him.
	#
	# The crouch is the TELL, and he holds it where he stands: nothing moves
	# him until the first running frame (`tell_of`). The whole wind-up has to
	# outlast a reaction. When he ran from the first frame, the blow was 0.36 s
	# from a standing start, and a player who saw it coming had about a tenth of
	# a second left to get out of a 27 px reach. Now it is 0.80 s: 0.50
	# crouched, then two 0.15 strides. Getting clear sideways takes about 0.4 s
	# of walking from a standing start, so a player who starts to move up to
	# 0.4 s after the crouch begins gets off his line, measured in
	# tests/test_big_mo_moves.gd - and he still lands on whoever stays on it.
	"rush": [
		{"dur": 0.50, "phase": "w", "dy": 2, "legs": [1, 1], "stance": -1, "hdy": 1,
			"L": {"ex": -17, "ey": 12, "gx": -15, "gy": -2},
			"R": {"ex": 17, "ey": 12, "gx": 15, "gy": -2}},
		{"dur": 0.15, "phase": "s", "dy": -1, "hdy": 2, "legs": [-4, 3], "stance": 4,
			"L": {"ex": -17, "ey": 12, "gx": -12, "gy": -7},
			"R": {"ex": 17, "ey": 12, "gx": 12, "gy": -7}},
		{"dur": 0.15, "phase": "s", "dy": -2, "hdy": 2, "legs": [3, -4], "stance": 4,
			"L": {"ex": -17, "ey": 12, "gx": -12, "gy": -7},
			"R": {"ex": 17, "ey": 12, "gx": 12, "gy": -7}},
		# The blow lands on ARRIVAL, not mid-charge: the impact is the last
		# running frame, so the whole dash is the wind-up and he connects when
		# he gets there.
		{"dur": 0.10, "phase": "s", "impact": true, "dy": -1, "hdy": 2, "legs": [-4, 3], "stance": 4,
			"L": {"ex": -17, "ey": 12, "gx": -12, "gy": -7},
			"R": {"ex": 17, "ey": 12, "gx": 12, "gy": -7}},
		{"dur": 0.18, "phase": "r", "dy": 1, "legs": [1, 1], "stance": 1,
			"L": GUARD_L, "R": GUARD_R},
	],
	# RAGE - 0.95 s, played ONCE at 72 HP and never again. He does not attack
	# through it and cannot be staggered out of it.
	#
	# The frame boundaries are the fire's beats, so the picture and the
	# eruption cannot drift: rage.gd's three pulses land on the starts of
	# frames 1, 2 and 4, and the blast on the start of frame 3. He loads, sinks
	# TWICE - the second one deeper than the first, which is what sells the
	# third as the one that gives - blows the ring out of the crouch, and comes
	# up through his own fire with his arms flung open. He settles into a
	# wider, heavier guard than the one he started the fight in.
	"rage": [
		{"dur": 0.16, "dy": 1, "legs": [1, 1], "stance": 1,
			"L": {"ex": -18, "ey": 12, "gx": -16, "gy": -3},
			"R": {"ex": 18, "ey": 12, "gx": 16, "gy": -3}},
		{"dur": 0.24, "dy": 2, "hdy": 1, "legs": [1, 1], "stance": 2, "blink": true,
			"L": {"ex": -19, "ey": 13, "gx": -18, "gy": 1},
			"R": {"ex": 19, "ey": 13, "gx": 18, "gy": 1}},
		{"dur": 0.11, "dy": 1, "stance": 2,
			"L": {"ex": -19, "ey": 9, "gx": -20, "gy": -4},
			"R": {"ex": 19, "ey": 9, "gx": 20, "gy": -4}},
		{"dur": 0.11, "dy": 2, "hdy": 1, "legs": [1, 1], "stance": 3, "blink": true,
			"L": {"ex": -20, "ey": 12, "gx": -19, "gy": 2},
			"R": {"ex": 20, "ey": 12, "gx": 19, "gy": 2}},
		{"dur": 0.18, "dy": -1, "hdy": -2, "stance": 2,
			"L": {"ex": -19, "ey": -2, "gx": -21, "gy": -13, "gs": 6},
			"R": {"ex": 19, "ey": -2, "gx": 21, "gy": -13, "gs": 6}},
		{"dur": 0.15, "stance": 1,
			"L": {"ex": -18, "ey": 11, "gx": -16, "gy": -5},
			"R": {"ex": 18, "ey": 11, "gx": 16, "gy": -5}},
	],
	# CONCEDE - one frame, deliberately. boss_base plays `concede_side` at zero
	# health and the row has to exist, but the animation that went with it was
	# rejected in review, so this is a placeholder posture: he stops, and his
	# hands come down. Whatever replaces it is a content decision, not a
	# structural one - add frames here and nothing else changes.
	"concede": [
		{"dur": 1.0,
			"L": {"ex": -16, "ey": 14, "gx": -14, "gy": 10},
			"R": {"ex": 16, "ey": 14, "gx": 14, "gy": 10}},
	],
	# UPPERCUT - the hook's twin, and its opposite. Same 0.70 s and the same
	# rear glove, so neither guess is the safe one; what tells them apart is
	# WHERE that glove goes. The hook cocks it up and out; this drops it to the
	# hip and sinks him two rows, then brings it up the middle. Wide and short
	# against narrow and long - step back from one, step aside from the other.
	"uppercut": [
		{"dur": 0.18, "phase": "w", "dy": 1, "legs": [1, 1], "stance": 1,
			"L": GUARD_L, "R": {"ex": 18, "ey": 13, "gx": 17, "gy": 4, "gs": 5}},
		{"dur": 0.26, "phase": "w", "dy": 2, "hdy": 1, "legs": [1, 1], "stance": 2,
			"L": {"ex": -17, "ey": 12, "gx": -14, "gy": -7},
			"R": {"ex": 17, "ey": 14, "gx": 13, "gy": 10, "gs": 5}},
		{"dur": 0.26, "phase": "w", "dy": 3, "hdy": 1, "legs": [2, 2], "stance": 2,
			"L": {"ex": -17, "ey": 12, "gx": -14, "gy": -7},
			"R": {"ex": 16, "ey": 14, "gx": 10, "gy": 12, "gs": 6}},
		{"dur": 0.08, "phase": "s", "impact": true, "dy": -2, "hdy": -2, "legs": [-1, -1],
			"L": GUARD_L, "R": {"ex": 12, "ey": -2, "gx": 5, "gy": -17, "gs": 8}},
		{"dur": 0.14, "phase": "r", "dy": -1,
			"L": GUARD_L, "R": {"ex": 14, "ey": 0, "gx": 9, "gy": -14, "gs": 7}},
		{"dur": 0.20, "phase": "r",
			"L": GUARD_L, "R": {"ex": 17, "ey": 8, "gx": 14, "gy": -6}},
		{"dur": 0.16, "phase": "r", "L": GUARD_L, "R": GUARD_R},
	],
	# SHELL - both gloves over the face, head tucked. Not an attack: a stance he
	# holds for SHELL_SECONDS, looping this bob, and every hit on it is blocked.
	"shell": [
		{"dur": 0.20, "hdy": 1,
			"L": {"ex": -13, "ey": 10, "gx": -5, "gy": -11, "gs": 6},
			"R": {"ex": 13, "ey": 10, "gx": 5, "gy": -11, "gs": 6}},
		{"dur": 0.20, "dy": 1, "hdy": 2,
			"L": {"ex": -13, "ey": 11, "gx": -5, "gy": -10, "gs": 6},
			"R": {"ex": 13, "ey": 11, "gx": 5, "gy": -10, "gs": 6}},
	],
	# OPEN - the shell waited out: guard on the floor, head rolling. The punish
	# window, looped for OPEN_SECONDS.
	"open": [
		{"dur": 0.20, "dy": 1, "hdx": -1, "blink": true,
			"L": {"ex": -17, "ey": 14, "gx": -16, "gy": 9},
			"R": {"ex": 17, "ey": 14, "gx": 16, "gy": 9}},
		{"dur": 0.20, "dy": 2, "hdy": 1,
			"L": {"ex": -17, "ey": 14, "gx": -15, "gy": 10},
			"R": {"ex": 17, "ey": 14, "gx": 15, "gy": 10}},
		{"dur": 0.20, "dy": 1, "hdx": 1, "blink": true,
			"L": {"ex": -17, "ey": 14, "gx": -16, "gy": 9},
			"R": {"ex": 17, "ey": 14, "gx": 16, "gy": 9}},
		{"dur": 0.20, "dy": 2, "hdy": 1,
			"L": {"ex": -17, "ey": 14, "gx": -15, "gy": 10},
			"R": {"ex": 17, "ey": 14, "gx": 15, "gy": 10}},
	],
	# COUNTER - what hitting the shell earns: the hook with the wind-up cut to
	# 0.15 s, out of the shell rather than out of the guard. The blow and the
	# recover are the hook's own frames.
	"counter": [
		{"dur": 0.07, "phase": "w", "dx": 2, "hdx": 1,
			"L": GUARD_L, "R": {"ex": 21, "ey": 8, "gx": 22, "gy": -9, "gs": 6}},
		{"dur": 0.08, "phase": "w", "dx": 3, "hdx": 1,
			"L": GUARD_L, "R": {"ex": 22, "ey": 7, "gx": 24, "gy": -11, "gs": 6}},
		{"dur": 0.08, "phase": "s", "impact": true, "dx": -2, "hdx": -1,
			"L": GUARD_L, "R": {"ex": 14, "ey": -2, "gx": -2, "gy": -8, "gs": 7}},
		{"dur": 0.14, "phase": "r", "dx": -2,
			"L": GUARD_L, "R": {"ex": 6, "ey": 2, "gx": -10, "gy": -4}},
		{"dur": 0.20, "phase": "r", "dx": -1,
			"L": GUARD_L, "R": {"ex": 17, "ey": 12, "gx": 10, "gy": -2}},
		{"dur": 0.16, "phase": "r", "L": GUARD_L, "R": GUARD_R},
	],
	# CLINCH - the arms thrown wide are the tell, then they close round you on
	# the impact frame, then the heave. The throw itself is carried through the
	# recover by the boss script, a frame the picture already shows.
	"clinch": [
		{"dur": 0.15, "phase": "w", "stance": 1,
			"L": {"ex": -20, "ey": 8, "gx": -24, "gy": -3, "gs": 5},
			"R": {"ex": 20, "ey": 8, "gx": 24, "gy": -3, "gs": 5}},
		{"dur": 0.15, "phase": "w", "dy": 1, "stance": 2,
			"L": {"ex": -19, "ey": 7, "gx": -15, "gy": 2, "gs": 5},
			"R": {"ex": 19, "ey": 7, "gx": 15, "gy": 2, "gs": 5}},
		{"dur": 0.10, "phase": "s", "impact": true, "dy": 1, "stance": 2,
			"L": {"ex": -17, "ey": 8, "gx": -6, "gy": 4, "gs": 5},
			"R": {"ex": 17, "ey": 8, "gx": 6, "gy": 4, "gs": 5}},
		{"dur": 0.16, "phase": "r", "dx": 3, "hdx": 2, "dy": -1, "legs": [-2, 1], "stance": 3,
			"L": {"ex": -4, "ey": -2, "gx": 12, "gy": -14, "gs": 5},
			"R": {"ex": 22, "ey": -3, "gx": 24, "gy": -13, "gs": 5}},
		{"dur": 0.24, "phase": "r", "dx": 1, "L": GUARD_L, "R": GUARD_R},
	],
	# FLURRY - raging only. Two frames of loading (the gloves grow), then five
	# straight punches alternating hands, FLURRY_GAP apart, while he marches.
	# The first lands on the impact frame like any blow; the boss script lands
	# the other four through the recover, each on the frame that throws it -
	# punch k at 0.30 + 0.2 k, every one of them a frame boundary below.
	"flurry": [
		{"dur": 0.15, "phase": "w", "dy": 1, "stance": 1,
			"L": {"ex": -17, "ey": 12, "gx": -14, "gy": -4, "gs": 6},
			"R": {"ex": 17, "ey": 12, "gx": 14, "gy": -4, "gs": 6}},
		{"dur": 0.15, "phase": "w", "dy": 1, "stance": 1,
			"L": {"ex": -16, "ey": 12, "gx": -13, "gy": -4, "gs": 7},
			"R": {"ex": 16, "ey": 12, "gx": 13, "gy": -4, "gs": 7}},
		{"dur": 0.10, "phase": "s", "impact": true, "legs": [-2, 1], "stance": 2, "R": GUARD_R,
			"L": {"ex": -12, "ey": 4, "gx": -6, "gy": -2, "gs": 9}},
		{"dur": 0.10, "phase": "r", "stance": 1, "L": GUARD_L, "R": GUARD_R},
		{"dur": 0.10, "phase": "r", "legs": [1, -2], "stance": 2, "L": GUARD_L,
			"R": {"ex": 12, "ey": 4, "gx": 6, "gy": -2, "gs": 9}},
		{"dur": 0.10, "phase": "r", "stance": 1, "L": GUARD_L, "R": GUARD_R},
		{"dur": 0.10, "phase": "r", "legs": [-2, 1], "stance": 2, "R": GUARD_R,
			"L": {"ex": -12, "ey": 4, "gx": -6, "gy": -2, "gs": 9}},
		{"dur": 0.10, "phase": "r", "stance": 1, "L": GUARD_L, "R": GUARD_R},
		{"dur": 0.10, "phase": "r", "legs": [1, -2], "stance": 2, "L": GUARD_L,
			"R": {"ex": 12, "ey": 4, "gx": 6, "gy": -2, "gs": 9}},
		{"dur": 0.10, "phase": "r", "stance": 1, "L": GUARD_L, "R": GUARD_R},
		{"dur": 0.10, "phase": "r", "legs": [-2, 1], "stance": 2, "R": GUARD_R,
			"L": {"ex": -12, "ey": 4, "gx": -6, "gy": -2, "gs": 9}},
		{"dur": 0.12, "phase": "r", "L": GUARD_L, "R": GUARD_R},
	],
}

const LOOPS := {"idle": true, "walk": true, "shell": true, "open": true}

## Base speed the sheet is sliced at; each frame's `dur` becomes a duration
## multiplier on it, so the sheet carries the attack's own timing.
const FPS := 10.0


## Seconds from the first frame to the blow: the wind-up the boss script runs.
static func windup_of(anim: String) -> float:
	var total := 0.0
	for frame in ANIMS[anim]:
		if frame.get("impact", false):
			return total
		total += frame["dur"]
	return total


## Seconds of loading before anything is thrown: the "w" frames at the head of
## an attack. For the rush it is how long he crouches before he runs - the
## boss script roots him for it and the Bell starts the speed lines after it.
static func tell_of(anim: String) -> float:
	var total := 0.0
	for frame in ANIMS[anim]:
		if frame.get("phase", "") != "w":
			return total
		total += frame["dur"]
	return total


## Everything after the blow: the recover the boss script runs.
static func recover_of(anim: String) -> float:
	return length_of(anim) - windup_of(anim)


static func length_of(anim: String) -> float:
	var total := 0.0
	for frame in ANIMS[anim]:
		total += frame["dur"]
	return total
