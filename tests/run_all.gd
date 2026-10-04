extends SceneTree
## Runs every test file, each in its own Godot process - which is the point of
## the split: one file, one clean world.
##
## Run: <godot> --headless --path . --script res://tests/run_all.gd
## Exits 0 only when every suite passed. Uses its own executable to spawn the
## children, so it needs no knowledge of where the binary lives; --fixed-fps is
## passed here so the individual commands stay copy-pasteable without it only
## when run through this.
##
## A suite's verdict is the RESULT line it PRINTED, not its exit code, and that
## distinction is load-bearing rather than lax. Godot segfaults during audio
## teardown often enough to show - roughly one run in four of test_bosses, the
## one suite that ends with a sound still looping, since a conceded boss is
## never freed and his axe burns for as long as he holds it. The crash lands
## after the last check has passed and after RESULT: PASS is on stdout, so the
## exit code alone would fail a suite that did everything right, which is the
## most confusing shape a flake can take. Stopping the players first was tried,
## from the node's own `_exit_tree` and from the harness before `quit()`, and
## neither moved the rate: the race is inside the engine's shutdown, not in
## anything this project can reach.
##
## A suite that crashes BEFORE printing a result still fails, because `passed`
## never goes true - which is the case that actually matters.

const SUITES := ["test_menu", "test_flow", "test_chain", "test_lock", "test_combat", "test_arc", "test_dodge", "test_hit_feel", "test_slam",
	"test_bosses", "test_ahmed_moves", "test_big_mo_moves",
	"test_rage", "test_silverman", "test_barks", "test_reinforcements",
	"test_dialogue", "test_ivan", "test_dominique", "test_reward", "test_enemy_sfx",
	"test_player_sfx", "test_studio", "test_surge", "test_scrubber",
	"test_steering", "test_dogleg", "test_music", "test_ui_sound", "test_alert",
	"test_level_select", "test_release", "test_updater", "test_party", "test_watch", "test_revive", "test_net", "test_lobby",
	"test_coop", "test_coop_world", "test_coop_rooms", "test_coop_bosses",
	"test_coop_talk", "test_coop_feel", "test_coop_screen", "test_coop_cracks",
	"test_coop_revive"]


func _initialize() -> void:
	var project := ProjectSettings.globalize_path("res://")
	var failed: Array[String] = []
	for suite in SUITES:
		print("\n=== %s ===" % suite)
		var output := []
		var code := OS.execute(OS.get_executable_path(),
			["--headless", "--path", project, "--fixed-fps", "60",
				"--script", "res://tests/%s.gd" % suite],
			output, true)
		var passed := false
		for chunk in output:
			print(chunk)
			if chunk.contains("RESULT: PASS"):
				passed = true
		if not passed:
			failed.append(suite)
		elif code != 0:
			# Passed every check and then died on the way out. Reported rather
			# than swallowed, but not counted as a failure - see the note above.
			print("  (note: %s printed PASS then exited %d - teardown crash)"
				% [suite, code])
	print("\n=== ALL SUITES: %s ===" % ("PASS" if failed.is_empty()
		else "FAIL -> " + ", ".join(failed)))
	quit(0 if failed.is_empty() else 1)
