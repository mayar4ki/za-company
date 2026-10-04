extends "res://tests/helpers.gd"
## The dodge - the tumble roll, picked from the Dodge Lab preview and shipped
## as previewed (player.gd's *The dodge* constants, tools/roll_pose.gd's frames,
## roll_dust.gd's dust). In the empty lobby, one stage after another:
##
## - the key is K and Ctrl, and a browser build keeps K alone;
## - all ten characters hold the three rows, four frames at 12.5 a second,
##   pixel for pixel what roll_pose.gd makes of their recoloured sheet - and the
##   source sheet holds no roll at all;
## - a roll goes the way the stick points, exactly DODGE_DISTANCE, runs on into
##   the walk, leaves dust that settles, and cannot be pressed again inside its
##   cooldown; with the stick at rest it goes backwards;
## - a blow probed on every frame of a roll misses exactly inside the
##   untouchable stretch and lands either side of it, while a drain and a slow
##   land straight through it;
## - it cuts a swing and a charge short, never the heavy, and a swing pressed
##   mid-roll goes off as it ends; a slow shortens it;
## - a real guard's blow, landing on a roll pinned against the wall where it
##   cannot carry the body out of reach, misses - after the same guard was
##   seen landing one with no roll;
## - online, the host trusts a teammate's word that it is rolling, and the
##   teammate's picture kicks up the same dust here.
##
## Its own suite because every stage moves the player, and a roll that moves
## them is exactly what a duel suite's geometry must never be handed.

const Roster := preload("res://game/player/characters/roster.gd")
const Art := preload("res://tools/character_art.gd")
const RollPose := preload("res://tools/roll_pose.gd")
const InputSource := preload("res://game/player/input_source.gd")
const SRC := "res://game/player/src/character_cc0.png"
const DUST := "res://game/player/roll_dust.gd"

## Open floor in the lobby, a roll's length clear either side; and a spot
## against the top wall, where a roll pointed up goes nowhere.
const OPEN := Vector2(240, 140)
const WALL := Vector2(120, 25)

var _stage := 0
var _at := 0
var _releases := {}
var _x0 := 0.0
var _y0 := 0.0
var _ended := -1
var _flag := false
var _samples: Array = []
var _guard: Node2D = null
var _prog := 0.0
var _health := 0


func _tick(frame: int) -> void:
	for code in _releases.keys():
		if frame >= int(_releases[code]):
			_key(code, false)
			_releases.erase(code)
	var t := frame - _at
	match _stage:
		0:
			if frame == 2:
				(current_scene.get_node("%PlayButton") as Button).pressed.emit()
			elif frame == 17:
				(current_scene.get_node("%Roster/mayar") as Button).pressed.emit()
			elif frame == 32:
				_check("lobby: empty, so nothing but the test moves the player (%d)"
					% get_nodes_in_group("enemies").size(), get_nodes_in_group("enemies").is_empty())
				_keys()
				_numbers()
				_sheets()
				_next(frame)
		1:
			_forward(frame, t)
		2:
			_backward(frame, t)
		3:
			_probe(frame, t)
		4:
			_cut_swing(frame, t)
		5:
			_owed_swing(frame, t)
		6:
			_cut_charge(frame, t)
		7:
			_not_the_heavy(frame, t)
		8:
			_slowed(frame, t)
		9:
			_guard_lands(frame, t)
		10:
			_guard_misses(frame, t)
		11:
			_stage += 1
			_teammate()
			_finish()


func _next(frame: int) -> void:
	_stage += 1
	_at = frame
	_ended = -1
	_flag = false


## A press, let go on the next frame: just-pressed fires once either way.
func _tap(code: Key, frame: int) -> void:
	_key(code, true)
	_releases[code] = frame + 1


func _place(at: Vector2) -> void:
	_player().global_position = at
	_player().velocity = Vector2.ZERO


## One of player.gd's own numbers, read off the live body's script - never
## preloaded here, because this file compiles before the autoloads exist and
## player.gd names one.
func _c(name: String) -> float:
	return float(_player().get_script().get_script_constant_map()[name])


func _rolling() -> bool:
	return float(_player().get("_dodge_t")) >= 0.0


func _dust(parent: Node) -> int:
	var n := 0
	for c in parent.get_children():
		var s: Script = c.get_script()
		if s != null and s.resource_path == DUST:
			n += 1
	return n


