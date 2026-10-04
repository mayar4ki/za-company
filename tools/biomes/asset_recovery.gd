extends RefCounted
## Floor 8 of THE NEW HIRE - the office boys' own repair floor, filed by the
## company under recovering value from what is broken.
##
## Data only, read by tools/biomes.gd; the key reference lives there.

const BIOME := {
	"node": "AssetRecovery",
	"title": "ASSET RECOVERY",
	# The back of house: dim, warm, worn, lit by whatever tubes still work,
	# against a building of polished stone and glass. The ramp is brown-grey
	# rather than blue-grey so arriving here reads as leaving the part of the
	# building visitors see - and the name on the door reads as the company
	# describing a junk room as a value stream, which is the same joke
	# CONFLICT RESOLUTION tells about a gym.
	"ramp": ["17130f", "302a22", "544a3c", "857a66", "b8ad96", "e4dcc8"],
	# Amber: warning lights, hazard tape, the colour of something being
	# worked on. Deliberately not the lobby's company teal - that teal is
	# now on the office boys' polos instead, so the uniform reads against
	# the room rather than into it.
	"accent": "e8a33a",
	# Above the lobby's 0.80: this floor is not over-lit, it is under-lit.
	"gamma": 0.95,
	# Dimmer than the lobby's floor and further from the ramp's top - a
	# working floor, not a polished one. Still bright enough in the middle
	# that the dark-haired half of the cast reads against it.
	"floor_band": Vector2(0.28, 0.78),
	# Scuffed carpet tiles down the middle rather than the lobby's clean
	# runner: the same band, less of the accent in it.
	"runner": 0.18,
	# DESIGN.md's "dividers as columns". Six of them in two rows, the full
	# colonnade, because on this floor the dividers ARE the open plan - and
	# they break the sight lines that let four office boys be pulled one at
	# a time instead of arriving together.
	"column": "divider",
	"hazard": "power_strip",
	# The junk. The brief for this room is that the office boys are the
	# people who fix things in this company and they are behind, so the
	# floor is their workshop: server racks along the top wall, e-waste
	# heaped down both sides, hardware in bits on every surface, and a
	# printer nobody has been able to use for weeks.
	#
	# It is dressed heavily but NOT in the middle. Two things need open
	# floor: a four-on-one fight, and the heavy attack this floor teaches -
	# an AoE is worthless in a room where you cannot gather anybody. So the
	# junk is a thick perimeter around a clear arena (about x 200-350,
	# y 110-200), which is also what makes the corners feel like somewhere
	# you go to pick a fight rather than somewhere you get cornered.
	#
	# Everything solid also has to leave the enemies room to leave their own
	# corners: they walk straight at the player and slide off what they hit,
	# with no pathfinding to recover from being wedged.
	"props": [
		# The server bank along the top wall, and the machine with the sign.
		{"type": "server_rack", "at": Vector2(150, 56)},
		{"type": "server_rack", "at": Vector2(176, 56)},
		{"type": "server_rack", "at": Vector2(202, 56)},
		{"type": "scrap_pile", "at": Vector2(228, 64)},
		{"type": "printer", "at": Vector2(340, 56)},
		{"type": "notice", "at": Vector2(372, 22), "turn": -0.09},
		{"type": "cooler", "at": Vector2(452, 48)},
		{"type": "dead_plant", "at": Vector2(492, 96)},
		# E-waste heaped down both side walls.
		{"type": "crt_stack", "at": Vector2(44, 128)},
		{"type": "scrap_pile", "at": Vector2(44, 176)},
		{"type": "pc_tower", "at": Vector2(44, 208)},
		{"type": "cable_spool", "at": Vector2(492, 130)},
		{"type": "scrap_pile", "at": Vector2(492, 178)},
		{"type": "toolbox", "at": Vector2(490, 212)},
		# Work in progress on the way into the arena.
		{"type": "toolbox", "at": Vector2(196, 96)},
		{"type": "pc_tower", "at": Vector2(330, 96)},
		{"type": "toolbox", "at": Vector2(452, 108)},
		{"type": "scrap_pile", "at": Vector2(76, 108)},
		# Junk narrowing the two approaches into the arena, without being in
		# it. Each of these was checked against the straight line its nearest
		# office boy walks to the middle: they walk at the player and slide
		# off what they hit, so a prop parked on that line is a prop one of
		# them grinds along on its way to the fight.
		{"type": "scrap_pile", "at": Vector2(168, 128)},
		{"type": "crt_stack", "at": Vector2(392, 128)},
		{"type": "pc_tower", "at": Vector2(176, 188)},
		{"type": "cable_spool", "at": Vector2(400, 190)},
		# Litter, which is the only thing that goes IN the arena: it blocks
		# nothing, so the floor can look worked-on without the fight or the
		# heavy losing the room they need.
		{"type": "debris", "at": Vector2(250, 140)},
		{"type": "debris", "at": Vector2(322, 124)},
		{"type": "debris", "at": Vector2(296, 178)},
		{"type": "debris", "at": Vector2(218, 192)},
		{"type": "debris", "at": Vector2(272, 210)},
		{"type": "debris", "at": Vector2(92, 200)},
		{"type": "debris", "at": Vector2(462, 166)},
		# The open plan itself: three desks nobody has tidied.
		{"type": "desk", "at": Vector2(72, 268)},
		{"type": "chair", "at": Vector2(72, 282)},
		{"type": "desk", "at": Vector2(196, 268)},
		{"type": "chair", "at": Vector2(196, 282)},
		{"type": "desk", "at": Vector2(348, 268)},
		{"type": "chair", "at": Vector2(348, 282)},
		{"type": "toolbox", "at": Vector2(160, 236)},
		{"type": "crt_stack", "at": Vector2(232, 240)},
		{"type": "cable_spool", "at": Vector2(352, 236)},
		{"type": "printer", "at": Vector2(470, 272)},
	],
	# FOUR KNOTS, not four boys one to a quadrant. This is the crowd floor and
	# the one that teaches the heavy, and the old arrangement could not teach
	# it: one body per corner meant no point in the room stood inside two sight
	# radii, so the sword was always the right answer and the ~1.3 rooted
	# seconds the heavy costs never bought anything. An AoE needs a crowd to be
	# an argument.
	#
	# So the corners keep their shape and gain weight - three north-west, three
	# south-west, two in each eastern corner - and every knot is tight enough
	# that walking into one wakes all of it.
	#
	# Every one of them is clear of the door line and both spawns by more than
	# its 80 px sight. None stands on a divider's x either, and that one is easy
	# to get wrong: the colonnade sits at x 72/152/232/312/392/472 with its art
	# 48 px tall, so an enemy parked at one of those x values and a lower y than
	# the divider's foot is drawn BEHIND it and simply cannot be seen until it
	# walks out. Two of these were at x 72 and 472 and were invisible in the
	# room.
	"enemies": [
		# North-west.
		{"type": "office_boy", "at": Vector2(104, 60)},
		{"type": "office_boy", "at": Vector2(56, 96)},
		{"type": "office_boy", "at": Vector2(132, 116)},
		# South-west, and this is the knot the hazard at (120, 152) sits over.
		{"type": "office_boy", "at": Vector2(140, 196)},
		{"type": "office_boy", "at": Vector2(120, 248)},
		{"type": "office_boy", "at": Vector2(56, 240)},
		# North-east.
		{"type": "office_boy", "at": Vector2(436, 64)},
		{"type": "office_boy", "at": Vector2(400, 110)},
		# South-east.
		{"type": "office_boy", "at": Vector2(456, 200)},
		{"type": "office_boy", "at": Vector2(424, 248)},
	],
	# The second beat, and the first floor in the game to have had one. Four
	# knots is the arrangement; this is what happens once it has been
	# three-quarters answered - more walk in through the door you came in by,
	# which on this floor is the only place anybody could come from.
	#
	# It is here rather than anywhere else because this is the CROWD floor and
	# the one that teaches the heavy: the lesson is "three of them are following
	# you and the sword is the wrong answer", and a floor whose whole job is to
	# say that once can afford to say it twice. Nothing above F8 gets one for
	# free - see game/levels/reinforcements.gd for why a room is an arrangement
	# rather than a population, and why these are finite and once each.
	#
	# Arriving through `start` needs no new marker and no vetted position: they
	# come in single file at the south threshold, which is the one spot in the
	# room already guaranteed clear of furniture. They hold if the player is
	# standing in it. The SECOND beat comes down the north stairs instead, so
	# the room's last word arrives from the door the player was leaving by.
	"reinforcements": [
		{"after_kills": 3, "from": "start",
			"enemies": ["office_boy", "office_boy", "office_boy"],
			# The heaviest `per_head` in the game, and this is the floor
			# entitled to it: the crowd floor is the one whose lesson IS the
			# head count, so a party gets two more boys per head rather than
			# one. Boys only, because this room's answer is the heavy and the
			# heavy does not care how many there are.
			"per_head": ["office_boy", "office_boy"]},
		{"after_kills": 8, "from": "returned",
			"enemies": ["office_boy", "office_boy"],
			"per_head": ["office_boy", "office_boy"]},
	],
	# The west wall, which is where DESIGN.md always wanted him, and this is the
	# floor with the heaviest `per_head` in the game - two more boys per head.
	# A room that scales the hardest is the room that most needs the heal to
	# scale too, and it does: one heart per head, out of the same count
	# (game/heads.gd). North of the scrap pile at (44, 176) and well clear of
	# the power strip at (120, 152), which is still live after the last body
	# falls.
	"relief": {"npc": "ivan", "from": "start", "at": Vector2(80, 180),
		"say": "res://game/npcs/ivan/after_asset_recovery.gd"},
}
