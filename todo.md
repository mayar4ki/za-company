[ ] In-game updater for Windows and macOS, in four parts (details below)
    [x] Part A - the shared core (owner) - built, on develop
    [ ] Part B - Windows install (owner) - built, on develop; waits for its
        rows of the Part D test on a real PC
    [ ] Part C - macOS install (teammate, needs a Mac) - can start now
    [ ] Part D - test both, then switch it on (owner + teammate)

[ ] Playtest notes (2026-10-03)
    [ ] Player movement feels odd, as if it lags - investigate
        [x] A teammate twitched a step forward and back 30 times a second,
            and shuffled in their idle pose before a walk (game/sync/CLAUDE.md)
        [x] Your own hits froze a teammate's legs while they kept sliding
        [ ] Still to watch in a real game: a teammate walking in place, then
            jumping ahead - messages arriving late. Note the corner ping
            when it happens
    [x] Dodge incoming attacks - the tumble roll, on K (and Ctrl off the
        web); its sound is still to be cut
    [ ] A dead player's camera follows the players still standing
    [ ] A teammate can revive a dead player, who gets up with 50% health
    [ ] Silverman's attacks hit harder - he is too weak now
    [ ] New attacks for the player after beating a boss
    [ ] A reward for fighting normal enemies, like extra health
    [ ] Web build: the health bar sticks up to the top right

# In-game updater: Windows and macOS

**For the agent doing one of these parts.** Read the common sections
(1-4 and 9) first, then YOUR part. Also read `CLAUDE.md` (the project's
rules) and `RELEASING.md` (how releases work). Some decisions are already
made, and they are marked **decided**: do not reopen them without asking the
owner.

**Who does what.**

| Part | Who | What |
|---|---|---|
| A | owner | everything both platforms share |
| B | owner | the Windows install step |
| C | teammate | the macOS install step; needs a Mac |
| D | both | the real-machine test, then the switch is turned on |

Part C starts once Part A is on `develop`. It changes ONE file
(`ui/update/update_install_macos.gd`) and needs nothing from Part B.

---

## 1. The goal

Today an installed game tells the player a new version exists, and the player
updates by hand. After this task, the player can update **from inside the
game**:

1. The main menu shows that a new version is out (this already works).
2. The player presses **UPDATE NOW**.
3. The game downloads the new version, showing progress, and checks the file.
4. The game installs it and restarts on the new version. Settings are kept.

If anything goes wrong, or the copy cannot update itself, the player gets
today's behaviour instead: a button that opens the release page in the
browser.

## 2. Decided (do not reopen)

- **Both platforms or neither.** The updater sits behind ONE switch,
  `ENABLED` in `ui/update/updater.gd`, and it stays `false` until Part D has
  passed on both platforms. While it is off, both platforms keep today's
  notice and link, so a release made in the meantime treats Windows and Mac
  the same.
- **No server.** Downloads come straight from the GitHub release. Nothing new
  is hosted anywhere.
- **The browser link never goes away.** Every failure, refusal or
  unsupported case falls back to "open the release page". A broken updater
  must never leave a player stuck on an old version with no way forward.
- **Whole-build updates only.** Download and install the full release file.
  Do NOT build a patch system that ships only the game data (`.pck`): it was
  considered and rejected, because engine and plugin changes still need a full
  install, and loading new code into a running game causes subtle bugs.
- **Only the installed Windows copy updates itself.** The portable zip has no
  installer to upgrade, so it keeps the link.
- **Only from the main menu**, never during a run.
- **Builds stay unsigned** for now. Signing is a separate, later task
  (RELEASING.md, "Later: signing").
- **Never change `VERSION` yourself.** A `VERSION` change on `main` publishes
  a public release. Ask the owner for any version number you need.

## 3. What exists (before Part A)