# ---- What does not move ------------------------------------------------------


func _keys() -> void:
	var codes := _dodge_codes()
	_check("keys: K dodges (%s)" % str(codes), codes.has(KEY_K))
	_check("keys: and so does Ctrl, off the web", codes.has(KEY_CTRL))
	InputSource.browser_keys()
	codes = _dodge_codes()
	_check("keys: a browser build drops Ctrl and keeps K (%s)" % str(codes),
		codes.has(KEY_K) and not codes.has(KEY_CTRL))
	InputMap.load_from_project_settings()
	_check("keys: put back for the rest of the run", _dodge_codes().has(KEY_CTRL))


func _dodge_codes() -> Array:
	var out := []
	for ev in InputMap.action_get_events(&"dodge"):
		if ev is InputEventKey:
			out.append(ev.physical_keycode)
	return out


func _numbers() -> void:
	_check("numbers: the untouchable stretch is inside the roll (%.2f-%.2f of %.2f)"
		% [_c("DODGE_SAFE_FROM"), _c("DODGE_SAFE_UNTIL"), _c("DODGE_SECONDS")],
		0.0 <= _c("DODGE_SAFE_FROM") and _c("DODGE_SAFE_FROM") < _c("DODGE_SAFE_UNTIL")
		and _c("DODGE_SAFE_UNTIL") <= _c("DODGE_SECONDS"))
	var sf: SpriteFrames = _sprite().sprite_frames
	var length := sf.get_frame_count("dodge_side") / sf.get_animation_speed("dodge_side")
	_check("numbers: the four frames last exactly the roll (%.3f s)" % length,
		is_equal_approx(length, _c("DODGE_SECONDS")))


func _sheets() -> void:
	var src := Image.load_from_file(ProjectSettings.globalize_path(SRC))
	_check("sheets: the roll is in no sheet on disk - the source stays 24 rows (%d)"
		% (src.get_height() / 32), src.get_height() == RollPose.ROWS["down"] * 32)
	var shape_bad: Array[String] = []
	var pixel_bad: Array[String] = []
	for entry in Roster.CHARACTERS:
		if not entry.has("recipe"):
			continue
		var sf: SpriteFrames = load(entry["frames"])
		var expect := RollPose.paint(Art.restyle(SRC, entry["recipe"]))
		var images := {}
		for dir in RollPose.ROWS:
			var anim: String = "dodge_" + dir
			if not sf.has_animation(anim) or sf.get_frame_count(anim) != 4 \
					or not is_equal_approx(sf.get_animation_speed(anim), 12.5) \
					or sf.get_animation_loop(anim):
				shape_bad.append("%s %s" % [entry["id"], anim])
				continue
			for k in 4:
				var at: AtlasTexture = sf.get_frame_texture(anim, k)
				if not images.has(at.atlas):
					var img: Image = at.atlas.get_image()
					if img.is_compressed():
						img.decompress()
					img.convert(Image.FORMAT_RGBA8)
					images[at.atlas] = img
				var got: Image = (images[at.atlas] as Image).get_region(Rect2i(at.region))
				var want := expect.get_region(Rect2i(k * 32, RollPose.ROWS[dir] * 32, 32, 32))
				if got.get_data() != want.get_data():
					pixel_bad.append("%s %s %d" % [entry["id"], anim, k])
	_check("sheets: all ten hold dodge down, up and side, 4 frames at 12.5, once %s"
		% str(shape_bad), shape_bad.is_empty())
	_check("sheets: every frame is roll_pose.gd's, off the recoloured sheet %s"
		% str(pixel_bad), pixel_bad.is_empty())


# ---- The roll ----------------------------------------------------------------


