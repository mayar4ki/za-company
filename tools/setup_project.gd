extends SceneTree
## One-shot project configuration. Re-runnable; safe to run again after edits.

func _key(physical_keycode: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = physical_keycode
	return ev


func _action(events: Array) -> Dictionary:
	return {"deadzone": 0.2, "events": events}


func _initialize() -> void:
	# Pixel art must not be filtered, or every sprite goes blurry when scaled.
	ProjectSettings.set_setting("rendering/textures/canvas_textures/default_texture_filter", 0)

	# Pixel-art snapping stops sprites shimmering when the smoothed camera lands
	# on a fractional position.
	ProjectSettings.set_setting("rendering/2d/snap/snap_2d_transforms_to_pixel", true)

	ProjectSettings.set_setting("display/window/size/viewport_width", 640)
	ProjectSettings.set_setting("display/window/size/viewport_height", 360)
	# Launch windowed - F11 goes fullscreen (autoload/display.gd).
	ProjectSettings.set_setting("display/window/size/mode", 0)

	# The window is an exact 3x of the 640x360 base, so pixels stay even.
	ProjectSettings.set_setting("display/window/size/window_width_override", 1920)
	ProjectSettings.set_setting("display/window/size/window_height_override", 1080)

	# The loading screen is the game's own icon on the menu's background (the
	# theme's BG_DEEP) rather than Godot's logo: the boot splash natively, and
	# the page the web build loads behind. It is splash.png, not icon.svg - a
	# boot splash takes only a PNG - and build_icon.gd writes both from one
	# picture. Stretch 0 is "Disabled", its real size (the art at 4x), and
	# unfiltered for the reason every sprite is. The web page styles the bar
	# around it (export_presets.cfg's `html/head_include`).
	ProjectSettings.set_setting("application/boot_splash/image", "res://splash.png")
	ProjectSettings.set_setting("application/boot_splash/stretch_mode", 0)
	ProjectSettings.set_setting("application/boot_splash/use_filter", false)
	ProjectSettings.set_setting("application/boot_splash/bg_color", Color("1b1119"))

	# What a player sees the game called: the window title, the .app, the
	# Start Menu entry. Only for builds carrying the `packaged` feature (the
	# Windows and macOS presets) - the bare name is also what names user://, so
	# renaming it outright would move every developer's saved settings and the
	# test suites' backup with it. `packaged` is also how the main menu knows to
	# look for a newer release (ui/update/release_check.gd).
	ProjectSettings.set_setting("application/config/name.packaged", "The New Hire")

	# The macOS build is universal, and Godot refuses to export one for Apple
	# Silicon unless the project imports ETC2/ASTC as well as S3TC/BPTC. It
	# costs nothing here: every texture in the game imports lossless (pixel
	# art), so there is no VRAM-compressed texture for a second format to copy.
	ProjectSettings.set_setting("rendering/textures/vram_compression/import_etc2_astc", true)

	# Physical keycodes so WASD stays positional on non-QWERTY layouts.
	ProjectSettings.set_setting("input/move_up", _action([_key(KEY_W), _key(KEY_UP)]))
	ProjectSettings.set_setting("input/move_down", _action([_key(KEY_S), _key(KEY_DOWN)]))
	ProjectSettings.set_setting("input/move_left", _action([_key(KEY_A), _key(KEY_LEFT)]))
	ProjectSettings.set_setting("input/move_right", _action([_key(KEY_D), _key(KEY_RIGHT)]))
	ProjectSettings.set_setting("input/attack", _action([_key(KEY_SPACE), _key(KEY_J)]))
	# The dodge - the tumble roll. K sits beside J for the hand on the attack
	# key; Ctrl is under the little finger of the hand on WASD. Ctrl is the
	# DESKTOP's second key only: in a browser Ctrl+W closes the tab and no page
	# can stop it, so input_source.gd takes Ctrl back out of a web build. Never
	# Shift: five quick presses open Windows' Sticky Keys box over the game.
	ProjectSettings.set_setting("input/dodge", _action([_key(KEY_K), _key(KEY_CTRL)]))
	# Talking to people. E is where a hand on WASD already is; Enter is for the
	# hand that is not. Space and J advance a line too (the subtitle box takes
	# `attack` as well), but only `interact` can START a conversation - walking
	# past someone mid-combo must never open one.
	ProjectSettings.set_setting("input/interact", _action([_key(KEY_E), _key(KEY_ENTER)]))
	ProjectSettings.set_setting("input/toggle_fullscreen", _action([_key(KEY_F11)]))
	# The online scoreboard, HELD rather than pressed - Counter-Strike's key for
	# Counter-Strike's board (DESIGN.md's *Ping, the Counter-Strike way*).
	ProjectSettings.set_setting("input/scoreboard", _action([_key(KEY_TAB)]))

	# Order matters: autoloads are readied in the order they appear here, and
	# both display.gd and difficulty.gd read saved values from Settings during
	# _ready. Clearing them first re-appends them, which is what puts Settings
	# ahead on a project that already had them registered.
	ProjectSettings.clear("autoload/Display")
	ProjectSettings.clear("autoload/Difficulty")
	ProjectSettings.clear("autoload/Music")
	ProjectSettings.clear("autoload/Net")
	ProjectSettings.clear("autoload/UiSound")
	ProjectSettings.set_setting("autoload/Settings", "*res://autoload/settings.gd")
	ProjectSettings.set_setting("autoload/Display", "*res://autoload/display.gd")
	ProjectSettings.set_setting("autoload/Difficulty", "*res://autoload/difficulty.gd")
	ProjectSettings.set_setting("autoload/Music", "*res://autoload/music.gd")
	# Online co-op's one door to the network. Reads nothing saved; its node
	# path, /root/Net, is the same on every machine, which is what its RPCs
	# need.
	ProjectSettings.set_setting("autoload/Net", "*res://autoload/net.gd")
	# Last, and it reads nothing saved: it hooks `node_added`, so it only has
	# to be ready before the first SCENE is built, not before the other three.
	ProjectSettings.set_setting("autoload/UiSound", "*res://autoload/ui_sound.gd")

	var err := ProjectSettings.save()
	print("ProjectSettings.save() -> ", error_string(err))
	quit(0 if err == OK else 1)
