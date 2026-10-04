extends RefCounted
## The floor where the software gets written - and the brightest room in the
## building after the lobby.
##
## It is also the SECOND floor that is not a rectangle, and the first that is
## not one piece: three halls stacked up the building and joined at alternating
## ends, so the walk crosses each of them in the opposite direction to the last.
## The call floor bends once; this one bends three times.
##
## ## Why the halls are as big as they are
##
## The shape was drawn twice. The first draft was a serpentine of CORRIDORS,
## and it was wrong for a reason this floor's own enemy comment already says
## out loud: a mix you meet one at a time is not a mix, it is a tour. Narrow
## legs hand the player one body at a time, which is the quadrant "lap" that
## was tried here and thrown out. So the shape is halls joined by short links,
## never a corridor that bends - each hall is 30 x 15 floor tiles, near enough
## the whole of the old room, and only the two links between them are tight.
##
## The second draft was too SHORT, and the arithmetic is worth writing down
## because it decides the size of every floor shaped like this one. On a
## rectangle the walk is a vertical band and a body clears it sideways, across
## 512 px of room. Here the walk CROSSES each hall, so the clearance budget is
## vertical and a hall has to hold the 54 px band plus the biggest sight radius
## standing off it - 130 for the slower. A hall of 13 floor rows leaves 154 px
## beside a wall-hugging band, which satisfies the rule by 24 px and would
## break the first time anybody nudged anything. 15 rows leaves 186. That is
## the whole reason this floor is 512 x 1008 rather than something tidier.
##
## The corollary is the one rule to keep when editing this file: **every
## crossing hugs a wall.** A band down the middle of a hall halves it twice
## over - once for the clearance either side, once for the fight - and the call
## floor's north-wall turn is the same decision for the same reason.
##
## Data only, read by tools/biomes.gd; the key reference lives there.