func _forward(frame: int, t: int) -> void:
	if t == 1:
		_place(OPEN)
	elif t == 4:
		_x0 = _player().global_position.x
		_key(KEY_D, true)
		_tap(KEY_K, frame)
	elif t == 5:
		_check("roll: K with the stick held rolls that way (%s, flipped %s)"
			% [_sprite().animation, _sprite().flip_h],
			_rolling() and _sprite().animation == "dodge_side" and not _sprite().flip_h)
		_check("roll: kicking up dust behind it (%d puffs)" % _dust(_player().get_parent()),
			_dust(_player().get_parent()) >= 2)
	elif t > 5 and _ended < 0 and not _rolling():
		_ended = frame
		var moved := _player().global_position.x - _x0
		_check("roll: exactly DODGE_DISTANCE (%.2f px)" % moved,
			absf(moved - _c("DODGE_DISTANCE")) < 0.5)
		_check("roll: in DODGE_SECONDS (%d frames)" % (t - 4), t - 4 == 20)
		_check("roll: and runs on into the walk (%.0f px/s)" % _player().velocity.x,
			_player().velocity.x > 60.0)
		_check("roll: then cools down (%.2f s)" % float(_player().get("_dodge_cooldown")),
			is_equal_approx(float(_player().get("_dodge_cooldown")), _c("DODGE_COOLDOWN")))
		_key(KEY_D, false)
	elif _ended > 0 and frame == _ended + 5:
		_tap(KEY_K, frame)
	elif _ended > 0 and frame == _ended + 7:
		_check("roll: a press inside the cooldown does nothing", not _rolling())
	elif _ended > 0 and frame == _ended + 40:
		_check("roll: and its dust has settled (%d)" % _dust(_player().get_parent()),
			_dust(_player().get_parent()) == 0)
		_next(frame)


func _backward(frame: int, t: int) -> void:
	if t == 1:
		_place(OPEN)
		_x0 = OPEN.x
	elif t == 3:
		_tap(KEY_K, frame)
	elif t == 4:
		_check("back: with the stick at rest it rolls away from the facing (%s, flipped %s)"
			% [_sprite().animation, _sprite().flip_h],
			_rolling() and _sprite().animation == "dodge_side" and _sprite().flip_h)
	elif t > 4 and _ended < 0 and not _rolling():
		_ended = frame
		var moved := _player().global_position.x - _x0
		_check("back: the whole roll backwards (%.2f px)" % moved,
			absf(moved + _c("DODGE_DISTANCE")) < 0.5)
	elif _ended > 0 and frame == _ended + 30:
		_next(frame)


## A blow on every frame of a roll and either side of it, the grace window
## cleared each time so only the roll can be what stops one.
func _probe(frame: int, t: int) -> void:
	var p := _player()
	if t == 1:
		_place(OPEN)
		_samples.clear()
	elif t == 3:
		_tap(KEY_K, frame)
	elif t >= 4 and t <= 27:
		var at := float(p.get("_dodge_t"))
		p.set("_grace", 0.0)
		p.set("health", 100)
		p.call("take_damage", 5)
		_samples.append([at, int(p.get("health")) < 100])
		if at >= 0.1 and at <= 0.2 and not _flag:
			_flag = true
			var ns: Array = p.call("net_state")
			_check("online: a rolling body's step says so (%d fields, %s, %s)"
				% [ns.size(), str(ns[7]) if ns.size() > 8 else "-", str(ns[8]) if ns.size() > 8 else "-"],
				ns.size() >= 9 and ns[7] == p.get("_dodge_dir") and ns[7] != Vector2.ZERO
				and ns[8] == true)
			p.call("drain", 3)
			_check("probe: a drain lands straight through a roll (%d)" % int(p.get("health")),
				int(p.get("health")) == 97)
			p.call("apply_slow", 0.5, 0.2)
			_check("probe: and so does a slow (%.2f)" % float(p.get("slow_factor")),
				is_equal_approx(float(p.get("slow_factor")), 0.5))
			p.set("slow_factor", 1.0)
			p.set("slow_seconds", 0.0)
	elif t == 28:
		var inside := _samples.filter(func(s: Array) -> bool:
			return s[0] >= _c("DODGE_SAFE_FROM") and s[0] <= _c("DODGE_SAFE_UNTIL"))
		var early := _samples.filter(func(s: Array) -> bool:
			return s[0] >= 0.0 and s[0] < _c("DODGE_SAFE_FROM"))
		var late := _samples.filter(func(s: Array) -> bool:
			return s[0] > _c("DODGE_SAFE_UNTIL"))
		var after := _samples.filter(func(s: Array) -> bool: return s[0] < 0.0)
		_check("probe: every blow inside the untouchable stretch misses (%d frames)" % inside.size(),
			not inside.is_empty() and inside.all(func(s: Array) -> bool: return not s[1]))
		_check("probe: the first frames of a roll are still open (%d)" % early.size(),
			not early.is_empty() and early.all(func(s: Array) -> bool: return s[1]))
		_check("probe: and so are its last (%d)" % late.size(),
			not late.is_empty() and late.all(func(s: Array) -> bool: return s[1]))
		_check("probe: and so is the body once it stands (%d)" % after.size(),
			not after.is_empty() and after.all(func(s: Array) -> bool: return s[1]))
		var ns: Array = p.call("net_state")
		_check("online: a standing body's step says it is not rolling",
			ns.size() >= 9 and ns[7] == Vector2.ZERO and ns[8] == false)
		p.call("revive")
	elif t == 60:
		_next(frame)