| File | What it does |
|---|---|
| `ui/main_menu/release_check.gd` (Part A moved it to `ui/update/`) | Reads `res://VERSION` (`current()`), compares versions (`is_newer()`), asks `https://api.github.com/repos/mayar4ki/za-company/releases/latest` once per run, and emits `newer_found(version, url)`. It only asks when the build has the `packaged` feature, so it never runs in the editor, the tests or the web build. `take(json)` handles the answer and is what the tests call. |
| `ui/main_menu/main_menu.gd` / `.tscn` | Shows the version in the footer (`%Version`). On `newer_found` it shows `%UpdateButton` ("v0.3.0 IS OUT - GET IT"), which opens the release page in the browser. |
| `tests/test_release.gd` | Checks the above with no network, and reads `export_presets.cfg` off disk. |
| `.github/workflows/release.yml` | When `VERSION` changes on `main`, it builds and publishes the release: Windows installer and portable zip, macOS `.dmg`, and the web build and server deploy. On `develop`, a push that touches the presets, the workflow or `tools/release/` is a **dry run**, which builds and publishes nothing. |
| `tools/release/installer.iss` | Inno Setup script. Installs per user by default, and its fixed `AppId` makes a new version upgrade the old one in place. **Never change the `AppId`.** |

**The release file names are a contract.** The updater finds its file by
name. If a name changes, the updater has to change in the same commit (a test
enforces this):

- `TheNewHire-<version>-windows-setup.exe`
- `TheNewHire-<version>-windows-portable.zip`
- `TheNewHire-<version>-macos.dmg`

## 4. The shape of it (the contract between the parts)

All new code lives in `ui/update/`:

| File | Part | Job |
|---|---|---|
| `updater.gd` | A | The facade. Holds the `ENABLED` switch, decides whether this copy can update itself, and runs download -> verify -> install. Picks the platform script by `OS.get_name()`. |
| `update_download.gd` | A | Picks the right file from the release, downloads it and `SHA256SUMS.txt`, and checks the SHA-256. |
| `update_panel.tscn` / `.gd` | A | The screen shown while updating: progress, cancel, the error state and the browser link. |
| `update_install_windows.gd` | B | The Windows install step. |
| `update_install_macos.gd` | C | The macOS install step. Part A ships it as a stub that refuses. |

**Each platform script has exactly these three members**, all static. The
facade calls nothing else:

```gdscript
## The end of the release file this platform downloads.
const ASSET_SUFFIX := "-windows-setup.exe"   # or "-macos.dmg"

## "" when the running copy at `executable_path` can replace itself, else a
## short reason it cannot (the player gets the browser link instead).
static func refusal(executable_path: String) -> String

## Installs the verified download at `package_path` over the copy at
## `executable_path` and arranges for the new version to start. Returns ""
## when that is under way - the facade then quits the game - or a reason it
## failed, which falls back to the browser link.
static func install(package_path: String, executable_path: String) -> String
```

**The developer test feed.** Starting the game with
`-- --update-feed=<release API URL>` reads that release instead of
`/releases/latest`, which skips pre-releases, AND switches the updater on for
that run whatever `ENABLED` says. It is how Parts B, C and D are tested before
the switch is on. Players never pass it.

---

## Part A - the shared core (owner)

1. **The release publishes checksums.** In `release.yml`'s `publish` job,
   write `dist/SHA256SUMS.txt` (`sha256sum` over the release files) before
   `gh release create`, so it is attached with them. The updater refuses any
   file whose SHA-256 does not match it.
2. **`release_check.gd`:**
   - Keep the whole release (its `assets`, each with `name` and
     `browser_download_url`), so the updater can find its file.
   - Honour `--update-feed`.
   - **Fix `is_newer()` for pre-releases.** Today `0.3.0-beta.2` vs
     `0.3.0-beta.1` gives false. Use semver ordering: compare the suffix's
     dot-separated parts, numbers as numbers, so `beta.2 > beta.1`,
     `beta.10 > beta.9`, and `1.0.0 > 1.0.0-rc.1` still holds.
3. **`ui/update/`:** the facade, the download and the panel, as in section 4.
   - The download goes to `user://updates/`, which is emptied when the game
     next starts.
   - Progress comes from `HTTPRequest.get_downloaded_bytes()` /
     `get_body_size()`, and the hash from `HashingContext`, in chunks.
   - The panel fits 640x360, works from the keyboard, uses the shared theme,
     and calls `UiSound.back()` where it handles Escape.
4. **`update_install_macos.gd` as a stub:** the three members, with
   `refusal()` returning "the macOS updater is not built yet (todo.md
   Part C)".
5. **The main menu:** when the updater is on and `refusal()` is "", the button
   reads **"v0.3.0 IS OUT - UPDATE"** and opens the panel. Otherwise it keeps
   today's text and link.
