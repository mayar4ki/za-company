extends Control
## The scoreboard, held on Tab in an online run (DESIGN.md's *Ping, the
## Counter-Strike way*): one row per player - who, which is also which
## character, their ping to the host and the route they came by. Picked as option A ("Table")
## from the Ping On Screen preview and built exactly as previewed: the pause
## menu's colours in a panel of its own, the room still visible around it.
##
## Deliberately dumb, like the HUD: game.gd hands it Net's roster with
## `show_rows()` and decides when it is up, and it never asks anybody anything.
## Every number in it is a distance to the HOST, as Counter-Strike's are to the
## server, so the host's own row has no ping and says HOST.

const Roster := preload("res://game/player/characters/roster.gd")
const Ping := preload("res://ui/ping.gd")
const MINI := preload("res://assets/fonts/KenneyMiniSquare.ttf")

## The menu theme's colours (tools/build_ui_theme.gd).
const BG := Color("1b1119")
const SURFACE := Color("3a3941")
const ACCENT := Color("6eb39d")
const TEXT := Color("fff8e1")
const DIM := Color("987a68")
const WIDTH := 320.0
## A row's height, and the room the heading, the column names and the footer
## take around them.
const ROW := 30.0
const HEAD := 40.0
const FOOT := 22.0
## The design viewport the panel is centred in.
const VIEW := Vector2(640, 360)


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## The party, in its order: Net's roster rows, `me` this machine's peer, and
## the room's code ("" for a game with none, which then says nothing about it).
func show_rows(rows: Array, me: int, code: String) -> void:
	for child in get_children():
		child.queue_free()
	var h := HEAD + ROW * rows.size() + FOOT
	var at := Vector2(roundf((VIEW.x - WIDTH) / 2), roundf((VIEW.y - h) / 2) - 10)
	_box(at, Vector2(WIDTH, h), Color(BG, 0.96), ACCENT, 2)
	_text("PARTY", at + Vector2(12, 8), ACCENT)
	if code != "":
		_text("ROOM %s" % code, at + Vector2(WIDTH - 12 - 120, 9), DIM, 12,
			HORIZONTAL_ALIGNMENT_RIGHT, 120)
	_text("PLAYER", at + Vector2(46, 28), DIM, 12)
	_text("PING", at + Vector2(176, 28), DIM, 12, HORIZONTAL_ALIGNMENT_RIGHT, 50)
	_text("ROUTE", at + Vector2(244, 28), DIM, 12)
	for i in rows.size():
		var row: Dictionary = rows[i]
		var y := at.y + 44 + ROW * i
		var mine := int(row.get("peer", 0)) == me
		if mine:
			_rect(Vector2(at.x + 4, y - 2), Vector2(WIDTH - 8, 28), Color(SURFACE, 0.9))
		var character := String(row.get("character", ""))
		_portrait(character, Vector2(at.x + 10, y - 8))
		_text(String(row.get("name", "")).to_upper(), Vector2(at.x + 46, y - 1),
			ACCENT if mine else TEXT)
		# Under the name the preview put the character's, which is the same word
		# now that a player is called after their character (net.gd's *Who
		# plays whom*) - so only this machine's row says anything there.
		if mine:
			_text("YOU", Vector2(at.x + 46, y + 12), DIM, 12)
		var route := String(row.get("route", ""))
		if route == "HOST":
			_text("-", Vector2(at.x + 176, y + 4), DIM, 16, HORIZONTAL_ALIGNMENT_RIGHT, 50)
			_text("HOST", Vector2(at.x + 244, y + 4), ACCENT)
		else:
			var ping := int(row.get("ping", -1))
			_text("..." if ping < 0 else "%d MS" % ping, Vector2(at.x + 176, y + 4),
				Ping.colour(ping), 16, HORIZONTAL_ALIGNMENT_RIGHT, 50)
			_text(route, Vector2(at.x + 244, y + 4), Ping.MID if route == "RELAY" else DIM)
	_text("HOLD TAB", at + Vector2(0, h - 18), DIM, 12, HORIZONTAL_ALIGNMENT_CENTER, WIDTH)


func _text(text: String, at: Vector2, colour := TEXT, size := 16,
		align := HORIZONTAL_ALIGNMENT_LEFT, width := 0.0) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override(&"font", MINI)
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", colour)
	label.horizontal_alignment = align
	label.position = at
	if width > 0.0:
		label.size = Vector2(width, size + 2)
	add_child(label)
	return label


func _rect(at: Vector2, size: Vector2, colour: Color) -> void:
	var rect := ColorRect.new()
	rect.position = at
	rect.size = size
	rect.color = colour
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)


## A panel drawn in whole pixels: the edge, then the fill inset by its width.
func _box(at: Vector2, size: Vector2, fill: Color, edge: Color, width: int) -> void:
	_rect(at, size, edge)
	_rect(at + Vector2(width, width), size - Vector2(width, width) * 2, fill)


## The character's own idle frame, at the size it is in the room.
func _portrait(character: String, at: Vector2) -> void:
	var path := Roster.frames_path(character)
	if path == "":
		path = Roster.frames_path(Roster.DEFAULT_ID)
	var frames := load(path) as SpriteFrames
	if frames == null:
		return
	var tex := TextureRect.new()
	tex.texture = frames.get_frame_texture("idle_down", 0)
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex.position = at
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.size = tex.texture.get_size()
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(tex)
