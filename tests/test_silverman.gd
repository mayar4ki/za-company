extends "res://tests/helpers.gd"
## SILVERMAN's fight: the glare both ways, the crossing that passes through
## you, the split, the prism, the glass ceiling, the cold room, and the ladder
## all of them hang off.
##
## His own suite rather than a fourth section of test_bosses.gd, for the reason
## the ladder exists: every check after the first depends on how much health he
## has left, and a file that walks a boss down through three phases cannot also
## hand the room to a next section unchanged. test_bosses.gd keeps his ART
## invariants - one picture per crossing, the ghost row, 1x, the concede -
## which are true of him at any health.
##
## Boots into the empty lobby and places him by hand, like test_combat.gd and
## test_bosses.gd, so his is the only thing in the room.
##
## Three habits worth keeping if you extend this:
##
## - **Geometry does the isolating, not frame numbers.** His band is a 20 px
##   lane and his crossing only travels along x, so a player parked 30 px off
##   his line is untouchable by both while the copy - which homes in two
##   dimensions - still reaches them. That is what lets the split's 12 be
##   asserted as a number rather than as "something happened".
## - **He always closes to `stop_distance`.** Left alone in CHASE he glides to
##   20 px and is then touching, so a check that needs him at range has to
##   fire before he arrives - which is why the ranged glare below is given
##   1.2 s left on its cooldown as the section opens, not none.
## - **His cooldowns are SHORT** (glare 1.6 s, split 3 s, the crossing 1.4 s),
##   so a section that wants one attack HOLDS the others by setting their
##   timers, rather than being laid out in the gaps between them - there are
##   no gaps any more. A phase change clears every attack's, which is the
##   other way to get one when you want it; it never clears the crossing's.
## - **Never set a position while he is crossing.** The dash drives him along a
##   curve off `_dash_from`, so moving him mid-flight fights it and lands him
##   somewhere neither of you chose - which is exactly how the split section
##   first failed: a stray crossing left him 31 px out, inside
##   `split_min_distance`, and he glared instead. Every setup frame below sits
##   in a gap between crossings, and the gaps are what the odd frame numbers
##   are about.

var _sv: Node2D
var _conceded := false
var _shakes := 0

# The crossing.
var _was_dashing := false
var _dash_started := -1
var _dash_ended := -1
var _dash_from := Vector2.ZERO
var _dash_travel := 0.0
var _moving_frames := 0
var _dash_anims := {}

# The ladder: every attack he opens, and the phase he was in when he did.
var _opened: Array[String] = []
var _prev_attack := ""
var _tiers_seen := {}

# The hug: how far off his line the player was standing when the glare landed
# on them anyway.
var _hug_offset := 0.0

# The interrupt attempt in his third phase.
var _tried_interrupt := -1
var _phase_after_interrupt := -1
var _commit_at_interrupt := -1.0

# The copy's blow, measured as a DELTA rather than against an absolute. He
# crosses the room on his own schedule between the setup frames, and a
# pass-through is 24 - so an absolute health here is really an assertion about
# every blow that came before it, which is how this check first failed.
var _before_copy := -1

# The cold room: a drain is a RATE, so what is counted is the number of
# separate frames health went down on. One blow cannot make five of those.
var _watch_drops := false
var _last_health := 0
var _drops := 0
var _health_at_edge := -1

# The prism, staged off the frame the first one actually begins rather than a
# frame number: when his last phase opens he may still be finishing whatever
# he was doing, so the cast lands a few frames either way. Its arc is fixed the
# moment it begins, which is what lets the test stand the player BEHIND it and
# then IN it, knowing exactly where both are.
var _prism_start := -1
var _prism_from := 0.0
var _prism_span := 0.0
var _prism_health := -1
var _prism_behind := -1

# The crossfire's down arm, measured as a delta like the copy.
var _before_arm := -1

# The glass ceiling, staged off the frame each cast actually begins, like the
# prism. Two casts: the first is dodged the way the preview showed (stand in a
# second-wave square, then step into a square the first wave emptied), the
# second is stood through, and its second wave is the one that lands.
var _ceiling_start := -1
var _ceiling_again := -1
var _ceiling_origin := Vector2.ZERO
var _ceiling_health := -1