6. **Tests:** `tests/test_updater.gd`, registered in `tests/run_all.gd` and
   listed in CLAUDE.md. No network: everything is handed in. Cover:
   - picking the file per platform;
   - parsing `SHA256SUMS.txt`;
   - a matching file passes, and a file with one byte changed is refused;
   - the switch: off means link only, and the feed overrides it;
   - the pre-release ordering;
   - the name contract, by reading `release.yml` off disk for each
     platform's `ASSET_SUFFIX`;
   - the panel opening, cancelling and falling back to the link;
   - nothing left behind in `user://` afterwards.

**Done when:** the suite passes alongside `test_release.gd` and
`test_menu.gd`, a dry run on `develop` is green, and with `ENABLED` false a
build behaves exactly as before.

**Status: done.** Everything above is in `ui/update/`, with
`tests/test_updater.gd` (36 checks) and eight pre-release cases added to
`test_release.gd`'s table. Two things worth knowing for Part C:

- `release_check.gd` now lives in `ui/update/`: the menu and the updater both
  read it.
- `Updater.refusal()` takes the OS name, the executable path and the feed as
  arguments (with the real ones as defaults), so every case can be tested
  from any machine. The macOS cases belong in `tests/test_updater.gd`'s
  `_switch()` / a new `_macos_refusal()`, handing paths in the same way
  `_windows_refusal()` does.

## Part B - Windows install (owner)

`ui/update/update_install_windows.gd`, plus `tools/release/installer.iss`.

- **`refusal()`:** an Inno Setup install has `unins000.exe` next to the
  game's exe. Without it the copy is portable: "a portable copy updates by
  download".
- **`install()`:** start the downloaded setup with `OS.create_process()` and
  `/SILENT /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS /RELAUNCH=1`.
  - `/SILENT` shows Setup's own progress window and asks nothing.
  - The facade quits the game straight after, because Setup cannot replace a
    running exe.
- **`installer.iss`:**
  - `CloseApplications=yes`, so a game that has not quite exited yet is
    waited for or closed, not a failed overwrite.
  - A second `[Run]` entry that starts the game with flags
    `nowait runasoriginaluser` and `Check: ShouldRelaunch`, plus a `[Code]`
    section where `ShouldRelaunch` is
    `ExpandConstant('{param:RELAUNCH|0}') = '1'`.
  - Keep the existing `postinstall` entry for normal installs.
  - `UsePreviousPrivileges` (on by default) keeps an update in the same mode
    as the first install: per user updates silently, and all users shows the
    admin prompt.

**Done when:** a dry run builds the installer with these changes, and the
Windows rows of the Part D matrix pass on the owner's PC.

**Status: built.** `update_install_windows.gd` and the `installer.iss`
changes are in. What is left is the Windows rows of the Part D matrix, which
need the two pre-releases.

## Part C - macOS install (teammate, needs a Mac)

**Change only `ui/update/update_install_macos.gd`.** Replace the stub with
the real thing, keeping its three members exactly as section 4 defines them.
If something in Parts A or B looks wrong, tell the owner rather than changing
it: two people fixing the same file is how a shared core turns into two.

- **First, check rather than assume:** mount a dry-run `.dmg` (from a dry run's
  *Artifacts*, or a pre-release) and note the exact name of the `.app` inside
  (expected "The New Hire.app") and of the binary in `Contents/MacOS/`.
- **`refusal(executable_path)`:** find the bundle (three levels up from
  `.../The New Hire.app/Contents/MacOS/<binary>`). Refuse, and the player
  gets the link, when:
  - the path contains `/AppTranslocation/`. The game was not moved to
    Applications, so macOS runs it from a hidden read-only copy.
  - the path starts with `/Volumes/`. It is running from the disk image.
  - the folder holding the bundle is not writable (a non-admin account). Test
    by creating and deleting a temporary file there.
- **`install(package_path, executable_path)`:**
  1. `hdiutil attach -nobrowse -readonly -mountpoint <temp dir> <dmg>`.
  2. `ditto` the new `.app` next to the old one under a temporary name.
  3. Rename the old one aside, rename the new one into place, and delete the
     old one. macOS allows replacing a running app's bundle.
  4. `hdiutil detach`.
  5. `xattr -dr com.apple.quarantine <bundle>`, which should be a no-op.
  6. `OS.create_process("/usr/bin/open", ["-n", <bundle>])`.
  7. On any failure, put the old bundle back before returning the reason.
- **Tests:** add the macOS `refusal()` cases to `tests/test_updater.gd`, as
  paths handed in, so they run on any machine.

