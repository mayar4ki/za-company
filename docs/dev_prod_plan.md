# Dev and production: what was decided, and what is left

Written 2026-10-02, at the start of M2. `docs/environments.md` says what
production and dev share and how each shared thing hurts; this page says what
was DECIDED about each one, and the plan for the parts still to build. When an
item here is done, move it up into *Decided and done* and say so in
environments.md.

## How a change reaches production

| What you change | Where it is tried first | How it reaches production |
|---|---|---|
| Game code | Deploy to dev: the dev site and the `dev` pre-release | A release |
| Signaling code (`server/signaling/`) | Deploy to dev: dev's own signaling, rebuilt from `develop` | A release |
| `server/deploy.sh` | The rehearsal on GitHub's throwaway runner (items A and B) | A release, through the hand-off - from the second release after v0.1.2 on |
| Caddyfile, coturn, and their parts of the compose file | CI checks only (`caddy validate`, `docker compose config`) | A release, which moves production AND dev at once |
| The `signaling` part of the compose file | Deploy to dev (dev's signaling starts from dev's own copy) | A release |
| The server's `.env` | Nowhere | Edited by hand on the server, and it moves both |

A deploy to dev is always started by hand (Actions -> Release -> Run workflow
on `develop`, *Deploy to dev* ticked) and never touches anything production
reads. RELEASING.md has both flows step by step.

## Decided and done

**1. Dev has its own signaling service.** A second `signaling` container on
the same droplet - compose project `za-dev`, port 8766, `/healthz` answers
`ok dev` - and the dev site's Caddy block points at it. A deploy to dev
rebuilds it from `develop`; a release never touches it after creating it the
first time. (Commit `80643a2`, shipped in v0.1.2.)

**Live and checked, 2026-10-02:** started by the first deploy to dev after
v0.1.2. The server runs two signaling containers from two images -
production's `server-signaling-1` (image `server-signaling`, built by the
release) on 8765, and dev's `za-dev-signaling-1` (image `za-dev-signaling`,
built by the deploy to dev) on 8766 - and the dev site's `/healthz` answers
`ok dev`. A deploy to dev rebuilds only the `za-dev` one, so production's
signaling is not touched by it.

**2. Dev desktop builds talk to dev's signaling.** `Net.signaling_url()`
(`autoload/net.gd`) is the one rule: a web build uses its own page's host, a
release desktop build (`packaged` and not `dev`) the live service, and
everything else - a dev build, the editor - dev's. The M0 test screen that
had its own live-only rule is deleted. (Commit `0b19288`.)

**3. A dev desktop build is a different app from the game.** "The New Hire
(dev)": its own name, its own `user://` folder, its own installer `AppId` and
macOS bundle id, and no update check. A tester can install both, and a dev
build can never overwrite the game or its settings - or, later, its saves.
`tools/release/prepare.sh` renames the build and refuses to build if a field
it renames has moved, and `installer.iss` takes `/DDev`.
`tests/test_release.gd` checks both halves off disk. Item D is the check
on real machines.

## Decided: keep it shared

**4. One deploy key: accepted for now.** The `DEPLOY_SSH_KEY` secret can run
every `deploy.sh` command, and any branch can read it, so one careless edit
to the dev jobs on `develop` could deploy to production without a release.
Accepted while one person pushes to `develop`. **Revisit** the day anyone
else gets push access: the fix is two keys (environments.md #3), about twenty
minutes.

**5. Caddy and coturn stay shared.** One of each, owned by the release. They
almost never change, so a second copy for dev is not worth its ports. Dev
cannot try a change to them, but since items A and B the deploy rehearsal
does: it starts Caddy and coturn on the new Caddyfile and flags on a
throwaway runner, checks both sites through Caddy, and fails if coturn
restarts (a flag coturn rejects is a restart loop, which is the relay down).
It cannot see the server's real certificates or `.env`, so after any release
that touches the Caddyfile or coturn, still watch the `deploy` job and the
site.

**6. The compose file: nothing to do.** It defines three services. Dev's
signaling is already started from dev's OWN copy of the file (from
`develop`), so the signaling part is already separate; the Caddy and coturn
parts come only from the release's copy and are shared along with them (5).
The one thing to remember: a new REQUIRED variable (`${X:?}`) in the
signaling service stops dev's signaling starting until it is in the server's
`.env` - add it there before the dev deploy that needs it.

**7. The secrets file (`/opt/za-company/server/.env`) stays shared.** Dev's
signaling reads the live `.env` because there is only one coturn, and the
two must agree on its secret. What is in it:

| Key | What it is | Secret? |
|---|---|---|
| `TURN_SECRET` | Signaling makes short-lived relay logins with it; coturn checks them with it | **Yes - the only one.** Whoever has it can use the relay and the server's bandwidth |
| `DOMAIN` | The server's name: the site, signaling, and where TURN is | No |
| `EXTERNAL_IP` | The server's public address, which coturn tells players | No |
| `TURN_PORT`, `TURN_MIN_PORT`, `TURN_MAX_PORT` | The relay's port and the range relayed players use | No |
| `TURN_TOTAL_QUOTA` | How many players can be relayed at once (40) | No |
| `SIGNAL_PORT`, `DEV_SIGNAL_PORT` | Where production's (8765) and dev's (8766) signaling listen, on loopback only | No |
| `PARTY_CEILING` | The most players any room may hold, whatever a client asks | No |

Two consequences. Rotating `TURN_SECRET` means restarting both signaling
services and coturn together. And dev cannot use a different value for any
of these (for example a bigger `PARTY_CEILING`); if it ever needs to, the
place is `up_dev` in `deploy.sh`, which already passes dev its own port.
The only other secret anywhere is `DEPLOY_SSH_KEY` on GitHub.

**8. One droplet.** There is no second server, so dev's signaling runs beside
production's on 458 MiB of RAM. "Be careful" becomes item C, so nobody has
to remember it.

## Decided: not a separate deploy.sh

**9. `deploy.sh` stays one script, and is tested instead of duplicated.**
The problem is real: a change to it cannot be tried anywhere before
production, and it only fully takes effect one release LATE, because a
release's `server` step is run by the copy the PREVIOUS release installed.
v0.1.2 is the proof: the old copy put the new Caddyfile in place, and the
step that would have started dev's signaling was only in the new copy, so
the dev site's signaling answered 502. (It was cleared by the next deploy to
dev: its `server-dev` step was one the old copy already knew.)

A dev copy that dev deploys could update was rejected because of what the
script is: it runs as root on the box that serves production, and its job is
deleting and replacing folders - `mirror` empties a whole directory except
`.env` and `web/`. A half-finished copy of it, one wrong path away from
production's folder, is the thing most able to break production. Items A
and B below solve the actual problem without that, and are built.

## To do

### A and B. The hand-off and the rehearsal - BUILT 2026-10-03

**Status:** built, and rehearsed on a throwaway machine; waiting for its
first run on GitHub (the next dry run, deploy to dev or release) and then for
two releases to take it live. See *Done when*.

**The hand-off** (`server/deploy.sh`). The `server` step is now only the
hand-off, run by whatever copy the last release installed: unpack the tar,
refuse it if it is not a server folder (it must now hold `deploy.sh` too),
install the new `deploy.sh`, and run it as `apply` on the folder it unpacked.
`apply` - the new copy - does everything else: the mirror, the stack, Caddy,
`settle`, the cleanup. So a change to any of that takes effect in the release
that ships it, and the only lines still a release late are the hand-off's
own, which must stay small. `apply` refuses to run alone: over SSH it is
never given a folder.

`settle` (item A) is folded into it: it is the last thing `apply` does, so it
too runs as the new copy, and it is still a command of its own, safe alone.