func _cut_swing(frame: int, t: int) -> void:
	var p := _player()
	if t == 1:
		_place(OPEN)
	elif t == 3:
		_tap(KEY_SPACE, frame)
	elif t == 6:
		_check("swing: under way (%s)" % p.get("_attack"), p.get("_attack") == "attack")
		_tap(KEY_K, frame)
	elif t == 7:
		_check("swing: a roll cuts it short (%s, %s)" % [p.get("_attack"), _sprite().animation],
			p.get("_attack") == "" and _rolling() and _sprite().animation.begins_with("dodge_"))
	elif t == 60:
		_next(frame)


func _owed_swing(frame: int, t: int) -> void:
	var p := _player()
	if t == 1:
		_place(OPEN)
	elif t == 3:
		_tap(KEY_K, frame)
	elif t == 8:
		_tap(KEY_SPACE, frame)
	elif t == 9:
		_check("owed: a swing pressed mid-roll waits (%s)" % p.get("_attack"),
			_rolling() and p.get("_attack") == "")
	elif t > 9 and _ended < 0 and not _rolling():
		_ended = frame
		_check("owed: and goes off as the roll ends (%s)" % p.get("_attack"),
			p.get("_attack") == "attack")
	elif _ended > 0 and frame == _ended + 50:
		_next(frame)


func _cut_charge(frame: int, t: int) -> void:
	var p := _player()
	if t == 1:
		_place(OPEN)
	elif t == 3:
		_key(KEY_SPACE, true)
	elif t > 3 and not _flag and bool(p.get("_charging")):
		_flag = true
		_tap(KEY_K, frame)
		_ended = frame
	elif _flag and frame == _ended + 1:
		_check("charge: a roll drops it like letting go early (%s, ring %s)"
			% [p.get("_charging"), p.get("_ring")],
			not bool(p.get("_charging")) and p.get("_ring") == null and _rolling())
		_key(KEY_SPACE, false)
	elif _flag and frame == _ended + 50:
		_next(frame)
	elif t > 120:
		_check("charge: the stance was reached", false)
		_key(KEY_SPACE, false)
		_next(frame)


func _not_the_heavy(frame: int, t: int) -> void:
	var p := _player()
	if t == 1:
		_place(OPEN)
	elif t == 3:
		_key(KEY_SPACE, true)
	elif t > 3 and not _flag and p.get("_attack") == "heavy":
		_flag = true
		_tap(KEY_K, frame)
		_ended = frame
	elif _flag and frame == _ended + 1:
		_check("heavy: no roll out of it (%s)" % p.get("_attack"),
			not _rolling() and (p.get("_attack") == "heavy" or p.get("_attack") == "wildfire"))
		_key(KEY_SPACE, false)
	elif _flag and frame == _ended + 70:
		_check("heavy: which plays out (%s)" % p.get("_attack"), p.get("_attack") == "")
		_next(frame)
	elif t > 150:
		_check("heavy: the heavy went off", false)
		_key(KEY_SPACE, false)
		_next(frame)


func _slowed(frame: int, t: int) -> void:
	var p := _player()
	if t == 1:
		_place(OPEN)
		p.call("apply_slow", 0.5, 3.0)
	elif t == 4:
		_x0 = p.global_position.x
		_key(KEY_D, true)
		_tap(KEY_K, frame)
	elif t > 5 and _ended < 0 and not _rolling():
		_ended = frame
		var moved := p.global_position.x - _x0
		_check("slow: half the legs, half the roll (%.2f px)" % moved,
			absf(moved - _c("DODGE_DISTANCE") * 0.5) < 0.5)
		_key(KEY_D, false)
	elif _ended > 0 and frame == _ended + 2:
		p.call("revive")
	elif _ended > 0 and frame == _ended + 30:
		_next(frame)


