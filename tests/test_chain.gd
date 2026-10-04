extends "res://tests/helpers.gd"
## Chain test: the walk up the building. The lobby -> the content studio -> the
## call center -> Ahmed's office -> the hub -> the marble hall -> the innovation
## lab -> the gym -> asset recovery -> hellfire -> the executive floor ->
## Silverman's office, on foot through every door, asserting each room's
## composition and dressing as it passes - and then turning round at the top to
## prove the way back down still works.
##
## Its own suite for the harness's reason: one suite = one process = one clean
## world. The walk used to be the middle of test_flow.gd, after that suite had
## paused, zoomed, died and walked into a wall in the lobby, so every room up
## here had to survive whatever the lobby left behind - and the lobby could not
## grow a check without moving every door above it.
##
## ## Legs, not frames
##
## That suite was one match over ABSOLUTE frame numbers, so inserting a floor
## meant renumbering every frame after it, about eighty per door. Here each floor
## is a function handed frames counted from its own first frame, and LEGS says
## how long each one lasts: a floor inserted into the building is one function
## and one row, and no other leg moves.
##
## ## Two things the walk needs that a clean install does not give it
##
## The ZOOM. A clean install opens at 150%, where the camera follows the player,
## and every door's "camera reframed on the new level" asks for the room's
## centre - which is only where the camera sits when the whole room fits.
## test_flow.gd used to leave the run at 100% by picking it in the pause menu;
## this suite asks Display for it before the run starts. That writes
## settings.cfg, which helpers.gd hands back at the end like everything else.
##
## The LOBBY'S OWN TRACK. The door out of the lobby is the one real handoff in
## the first half of the chain, and the check two floors up that the bed has
## taken over only means something if the lobby's track was really playing as
## the player left. So the lobby leg waits out the menu's handoff, and says so.

## Nine floors of twelve play this one, and the same copy of it: the bed is
## handed from room to room rather than restarted at each door.
const BED := "res://assets/music/level_loop.wav"

## Floor 1's own, and the only track in the building below the finale that is a
## FLOOR's rather than a boss's. It is here so the door out of the lobby is a
## real handoff - two different files, one player - rather than the no-op every
## other ordinary door is.
const LOBBY := "res://assets/music/lobby_loop.wav"

## The walk, one floor at a time. Each row is a leg's function and how many
## frames it lasts; the function is handed frames counted from its own first
## frame. Inserting a floor is one function and one row - no other leg moves.
##
## A floor's leg is 80 frames, the spacing every door of the walk has always
## had: up into the north door from y 78 and the two fades either side of it.
## The lobby's is longer because it waits for its own music first, and the
## hub's because it stands on its hazard first.
const LEGS := [
	[&"_start", 26],
	[&"_lobby", 163],
	[&"_content_studio", 80],
	[&"_call_center", 80],
	[&"_ahmed_office", 80],
	[&"_the_hub", 100],
	[&"_marble_hall", 80],
	[&"_innovation_lab", 80],
	[&"_conflict_resolution", 80],
	[&"_asset_recovery", 80],
	[&"_hellfire", 80],
	[&"_executive_floor", 80],
	[&"_silverman_office", 80],
	[&"_back_down", 1],
]

## How far into the bed the hub was, read at its door and checked again at the
## next one. A restart would put this back to nearly nothing.
var _bed_position := 0.0


func _tick(frame: int) -> void:
	var start := 0
	for leg in LEGS:
		if frame < start + int(leg[1]):
			call(leg[0], frame - start)
			return
		start += int(leg[1])


## Into a run, the way test_flow.gd gets there: the menu, the character select,
## the game. The zoom is put at 100% before any of it, so the run is built
## framing the whole room - see the header.
func _start(frame: int) -> void:
	match frame:
		2:
			_autoload("Display").call("set_zoom", 1.0)
			(current_scene.get_node("%PlayButton") as Button).pressed.emit()
		14:
			# The same pick as test_flow.gd's; nothing on the walk depends on who.
			(current_scene.get_node("%Roster/reem") as Button).pressed.emit()


## Floor 1: arrive, wait for the lobby's own track, then out by the north door.
func _lobby(frame: int) -> void:
	match frame:
		0:
			_check("start: the walk sets out from the lobby (got %s)"
				% ("<none>" if _level() == null else _level().name),
				current_scene.scene_file_path == "res://game/game.tscn"
					and _level() != null and _level().name == "Lobby")
			# The premise every door below leans on, measured rather than
			# assumed: at 100% the room fits, so the camera sits on its centre.
			_check("camera: the walk is framed whole, at 100%% (zoom %s, at %s)"
				% [_camera().zoom, _camera().global_position],
				_camera().zoom == Vector2(1, 1)
					and _camera().global_position == _level().bounds().get_center())
			# Nobody in the lobby to beat, so its door is open from the first
			# frame - the one room in the building that is not a lock.
			_check("lock: the lobby has nobody in it to beat, so it is open from the start",
				get_nodes_in_group("enemies").is_empty() and _doors_say(true))
		88:
			# The menu's track has had to leave before this one could start, and
			# 88 frames after arriving is comfortably past Music.FADE_SECONDS.
			# Checked here, as the player leaves, because the call center's
			# "gave way to the building's bed" is only a handoff if this was the
			# track being handed off.
			_check("music: the lobby is playing its own track as the walk leaves it (%s)"
				% ("<silent>" if _music_track() == "" else _music_track()),
				_music_track() == LOBBY)
			# Walk north into the doorway. Approaching on foot rather than
			# teleporting onto the threshold is the point: this is the path a
			# player actually takes through the door.
			_leave(Vector2(272, 78))


