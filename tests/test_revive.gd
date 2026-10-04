extends "res://tests/helpers.gd"
## Picking somebody back up (game/revive.gd): option A, Steady hands, from the
## Revive Lab preview. A party of two on one machine - the keyboard's player and
## Anas on synthesized hands - in the empty lobby, well away from HR, whose
## prompt the same key answers.
##
## - Down is lying down: the `fall` rows, the solid darker tint, in the
##   `fallen` group, and an E over the body for the player close enough.
## - Holding E roots the one reviving, turns them to the body and keeps their
##   swing; a green ring fills under the body and the E goes.
## - SECONDS of holding: half full at two, and a blow on the one reviving knocks
##   a second off, with the ring red for it.
## - Letting go runs it back down, and the E comes back.
## - Done: up where they lay, at 50 health with a grace window, turned to the
##   one who got them up, playing `rise`, in the fight again - with a green +50
##   - and the pool of lives exactly as it was, at none.
## - A wait at the door overtakes a revive in progress, and leaves nothing of it.
## - The one down reads who is getting them up along the bottom of the screen,
##   and is back to watching when they let go.
##
## Frame budget: 60 fps. A revive is SECONDS (4 s, 240 frames).

const VirtualInput := preload("res://game/player/virtual_input.gd")
const Heads := preload("res://game/heads.gd")

const HERE := Vector2(184, 150)
const THERE := Vector2(196, 150)

var _hands := VirtualInput.new()
var _released_at := 0.0
var _door := Vector2.ZERO
## The frame the second revive finished on - caught as it happens, since how
## much was left to fill decides it.
var _done_at := -1


func _tick(frame: int) -> void:
	if _done_at < 0 and frame > 200 and frame < 480 and not _second().call("is_down"):
		_done_at = frame
		_done()
	match frame:
		2:
			var game_script: GDScript = load("res://game/game.gd")
			game_script.next_party = [{}, {"character": "anas", "input": _hands}]
			(current_scene.get_node("%PlayButton") as Button).pressed.emit()
		17:
			(current_scene.get_node("%Roster/reem") as Button).pressed.emit()
		32:
			_door = (_level().call("spawn_position", &"start") as Vector2) + Vector2(6, 0)
			# The hearts are spent, so the one who falls stays down: only a
			# revive gets them up.
			current_scene.set("lives", 0)
			_player().global_position = HERE
			_second().global_position = THERE
			_second().call("drain", 999)
		34:
			_check("down: lying down - the fall, not the standing frame (%s)" % _anim(_second()),
				_second().call("is_down") and _anim(_second()) == "fall_side")
			_check("down: in the darker tint, solid, rather than faded out",
				_sprite_of(_second()).modulate == _const("res://game/player/player.gd", "DOWN_TINT")
					and _sprite_of(_second()).modulate.a == 1.0)
			_check("down: findable by group, which is how a revive finds them",
				_second().is_in_group(_const("res://game/player/player.gd", "FALLEN_GROUP"))
					and not _player().is_in_group(_const("res://game/player/player.gd", "FALLEN_GROUP")))
			_check("down: and the run goes on with one standing",
				not paused and _lives() == 0)
			_check("prompt: an E over the body the keyboard's player can reach",
				_prompt() != null and _prompt().visible)
			_check("ring: none until somebody holds", _rings().is_empty())
		40:
			_key(KEY_E, true)
		43:
			_check("hold: holding E over them is reviving them",
				_player().call("revive_target") == _second())
			_check("hold: standing still, turned to them (%s)" % _anim(_player()),
				_player().velocity.length() < 1.0 and _anim(_player()) == "idle_side"
					and not _sprite_of(_player()).flip_h)
			_check("hold: a green ring under them, filling",
				_rings().size() == 1 and _rings()[0].get("live") == true
					and _revive().call("filling", _second()))
			_check("hold: and the E is gone - somebody is on it", not _prompt().visible)
			_key(KEY_SPACE, true)
		45:
			_key(KEY_SPACE, false)
			_check("hold: the attack button does nothing while holding (%s)" % _player().get("_attack"),
				_player().get("_attack") == "")
		160:
			_check("seconds: half full at two seconds (%.2f)" % _progress(),
				absf(_progress() - 0.5) < 0.03)
			_check("seconds: and the ring says so (%.2f)" % float(_rings()[0].get("progress")),
				absf(float(_rings()[0].get("progress")) - _progress()) < 0.01)
			_player().call("take_damage", 10)
		161:
			_check("blow: a blow on the one reviving knocks a second off (%.2f)" % _progress(),
				absf(_progress() - 0.25) < 0.03)
			_check("blow: and the ring shows red for it",
				float(_rings()[0].get("lost")) > 0.0)
			_check("blow: they are still holding, so it goes on",
				_revive().call("filling", _second()))
		170:
			_key(KEY_E, false)
			_released_at = _progress()
		200:
			_check("let go: it runs back down (%.2f from %.2f)" % [_progress(), _released_at],
				_progress() < _released_at - 0.1 and not _revive().call("filling", _second()))
			_check("let go: the one who was reviving can move again",
				_player().call("revive_target") == null)
			_check("let go: and the E is back", _prompt().visible)
			_key(KEY_E, true)
		480:
			_check("done: it finished, by 480 (%d)" % _done_at, _done_at > 0)
			_key(KEY_E, false)
		# RISE_SECONDS after it finished, they stand.
		495:
			_check("rise: stood up, and theirs to move again (%s)" % _anim(_second()),
				_anim(_second()) == "idle_side" and _second().is_physics_processing())
			# A heart left, so the next fall gets up at the door 3 s on - and a
			# revive that has not finished by then is overtaken.
			current_scene.set("lives", 1)
			_second().call("drain", 999)
			_key(KEY_E, true)
		560:
			_check("door: a revive started while the door's wait runs (%.2f)" % _progress(),
				_progress() > 0.2 and _lives() == 0)
		# The wait ends at 495 + 180.
		680:
			_check("door: the door's wait got them up first, at the door",
				not _second().call("is_down") and _second().global_position.distance_to(_door) < 1.0
					and _second().get("health") == 100)
			_check("door: and nothing of the revive is left",
				_progress() == 0.0 and _rings().is_empty())
			_key(KEY_E, false)
			# Now the keyboard's own player goes down, and Anas comes over.
			_player().call("drain", 999)
		682:
			_second().global_position = _player().global_position + Vector2(12, 0)
			_hands.interact = true
		690:
			_check("helper: the one down reads who is getting them up (%s)" % _watching(),
				_watching() == "ANAS IS GETTING YOU UP")
			_hands.interact = false
		694:
			_check("helper: and is back to watching when they let go (%s)" % _watching(),
				_watching().begins_with("WATCHING ANAS"))
			_hands.interact = true
		# From nearly nothing at 694, 240 frames and a few to spare.
		945:
			_check("helper: up again - the camera theirs and the line gone",
				not _player().call("is_down") and current_scene.call("watched") == _player()
					and _watching() == "")
			_check("helper: on the same 50 (%s)" % _player().get("health"),
				_player().get("health") == 50)
			_hands.interact = false
			_finish()