# ---- A real blow -------------------------------------------------------------


## The control: a guard standing beside the player lands his blow when nothing
## gets in the way, so the next stage's miss is the roll's and not a setup that
## never struck.
func _guard_lands(frame: int, t: int) -> void:
	if t == 1:
		_place(WALL)
		_guard = (load("res://game/enemies/regular/regular.tscn") as PackedScene).instantiate()
		_level().get_node("Props").add_child(_guard)
		_guard.global_position = WALL + Vector2(12, 0)
		_guard.set("speed", 0.0)
		_health = int(_player().get("health"))
		_prog = 0.0
	elif t > 1:
		var prog := float(_guard.call("_windup_progress"))
		if _prog > 0.5 and prog == 0.0:
			_check("guard: beside the player, with no roll, his blow lands (%d -> %d)"
				% [_health, int(_player().get("health"))], int(_player().get("health")) < _health)
			_next(frame)
		elif t > 200:
			_check("guard: wound up and struck", false)
			_next(frame)
		_prog = prog


## The same guard again, and a roll pressed late in his wind-up, pointed into
## the wall: the body goes nowhere, so it is still in his reach when he strikes,
## and the only thing that can make the blow miss is the roll.
func _guard_misses(frame: int, t: int) -> void:
	var p := _player()
	var prog := float(_guard.call("_windup_progress"))
	if not _flag and float(p.get("_grace")) == 0.0 and prog >= 0.7:
		_flag = true
		_y0 = p.global_position.y
		_health = int(p.get("health"))
		_key(KEY_W, true)
		_tap(KEY_K, frame)
	elif _flag and _ended < 0 and _prog > 0.5 and prog == 0.0:
		_ended = frame
		var at := float(p.get("_dodge_t"))
		_check("guard: the same blow, struck mid-roll, misses (%d -> %d, %.3f s in)"
			% [_health, int(p.get("health")), at],
			int(p.get("health")) == _health and at >= _c("DODGE_SAFE_FROM")
			and at <= _c("DODGE_SAFE_UNTIL"))
		_check("guard: and the wall stopped the roll where it stood (%.2f px)"
			% (p.global_position.y - _y0), absf(p.global_position.y - _y0) < 1.5)
		_key(KEY_W, false)
	elif _ended > 0 and frame == _ended + 2:
		_guard.queue_free()
		_next(frame)
	elif t > 240:
		_check("guard: wound up again for the roll", false)
		_key(KEY_W, false)
		_next(frame)
	_prog = prog


# ---- Online ------------------------------------------------------------------


## A teammate's body as the host holds it: moved by its owner, judged here. The
## owner says it is rolling and the host takes its word; says it is standing and
## a blow lands. Its picture going into a roll and out of it kicks up the dust.
func _teammate() -> void:
	var mate: CharacterBody2D = (load("res://game/player/player.tscn") as PackedScene).instantiate()
	mate.set("remote", true)
	mate.set("character", "anas")
	_level().add_child(mate)
	mate.global_position = Vector2(420, 160)
	var at := mate.global_position
	var rolling := [at, "dodge_side", 1, false, Color.WHITE.to_rgba32(), true, 0.0, Vector2.RIGHT, true]
	var standing := [at, "idle_side", 0, false, Color.WHITE.to_rgba32(), true, 0.0, Vector2.ZERO, false]
	mate.call("apply_net_state", rolling)
	mate.call("take_damage", 10)
	_check("online: the host trusts a teammate's roll (%d)" % int(mate.get("health")),
		int(mate.get("health")) == 100)
	mate.call("apply_net_state", standing)
	mate.call("take_damage", 10)
	_check("online: and lands the blow once it says it is standing (%d)" % int(mate.get("health")),
		int(mate.get("health")) == 90)
	var before := _dust(_level())
	mate.call("net_draw", rolling, at)
	var kicked := _dust(_level()) - before
	mate.call("net_draw", standing, at)
	var stood := _dust(_level()) - before - kicked
	# Two kicked up behind it and the first of its trail, as a roll of this
	# machine's own starts; then the one it stands up into.
	_check("online: a teammate's picture rolling kicks up its dust here (%d, then %d)"
		% [kicked, stood], kicked == 3 and stood == 1)
	mate.queue_free()