## Floor 2.
func _content_studio(frame: int) -> void:
	match frame:
		0:
			_key(KEY_W, false)
			_check("door: walking north out of the lobby loads the studio (got %s)"
				% ("<none>" if _level() == null else _level().name),
				_level() != null and _level().name == "ContentStudio")
			_check("door: player arrives by the studio's south door (%s)"
				% _player().global_position,
				_player().global_position.distance_to(Vector2(272, 240)) < 40.0)
			_check("door: transition faded back in",
				(current_scene.get_node("Transition/Fade") as ColorRect).color.a < 0.01)
			_check("door: camera reframed on the new level (%s)"
				% _camera().global_position,
				_camera().global_position == _level().bounds().get_center())
			_check("title: walking through a door announces the new room (got '%s' at %.2f)"
				% [_title_text(), _title().modulate.a],
				_title_text() == "THE CONTENT STUDIO" and _title().modulate.a == 1.0)
			# Deliberately NOT read here. The door behind the player was a
			# handoff - the lobby's track had to finish leaving before the bed
			# could start - so the bed is still coming up on this frame and the
			# playhead belongs to the wrong file. The bed's own no-restart check
			# is the hub's door, where it has been playing since Ahmed conceded.
			# The studio's furniture IS its lighting, which is why the count is
			# checked rather than one instance: five stands is the difference
			# between a lit room and a dark one with a lamp in it.
			var stands: Array = _level().get_node("Props").get_children().filter(
				func(n: Node) -> bool: return n.name.begins_with("RingLight"))
			_check("level: the studio is lit by five ring lights (%d)"
				% stands.size(), stands.size() == 5)
			var kit := ["Backdrop1", "Neon1", "CameraRig1", "EditDesk1", "Sofa1"]
			var short: Array = kit.filter(func(n: String) -> bool:
				return _level().get_node_or_null("Props/" + n) == null)
			_check("level: the studio is dressed as a studio (missing %s)"
				% [short], short.is_empty())
			# The sixth light is the hazard: DESIGN.md's ring light knocked over
			# and left at full output. Its presence is what proves a biome can
			# pick a hazard style that is neither fire nor sparks.
			_check("level: the fallen ring light is standing in the room",
				_level().get_node_or_null("Props/Torch") != null)
			# And from here up the standing five are hazards too, on the floor's
			# clock. What the rhythm actually DOES is tests/test_studio.gd's -
			# it takes eleven seconds to watch one turn of it, which is not
			# something to do in the middle of a walk through twelve floors.
			# What belongs here is that the dressing still carries it: a biome
			# that lost the `studio` key would leave a room that looks right,
			# passes every check above, and never switches on.
			_check("level: the studio runs a clock",
				_level().get_node_or_null("Studio") != null
					and (_level().get_node("Studio") as Node).is_in_group("studio"))
			_check("level: the rig and the rail it runs on are both in the room",
				_level().get_node_or_null("Props/Dolly") != null
					and _level().get_node_or_null("Props/Rail1") != null)
			# Hearts are the lobby's alone: floor 1 is where a player finds out
			# what a heal is, and above it the supply is meant to be Ivan
			# carrying one to you, not a room leaving one lying about. Checked on
			# the first floor above the lobby, where the rule first bites.
			_check("level: no heart above the lobby",
				_level().get_node_or_null("Props/Health") == null)
			# Four drain fields and the two fights inside one of them. The west
			# side is a POCKET rather than a picket, and the property below is what
			# that means: there is a spot over there where all four of the west's
			# bodies can see the player at once. Four spread across a half is four
			# errands; four whose fields share a point is a fight, and it is the
			# floor's routing lesson - the fallen ring light at (120, 152) sits
			# under it. It stops being true the moment any of them is nudged out.
			_check("enemies: the studio fields four drains and three boys (%s)"
				% [_cast()], _cast() == ["office_boy", "office_boy",
					"office_boy", "social_media", "social_media",
					"social_media", "social_media"])
			var west: Array = get_nodes_in_group("enemies").filter(
				func(n: Node2D) -> bool:
					return n.position.x < 160.0)
			var together := false
			for px in range(16, 160, 4):
				for py in range(16, 288, 4):
					var at := Vector2(px, py)
					var all_see := true
					for n in west:
						var d := (n as Node2D).position.distance_to(at)
						if d > float(n.get("sight_radius")):
							all_see = false
							break
					if all_see:
						together = true
						break
				if together:
					break
			_check("enemies: and the four western fields share a spot (%d west)"
				% west.size(), west.size() == 4 and together)
			_leave(Vector2(272, 78))