func _tick(frame: int) -> void:
	if _sv != null and is_instance_valid(_sv):
		var now: String = _sv.get("attack")
		if now != "" and _prev_attack == "":
			_opened.append(now)
			_tiers_seen[now] = int(_sv.call("tier"))
			if now == "prism" and _prism_start < 0:
				_prism_start = frame
				_prism_from = _sv.get("prism_from")
				_prism_span = _sv.get("prism_span")
				# Dead opposite the middle of the fan: 220 degrees of the room
				# the sweep never covers.
				_player().global_position = _prism_spot(_prism_from + _prism_span * 0.5 + PI)
				_prism_health = _player().get("health")
			if now == "ceiling":
				if _ceiling_start < 0:
					_ceiling_start = frame
					_ceiling_origin = _sv.get("ceiling_origin")
				elif _ceiling_again < 0:
					_ceiling_again = frame
		_prev_attack = now

		var crossing: bool = _sv.get("dashing")
		if crossing and not _was_dashing:
			_dash_from = _sv.global_position
			_dash_started = frame
		elif _was_dashing and not crossing:
			_dash_travel = _dash_from.distance_to(_sv.global_position)
			_dash_ended = frame
		if crossing:
			_dash_anims[_sprite_of(_sv).animation] = true
		if _sv.get("dash_moving"):
			_moving_frames += 1
		_was_dashing = crossing

		# Third phase: hit him at the very start of a wind-up, where phase one
		# would have staggered him. Once, and the next frame's phase is the
		# answer.
		if frame > 601 and frame < 690 and _tried_interrupt < 0 \
				and now != "" and _sv.get("phase") == 1:
			_commit_at_interrupt = _sv.get("commit_fraction")
			_sv.call("take_damage", 1)
			_tried_interrupt = frame
		elif _tried_interrupt > 0 and frame == _tried_interrupt + 1:
			_phase_after_interrupt = _sv.get("phase")

	# The prism's two halves, by frames into the cast: 60 of wind-up, then 84 of
	# sweep. At 0.8 s into the sweep the beam has crossed 57% of its arc and
	# the player steps into the arc AHEAD of it, at 90%, which the beam reaches
	# at 1.26 s - so the second half is a body the light is coming towards.
	if _prism_start > 0 and _sv != null:
		var into := frame - _prism_start
		if into == 108:
			_prism_behind = _player().get("health")
			_check("silverman: behind the fan the prism never reaches you (%s -> %s)"
				% [_prism_health, _prism_behind], _prism_behind == _prism_health)
			_player().global_position = _prism_spot(_prism_from + _prism_span * 0.9)
		elif into == 147:
			_check("silverman: inside its arc the beam lands its 24, once (%s -> %s)"
				% [_prism_behind, _player().get("health")],
				_prism_behind - int(_player().get("health")) == 24)

	# The glass ceiling's first cast, by frames into it: the first wave lands at
	# 0.95 s (57 frames) and the second at 1.65 s (99), off his sheet's row.
	if _ceiling_start > 0 and _sv != null:
		var into := frame - _ceiling_start
		if into == 2:
			_ceiling_checks_grid()
			_ceiling_health = _player().get("health")
		elif into == 62:
			_check("silverman: standing in a second-wave square, the first wave misses you (%s -> %s)"
				% [_ceiling_health, _player().get("health")],
				_player().get("health") == _ceiling_health)
			# The dodge the preview showed: into a square the first wave has
			# just emptied, the one west of where you stand.
			_player().global_position = _ceiling_origin + Vector2(60, 42)
		elif into == 110:
			_check("silverman: step into a square it emptied and the second misses you too (%s -> %s)"
				% [_ceiling_health, _player().get("health")],
				_player().get("health") == _ceiling_health)
		elif into == 135:
			# Again at once, and this time the player stands still.
			_sv.set("_ceiling_timer", 0.0)
	if _ceiling_again > 0 and _sv != null:
		var into := frame - _ceiling_again
		if into == 2:
			_ceiling_health = _player().get("health")
		elif into == 110:
			_check("silverman: stand still and the second wave lands its 14, once (%s -> %s)"
				% [_ceiling_health, _player().get("health")],
				_ceiling_health - int(_player().get("health")) == 14)
			_check("silverman: and that was his second ceiling (%d)" % _sv.get("ceiling_casts"),
				int(_sv.get("ceiling_casts")) == 2)
			# Out of his sight again, so nothing else lands before the concede.
			_sv.set("sight_radius", 0.0)
			_health_at_edge = _player().get("health")
		elif into == 220:
			_check("silverman: and the glass clears itself away (%d grids left)" % _grids().size(),
				_grids().is_empty())

	if _watch_drops:
		var health: int = _player().get("health")
		if health < _last_health:
			_drops += 1
		_last_health = health

	match frame:
		2:
			(current_scene.get_node("%PlayButton") as Button).pressed.emit()
		17:
			(current_scene.get_node("%Roster/reem") as Button).pressed.emit()
		32:
			_check("silverman: the lobby starts empty, so the fight is placed (%d)"
				% get_nodes_in_group("enemies").size(),
				get_nodes_in_group("enemies").is_empty())
			_sv = (load("res://game/bosses/silverman/silverman.tscn") as PackedScene).instantiate() as Node2D
			_level().get_node("Props").add_child(_sv)
			_sv.connect("conceded", func() -> void: _conceded = true)
			_sv.connect("shook", func(_s: float, _t: float) -> void: _shakes += 1)
			_check("silverman: he opens at 288 - twelve heavies (%s)" % _sv.get("health"),
				_sv.get("health") == 288)
			_check("silverman: and opens in his first phase (%s)" % _sv.call("tier"),
				int(_sv.call("tier")) == 1)
			# His screen layer must sit UNDER the HUD: a room going white that
			# takes his own health bar with it hides the one number the player
			# is reading while it lands.
			_check("silverman: the glare draws below the HUD (%d < %d)"
				% [_glare_layer(), _hud_layer()], _glare_layer() < _hud_layer())
			_check("silverman: the band draws in the room and the wash on the frame (%s)"
				% str(_glare_parts()), _glare_parts() == ["band", "screen"])
			# The prism's three parts, and where each has to sit: the fan on the
			# floor under him, the beam over everything standing in the room,
			# the flash on his own layer under the HUD.
			var children := _sv.get_children().map(func(n: Node) -> String: return n.name)
			_check("silverman: the prism's fan draws under him and its beam over him (%s)"
				% str(children),
				children.find("PrismFloor") < children.find("AnimatedSprite2D")
					and children.find("PrismAir") > children.find("AnimatedSprite2D")
					and _sv.get_node("PrismAir").z_index > 0)
			_check("silverman: and its flash goes on his layer, under the HUD",
				_sv.get_node_or_null("Glare/PrismScreen") != null)
			_check("silverman: the glare's white flash is a row on the sheet (%d frame)"
				% _sprite_of(_sv).sprite_frames.get_frame_count(&"flash_side"),
				_sprite_of(_sv).sprite_frames.get_frame_count(&"flash_side") == 1)
			_check("silverman: and its light draws over him (%s)"
				% str(_sv.get_node_or_null("GlareAir")),
				_sv.get_node_or_null("GlareAir") != null and _sv.get_node("GlareAir").z_index > 0)
			_check("silverman: the prism has its own row on the sheet (%d frames)"
				% _sprite_of(_sv).sprite_frames.get_frame_count(&"prism_side"),
				_sprite_of(_sv).sprite_frames.get_frame_count(&"prism_side") == 6)
			_check("silverman: and so does the glass ceiling (%d frames)"
				% _sprite_of(_sv).sprite_frames.get_frame_count(&"ceiling_side"),
				_sprite_of(_sv).sprite_frames.get_frame_count(&"ceiling_side") == 6)
			# ---- THE HUG. Standing on him, due south, which is the one place
			# every reach he owns used to miss: the band is a 20 px lane through
			# his chest (so it misses on BOTH axes from here), the crossing only
			# travels along x, and the split will not fire closer than 34. He
			# has to have an answer or the last fight in the game is free.
			_sv.global_position = Vector2(382, 140)
			_player().global_position = Vector2(382, 160)
		48:
			_check("silverman: hugged, he winds up on contact (phase %s, '%s')"
				% [_sv.get("phase"), _sv.get("attack")],
				_sv.get("phase") == 1 and _sv.get("attack") == "glare")
			# The telegraph is the DULL steps on the sheet, not a tint. The base
			# fades a winding enemy towards amber, which on a body of six exact
			# greyscale values is a multiply landing between two rungs.
			_check("silverman: he is never tinted while he loads (%s)"
				% _sprite_of(_sv).modulate, _sprite_of(_sv).modulate == Color.WHITE)
			_check("silverman: nothing has landed yet (%s)" % _player().get("health"),
				_player().get("health") == 100)
			_hug_offset = absf(_player().global_position.y - _sv.global_position.y)
		95:
			# The band cannot have done this: at 20 px due south the player is
			# outside its lane in y AND beside it in x. The glare bursting off
			# HIM is what lands, which is the whole point of the fix.
			_check("silverman: hugging him is off the band's line (%.0f px of 20)"
				% _hug_offset, _hug_offset >= 20.0)
			_check("silverman: and the glare still bursts off him for 24 (%s)"
				% _player().get("health"), _player().get("health") == 76)
		130:
			# ---- THE CROSSING. 60 px is inside its own 72, which is the whole
			# of the pass-through: he goes THROUGH rather than stopping short.
			# The glare is held until the band section asks for it: it comes
			# round in 1.6 s, and he lands from the crossing standing on you.
			_player().global_position = Vector2(322, 140)
			_sv.set("_glare_timer", 99.0)
		175:
			_check("silverman: out of reach, he crosses (started %d)"
				% _dash_started, _dash_started > 0)
			_check("silverman: the crossing covers its 72 px (%.1f)" % _dash_travel,
				absf(_dash_travel - 72.0) < 8.0)
			_check("silverman: and takes its half second (%d frames)"
				% (_dash_ended - _dash_started),
				_dash_ended - _dash_started >= 26 and _dash_ended - _dash_started <= 36)
			_check("silverman: one picture for the whole crossing (%s)"
				% str(_dash_anims.keys()), _dash_anims.keys() == [&"dash_side"])
			_check("silverman: the smear draws on the travel beats only (%d frames)"
				% _moving_frames, _moving_frames >= 7 and _moving_frames <= 15)
			# ONE blow, not three: all three travel beats can hit and a flag
			# keeps the crossing to a single pass-through.
			_check("silverman: he passes THROUGH you for 24, once (%s)"
				% _player().get("health"), _player().get("health") == 52)
			_check("silverman: and comes out the other side of you (%.0f)"
				% _sv.global_position.x, _sv.global_position.x < 322.0)
		200:
			# ---- THE BAND. Given 1.2 s before the glare comes round, because
			# he closes to stop_distance while he waits: 110 px now is ~64 px by
			# the time it fires, which is still outside the burst's own reach so
			# what lands here can only be the sweep. The crossing is held from
			# here to the end: at 110 px he would otherwise cross first and land
			# on you, and every section after this one wants him where it put him.
			_sv.global_position = Vector2(382, 140)
			_player().global_position = Vector2(272, 140)
			_sv.set("_glare_timer", 1.2)
			_sv.set("_dash_cool", 99.0)
		350:
			_check("silverman: at range he glares with no contact needed (%s)"
				% str(_opened), _opened.size() >= 2 and _opened[1] == "glare")
			_check("silverman: the band crosses the room and lands its 24 (%s)"
				% _player().get("health"), _player().get("health") == 28)
			_check("silverman: from outside the burst, so that was the sweep (%.0f px)"
				% _sv.global_position.distance_to(_player().global_position),
				_sv.global_position.distance_to(_player().global_position) > 27.0)
			_check("silverman: a blow that big shakes the room (%d)" % _shakes,
				_shakes >= 1)
		400:
			# ---- THE MEETING. 192, and the split arrives -------------------
			_sv.call("take_damage", 108)
			_check("silverman: at two thirds he is in his second phase (%s at %s HP)"
				% [_sv.call("tier"), _sv.get("health")],
				int(_sv.call("tier")) == 2 and _sv.get("health") == 180)
			_check("silverman: a phase announces itself (%.1f s)" % _sv.get("herald"),
				float(_sv.get("herald")) > 0.0)
			# 30 px off his line: the band is a 20 px lane and the crossing only
			# moves along x, so neither reaches here - but the copy homes in two
			# dimensions and will. Three of his 24s have landed by now, so the
			# player is topped up: the checks from here on are deltas, and a
			# player who dies mid-section respawns at the door.
			_sv.global_position = Vector2(332, 140)
			_player().global_position = Vector2(272, 110)
			_player().call("heal", 100)
		460:
			_check("silverman: in his second phase he divides (%s)" % str(_opened),
				_opened.has("split"))
			_check("silverman: and the split is a second-phase thing only (%s)"
				% str(_tiers_seen), _tiers_seen.get("split", 0) >= 2)
			_check("silverman: the copy is in the room (%d)" % _copies().size(),
				_copies().size() == 1)
			var copies := _copies()
			_check("silverman: it is not a body - no groups, nothing to fight (%s)"
				% (str(copies[0].get_groups()) if not copies.is_empty() else "no copy"),
				not copies.is_empty() and copies[0].get_groups().is_empty())
			_check("silverman: and he stands still while it goes (%s)"
				% _sv.global_position,
				_sv.global_position.distance_to(Vector2(332, 140)) < 6.0)
			# Before it arrives: the copy emerges for 0.30 s and then walks, so
			# it is still on its way over here.
			_before_copy = _player().get("health")
		520:
			_check("silverman: the copy walks you down for 18 (%s -> %s)"
				% [_before_copy, _player().get("health")],
				_before_copy - int(_player().get("health")) == 18)
		560:
			_check("silverman: the copy is gone a second and a half later (%d)"
				% _copies().size(), _copies().is_empty())
		600:
			# ---- THE PERFORMANCE REVIEW. 96, and the room goes cold --------
			_sv.call("take_damage", 90)
			_check("silverman: at a third he is in his last phase (%s at %s HP)"
				% [_sv.call("tier"), _sv.get("health")],
				int(_sv.call("tier")) == 3 and _sv.get("health") == 90)
		700:
			_check("silverman: his last phase is uninterruptible (commit %.2f)"
				% _commit_at_interrupt, is_equal_approx(_commit_at_interrupt, 0.0))
			_check("silverman: so a hit at the start of a wind-up does not stagger him (phase %s)"
				% _phase_after_interrupt, _phase_after_interrupt == 1)
		760:
			_check("silverman: his last phase opens with the prism (%s)" % str(_opened),
				_prism_start > 0 and _tiers_seen.get("prism", 0) == 3)
			_check("silverman: and the prism is a last-phase thing only (%s)"
				% str(_tiers_seen), _opened.find("prism") > _opened.find("split"))
			# THE COLD ROOM, isolated the honest way: his sight goes to zero, so
			# he cannot glare, cannot cross and cannot even turn - and the aura
			# bites anyway, which is the design. It is not on the cycle.
			_sv.set("sight_radius", 0.0)
			_sv.global_position = Vector2(332, 140)
			# 30 px: outside Touch (22 + the player's 5), inside the aura (34).
			_player().global_position = Vector2(362, 140)
			_player().call("heal", 100)
			_last_health = _player().get("health")
			_watch_drops = true
		880:
			_check("silverman: standing near him costs health with no telegraph (%s)"
				% _player().get("health"), _player().get("health") < 100)
			# A rate, not a blow. Three points a second cannot arrive on one frame.
			_check("silverman: and it is a DRAIN - it ticks (%d separate frames)"
				% _drops, _drops >= 5)
			_check("silverman: he never wound up for any of it (phase %s, '%s')"
				% [_sv.get("phase"), _sv.get("attack")],
				_sv.get("phase") == 0 and _sv.get("attack") == "")
		890:
			# Out of the aura, still well inside where it was biting.
			_player().global_position = Vector2(382, 140)
			_health_at_edge = _player().get("health")
		960:
			_check("silverman: step out of the radius and it stops (%s -> %s)"
				% [_health_at_edge, _player().get("health")],
				_player().get("health") == _health_at_edge)
		965:
			# ---- THE CROSSFIRE. The glare's arms straight up and down. 50 px
			# due south of him is outside the burst (Touch, 22) and outside the
			# cold room (34), and off the band's lane by a long way - so the
			# only thing that can reach a player standing here is the down arm.
			# The split and the prism would both come first in his last phase,
			# so their cooldowns are held off for this one glare.
			_sv.set("sight_radius", 130.0)
			_sv.set("_split_timer", 99.0)
			_sv.set("_prism_timer", 99.0)
			_sv.set("_ceiling_timer", 99.0)
			_player().global_position = _sv.global_position + Vector2(0.0, 50.0)
			_before_arm = _player().get("health")
		1060:
			_check("silverman: due south of him, the glare's down arm lands its 24 (%s -> %s)"
				% [_before_arm, _player().get("health")],
				_before_arm - int(_player().get("health")) == 24)
			_check("silverman: and it was a glare that did it (%s)" % _opened.back(),
				_opened.back() == "glare")
			# The aura check below compares against health after this glare, not
			# before it - the arm's 24 is not the aura's. And his sight goes
			# again, or the next glare - 1.6 s on - lands before he concedes.
			_health_at_edge = _player().get("health")
			_sv.set("sight_radius", 0.0)
		1065:
			# ---- THE GLASS CEILING. Everything else is held, so the ceiling is
			# all he can do; 60 px due south is outside the cold room (34) and
			# Touch (22), and the grid centres on the player, which puts them
			# in its middle square - a second-wave one. The checks are in
			# _tick, by frames into each cast.
			_sv.set("sight_radius", 130.0)
			_sv.set("_glare_timer", 99.0)
			_sv.set("_split_timer", 99.0)
			_sv.set("_prism_timer", 99.0)
			_sv.set("_ceiling_timer", 0.0)
			_sv.global_position = Vector2(332, 140)
			_player().global_position = Vector2(332, 200)
			_player().call("heal", 100)
		1460:
			_sv.call("take_damage", 500)
			_check("silverman: at zero he concedes (%s)" % _sv.get("has_conceded"),
				_sv.get("has_conceded") == true)
			_check("silverman: conceding is a signal the door can hear", _conceded)
			_check("silverman: out of the fight, still in the room",
				not _sv.is_in_group("enemies") and _sv.is_inside_tree()
				and _sv.is_in_group("bosses"))
			_check("silverman: losing flight is the defeat (%s)"
				% _sprite_of(_sv).animation, _sprite_of(_sv).animation == &"concede_side")
		1480:
			_check("silverman: a conceded boss draws no aura", _drawn_nothing())
			_check("silverman: and casts no more copies (%d)" % _copies().size(),
				_copies().is_empty())
		1550:
			_check("silverman: he settles, then keeps cooling (%s)"
				% _sprite_of(_sv).animation, _sprite_of(_sv).animation == &"beaten_side")
			_check("silverman: and stops crossing the room",
				_sv.get("dashing") == false and _sv.get("dash_moving") == false)
			_check("silverman: the ladder was climbed in order (%s)" % str(_opened),
				_opened[0] == "glare" and _opened.has("split"))
			_check("silverman: and the glass ceiling is a last-phase thing only (%s)"
				% str(_tiers_seen), _tiers_seen.get("ceiling", 0) == 3)
			_finish()


