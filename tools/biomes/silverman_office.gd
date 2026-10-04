extends RefCounted
## Floor 10: the penthouse, and the last room in DESIGN.md's building - the
## city window, one desk, one face-down sticky note, and floor to fight on.
##
## Data only, read by tools/biomes.gd; the key reference lives there.

const BIOME := {
	"node": "SilvermanOffice",
	"title": "SILVERMAN'S OFFICE",
	# The other half of the executive floor's track - the same file, named
	# again rather than inherited, because a floor is furnished from its own
	# data and nothing here reads the floor below. Silverman deliberately
	# declares NO theme of his own: a boss theme would interrupt this one on
	# the frame his bar goes up and hand it back on the frame he concedes,
	# and the point of putting it a floor early is that the last stretch of
	# the building is one unbroken piece of music.
	"music": "res://assets/music/finale_loop.wav",
	# Cold, and the only ramp in the game with no warmth anywhere in it. Every
	# floor below has a temperature - asset recovery's worn brown, the executive
	# floor's mahogany, the innovation lab's pale wood - and this one is charcoal
	# and glass going up to a blue-white, so the room reads as a place that was
	# specified rather than furnished.
	"ramp": ["0a0b0f", "1b1e26", "343946", "5c6373", "9aa2b2", "e8ecf3"],
	# Platinum, which is not a colour so much as the absence of one: this is
	# the one room in the building whose accent adds no hue at all. It is the
	# gym's argument made the opposite way - the gym is grey so its red paint
	# is the only warm thing in it, and this room is grey so the CITY is.
	# Everything with a colour in here is on the other side of the glass.
	"accent": "bccadd",
	"gamma": 1.05,
	# Dark, and the darkest floor in the game after the content studio. A
	# penthouse at night is lit by what is outside it; a bright floor here
	# would be an office with the strip lights on, which is the one thing this
	# room must not look like. Checked with the cast standing on it - the
	# ramp's top is a blue-white, so the floor stops well short of it and the
	# pale characters still read.
	"floor_band": Vector2(0.20, 0.58),
	# Barely there. The band across the middle is a shade of stone rather than
	# a carpet, because the thing on this floor is the rug and a second band
	# under it would be competing with it - the gym's lesson.
	"runner": 0.12,
	# NO COLONNADE. DESIGN.md asks for a wide open arena and this is the second
	# floor to hand in an empty layout, after the gym: the last fight in the
	# game is three phases long and two of them are about distance, so there is
	# nothing in this room to break a line of sight or a charge.
	"columns": {"rows": [], "xs": []},
	# And no hazard, for the third time and the same reason - Ahmed's office,
	# the gym, and now here. A boss room that also burns you is a boss room
	# where the death was the floor's fault.
	"hazard": "none",
	# EVERYTHING IS AGAINST A WALL. The middle of this room is the arena and
	# the only thing in it is the rug, which blocks nothing: no prop here has a
	# collision box anywhere inside x 150-400, y 150-280.
	#
	# There is ONE door in this room. The penthouse is the end of the chain, so
	# nothing is cut through its north wall - which is why the window runs
	# 480 px unbroken, and why the only lane to keep clear runs from the south
	# door up to the desk rather than the whole height of the room.
	"props": [
		# ---- The north wall, which is not a wall ---------------------------
		# The room, in one prop, wall to wall.
		{"type": "city_window", "at": Vector2(32, 18)},
		# ---- The one desk, with its back to the city -----------------------
		# West of the middle rather than on it, because the arena wants the
		# floor and because a desk dead ahead of the door is a desk you walk
		# into. The chair is listed first so it reads behind the desk;
		# Y-sorting does the rest.
		{"type": "chair", "at": Vector2(150, 100)},
		{"type": "exec_desk", "at": Vector2(150, 136)},
		# Two pixels south of the desk's foot, which is what puts it ON the
		# desk - see sticky_note.gd, where the whole trick is explained.
		{"type": "sticky_note", "at": Vector2(174, 138)},
		{"type": "plant", "at": Vector2(36, 104)},
		{"type": "plant", "at": Vector2(508, 104)},
		# The console under the east glass, and the only other flat surface in
		# the room.
		{"type": "table", "at": Vector2(430, 108)},
		# ---- The arena ----------------------------------------------------
		# The same rug the floor below has, which is the catalogue working as
		# intended: one painter, this room's palette, and in a room with no
		# hue in it the pattern comes out platinum on slate. It centres on the
		# room and it blocks nothing, so it marks the floor the last fight
		# happens on without standing in it.
		{"type": "rug", "at": Vector2(164, 170)},
		# ---- The corner he asks you to sit down in -------------------------
		{"type": "plant", "at": Vector2(36, 210)},
		{"type": "sofa", "at": Vector2(60, 250)},
		{"type": "table", "at": Vector2(60, 270)},
		# And the corner he pours from. The trolley is the executive floor's,
		# one storey up.
		{"type": "bar_cart", "at": Vector2(496, 214)},
		{"type": "sofa", "at": Vector2(486, 262)},
	],
	# Empty, and it stays empty: nothing may STAND in the arena, since two of
	# the last fight's three phases are about distance and the rug is the only
	# thing in the middle of the room. The beat below is how this floor gets
	# bodies without a placement - an arrival carries no `at`.
	"enemies": [],
	# SILVERMAN, on the centre line, 100 px north of where you walk in.
	#
	# x is `DOOR_CENTRE_X` and that is the load-bearing half of it: his glare
	# sweeps 140 px along x and his crossing travels 72 along x, so he is the
	# one boss in the game whose attacks need the room's WIDTH - and centred is
	# the only placement that gives him all of it in both directions. Off to one
	# side, half his fight runs out of floor.
	#
	# y 140 puts him 100 px from the south spawn, inside his 130 sight, so he
	# has seen you before you have taken a step: a boss floor is an arena and
	# the walk through it goes through him. It is also clear of everything -
	# the desk, chair and sticky note all sit at x <= 174, the console at 430,
	# the plants at 36 and 508 - and it stands him just off the north edge of
	# the rug, which is what the rug is for.
	#
	# **There is no door for him to lock.** Every other boss floor shuts its
	# north door until he concedes; this one has no north door at all, because
	# the penthouse is the end of the chain and build_levels.gd only cuts one
	# where there is a next level. Beating him opens nothing - he is the last
	# thing in the building, and what happens after is the ending, not a floor.
	"boss": {"type": "silverman", "at": Vector2(272, 140)},
	# **LIVE.** Authored before the boss existed and inert while `Props/Boss`
	# was null; Silverman is standing there now, so these three beats fire.
	#
	# THE THRESHOLDS ARE QUARTERS of whatever he opens at - 288 solo, twelve
	# heavies, plus 96 per extra head - which is why they are fractions: his
	# health is no longer one number. They are deliberately OFF his phase
	# boundaries: his ladder turns at two thirds and a third, and the beat
	# lands at three quarters, a half and a quarter, so a phase change and an
	# arrival never coincide at any party size. One thing to read at a time was
	# the whole argument for the arena being empty; it applies just as much to
	# the two clocks running on his health.
	#
	# In by the SOUTH door, which is the door that seals behind you - so the
	# bodies come through the one way out, and the seal is the reason they can.
	# It is the only boss floor where the beat has a story rather than just a
	# marker.
	#
	# His own phases already carry a slow pulse (P2) and a drain (P3), so the
	# pair here is deliberately weighted toward drain and boys rather than
	# repeating the slow: ONE call_center in the whole fight, at the halfway
	# point, and never in `per_head`.
	"reinforcements": [
		{"at_boss_fraction": 0.75, "from": "start",
			"enemies": ["social_media", "social_media"],
			"per_head": ["social_media"]},
		{"at_boss_fraction": 0.5, "from": "start",
			"enemies": ["call_center", "office_boy"],
			"per_head": ["office_boy"]},
		{"at_boss_fraction": 0.25, "from": "start",
			"enemies": ["social_media", "social_media", "office_boy"],
			"per_head": ["social_media"]},
	],
	# The penthouse, and the last time anybody is kind to you. He comes up by the
	# south door - the one that seals behind you, as every room's does until it
	# is beaten - and he arrives once it is, already on the inside of it with
	# you. East of the desk and off the rug, in the open floor the fight is
	# fought across.
	"relief": {"npc": "ivan", "from": "start", "at": Vector2(400, 176),
		"say": "res://game/npcs/ivan/after_silverman_office.gd"},
}