**The rehearsal** (`tools/release/rehearse_deploy.sh`, the release
workflow's `server` job, after the bundle is made). On GitHub's throwaway
runner, at the server's own paths, with `DOMAIN=localhost` so Caddy signs its
own certificates and nothing asks the internet:

1. The box as the previous release left it: that release's `deploy.sh`
   installed, and its own server files deployed by it.
2. This bundle deployed by THAT script - the upgrade the server will really
   see. Checks: the installed script is now this commit's, the live site's
   `/healthz` says `ok` and the dev site's says `ok dev`, both through Caddy
   by name, the way a player reaches them, and coturn stays up on this
   commit's flags without restarting.
3. This bundle again, by the copy step 2 installed - every release after,
   and the only path that runs the hand-off. Checks: the new copy said it
   took over, and both sites again.
4. A deploy to dev (and the live signaling CONTAINER is the same one after
   it, which is the proof a dev deploy leaves production alone), `settle`
   alone, a web build to each site, and one with no `index.wasm`, which must
   be refused with the live site untouched.

Any failure fails the `server` job, and `publish`, `deploy` and `deploy-dev`
all wait for that job - so a script that cannot upgrade the server stops the
release before anything is published or the server is touched. On failure
the log carries `docker ps -a` and both stacks' last lines.

Two things changed from the plan, both for the better. No path in
`deploy.sh` had to become overridable: the rehearsal uses the server's REAL
paths, which is safe because the machine is thrown away - and the script
refuses to run anywhere `GITHUB_ACTIONS` is not `true`, since on a real
server it would replace `/opt/za-company`. And it checks through Caddy rather
than straight at the signaling ports, because the v0.1.2 failure was a route
with nothing behind it, which only a request by name can see.

**Proven, 2026-10-03,** in a privileged throwaway container on the
developer's machine (ubuntu 24.04 with its own Docker):

- v0.1.2 -> this commit, and this commit -> itself: all 21 checks pass.
- v0.1.1's script deploying v0.1.2's files - the release that shipped the
  502 - FAILS, at "the dev site reaches dev's own signaling", with the 502.
  So it would have stopped v0.1.2.
- This commit with `--no-dtls` added to coturn's flags - the 4.18 trap,
  a restart loop - FAILS, at "coturn stays up on this commit's flags". So a
  flag coturn rejects now stops a release instead of taking the relay down.

**When it takes effect on the real server:**

| Release | Deployed by | What happens |
|---|---|---|
| The next one | v0.1.2's script, which knows nothing of the hand-off | It deploys the old way and installs the new script. The rehearsal has already checked exactly this upgrade |
| The one after | The new script | The first deploy through the hand-off; its `deploy` log says `za-deploy: the new copy takes over` |

The rehearsal itself starts at once: it runs on every dry run, deploy to dev
and release, and - since the gap below was closed - on every push that
touches `server/`. It first passed on GitHub on 2026-10-02 (run 37061169709,
the dry run of `e0c2073`).

**The gap, closed 2026-10-03.** release.yml's push `paths` leave `server/`
out on purpose, because a dry run builds the game for three platforms; so a
push that changed only server files started no run, and a broken server
change was first noticed at the next deploy to dev or release - days later,
mixed in with other work. Nothing broken could reach the server (both of
those stop on the checks), but it was found late. Now:

- `.github/actions/server_checks/` holds the server's checks ONCE: the
  signaling tests, the compose file, the Caddyfile, the bundle, and the
  rehearsal.
- release.yml's `server` job uses it, as before, gating every release and
  deploy to dev.
- `.github/workflows/server.yml` uses it on every push to `develop` or
  `main` that touches `server/`, the rehearsal script or the checks
  themselves: a few minutes, no game builds, its own queue (a newer push
  cancels an older run, and it never holds up a deploy to dev). It
  publishes and gates nothing - it is only how a broken server change is
  noticed while whoever made it still remembers it.

**Done when:** the rehearsal has passed once on GitHub (done); the next
release's `deploy` job passes; and the release after it shows `the new copy
takes over` in its `deploy` log.

### C. A memory cap on the signaling containers

**Status:** SKIPPED for now (decided 2026-10-03). Step 1 is done; the cap
itself is about fifteen minutes whenever it is wanted.

1. ~~Measure first.~~ Done 2026-10-02, `docker stats --no-stream` on the
   server: production's signaling 11.8 MiB, dev's 17.8 MiB, Caddy 20.9 MiB,
   coturn 2.3 MiB - and every container's limit is the whole server's
   458 MiB, which is to say there is no cap yet.
2. One line on the `signaling` service in `docker-compose.yml`:
   `mem_limit: ${SIGNAL_MEM_LIMIT:-128m}` - about seven times the bigger of
   the two today, so it only ever stops a runaway. Both copies start from that
   file, so it caps production's and dev's alike - a runaway dev build is then
   killed by Docker instead of pushing production into swap.
3. The next deploy to dev gives dev's copy the cap, and the next release
   gives production's.

**Done when:** `docker inspect` shows the limit on both signaling containers.

### D. Check the dev app on real machines

**Status:** SKIPPED for now (decided 2026-10-03). Ten minutes, by hand,
whenever a tester first installs a dev build - until then, item 3 is checked
off disk by `tests/test_release.gd` but has never been installed for real.

- **Windows:** install the dev setup on a machine that has the game
  installed. Expect both in the Start Menu and in *Installed apps*, in two
  folders, each with its own uninstaller; the dev window titled "The New Hire
  (dev)"; its settings in `%APPDATA%\Godot\app_userdata\The New Hire (dev)`;
  and no update notice on its menu.
- **macOS:** "The New Hire (dev).app" sits beside "The New Hire.app" in
  Applications, and neither replaces the other.
- **Online:** a dev desktop build and the dev web site can play together
  (both on dev's signaling).

One thing will look like a bug and is not: a dev build installed BEFORE this
change used the game's own `AppId`, so it replaced the game. After it, the
first new dev build starts with fresh settings in its own folder, and the
next release installer upgrades that old copy back into the game.