## Where a body stands to be 60 px out from his chest along `angle` - outside
## the cold room's 34 and Touch's 22, so the only thing that can reach it is
## the beam. The player is measured at its own chest, 5 px up, as he is.
func _prism_spot(angle: float) -> Vector2:
	var chest := _sv.global_position + Vector2(0.0, -20.0)
	return chest + Vector2.from_angle(angle) * 60.0 - Vector2(0.0, -5.0)


func _sprite_of(enemy: Node2D) -> AnimatedSprite2D:
	return enemy.get_node("AnimatedSprite2D") as AnimatedSprite2D


## Everything in the room wearing copy.gd. Found by script rather than by group
## precisely because a copy is in no group - see copy.gd's header.
func _copies() -> Array[Node]:
	var found: Array[Node] = []
	var script := load("res://game/bosses/silverman/copy.gd")
	for child in _level().get_node("Props").get_children():
		if child.get_script() == script:
			found.append(child)
	return found


## Everything in the room wearing ceiling.gd - in no group either, like a copy.
func _grids() -> Array[Node]:
	var found: Array[Node] = []
	var script := load("res://game/bosses/silverman/ceiling.gd")
	for child in _level().get_node("Props").get_children():
		if child.get_script() == script:
			found.append(child)
	return found


## Where the glass ceiling is and how it is put together, two frames into the
## first cast: in the room and not on him, its floor as rows in the room's
## depth sort, its panes over everybody, its flash under the HUD - and the
## squares themselves, all on the floor, with the player in a second-wave one.
func _ceiling_checks_grid() -> void:
	var grids := _grids()
	_check("silverman: the glass ceiling falls in the room, not on him (%d grid)" % grids.size(),
		grids.size() == 1 and grids[0].get_parent() == _sv.get_parent())
	if grids.is_empty():
		return
	var grid := grids[0] as Node2D
	_check("silverman: and it is not a body - no groups (%s)" % str(grid.get_groups()),
		grid.get_groups().is_empty())
	var strips: Array = grid.get("_strips")
	var first := strips[0] as Node2D if not strips.is_empty() else null
	_check("silverman: its floor is one row per pixel, each in the room's depth sort (%d rows from y %s)"
		% [strips.size(), first.global_position.y if first != null else -1.0],
		grid.y_sort_enabled and strips.size() == 84 and first != null
			and is_equal_approx(first.global_position.y, _ceiling_origin.y))
	_check("silverman: its panes fall over everybody (z %d)" % grid.get_node("Air").z_index,
		grid.get_node("Air").z_index > 0)
	_check("silverman: and its flash goes under the HUD (%d < %d)"
		% [(grid.get_node("Flash") as CanvasLayer).layer, _hud_layer()],
		(grid.get_node("Flash") as CanvasLayer).layer < _hud_layer())
	var cells: Array = load("res://game/bosses/silverman/ceiling.gd").call("cells", _ceiling_origin)
	# The room's bounds less the walls, and less his window up top: whatever
	# room he is in (this suite's is the lobby), the squares stay on its floor.
	var b: Rect2 = _level().call("bounds")
	var floor_rect := Rect2(b.position + Vector2(22, 84), b.size - Vector2(44, 106))
	var inside := cells.filter(func(c: Dictionary) -> bool:
		return floor_rect.encloses(c["rect"]))
	_check("silverman: fifteen squares, every one on the floor (%d of %d)"
		% [inside.size(), cells.size()], cells.size() == 15 and inside.size() == 15)
	var mine := cells.filter(func(c: Dictionary) -> bool:
		return (c["rect"] as Rect2).has_point(_player().global_position))
	_check("silverman: centred on the player, who stands in a second-wave square (%s)"
		% str(mine.map(func(c: Dictionary) -> int: return c["wave"])),
		mine.size() == 1 and mine[0]["wave"] == 1)


## The glare's two parts, in the order they draw: under the body, then the
## frame itself.
func _glare_parts() -> Array:
	var parts := []
	for path in ["GlareBand", "Glare/GlareScreen"]:
		var node := _sv.get_node_or_null(path)
		if node != null:
			parts.append(str(node.get("part")))
	return parts


func _glare_layer() -> int:
	var layer := _sv.get_node_or_null("Glare") as CanvasLayer
	return layer.layer if layer != null else -999


func _hud_layer() -> int:
	return (current_scene.get_node("HUD") as CanvasLayer).layer


## A conceded boss is harmless, and the aura is the one thing on him that does
## not run off the attack cycle - so it is the one that has to be checked.
func _drawn_nothing() -> bool:
	return _player().get("health") == _health_at_edge