## Floor 3, the dogleg.
func _call_center(frame: int) -> void:
	match frame:
		0:
			_key(KEY_W, false)
			_check("door: the chain continues on into the call center (got %s)"
				% ("<none>" if _level() == null else _level().name),
				_level() != null and _level().name == "CallCenter")
			_check("title: the call center announces itself (got '%s')"
				% _title_text(), _title_text() == "THE CALL CENTER")
			# TWO FLOORS BACK the lobby was playing its own track, and by here
			# the building's bed has taken over. That is the handoff finishing:
			# there is one player, so the lobby's track had to fade out before
			# the bed could start, and it is the only door in the first half of
			# the chain that is not a no-op. The bed arriving LATE is the whole
			# reason it is checked a floor further on than the door that asked
			# for it.
			_check("music: the lobby's track gave way to the building's bed (%s)"
				% ("<silent>" if _music_track() == "" else _music_track()),
				_music_track() == BED)
			# DESIGN.md's densest floor, and the density IS the room: twenty-four
			# dividers in four ranks rather than asset recovery's twelve in two.
			# Counted, because a maze that lost a rank is not a maze.
			var maze: Array = _level().get_node("Props").get_children().filter(
				func(n: Node) -> bool: return n.name.begins_with("Column"))
			_check("level: the call floor is a maze of twenty-four dividers (%d)"
				% maze.size(), maze.size() == 24)
			var ranks: Array = _level().get_node("Props").get_children().filter(
				func(n: Node) -> bool: return n.name.begins_with("CallDesk"))
			# Thirteen seats: two ranks across the hall and a bank up the arm,
			# which is the annex being a quarter of the floor rather than a
			# corridor. A room this size dressed for the old one reads as a
			# call floor somebody has already been made redundant from.
			_check("level: thirteen identical stations in it (%d)"
				% ranks.size(), ranks.size() == 13)
			# The board is the floor's joke, and it is also the one thing on it
			# that needed new drawing code - the pixel font had no digits until a
			# board that counts calls needed to write a number.
			var fittings := ["Wallboard1", "Notice1", "Printer1", "Cooler1"]
			var bare: Array = fittings.filter(func(n: String) -> bool:
				return _level().get_node_or_null("Props/" + n) == null)
			_check("level: the call floor is dressed as a call floor (missing %s)"
				% [bare], bare.is_empty())
			# The jammed photocopier, which is a hazard rather than furniture:
			# the catalogue's `printer` is a machine nobody can use and this is a
			# machine nobody should touch. Both are in this room.
			_check("level: the jammed copier is standing in the room",
				_level().get_node_or_null("Props/Torch") != null)
			# Two slowers and seven boys, and the PAIR is still the lesson - so
			# when this floor's weight needs trimming it loses a boy, never one of
			# these. The boys went up because a slow the player can walk off before
			# reaching the next body is the lesson cancelling itself out.
			_check("enemies: the call floor fields the pair and seven boys (%s)"
				% [_cast()], _cast() == ["call_center", "call_center",
					"office_boy", "office_boy", "office_boy", "office_boy",
					"office_boy", "office_boy", "office_boy"])
			# Nobody parked behind a divider's 48 px of panel. Twenty-four
			# dividers is twenty-four chances to make an enemy invisible rather
			# than merely unfair, and only the ones NORTH of a foot hide
			# anything - within the
			# panel's own height of it, which is the half of the rule the old
			# version of this check got for free by every body being in the top
			# half of a room that no longer exists.
			var hidden: Array = get_nodes_in_group("enemies").filter(
				func(n: Node2D) -> bool:
					for x in [72, 152, 232, 312, 392, 552]:
						if absf(n.position.x - float(x)) >= 24.0:
							continue
						for foot in [352.0, 432.0, 512.0, 560.0]:
							if n.position.y < foot and n.position.y >= foot - 48.0:
								return true
					return false)
			_check("enemies: none of the nine hides behind a divider (%d)"
				% hidden.size(), hidden.is_empty())
			# THE DOGLEG: the way up is at the top of an arm in the north-east
			# corner, not over the door the player came in by. Every other floor in
			# the chain is left by walking straight up the middle.
			_leave(Vector2(480, 78))


## Floor 4, the first boss.
func _ahmed_office(frame: int) -> void:
	match frame:
		0:
			_key(KEY_W, false)
			_check("door: the chain continues on into Ahmed's office (got %s)"
				% ("<none>" if _level() == null else _level().name),
				_level() != null and _level().name == "AhmedOffice")
			_check("title: the boss floor announces itself (got '%s')"
				% _title_text(), _title_text() == "AHMED'S CORNER OFFICE")
			# The one thing this room is built around not having. Ahmed is the
			# only thing in here that is meant to hurt, and he is build step 6.
			_check("level: Ahmed's office has no hazard in it",
				_level().get_node_or_null("Props/Torch") == null)
			_check("level: no heart on the boss floor",
				_level().get_node_or_null("Props/Health") == null)
			# Ahmed is the only thing in here, and he is in the way: a room's
			# doors are shut until it is beaten, and on a boss floor that is
			# him conceding. The fight itself is test_bosses.gd's; this walk
			# concedes him the short way so the chain can go on.
			var boss := _level().get_node_or_null("Props/Boss")
			_check("boss: Ahmed stands in his office", boss != null)
			_check("level: no adds at rest on the boss floor - Ahmed alone (%d)"
				% get_nodes_in_group("enemies").size(),
				get_nodes_in_group("enemies").size() == 1)
			_check("door: both ways out are shut while Ahmed stands",
				_doors_say(false))
			# The bar is game.gd's doing, not the boss's: it finds him by group
			# on arrival and feeds the HUD the way it feeds the player's own.
			_check("hud: the boss bar is up and names him (got '%s')"
				% _boss_name(), _boss_bar().visible and _boss_name() == "AHMED")
			# His theme rides in on the same wiring as his bar, and the whole
			# reason it is checked HERE is that three floors of the bed came
			# first: a boss is the only thing that interrupts it.
			_check("music: Ahmed's floor brings his theme up (%s)"
				% ("<silent>" if _music_track() == "" else _music_track()),
				_music_track() == "res://assets/music/ahmed_theme_loop.wav")
			# Sealed to a real end, not frame 0 - see test_menu.gd. A theme
			# that loops at frame 0 is a silent fight with every other check
			# in this suite still green.
			var theme := null if _music() == null else _music().stream as AudioStreamWAV
			_check("music: his stream is sealed as a loop with a real end (%d)"
				% (0 if theme == null else theme.loop_end),
				theme != null and theme.loop_mode == AudioStreamWAV.LOOP_FORWARD
					and theme.loop_end > 0)
			_check("hud: it opens full - 240 px of channel for 144 HP (%s)"
				% _boss_fill().size.x, is_equal_approx(_boss_fill().size.x, 240.0))
			if boss != null:
				# A quarter of him, to prove the width is his health arriving by
				# signal and not a number read once on the way in. 36 of 144 is a
				# quarter of the bar, and the chip is that quarter standing pale
				# where the fill was.
				boss.call("take_damage", 36)
			_check("hud: a quarter of him comes off the bar (%s)"
				% _boss_fill().size.x, is_equal_approx(_boss_fill().size.x, 180.0))
			_check("hud: the chip stands in the 60 px it just lost (%s wide, %s)"
				% [_boss_chip().size.x, _boss_chip().visible],
				_boss_chip().visible and is_equal_approx(_boss_chip().size.x, 60.0))
			if boss != null:
				boss.call("take_damage", 108)
			_check("boss: at zero he concedes rather than dying (%s)"
				% ("gone" if boss == null else str(boss.get("has_conceded"))),
				boss != null and boss.get("has_conceded") == true)
			_check("hud: the bar goes with him when he kneels",
				not _boss_bar().visible)
			# The quarter above put him ON his first beat's threshold and the
			# blow after it took him to nothing before the beat could answer:
			# a beat he never called is not one the doors may wait for.
			_check("door: both ways open once he has, uncalled beats and all",
				_doors_say(true))
			_leave(Vector2(272, 78))