const BIOME := {
	"node": "InnovationLab",
	"title": "THE INNOVATION LAB",
	# Light, and light on purpose: this is the floor the company spent the
	# refurbishment budget on. Warm off-white walls and pale wood, which is
	# what every office built for engineers in the last ten years looks like -
	# and it is the exact opposite of the content studio two floors down, where
	# the ramp never reaches white at all.
	#
	# The contrast is doing work rather than just being pretty. Nothing else in
	# the building is this bright, so the screens on these desks are the
	# DARKEST things in the room instead of the lightest, which is how a floor
	# full of monitors reads as a floor full of monitors.
	"ramp": ["24211c", "4a463d", "7d7768", "aaa495", "d5d0c2", "faf7f0"],
	# The blue every editor's syntax highlighting is set to. No other floor is
	# blue - the call centre's cyan is the nearest and it is colder and
	# greener - so the accent alone says which team this is.
	"accent": "3f6fe0",
	# Below 1.0 lifts the mid-tones, the same as the lobby: a bright room under
	# too many downlights rather than a dim one.
	"gamma": 0.78,
	# High, but stopping short of the ramp's near-white top, which is the
	# lobby's lesson: a floor at the hot end takes the pale half of the cast
	# with it. Checked with three of them standing on it.
	"floor_band": Vector2(0.40, 0.88),
	# A carpet runner down the middle with a little of the blue in it. The band
	# is derived from the room's own height, so on a 63-row floor it lands in
	# the MIDDLE hall rather than a third of the way up one of them.
	"runner": 0.14,
	# 32 x 63, with two bars cut out at alternating ends - the S. The halls are
	# full width; only the two links are narrow, and each is 6 tiles (96 px),
	# which is wide enough for a 64 px body and a doorway's worth of room
	# either side of it.
	#
	#   rows  1-15   TOP HALL      the machine room, and the way out
	#   rows 17-22   west link     cols 1-6
	#   rows 24-38   MIDDLE HALL   the open-plan pod, and the runner
	#   rows 40-45   east link     cols 25-30
	#   rows 47-61   BOTTOM HALL   the second pod, and the way in
	#
	# The doors are not in line with each other and neither is on the middle
	# column: the way in is the bottom hall's west end, the way out is the top
	# hall's east end, and the room between them is the whole S.
	"shape": {
		"cols": 32, "rows": 63,
		"cut": [Rect2i(0, 40, 24, 6),    # the bottom bar, open on the EAST
				Rect2i(8, 17, 24, 6)],   # the top bar, open on the WEST
		"doors": {"out": 24, "back": 8},
	},
	# The walk, in six legs meeting at five corners. Each crossing hugs the
	# wall its link arrives at, which leaves the body of every hall for the
	# fight rather than cutting it in half - the call floor's rule, applied
	# three times.
	#
	# Up out of the south door and east along the bottom hall, up the east
	# link, west across the middle hall, up the west link, east across the top
	# hall, out. The vertical legs overlap the crossings at their ends: a turn
	# has to be inside the lane or the walk clips a wall.
	"lane": [
		Rect2(117, 938, 330, 54),    # bottom hall, west to east, on the wall
		Rect2(413, 570,  54, 422),   # up the east link
		Rect2( 37, 570, 430, 54),    # middle hall, east to west, on the wall
		Rect2( 37, 202,  54, 422),   # up the west link
		Rect2( 37, 202, 390, 54),    # top hall, west to east, on the wall
		Rect2(373,  16,  54, 240),   # up to the north door
	],
	# Glazed steel pillars, and NOT cubicle dividers - the point of an
	# engineering floor is that it is open plan. Two per hall rather than the
	# old four in one room, which is the same density over 2.7x the floor.
	#
	# The xs are the two columns that clear every vertical leg of the walk in
	# all three halls at once, which is what a cross product costs on a shaped
	# floor: col 7 stands 21 px east of the west link's climb, col 22 stands
	# 5 px west of where the east climb begins. Anything between them is in
	# somebody's lane on one floor or another.
	"column": "pillar",
	"columns": {"rows": [6, 28, 52], "xs": [7, 22]},
	# The same overloaded strip as the floors below, and it needs no excuse
	# here: fifteen workstations now, each with a laptop, two monitors and a
	# machine under the desk, all fed from whatever was already plugged in.
	# It stands in the bottom hall, under the knot, where it always did.
	"hazard": "power_strip",
	"hazard_at": Vector2(176, 850),
	# No `heart_at` beside it, because this floor has never carried a heart:
	# `heart` is unset, so there is no stand for one to default onto. The lab
	# is the last floor before the gym and it is meant to be entered hurt -
	# and left whole: see `reward` below.
	# Three rooms, three jobs. Everything wall-mounted is on a wall the player
	# actually faces while crossing, and nothing stands in a link: a prop is a
	# solid body, and the two links are the only places on this floor where one
	# of them could shut the room.
	"props": [
		# ---- TOP HALL: the machine room -----------------------------------
		# What the floor runs on, and the last thing you walk past on the way
		# out. The board comes first because it is the biggest thing on the
		# north wall and everything else up here is placed around it.
		# A sign's words are baked into its painter, so borrowing another
		# floor's sign borrows its joke: `poster` says FIX IT / IN POST and
		# `whiteboard` says SMILE / THEY CAN / HEAR IT, which are the hub's
		# and the call floor's. This floor's two signs are its own - a build
		# that has been failing for nine runs, and a diagram nobody may erase.
		{"type": "build_board", "at": Vector2(140, 18)},
		{"type": "server_rack", "at": Vector2(300, 58)},
		{"type": "server_rack", "at": Vector2(326, 58)},
		{"type": "pc_tower", "at": Vector2(352, 58)},
		{"type": "dev_desk", "at": Vector2(250, 60)},
		{"type": "chair", "at": Vector2(250, 74)},
		{"type": "plant", "at": Vector2(36, 120)},
		# East of the climb to the door, in the pocket the walk leaves behind.
		{"type": "cooler", "at": Vector2(458, 60)},
		{"type": "coffee", "at": Vector2(462, 96)},
		{"type": "scrap_pile", "at": Vector2(330, 180)},
		{"type": "debris", "at": Vector2(150, 150)},
		# The floor of the machine room, which the first pass left as carpet. A
		# hall this size needs filling or it reads as a room they ran out of
		# budget for - which is the one thing this floor is not.
		{"type": "crt_stack", "at": Vector2(70, 58)},
		{"type": "crt_stack", "at": Vector2(60, 175)},
		{"type": "toolbox", "at": Vector2(104, 186)},
		{"type": "cable_spool", "at": Vector2(250, 170)},
		{"type": "cable_spool", "at": Vector2(320, 120)},
		{"type": "crt_stack", "at": Vector2(458, 150)},
		{"type": "debris", "at": Vector2(460, 200)},
		# ---- MIDDLE HALL: the open plan -----------------------------------
		# Five workstations in two rows and the whiteboard they argue at. The
		# runner goes down the middle of this hall, so the desks flank it.
		{"type": "diagram", "at": Vector2(160, 386)},
		{"type": "dev_desk", "at": Vector2(140, 430)},
		{"type": "chair", "at": Vector2(140, 444)},
		{"type": "dev_desk", "at": Vector2(216, 430)},
		{"type": "chair", "at": Vector2(216, 444)},
		{"type": "dev_desk", "at": Vector2(292, 430)},
		{"type": "chair", "at": Vector2(292, 444)},
		{"type": "dev_desk", "at": Vector2(140, 510)},
		{"type": "chair", "at": Vector2(140, 524)},
		{"type": "dev_desk", "at": Vector2(216, 510)},
		{"type": "chair", "at": Vector2(216, 524)},
		{"type": "plant", "at": Vector2(392, 398)},
		{"type": "cable_spool", "at": Vector2(452, 480)},
		{"type": "debris", "at": Vector2(330, 520)},
		{"type": "cooler", "at": Vector2(340, 412)},
		{"type": "dev_desk", "at": Vector2(368, 510)},
		{"type": "chair", "at": Vector2(368, 524)},
		{"type": "pc_tower", "at": Vector2(420, 470)},
		{"type": "crt_stack", "at": Vector2(460, 545)},
		{"type": "plant", "at": Vector2(110, 480)},
		{"type": "debris", "at": Vector2(250, 550)},
		# ---- BOTTOM HALL: the second pod and the breakout -----------------
		# Where the player comes in. Three desks along the west, somewhere to
		# sit in the east, and the printer nobody on this floor has used since
		# they were hired.
		{"type": "dev_desk", "at": Vector2(100, 800)},
		{"type": "chair", "at": Vector2(100, 814)},
		{"type": "dev_desk", "at": Vector2(176, 800)},
		{"type": "chair", "at": Vector2(176, 814)},
		{"type": "dev_desk", "at": Vector2(252, 800)},
		{"type": "chair", "at": Vector2(252, 814)},
		{"type": "printer", "at": Vector2(60, 762)},
		{"type": "cable_spool", "at": Vector2(36, 862)},
		{"type": "debris", "at": Vector2(150, 872)},
		{"type": "debris", "at": Vector2(330, 776)},
		{"type": "sofa", "at": Vector2(348, 880)},
		{"type": "table", "at": Vector2(348, 902)},
		{"type": "plant", "at": Vector2(300, 872)},
		# The plant nobody on this floor has watered, which is every dev
		# floor's second plant.
		{"type": "notice", "at": Vector2(300, 754)},
		{"type": "crt_stack", "at": Vector2(390, 795)},
		{"type": "toolbox", "at": Vector2(300, 820)},
		{"type": "scrap_pile", "at": Vector2(390, 820)},
		# By the sofa rather than against the east wall: the climb to the east
		# link runs the full height of this hall at x 413-467, which leaves
		# only 29 px of floor beyond it - a strip too narrow to stand
		# anything in without standing it on the walk.
		{"type": "cooler", "at": Vector2(270, 890)},
		{"type": "coffee", "at": Vector2(240, 890)},
		{"type": "debris", "at": Vector2(386, 906)},
		{"type": "dead_plant", "at": Vector2(40, 908)},
	],
	# THE FIRST ONE-OF-EACH MIX, and it used to be one body per quadrant so the
	# room was a lap rather than a line. The lap was the problem: four corners
	# with one enemy in each is four errands, and the floor whose mechanic is
	# holding all three answers at once never actually asked for two of them
	# together. A mix you meet one at a time is not a mix, it is a tour.
	#
	# The S is the version of that argument this floor can now lose by accident,
	# which is why the mix is per HALL rather than spread along the route. Each
	# hall is its own arrangement and each one asks for more than one answer at
	# a time; what the shape adds is that you cannot see the next one from the
	# last, so a room you have finished stays finished and a room you have not
	# entered tells you nothing.
	#
	# Being the first room that asks the player to hold all three answers AT
	# ONCE is still the mechanic, and the middle hall is where it is asked -
	# boy, boy, drain and the slower, on 480 x 240 of open floor. That is also
	# what earns the executive floor for free, since the exam is this fight one
	# rank bigger with the masks off.
	"enemies": [
		# BOTTOM HALL - the knot, with the hazard under it. Two boys and a
		# drain answering together, the first thing the floor asks.
		{"type": "office_boy", "at": Vector2(120, 770)},
		{"type": "office_boy", "at": Vector2(240, 790)},
		{"type": "social_media", "at": Vector2(60, 780)},
		# MIDDLE HALL - all three answers at once, on the widest ground. Every
		# body here sits in the middle of the hall's depth rather than against a
		# wall, because a hall has a crossing at one end AND the hall above it has
		# one at the other: sight is a radius, not a line of sight, so a body
		# tucked against the north wall is looking through eight tiles of masonry
		# at the walk in the room above. That is the one placement trap this
		# shape has and no rectangular floor can.
		{"type": "office_boy", "at": Vector2(200, 455)},
		{"type": "office_boy", "at": Vector2(355, 450)},
		{"type": "social_media", "at": Vector2(440, 408)},
		{"type": "call_center", "at": Vector2(280, 413)},
		# TOP HALL - the last two, between the player and the stairs.
		{"type": "office_boy", "at": Vector2(200, 85)},
		{"type": "social_media", "at": Vector2(120, 50)},
	],
	# One of each again, because a beat has to restate the floor's lesson and the
	# lesson here IS the mix. The only floor whose beat carries a `call_center`,
	# and it is why `per_head` exists: a party gets more boys to be slowed among,
	# never a second slower.
	#
	# The second beat drops the slower and comes down the north stairs. By then
	# the room has usually collapsed onto one knot, and what it needs is not a
	# fourth answer to hold but two more bodies standing between the player and
	# the door they were walking to.
	#
	# The S makes both of these better and neither of them had to change: an
	# arrival at a door is now an arrival one or two HALLS away, which has to
	# walk the shape to reach you. That is pacing the flat room could not buy.
	"reinforcements": [
		{"after_kills": 3, "from": "start",
			"enemies": ["office_boy", "social_media", "call_center"],
			"per_head": ["office_boy"]},
		{"after_kills": 7, "from": "returned",
			"enemies": ["office_boy", "social_media"],
			"per_head": ["office_boy"]},
	],
	# The floor's heal: once the room is clear, the last body down leaves a
	# heart per head where it fell. The hub and the marble hall below feed
	# nobody, so without it this was three floors without a heal straight into
	# Big Mo. A drop rather than Ivan because the S cannot bring him: he would
	# walk in at the south door, two halls behind wherever the fight ended.
	"reward": true,
	# The FOURTH beat, and the one floor that carries it WITHOUT Ivan: the gym
	# is next, and this floor is not one of the six he walks. So he arrives
	# alone, through the north door like every briefing, and the room has one
	# arrival rather than two.
	#
	# In the top hall, which is the one he comes down into - west of the climb
	# to the door, north of the crossing, and clear of the desk at (250, 60) and
	# of this hall's two pillars. The walk from the north door is short and
	# crosses nothing.
	"briefing": {"npc": "dominique", "from": "returned", "at": Vector2(200, 130),
		"say": "res://game/npcs/dominique/before_big_mo.gd"},
}
