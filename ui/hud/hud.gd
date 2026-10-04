extends Control
## In-game HUD, instanced once by game.tscn. One health bar for now; anything
## else the game grows on screen (keys, score, boss bars) joins it here rather
## than as loose nodes in game.tscn.
##
## Deliberately dumb: it renders whatever game.gd feeds it and never reaches
## for the player itself, so it keeps working when the thing with health is a
## different node - or when a second bar shows someone else's.
##
## Sized in design pixels against the 640x360 viewport: 66px of fill inside a
## 1px border, tucked into the top-left corner.
##
## The boss bar is its own scene under the same folder and this script only
## forwards to it, so game.gd still has one thing to talk to and neither bar
## has to know the other exists.
##
## **The rest of the party is a row each under the hearts** - a small bar and a
## name - built by `set_party()` from whatever game.gd hands it. The big bar is
## always THIS machine's player and the hearts are the party's one pool, so a
## party of one is given no rows and the HUD is exactly what it always was.

const FILL_WIDTH := 66.0
## A party row: where the first one sits, how far apart they are, and the width
## of the fill inside its 1px border.
const ROW_TOP := 33.0
const ROW_STEP := 9.0
const ROW_FILL := 40.0
const BORDER := Color(0.0784314, 0.0862745, 0.109804, 1)
const BACK := Color(0.168627, 0.027451, 0.0509804, 1)
const FILL := Color(0.847059, 0.196078, 0.235294, 1)
const TEXT := Color(0.937255, 0.941176, 0.960784, 1)
## A row whose player is down: still listed, so nobody wonders where they went.
const DOWN_ALPHA := 0.4
const FONT := preload("res://assets/fonts/KenneyPixel.ttf")
## The connection's two pieces of the HUD, online only (DESIGN.md's *Ping, the
## Counter-Strike way*), both picked from the Ping On Screen preview and built
## as previewed: this machine's ping in the top-right corner, where nothing
## else lives, and a one-line NOTICE across the top for what the connection
## has to say - the relay, somebody leaving.
const PING_AT := Vector2(572.0, 8.0)
const PING_WIDTH := 60.0
const MINI := preload("res://assets/fonts/KenneyMiniSquare.ttf")
const NOTICE_BACK := Color(0.105882, 0.0666667, 0.0980392, 0.85)
const NOTICE_TOP := 40.0
const NOTICE_HEIGHT := 16.0
## How much wider than its words a notice is, left and right together.
const NOTICE_PAD := 24.0
## The design viewport the notice is centred in.
const VIEW_WIDTH := 640.0
## The line a player who is down reads - see set_watching(). On the notice's
## strip, at the bottom of the screen: under the subtitle (which ends at 314)
## and where only this machine's own conversation would draw, and a body that is
## down has none. Never narrower than the words "WATCHING" and a long name.
const WATCH_TOP := 330.0
const WATCH_WIDTH := 160.0
const WATCH_COLOUR := TEXT

## Preloaded rather than reached for by class_name, like every other typed
## node in the game: global class names live in an editor-written cache.
const BossBarType := preload("res://ui/hud/boss_bar.gd")

## Same 9x8 mask as the heal pickup in tools/build_biomes.gd, kept in step by
## hand. Drawn at runtime rather than generated to a .tres: the HUD is not
## biome art, and two 9x8 sprites are not worth a generator of their own.
const HEART := [
	".XX...XX.",
	"XXXX.XXXX",
	"XXXXXXXXX",
	"XXXXXXXXX",
	".XXXXXXX.",
	"..XXXXX..",
	"...XXX...",
	"....X....",
]

@onready var _fill: ColorRect = %Fill
@onready var _percent: Label = %Percent
@onready var _hearts: HBoxContainer = %Hearts
@onready var _boss_bar: BossBarType = %BossBar

@onready var _heart_full := _heart_texture(true)
@onready var _heart_empty := _heart_texture(false)