## Floor 5, and the one leg with two stops in it: the room, then its hazard.
func _the_hub(frame: int) -> void:
	match frame:
		0:
			_key(KEY_W, false)
			_check("door: the chain continues on into the hub (got %s)"
				% ("<none>" if _level() == null else _level().name),
				_level() != null and _level().name == "TheHub")
			_check("title: the hub announces itself (got '%s')"
				% _title_text(), _title_text() == "THE HUB")
			# Cleared on entry, not left behind by the floor below: a room
			# with no boss in it clears the bar whether or not one ever hid it.
			_check("hud: no boss bar on the floor above his",
				not _boss_bar().visible)
			# And no theme either: the bed is back. It took over on `conceded`
			# rather than at the door, which is why the handoff is long over by
			# the time the next room is standing - the fight ended, not the
			# floor.
			_check("music: his theme gave way to the bed (%s)"
				% ("<silent>" if _music_track() == "" else _music_track()),
				_music_track() == BED)
			# Sealed to a real end, not to frame 0 - see test_menu.gd. The lobby's
			# track is the same check in test_flow.gd; this is the building's,
			# which plays on nine of the twelve floors and so is the track with
			# the most to lose from a loop that wraps before it has played
			# anything.
			var bed := null if _music() == null else _music().stream as AudioStreamWAV
			_check("music: the building's bed is a loop with a real end (%d)"
				% (0 if bed == null else bed.loop_end),
				bed != null and bed.loop_mode == AudioStreamWAV.LOOP_FORWARD
					and bed.loop_end > 0)
			# Noted here, tested at the next door: two ordinary floors share one
			# bed, and asking for the track already playing is a no-op. This is
			# the pair rather than the studio's door because the bed has been
			# playing since Ahmed gave in a floor below, so the number read here
			# is the bed's own and not a handoff caught halfway.
			#
			# SEEKED first, for test_music.gd's reason: headless mixing crawls,
			# so the playhead is still at 0.00 here and "it did not go
			# backwards" would be true of a restart as well. A seek is not
			# mixing - it puts the playhead where no fresh `play()` could leave
			# it, and the door either keeps it there or does not.
			_music().seek(20.0)
			_bed_position = _music().get_playback_position()
			# The floor's split, fought: the slower holds the call side and both
			# drains are INSIDE the glass offices - which is what makes each
			# office a decision rather than dressing, since the only way in is
			# through its one 32 px gap.
			_check("enemies: the hub fields a slower, four boys, three drains (%s)"
				% [_cast()], _cast() == ["call_center", "office_boy",
					"office_boy", "office_boy", "office_boy", "social_media",
					"social_media", "social_media"])
			var east: Array = get_nodes_in_group("enemies").filter(
				func(n: Node2D) -> bool:
					return n.position.x > 300.0 						and n.scene_file_path.contains("social_media"))
			_check("enemies: and both drains sit in the media half (%d of 2)"
				% east.size(), east.size() == 2)
			# One room, two halves, and what is checked is that BOTH halves came
			# through the regeneration: phones and cubicles on the call side,
			# glass and lit screens on the media side. Same guard as every other
			# dressing check here - a stale build leaves a bare box that passes
			# every other check on this floor.
			var halves := ["CallDesk1", "Whiteboard1", "Partition1", "EditDesk1",
				"Poster1", "CameraRig1"]
			var gone: Array = halves.filter(func(n: String) -> bool:
				return _level().get_node_or_null("Props/" + n) == null)
			_check("level: both halves of the hub are dressed (missing %s)"
				% [gone], gone.is_empty())
			# The offices are runs of partition segments with a segment left out
			# for the door, six to a bay. Counted rather than spot-checked,
			# because a bay that lost a pane is a bay with a hole in it.
			var glass: Array = _level().get_node("Props").get_children().filter(
				func(n: Node) -> bool: return n.name.begins_with("Partition"))
			_check("level: the media half is walled into two offices (%d panes)"
				% glass.size(), glass.size() == 12)
			# The hazard check lives here rather than on floor 1, which no longer
			# has one: this is a floor with a hazard AND nobody in it, so
			# standing on the arcing power strip proves hazard_base.gd hurts
			# without an office boy wandering into the measurement.
			_health_mark = _player().get("health")
			_player().global_position = Vector2(120, 152)
		20:
			_check("hazard: standing on the power strip costs health (%d -> %s)"
				% [_health_mark, _player().get("health")],
				_player().get("health") < _health_mark)
			# On along the chain, from the same distance every other leg is
			# walked from.
			_leave(Vector2(272, 78))


## Floor 6.
func _marble_hall(frame: int) -> void:
	match frame:
		0:
			_key(KEY_W, false)
			_check("door: the chain continues on into the marble hall (got %s)"
				% ("<none>" if _level() == null else _level().name),
				_level() != null and _level().name == "MarbleHall")
			# The bed crossed the door rather than starting again behind it.
			# Read off the playback position and not off the track name, which
			# a restart would leave looking identical - and it moves under the
			# dummy driver, which is the only reason this is checkable headless.
			#
			# `>=` rather than `>`: the dummy driver advances the playhead by
			# whole mix buffers, so 80 frames of a fast headless run may not
			# move it at all. What a restart cannot do is send it BACKWARDS,
			# and that is the whole of what is being asked here.
			_check("music: the same bed plays on into the marble hall (%s)"
				% ("<silent>" if _music_track() == "" else _music_track()),
				_music_track() == BED)
			_check("music: and it was not started over at the door (%.2fs, was %.2fs)"
				% [_music().get_playback_position(), _bed_position],
				_music().get_playback_position() >= _bed_position)
			# Eight guards in two gangs, and they are the RESKIN. This floor was
			# the last one
			# outside hellfire and the exam still fielding an original, and the
			# retype is the building's rule made whole: the reskins are the
			# company's staff and hold floors 1-9, the originals appear only
			# from hellfire up. Mechanically identical - the same 24 HP, the
			# same cycle - so this check is about the costume and nothing else.
			#
			# Plus the one `security`, standing in the middle of the east gang:
			# the fourth archetype's only appearance in the building, and the
			# reason this floor is no longer one enemy repeated twelve times.
			# It is listed LAST because build_levels.gd writes a biome's
			# `enemies` in the order they are authored, so this assertion is
			# also quietly checking that the data file still reads west gang,
			# east gang, anchor - which is how anybody reading it finds him.
			_check("enemies: the marble hall fields eight office boys and one security (%s)"
				% [_cast()], _cast() == ["office_boy", "office_boy",
					"office_boy", "office_boy", "office_boy", "office_boy",
					"office_boy", "office_boy", "security"])
			# The nave's doors are at col 12, not the building's usual col 16 -
			# so the walk up and out of this one is x 208 rather than x 272.
			_leave(Vector2(208, 78))