## Everything about a revive the moment it finishes.
func _done() -> void:
	_check("done: up where they lay (%s)" % _second().global_position,
		not _second().call("is_down") and _second().global_position.distance_to(THERE) < 1.0)
	_check("done: at 50 health, with a grace window (%s, %.2f)"
		% [_second().get("health"), float(_second().get("_grace"))],
		_second().get("health") == 50 and float(_second().get("_grace")) > 0.0)
	_check("done: in the fight again (%d heads)" % Heads.count(self),
		Heads.count(self) == 2 and _second().is_in_group("player")
			and not _second().is_in_group(_const("res://game/player/player.gd", "FALLEN_GROUP")))
	_check("done: and the pool never heard of it (%s)" % _lives(), _lives() == 0)
	_check("done: their row is lit again", _row().modulate.a == 1.0)
	_check("done: a green +50 over them", _healed_number() != null)
	_check("done: turned to the one who got them up",
		_sprite_of(_second()).flip_h)
	_check("done: and nothing left of the revive but the flare",
		_progress() == 0.0 and _rings().all(func(r: Node) -> bool: return r.call("flaring")))


## A constant of a game script, read once the game is up: preloading player.gd
## here would compile it before the autoloads it names exist (tests/CLAUDE.md).
func _const(path: String, name: String) -> Variant:
	return (load(path) as GDScript).get_script_constant_map()[name]


func _second() -> CharacterBody2D:
	return current_scene.get_node("Player2")


func _sprite_of(body: Node) -> AnimatedSprite2D:
	return body.get_node("AnimatedSprite2D")


func _anim(body: Node) -> String:
	return String(_sprite_of(body).animation)


func _revive() -> Node:
	return current_scene.get_node("Revive")


func _progress() -> float:
	return float(_revive().call("progress", _second()))


func _prompt() -> Node2D:
	return _revive().get_node_or_null("RevivePrompt")


func _rings() -> Array:
	return get_nodes_in_group(&"revive_ring")


func _row() -> Control:
	return (current_scene.get_node("HUD/Hud").call("party_rows") as Array)[0]


func _watching() -> String:
	return String(current_scene.get_node("HUD/Hud").call("watching_text"))


func _healed_number() -> Node:
	for child in _second().get_children():
		if child.get("text") == "+%d" % _const("res://game/revive.gd", "HEALTH"):
			return child
	return null