## One Control per party row, in slot order; its fill is the child named Fill.
var _rows: Array[Control] = []
## The corner ping and the notice up now, each made the first time it is asked
## for - so a solo HUD never has either.
var _ping: Label = null
var _notice: Control = null
## The watching line while it is up, and what it says.
var _watch: Control = null
var _watch_text := ""


## The rest of the party, one row per name, in the order game.gd keeps them.
## Rebuilt whole rather than patched, because it is asked once per run.
func set_party(names: Array) -> void:
	for row in _rows:
		row.queue_free()
	_rows.clear()
	for i in names.size():
		_rows.append(_party_row(i, String(names[i])))


func set_member_health(slot: int, health: int, max_health: int) -> void:
	if slot < 0 or slot >= _rows.size():
		return
	var fill := _rows[slot].get_node("Fill") as ColorRect
	fill.size.x = roundf(ROW_FILL * float(health) / float(max_health))


func set_member_down(slot: int, down: bool) -> void:
	if slot < 0 or slot >= _rows.size():
		return
	_rows[slot].modulate.a = DOWN_ALPHA if down else 1.0


## The party rows, for tests: one Control each, in slot order.
func party_rows() -> Array[Control]:
	return _rows


func set_health(health: int, max_health: int) -> void:
	var ratio := float(health) / float(max_health)
	_fill.size = Vector2(roundf(FILL_WIDTH * ratio), _fill.size.y)
	_percent.text = "%d%%" % roundi(ratio * 100.0)


## One icon per possible life, full for the ones still held, a dark slot for
## the ones spent - so losing a life reads as a change, not a disappearance.
func set_lives(lives: int, max_lives: int) -> void:
	while _hearts.get_child_count() < max_lives:
		var icon := TextureRect.new()
		icon.stretch_mode = TextureRect.STRETCH_KEEP
		_hearts.add_child(icon)
	for i in _hearts.get_child_count():
		var icon := _hearts.get_child(i) as TextureRect
		icon.visible = i < max_lives
		icon.texture = _heart_full if i < lives else _heart_empty


## The boss bar, up only on a floor that has one. Three calls rather than
## one that means different things: game.gd names him once on arrival, then
## his own health_changed drives set_boss_health straight through.
func set_boss(title: String, health: int, max_health: int) -> void:
	_boss_bar.show_boss(title, health, max_health)


func set_boss_health(health: int, max_health: int) -> void:
	_boss_bar.set_health(health, max_health)


func clear_boss() -> void:
	_boss_bar.hide_boss()


## This machine's ping in the corner, in its colour - or HOST, on the host's
## own screen, which has no distance to itself.
func set_ping(text: String, colour: Color) -> void:
	if _ping == null:
		_ping = Label.new()
		_ping.name = "Ping"
		_ping.position = PING_AT
		_ping.size = Vector2(PING_WIDTH, 10.0)
		_ping.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_ping.add_theme_font_override("font", FONT)
		_ping.add_theme_font_size_override("font_size", 16)
		_ping.add_theme_color_override("font_shadow_color", BORDER)
		_ping.add_theme_constant_override("shadow_offset_x", 1)
		_ping.add_theme_constant_override("shadow_offset_y", 1)
		add_child(_ping)
	_ping.text = text
	_ping.add_theme_color_override("font_color", colour)


## What the corner says, or "" with no ping on screen. For tests.
func ping_text() -> String:
	return _ping.text if _ping != null else ""


## One line across the top for `seconds`, in `colour`, on a dark strip at least
## `width` wide - wider if the words need it. A new notice replaces one still
## up rather than stacking under it.
func notice(text: String, colour: Color, width: float, seconds: float) -> void:
	if _notice != null:
		_notice.queue_free()
	var holder := _strip("Notice", text, colour, width, NOTICE_TOP)
	_notice = holder
	get_tree().create_timer(seconds).timeout.connect(func() -> void:
		if is_instance_valid(holder):
			holder.queue_free())