## Floor 7, the S.
func _innovation_lab(frame: int) -> void:
	match frame:
		0:
			_key(KEY_W, false)
			_check("door: the chain continues on into the innovation lab (got %s)"
				% ("<none>" if _level() == null else _level().name),
				_level() != null and _level().name == "InnovationLab")
			_check("title: the innovation lab announces itself (got '%s')"
				% _title_text(), _title_text() == "THE INNOVATION LAB")
			# Ten workstations, and the count is the check because the pods
			# ARE the room: one in the machine room at the top, six across the
			# open plan in the middle, three in the pod you walk in on.
			var pods: Array = _level().get_node("Props").get_children().filter(
				func(n: Node) -> bool: return n.name.begins_with("DevDesk"))
			_check("level: ten workstations on the innovation lab (%d)"
				% pods.size(), pods.size() == 10)
			# The two things written on this floor's walls, and the two things
			# that make it read as an engineering floor rather than an office
			# with nice lighting: a diagram nobody may erase, and a build that
			# has been failing for nine runs.
			var fitted := ["Diagram1", "BuildBoard1", "Coffee1", "ServerRack1",
				"Sofa1"]
			var wanting: Array = fitted.filter(func(n: String) -> bool:
				return _level().get_node_or_null("Props/" + n) == null)
			_check("level: the innovation lab is dressed as one (missing %s)"
				% [wanting], wanting.is_empty())
			_check("level: it has the power strip and no heart",
				_level().get_node_or_null("Props/Torch") != null
					and _level().get_node_or_null("Props/Health") == null)
			# THE FIRST ONE-OF-EACH MIX, and since the floor became an S the
			# arrangement is per HALL rather than per quadrant: three rooms you
			# cannot see out of, each of which asks for more than one answer at
			# a time. This floor had
			# no mechanic assigned, and being the first room that asks for all
			# three answers at once IS the mechanic - which is also what earns
			# the executive floor as its exam, the same fight one rank bigger.
			_check("enemies: the lab fields a slower, five boys, three drains (%s)"
				% [_cast()], _cast() == ["call_center", "office_boy",
					"office_boy", "office_boy", "office_boy", "office_boy",
					"social_media", "social_media", "social_media"])
			# And none of the three halls is empty. The quadrant check this
			# replaces asked the same question of a rectangle - is the room an
			# arrangement or a heap - and on a floor you cannot see across it is
			# the one that matters: a hall the player walks into empty is a
			# third of the floor spent on nothing. Two bodies is the floor,
			# because one is an errand.
			var halls := [0, 0, 0]
			for n in get_nodes_in_group("enemies"):
				var y: float = (n as Node2D).position.y
				halls[0 if y < 256.0 else (1 if y < 624.0 else 2)] += 1
			_check("enemies: every hall of the S is arranged, none is a walk (%s)"
				% [halls], halls.min() >= 2 and halls[0] + halls[1] + halls[2] == 9)
			# The way out of this one is the TOP hall's east end - col 24, not
			# the building's usual col 16 - so the climb out is x 400.
			_leave(Vector2(400, 78))


