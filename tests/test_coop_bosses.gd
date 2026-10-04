extends "res://tests/coop.gd"
## Two machines in one run (DESIGN.md's Multiplayer, M3) - the BOSSES: drawn
## on the guest from the room's snapshot like any enemy, and what a snapshot
## cannot carry - a line, a fire thrown, a shake - told to the guest as a
## MOMENT (game/sync/world.gd's *A moment*). The harness is tests/coop.gd.
##
## - **Ahmed**: his bar is up on the guest by his name, the line he shouts is
##   the line the guest reads, the fire he throws is thrown on the guest's copy
##   of him, the chair he sits in stays under him there - an effect that ends
##   with its attack must not find the guest a snapshot behind - a shake shakes
##   the guest's camera, his stop holds both machines' pictures and neither's
##   clock (M4), and his health and his concede follow.
## - **Big Mo**: going up is the guest's to see too - the fire he keeps.
## - **Silverman**: the copy he casts walks on the guest's floor, the prism's
##   fan is the one the host measured, the glass ceiling comes down on the
##   guest's floor in the squares the host chose, and he crosses through the
##   guest's player the way he crosses the host's.
##
## Each boss is made to do the thing under test rather than waited on, the way
## test_ahmed_moves.gd stages a move: what is under test is the getting there.

const AHMED := "res://game/levels/ahmed_office/ahmed_office.tscn"
const BIG_MO := "res://game/levels/conflict_resolution/conflict_resolution.tscn"
const SILVERMAN := "res://game/levels/silverman_office/silverman_office.tscn"
const FAN_WAVE := "res://game/bosses/ahmed/fan_wave.gd"
const CHAIR_RUN := "res://game/bosses/ahmed/chair_run.gd"
const COPY := "res://game/bosses/silverman/copy.gd"
const CEILING := "res://game/bosses/silverman/ceiling.gd"


func _init() -> void:
	port = 47971
	start_level = AHMED


func _plan() -> Array[Callable]:
	return [_together, _ahmed_bar, _ahmed_says, _ahmed_throws, _ahmed_sits,
		_ahmed_shakes, _ahmed_stops, _ahmed_hurt, _ahmed_gives_in, _to_big_mo, _arrived,
		_big_mo_bar, _big_mo_rages, _to_silverman, _arrived, _silverman_copies,
		_silverman_prism, _silverman_ceiling, _silverman_ceiling_where,
		_silverman_crosses, _silverman_lands]


func _boss() -> Node:
	var level := _level()
	return level.get_node_or_null("Props/Boss") if level != null else null


func _bar(title: String) -> void:
	_expect("%s: his bar is up on the guest, by his name" % title, "boss_bar", [],
		func(a: Array) -> bool: return a.size() == 2 and a[0] == true and a[1] == title)


func _arrived() -> void:
	var room: int = _sync().get("room")
	var level := String(_level().name)
	_expect("travel: the guest arrives there in the same room", "where", [],
		func(a: Array) -> bool:
			return a.size() == 4 and a[2] == room and a[3] == level)


func _ahmed_bar() -> void:
	_bar("AHMED")


func _ahmed_says() -> void:
	var boss := _boss()
	boss.call("_say", "spot")
	var line := _subtitle_line()
	_check("ahmed: shouts on the host (%s)" % line, line != "")
	_expect("ahmed: and the guest reads the very same line", "subtitle", [],
		func(a: Array) -> bool:
			return a.size() == 3 and a[0] == true and a[1] == "AHMED" and a[2] == line)


func _ahmed_throws() -> void:
	var boss := _boss() as Node2D
	boss.call("_spawn_fx", load(FAN_WAVE), boss.global_position, false, {"damage": 0})
	_expect("ahmed: the fire he throws is thrown on the guest's copy of him",
		"children", ["Props/Boss", FAN_WAVE], func(n: int) -> bool: return n >= 1)


func _ahmed_sits() -> void:
	_boss().call("_begin_attack", "chair")
	_since = _f
	_expect("ahmed: and the chair he sits in stays under him there",
		"children", ["Props/Boss", CHAIR_RUN], func(n: int) -> bool:
			# Asked again once it has had the frames a self-ending effect
			# would need to end itself on a guest a snapshot behind.
			return n == 1 and _f - _since > 20)