## The notice up now, or "". For tests.
func notice_text() -> String:
	if _notice == null or not is_instance_valid(_notice) or _notice.is_queued_for_deletion():
		return ""
	return (_notice.get_node("Line") as Label).text


## While this machine's player is down, whose fight the camera is following -
## and, when there is more than one teammate standing, the key that moves it on.
## Empty takes the line down. game.gd asks every frame, so the strip is only
## built again when the words change.
func set_watching(who: String, more: bool) -> void:
	var text := ""
	if who != "":
		text = "WATCHING %s" % who.to_upper()
		if more:
			text += "   SPACE: NEXT"
	if text == _watch_text:
		return
	_watch_text = text
	if _watch != null:
		_watch.queue_free()
		_watch = null
	if text != "":
		_watch = _strip("Watching", text, WATCH_COLOUR, WATCH_WIDTH, WATCH_TOP)


## What the watching line says, or "". For tests.
func watching_text() -> String:
	return _watch_text


## One line of the menu's small font, centred on a dark strip at `top` at least
## `width` wide - wider if the words need it: the notice's look, which the
## watching line borrows.
func _strip(node_name: String, text: String, colour: Color, width: float, top: float) -> Control:
	var w := maxf(width, ceilf(MINI.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x) + NOTICE_PAD)
	var x := roundf((VIEW_WIDTH - w) / 2.0)
	var holder := Control.new()
	holder.name = node_name
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	var strip := ColorRect.new()
	strip.position = Vector2(x, top)
	strip.size = Vector2(w, NOTICE_HEIGHT)
	strip.color = NOTICE_BACK
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(strip)
	var line := Label.new()
	line.name = "Line"
	line.text = text
	line.position = Vector2(x, top + 1.0)
	line.size = Vector2(w, 14.0)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_theme_font_override("font", MINI)
	line.add_theme_font_size_override("font_size", 12)
	line.add_theme_color_override("font_color", colour)
	holder.add_child(line)
	return holder


## A small bar in a 1px border with a name beside it - the big bar's colours
## and font at a party member's size.
func _party_row(slot: int, label: String) -> Control:
	var row := Control.new()
	row.name = "Member%d" % (slot + 1)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.position = Vector2(8.0, ROW_TOP + ROW_STEP * slot)
	add_child(row)
	for part in [["Border", Vector2.ZERO, Vector2(ROW_FILL + 2.0, 6.0), BORDER],
			["Back", Vector2.ONE, Vector2(ROW_FILL, 4.0), BACK],
			["Fill", Vector2.ONE, Vector2(ROW_FILL, 4.0), FILL]]:
		var rect := ColorRect.new()
		rect.name = part[0]
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.position = part[1]
		rect.size = part[2]
		rect.color = part[3]
		row.add_child(rect)
	var name_label := Label.new()
	name_label.name = "Name"
	name_label.text = label
	name_label.position = Vector2(ROW_FILL + 6.0, -2.0)
	name_label.size = Vector2(80.0, 10.0)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_override("font", FONT)
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", TEXT)
	name_label.add_theme_color_override("font_shadow_color", BORDER)
	name_label.add_theme_constant_override("shadow_offset_x", 1)
	name_label.add_theme_constant_override("shadow_offset_y", 1)
	row.add_child(name_label)
	return row


func _heart_texture(full: bool) -> Texture2D:
	var w: int = HEART[0].length()
	var img := Image.create(w, HEART.size(), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in HEART.size():
		for x in w:
			if HEART[y][x] != "X":
				continue
			var c := Color("32363f")
			if full:
				c = Color("c8283c")
				if y <= 1:
					c = Color("e0465a")
				elif y >= 5:
					c = Color("8c1626")
			img.set_pixel(x, y, c)
	if full:
		img.set_pixel(2, 1, Color("f2a0aa"))
	return ImageTexture.create_from_image(img)