## Floor 8, the second boss.
func _conflict_resolution(frame: int) -> void:
	match frame:
		0:
			_key(KEY_W, false)
			_check("door: the chain continues on into the gym (got %s)"
				% ("<none>" if _level() == null else _level().name),
				_level() != null and _level().name == "ConflictResolution")
			_check("title: the gym announces itself (got '%s')"
				% _title_text(), _title_text() == "CONFLICT RESOLUTION")
			# DESIGN.md asks this floor for a tight arena with nothing in it to
			# hide behind, and it is the first floor to have NO colonnade at
			# all. Both halves of that are checked: nothing placed, and no
			# scene left behind for the thing it does not place.
			var pillars: Array = _level().get_node("Props").get_children().filter(
				func(n: Node) -> bool: return n.name.begins_with("Column"))
			_check("level: the gym has no colonnade (%d)" % pillars.size(),
				pillars.is_empty())
			_check("level: and carries no column scene either",
				not ResourceLoader.exists(
					"res://game/levels/conflict_resolution/props/fixtures/column.tscn"))
			# The ring is paint, not a thing: a marking blocks nothing, so its
			# scene root is a bare Node2D rather than a body. Getting this wrong
			# would put an invisible wall across the middle of a boss arena.
			var ring := _level().get_node_or_null("Props/BoxingRing1")
			_check("level: the ring is painted on the floor and blocks nothing",
				ring != null and not (ring is StaticBody2D))
			var gear := ["Motto1", "HeavyBag1", "WeightRack1", "Sofa1"]
			var unfit: Array = gear.filter(func(n: String) -> bool:
				return _level().get_node_or_null("Props/" + n) == null)
			_check("level: the gym is dressed as a gym (missing %s)"
				% [unfit], unfit.is_empty())
			# A boss room has one thing in it that hurts, and it is the boss:
			# no hazard, no heart, and for now no Big Mo either.
			_check("level: no hazard and no heart in the gym",
				_level().get_node_or_null("Props/Torch") == null
					and _level().get_node_or_null("Props/Health") == null)
			# Big Mo and nothing else: a rhythm fight is one fight, so the ring
			# has to stay clear. Same shape as the check on Ahmed's floor.
			_check("boss: Big Mo stands in the ring",
				_level().get_node_or_null("Props/Boss") != null
					and _level().get_node("Props/Boss").is_in_group("bosses"))
			_check("level: no adds in the gym - Big Mo alone (%d)"
				% get_nodes_in_group("enemies").size(),
				get_nodes_in_group("enemies").size() == 1)
			# The SECOND boss, and the point of checking him too: nothing about
			# the bar is per boss. He is named off his own scene, not his node,
			# which build_levels.gd calls Boss on every floor alike.
			_check("hud: the gym's boss gets the same bar, named for him (got '%s')"
				% _boss_name(), _boss_bar().visible and _boss_name() == "BIG MO")
			_check("hud: full channel for his 216 as much as for Ahmed's 144 (%s)"
				% _boss_fill().size.x, is_equal_approx(_boss_fill().size.x, 240.0))
			# And the theme on the same terms as the bar: HIS file, named on his
			# scene root, not Ahmed's carried up three floors. Three rooms of
			# the bed stand between the two fights, so what this actually
			# catches is a second theme that never replaced the first.
			_check("music: the gym plays Big Mo's theme, not Ahmed's (%s)"
				% ("<silent>" if _music_track() == "" else _music_track()),
				_music_track() == "res://assets/music/big_mo_theme_loop.wav")
			var gym_theme := null if _music() == null else _music().stream as AudioStreamWAV
			_check("music: his stream is sealed as a loop with a real end (%d)"
				% (0 if gym_theme == null else gym_theme.loop_end),
				gym_theme != null and gym_theme.loop_mode == AudioStreamWAV.LOOP_FORWARD
					and gym_theme.loop_end > 0)
			_leave(Vector2(272, 78))


## Floor 9.
func _asset_recovery(frame: int) -> void:
	match frame:
		0:
			_key(KEY_W, false)
			_check("door: the chain continues on into asset recovery (got %s)"
				% ("<none>" if _level() == null else _level().name),
				_level() != null and _level().name == "AssetRecovery")
			_check("title: asset recovery announces itself (got '%s')"
				% _title_text(), _title_text() == "ASSET RECOVERY")
			# The one floor above the lobby that has its people already, and they
			# are the COMPANY's - office boys, not dungeon guards. The scene path
			# is what proves that, since build_levels.gd names every enemy
			# instance Enemy<n> whatever type it is.
			var boys := get_nodes_in_group("enemies")
			var reskinned: Array = boys.filter(func(e: Node) -> bool:
				return e.scene_file_path.contains("office_boy"))
			_check("enemies: asset recovery fields ten office boys (%d of %d)"
				% [reskinned.size(), boys.size()],
				boys.size() == 10 and reskinned.size() == 10)
			_check("enemies: an office boy is a reskin, so it has a guard's health (%s)"
				% (boys[0].get("max_health") if not boys.is_empty() else "<none>"),
				not boys.is_empty() and boys[0].get("max_health") == 24)
			# Nothing has noticed the player yet, which is the placement rule
			# this room has to keep: the walk from the south door to the north
			# one passes no office boy's 80 px sight.
			var awake: Array = boys.filter(func(e: Node) -> bool:
				return e.get("phase") != 0)
			_check("enemies: the door-to-door walk wakes nobody (%d awake)"
				% awake.size(), awake.is_empty())
			# The junk is the room. Same guard as the lobby's dressing check, and
			# it matters more here: a regeneration with stale data would leave an
			# empty box that still passed every other check on this floor.
			var junk := ["ServerRack1", "Printer1", "CrtStack1", "Toolbox1",
				"CableSpool1", "ScrapPile1", "Debris1", "Notice1"]
			var absent: Array = junk.filter(func(n: String) -> bool:
				return _level().get_node_or_null("Props/" + n) == null)
			_check("level: asset recovery is dressed as a repair floor (missing %s)"
				% [absent], absent.is_empty())
			_leave(Vector2(272, 78))


## Floor 10.
func _hellfire(frame: int) -> void:
	match frame:
		0:
			_key(KEY_W, false)
			_check("door: the chain continues on into hellfire (got %s)"
				% ("<none>" if _level() == null else _level().name),
				_level() != null and _level().name == "Hellfire")
			# Still up, and reading the room we are in now: a second card cuts the
			# first one off rather than queueing behind it.
			_check("title: a new room replaces the last one's name (got '%s' at %.2f)"
				% [_title_text(), _title().modulate.a],
				_title_text() == "HELLFIRE" and _title().modulate.a == 1.0)
			# Per-biome composition, second half: hellfire is the room that
			# escalates, and both of its extras are identified by their own
			# exports rather than by class, the way everything here avoids the
			# class cache.
			var here := get_nodes_in_group("enemies")
			var drainers := here.filter(func(e): return e.get("drain_per_second") != null)
			var slowers := here.filter(func(e): return e.get("slow_seconds") != null)
			_check("enemies: hellfire fields all three types (%d: %dD %dS)"
				% [here.size(), drainers.size(), slowers.size()],
				here.size() == 10 and drainers.size() == 3 and slowers.size() == 1)
			# Straight on through, and the walk is the check: hellfire keeps
			# every sight radius off the door line like every other floor, so ten
			# enemies in the room still let the player cross it.
			#
			# The x is ASKED FOR rather than written down. This floor is not a
			# rectangle and has been re-cut once already - the way out was x 320
			# when its doors were at col 19, and a reshape moved it without
			# moving anything a check here could see, so the suite walked into
			# masonry for eighty frames and blamed the door. `walk_lane()` is
			# the room's own answer to "where may somebody stand", which is the
			# same question, so a floor re-cut again tomorrow still crosses.
			var lane: Array[Rect2] = _level().call("walk_lane")
			var top: Rect2 = lane[0]
			for leg in lane:
				if leg.position.y < top.position.y:
					top = leg
			_leave(Vector2(top.get_center().x, 78))