func _ahmed_shakes() -> void:
	_boss().emit_signal("shook", 3.0, 0.4)
	_expect("ahmed: a shake shakes the guest's camera too", "shaking", [],
		func(left: float) -> bool: return left > 0.0)


## And his stop, which online holds each machine's picture rather than the
## host's clock (game/picture_hold.gd).
func _ahmed_stops() -> void:
	_boss().emit_signal("froze", 0.1)
	_check("ahmed: his stop holds the host's picture, never its clock",
		int(current_scene.get_node("PictureHold").get("held")) >= 1 and Engine.time_scale == 1.0)
	_expect("ahmed: and holds the guest's picture too", "holds", [],
		func(n: int) -> bool: return n >= 1)


func _ahmed_hurt() -> void:
	var boss := _boss()
	boss.call("take_damage", 48)
	var left := int(boss.get("health"))
	_expect("ahmed: his health follows the host's (%d)" % left, "get",
		["Props/Boss", ["health"]], func(a) -> bool:
			return a is Array and int(a[0]) == left)


func _ahmed_gives_in() -> void:
	_boss().call("take_damage", 9999)
	_expect("ahmed: and so does the end - conceded there, the bar down", "boss_bar", [],
		func(a: Array) -> bool:
			return a.size() == 2 and a[0] == false)


func _to_big_mo() -> void:
	current_scene.call("_travel", BIG_MO, &"start")
	_deadline = 600
	_wait("travel: the host takes the party up to Big Mo",
		func() -> bool: return _level() != null and _level().scene_file_path == BIG_MO)


func _big_mo_bar() -> void:
	_bar("BIG MO")


func _big_mo_rages() -> void:
	_boss().call("_begin_rage")
	_expect("big mo: going up is the guest's to see too", "get",
		["Props/Boss", ["is_raging"]], func(a) -> bool: return a is Array and a[0] == true)


func _to_silverman() -> void:
	current_scene.call("_travel", SILVERMAN, &"start")
	_deadline = 600
	_wait("travel: and up to Silverman",
		func() -> bool: return _level() != null and _level().scene_file_path == SILVERMAN)


func _silverman_copies() -> void:
	_boss().call("_cast_copy")
	_expect("silverman: the copy he casts walks on the guest's floor", "children",
		["Props", COPY], func(n: int) -> bool: return n >= 1)


func _silverman_prism() -> void:
	var boss := _boss()
	boss.call("_aim_prism")
	var casts := int(boss.get("prism_casts"))
	var from := float(boss.get("prism_from"))
	_expect("silverman: the prism's fan is the one the host measured", "get",
		["Props/Boss", ["prism_casts", "prism_from", "_prism_lengths"]], func(a) -> bool:
			return a is Array and int(a[0]) == casts and absf(float(a[1]) - from) < 0.001 \
				and (a[2] as PackedFloat32Array).size() == 48)


func _silverman_ceiling() -> void:
	_boss().call("_aim_ceiling")
	_expect("silverman: the glass ceiling comes down on the guest's floor", "children",
		["Props", CEILING], func(n: int) -> bool: return n >= 1)


## Where the host put it, which is where the player stood on the HOST's
## machine - the guest is told the corner, never left to work it out.
func _silverman_ceiling_where() -> void:
	var boss := _boss()
	var casts := int(boss.get("ceiling_casts"))
	var origin: Vector2 = boss.get("ceiling_origin")
	_expect("silverman: in the squares the host chose", "get",
		["Props/Boss", ["ceiling_casts", "ceiling_origin"]], func(a) -> bool:
			return a is Array and int(a[0]) == casts \
				and (a[1] as Vector2).distance_to(origin) < 0.01)


func _silverman_crosses() -> void:
	_boss().set("dashing", true)
	_expect("silverman: crossing, he goes through the guest's player there too",
		"get", ["Props/Boss", ["dashing", "_dash_excepted"]], func(a) -> bool:
			return a is Array and a[0] == true and (a[1] as Array).size() == 2)


func _silverman_lands() -> void:
	_boss().set("dashing", false)
	_expect("silverman: and is solid again when he lands", "get",
		["Props/Boss", ["dashing", "_dash_excepted"]], func(a) -> bool:
			return a is Array and a[0] == false and (a[1] as Array).is_empty())