**Done when:** the macOS rows of the Part D matrix pass on a real Mac.

## Part D - test both, then switch it on (owner + teammate)

1. Ask the owner for two version numbers and the go-ahead. They become two
   real, public pre-releases, for example `0.3.0-beta.1` and `0.3.0-beta.2`.
   - Both must contain Parts A, B and C, so the OLD one can already update.
   - This is the one time unfinished work goes to `main`, and only as a
     pre-release. `/releases/latest` skips pre-releases, so no player is
     offered them.
2. Merge `develop` into `main` with `VERSION` set to the first number, and
   push. Wait for the release, then do the same for the second.
3. Install the first, then run it with the feed pointing at the second, e.g.
   `.../releases/tags/v0.3.0-beta.2`:
   - Windows: `"%LOCALAPPDATA%\Programs\The New Hire\TheNewHire.exe" -- --update-feed=<URL>`
   - macOS: `"/Applications/The New Hire.app/Contents/MacOS/<binary>" -- --update-feed=<URL>`

   The `--` matters on both: Godot hands the game only the arguments after it.
4. Work through the matrix, and record the results for the owner.

| # | Platform | Situation | Expected |
|---|---|---|---|
| 1 | Windows | installed per user | updates, restarts, footer shows the new version, settings kept, still one entry in *Apps & features* |
| 2 | Windows | installed for all users | admin prompt, then same as 1 |
| 3 | Windows | portable zip | no UPDATE NOW; the link opens the release page |
| 4 | Windows | cancel mid-download | old version keeps working; the link still works |
| 5 | Windows | network off | no notice at all, no error |
| 6 | macOS | in /Applications (after "Open Anyway" once) | updates, restarts, new version, settings kept |
| 7 | macOS | run from the mounted disk image | link only |
| 8 | macOS | run from Downloads without moving it | link only |
| 9 | macOS | non-admin account, app in /Applications | link only |
| 10 | macOS | cancel mid-download | old version keeps working |
| 11 | both | after an update | record whether the "unsigned app" warning appeared again (expected: no) |

Apple Silicon is the priority Mac; test an Intel one too if one is available.

5. **Only when every row passes:**
   - set `ENABLED := true` in `ui/update/updater.gd`;
   - update RELEASING.md ("If there is a new version") and CLAUDE.md;
   - tick the boxes at the top of this file;
   - the next normal release ships the updater to everyone.

---

## 9. Rules and know-how from this project

- **CLAUDE.md is the rulebook.** Above all:
  - one file per job;
  - snake_case names;
  - scripts sit next to their scenes;
  - `preload`, not `class_name`, because global class names live in an
    editor cache a fresh checkout does not have;
  - don't pre-create empty folders.
- **Work on `develop`, and commit and push to `develop`.** `main` takes
  finished work by merge, and Part D is the one exception.
- **The Godot binary** on the owner's machine is
  `~/OneDrive/Desktop/Godot_v4.7.2-stable_win64_console.exe`.
  - One suite: `--headless --path . --fixed-fps 60 --script res://tests/test_<name>.gd`.
  - All suites: `--headless --path . --script res://tests/run_all.gd`.
- **Back up `settings.cfg` before running any suite**
  (`%APPDATA%\Godot\app_userdata\za-company\settings.cfg` on Windows,
  `~/Library/Application Support/Godot/app_userdata/za-company/settings.cfg`
  on a Mac). The harness blanks it during a suite and only restores it at the
  end, so a suite that is killed or hangs loses the developer's settings.
- **Run `--import` only while the Godot editor is closed.** Two editors on
  one project corrupt each other.
- **Never kill a Godot process you did not start.** Other agents and
  teammates run tests on the same machine.
- **CI logs need a GitHub login, but error annotations do not.** The scripts
  in `tools/release/` turn failures into `::error::` lines. To watch a run:
  - `https://api.github.com/repos/mayar4ki/za-company/actions/runs?head_sha=<sha>` finds the run.
  - `.../actions/runs/<id>/jobs` gives each job's steps and result.
  - `.../check-runs/<job id>/annotations` gives the errors.
- **The owner's machine has no `gh` CLI.** Use the GitHub REST API with
  `curl`, or the web page.

Out of scope, so leave it for later: code signing; store distribution
(itch.io, Steam); refusing online co-op between different game versions
(DESIGN.md, Multiplayer, M2).