## Floor 11, the exam.
func _executive_floor(frame: int) -> void:
	match frame:
		0:
			_key(KEY_W, false)
			_check("door: the chain continues on into the executive floor (got %s)"
				% ("<none>" if _level() == null else _level().name),
				_level() != null and _level().name == "ExecutiveFloor")
			_check("title: the executive floor announces itself (got '%s')"
				% _title_text(), _title_text() == "THE EXECUTIVE FLOOR")
			# The glass wall IS the room: fourteen bays across the whole floor
			# with one gap in the middle, which is DESIGN.md's centre chokepoint
			# drawn rather than described. Counting them is what catches a bay
			# lost out of the data, since a wall with a second hole in it stops
			# being a chokepoint at all.
			var glass: Array = _level().get_node("Props").get_children().filter(
				func(n: Node) -> bool: return n.name.begins_with("Partition"))
			_check("level: fourteen bays of glass across the floor (%d)"
				% glass.size(), glass.size() == 14)
			# And the gap is where the doors are. Every level in the chain has
			# to leave the door line walkable, and this is the only one that
			# builds a wall across the line it has to leave open.
			var across: Array = glass.filter(func(n: Node2D) -> bool:
				return absf(n.position.x - 272.0) < 48.0)
			_check("level: the chokepoint is open on the door line (%d in it)"
				% across.size(), across.is_empty())
			# The prizes are behind the glass, which is the whole point of
			# putting them there: DESIGN.md wants every one of them to cost a
			# step into somebody's radius.
			var fitted := ["AwardsCabinet1", "AwardsCabinet4", "BoardroomTable1",
				"Portrait1", "BarCart1", "Rug1"]
			var wanting: Array = fitted.filter(func(n: String) -> bool:
				return _level().get_node_or_null("Props/" + n) == null)
			_check("level: the executive floor is dressed as one (missing %s)"
				% [wanting], wanting.is_empty())
			_check("level: it has the polisher and no heart",
				_level().get_node_or_null("Props/Torch") != null
					and _level().get_node_or_null("Props/Health") == null)
			# The exam, and the reskins are gone: from hellfire up the building
			# stops pretending to be an office, so this floor and the one below
			# it are the only two that field the originals. A reskin appearing
			# here is the rule quietly broken.
			_check("enemies: the exam fields eleven originals, masks off (%s)"
				% [_cast()], _cast() == ["regular", "regular", "regular",
					"regular", "regular", "regular", "regular", "warden",
					"warden", "wraith", "wraith"])
			# THE INVARIANT THE WHOLE CHAIN RESTS ON, checked on the floor with
			# the most people standing on it: no placed enemy's sight reaches
			# the door lane, so the straight walk between the two doors stays
			# safe in every biome - which is what the door legs of this suite
			# walk. The lane is x 246-300 at every y, and the radius is read off
			# each instance rather than hardcoded, so a retuned sight_radius
			# fails here instead of silently owning the walk.
			var seeing: Array = get_nodes_in_group("enemies").filter(
				func(n: Node2D) -> bool:
					return maxf(246.0 - n.position.x, n.position.x - 300.0) \
						<= float(n.get("sight_radius")))
			_check("enemies: none of the eleven sees the door lane (%s)"
				% [seeing.map(func(n: Node) -> String: return n.name)],
				seeing.is_empty())
			# Both drains belong IN the north half, and this is a placement
			# mistake that would look fine in the editor: an enemy on the far
			# side of the partitioning grinds along it instead of coming round
			# through the gap, so a wraith placed south of the glass to guard
			# the trophy wall guards nothing.
			var drains: Array = get_nodes_in_group("enemies").filter(
				func(n: Node2D) -> bool:
					return n.scene_file_path.contains("wraith"))
			var behind: Array = drains.filter(func(n: Node2D) -> bool:
				return n.position.y < 128.0)
			_check("enemies: both drains are behind the glass (%d of %d)"
				% [behind.size(), drains.size()],
				drains.size() == 2 and behind.size() == 2)
			# This floor's own idea, and the only legal way to put a body at
			# the chokepoint: the gap is ON the door line, where the check
			# above forbids a placement, so the late warden has to arrive
			# rather than stand. The marker is the half that can silently go
			# missing - spawn_position falls back to the middle of the room on
			# an unknown name, which here is only 16 px away and would pass a
			# looser check.
			var beat := _level().get_node_or_null("Reinforcements")
			var waves: Array = [] if beat == null else beat.get("waves")
			_check("beat: three late groups, the first and last by the chokepoint (%s)"
				% [waves],
				waves.size() == 3 and waves[0].get("from", "") == "chokepoint"
					and waves[0].get("enemies", [])
						== ["warden", "regular", "regular"]
					and waves[0].get("per_head", []) == ["regular"]
					and waves[2].get("from", "") == "chokepoint")
			_check("beat: and the chokepoint marker exists to arrive at (%s)"
				% _level().call("spawn_position", &"chokepoint"),
				_level().call("spawn_position", &"chokepoint")
					== Vector2(272, 168))
			_leave(Vector2(272, 78))


## Floor 12, the last fight - and the end of the chain, so the leg turns round.
func _silverman_office(frame: int) -> void:
	match frame:
		0:
			_key(KEY_W, false)
			_check("door: the chain continues on into Silverman's office (got %s)"
				% ("<none>" if _level() == null else _level().name),
				_level() != null and _level().name == "SilvermanOffice")
			_check("title: the penthouse announces itself (got '%s')"
				% _title_text(), _title_text() == "SILVERMAN'S OFFICE")
			# DESIGN.md asks for a wide open arena, and this is what one is:
			# nothing SOLID anywhere in the middle of the room. The rug there
			# blocks nothing, and every other prop is against a wall - so the
			# last fight in the game has the floor its three phases need, and
			# a piece of furniture nudged into the middle fails here.
			var middle := Rect2(150, 150, 250, 130)
			var inside: Array = _level().get_node("Props").get_children().filter(
				func(n: Node) -> bool:
					return n is StaticBody2D and middle.has_point(n.position))
			_check("level: the arena is clear of everything solid (%d in it)"
				% inside.size(), inside.is_empty())
			# The window, the one desk and the note that is turned over - the
			# three things DESIGN.md names for this room, and StickyNote1 is
			# the node the ending will have to find.
			var fitted := ["CityWindow1", "ExecDesk1", "StickyNote1", "Rug1"]
			var wanting: Array = fitted.filter(func(n: String) -> bool:
				return _level().get_node_or_null("Props/" + n) == null)
			_check("level: the window, the desk and the note (missing %s)"
				% [wanting], wanting.is_empty())
			var columns: Array = _level().get_node("Props").get_children().filter(
				func(n: Node) -> bool: return n.name.begins_with("Column"))
			_check("level: no colonnade, no hazard, no heart (%d columns)"
				% columns.size(), columns.is_empty()
					and _level().get_node_or_null("Props/Torch") == null
					and _level().get_node_or_null("Props/Health") == null)
			# THE LAST FIGHT, standing in it. game.gd finds him by group when it
			# builds the room, which makes this the only suite that can prove he
			# gets a bar at all - test_silverman.gd places him by hand into a
			# room that is already up, so nothing there ever wires one.
			var last := _level().get_node_or_null("Props/Boss")
			_check("boss: Silverman is standing in the penthouse (%s)"
				% ("<none>" if last == null else str(last.get("health"))),
				last != null and last.get("health") == 288)
			_check("boss: and he is in both groups, like every boss",
				last != null and last.is_in_group("bosses")
					and last.is_in_group("enemies"))
			# Near, not AT: he has been hovering since the room came up and has
			# already started closing on the player, so this is a check that he
			# was placed on the centre line - not that he stayed nailed to it.
			_check("boss: he is on the centre line, off the rug's north edge (%s)"
				% ("<none>" if last == null else str(last.position)),
				last != null and last.position.distance_to(Vector2(272, 140)) < 8.0)
			_check("hud: the boss bar is up and names him (got '%s')"
				% _boss_name(), _boss_bar().visible and _boss_name() == "SILVERMAN")
			_check("hud: it opens full - 240 px of channel for 288 HP (%s)"
				% _boss_fill().size.x, is_equal_approx(_boss_fill().size.x, 240.0))
			# NO WAY UP. The penthouse is the end of the chain, so
			# build_levels.gd cuts nothing through that wall. Beating him opens
			# no floor - what comes after him is the ending, not a room.
			_check("door: the penthouse has no way up to shut",
				_level().get_node_or_null("Props/Exit") == null)
			# But it does have a way back, and that one seals behind you like
			# every room's: the stair you came up by is shut until he concedes.
			_check("door: the way back down is shut while he stands",
				_level().get_node_or_null("Props/Return") != null
					and _doors_say(false))
			# Conceded the short way, exactly as Ahmed's floor does it: the fight
			# is tests/test_silverman.gd's, and a live boss glaring across the
			# room while the player walks back out makes the rest of this
			# section a coin toss.
			if last != null:
				last.call("take_damage", 500)
			_check("boss: at zero he concedes rather than dying (%s)"
				% ("gone" if last == null else str(last.get("has_conceded"))),
				last != null and last.get("has_conceded") == true)
			_check("hud: the bar goes with him when he settles",
				not _boss_bar().visible)
			_check("boss: and the room is clear with him still standing in it (%d)"
				% get_nodes_in_group("enemies").size(),
				get_nodes_in_group("enemies").is_empty() and last.is_inside_tree())
			# One blow from 288 to nothing, straight past all three of his
			# thresholds: none of those beats will ever come, and the stair
			# must not wait for them.
			_check("door: conceding opens the way back down, uncalled beats and all",
				_doors_say(true))
			# Ivan's cue has just come, and he would walk in at the very door
			# the player is about to leave by.
			_clear_room()
			# The end of the chain, so there is nothing north of here to walk
			# to: turn round instead and prove the way back down still works.
			_key(KEY_S, true)


## Back down the one stair the penthouse has, and the walk is over.
func _back_down(frame: int) -> void:
	match frame:
		0:
			_key(KEY_S, false)
			_check("return: the penthouse goes back down to the executive floor"
				+ " (got %s)"
				% ("<none>" if _level() == null else _level().name),
				_level() != null and _level().name == "ExecutiveFloor")
			_check("return: player arrives by the door they left through (%s)"
				% _player().global_position,
				_player().global_position.distance_to(Vector2(272, 80)) < 60.0)
			_finish()


## Out by the north door from `at`, the way every leg leaves - after beating the
## room the short way (helpers.gd's `_clear_room`), because a room's doors are
## shut until it is beaten. Both sides of that are checked on every floor
## rather than one, since a floor whose doors forgot to lock is a floor the
## player can walk straight past, and the walk is the one suite that visits
## them all.
func _leave(at: Vector2) -> void:
	var room := String(_level().name)
	if not get_nodes_in_group("enemies").is_empty():
		_check("lock: %s is sealed both ways while anybody in it stands" % room,
			_doors_say(false))
	_clear_room()
	_check("lock: %s lets the party out once it is beaten" % room,
		_doors_say(true))
	_player().global_position = at
	_key(KEY_W, true)


## Whether every door in this room - the way up, and the way back down where
## there is one - answers `can_travel()` with `open`.
func _doors_say(open: bool) -> bool:
	for door in get_nodes_in_group("door"):
		if bool(door.call("can_travel")) != open:
			return false
	return true


## Every enemy standing in the current room, by type, sorted. Six floors assert
## their own composition as this suite walks past, and composition is most of
## what makes one room feel unlike the next - so the cast is the check rather
## than the head count.
func _cast() -> Array:
	var cast: Array = get_nodes_in_group("enemies").map(
		func(n: Node) -> String:
			return n.scene_file_path.get_file().get_basename())
	cast.sort()
	return cast
