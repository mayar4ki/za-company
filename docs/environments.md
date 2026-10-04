# Production and dev

There are two places the game runs, and they are not two copies of the same
setup. This page says what is separate, what is shared, and which of the
shared parts will cause trouble later, when, and what fixes it. How each one
is deployed is RELEASING.md (*Deploying* and *Deploying to dev*).

| | Production | Dev |
|---|---|---|
| Web game | https://za-company.mayar-deeb.dev | https://dev.za-company.mayar-deeb.dev |
| Windows and macOS files | a versioned GitHub Release (`v0.1.1`) | the rolling `dev` pre-release |
| Started by | `VERSION` changing on `main` | Run workflow on `develop`, *Deploy to dev* ticked |
| Server folder | `web/game/` | `web/dev-game/` |
| Signaling | `server`, port 8765, the release's `server/` | `za-dev`, port 8766, the dev deploy's `server/` |
| Desktop builds can tell | (no `dev` feature) | `OS.has_feature("dev")` |

Separate: the web builds, the desktop builds, the signaling service, and what
starts each deploy.

Shared: the droplet, its Caddy, coturn, the deploy key, and the workflow
(`release.yml` builds both with the same jobs). Of the server's own files only
`signaling/` can reach dev first - a deploy to dev rebuilds dev's copy of it -
and the Caddyfile, the compose file and `deploy.sh` still reach the server
only with a **release** - rehearsed first on a throwaway runner, but never
tried on dev.

## When sharing bites

Four things, in the order they will hurt. The first and the fourth are fixed
and the second is fixed for signaling, all at the start of M2; the third is
accepted for now. What was decided about each, and what is still to do, is
`docs/dev_prod_plan.md`.

### 1. One signaling service - FIXED at the start of M2

**When:** the first time the signaling protocol changes, which M2 (the `Net`
autoload and the lobby) will do several times.

**What happens:** a dev build speaking the new protocol is refused by the
production service with `version`, and the production service can only be
changed by a release - so dev cannot test multiplayer work before it ships.
The other way round is no better: release the new service, and the dev site
breaks until dev catches up.

**Fixed:** a second `signaling` container for dev on the same droplet - its
own compose project, `za-dev`, on port 8766 - and the dev site's Caddy block
pointing at it. coturn stays shared (see below). About 40 MB of memory. Its
`/healthz` says `ok dev`, which is how a deploy to dev proves the dev site
reaches it (server/README.md, *Dev's signaling*).

### 2. Server changes cannot be tried anywhere first - FIXED for signaling

**When:** any release that changes Caddy, coturn or signaling.

**What happens:** the change goes straight to production, and dev with it.
The release's `server` job checks the compose file and runs the signaling
tests, but it cannot see how a program reacts to its configuration. The real
case: coturn 4.18 rejects `--no-dtls`, which a config check passes and coturn
answers with a restart loop. Shipped in a release, that is production's relay
down.

**Fixed for signaling:** a deploy to dev rebuilds dev's copy of the
signaling service from `develop` (`deploy.sh server-dev`), so a signaling
change runs on dev before a release takes it to production.

**Still true for Caddy and coturn: dev cannot try them.** There is one of
each - one pair of 80/443, one TURN port - and they are the release's. What
closes most of the gap instead is the **deploy rehearsal**
(`tools/release/rehearse_deploy.sh`, in the release's `server` job, 2026-10-03):
before anything is published, a throwaway runner is upgraded from the
previous release to this commit at the server's real paths, which starts
Caddy and coturn on the NEW Caddyfile and flags, and checks both sites
through Caddy by name and that coturn stays up without restarting. So the
coturn case above now stops the release instead of reaching production. And
`deploy.sh` itself is rehearsed the same way - the upgrade the server will
really see, then the hand-off (docs/dev_prod_plan.md, items A and B). What
the rehearsal cannot see is the server's own environment - its real
certificates, its real `.env` - so still watch the `deploy` job and the site
after a release that touches the Caddyfile or coturn.

### 3. One deploy key for both - unlikely, high impact, cheap to fix

**When:** any time, by accident.

**What happens:** the `DEPLOY_SSH_KEY` secret can run all four of
`deploy.sh`'s commands - `web`, `web-dev`, `server` and `server-dev` - and a workflow on any
branch can read it. One careless edit to the dev jobs on `develop` could
deploy to production with no release.

**Fix:** two keys.

- A **dev key** whose `authorized_keys` line gives `deploy.sh` an argument
  that only allows `web-dev` and `server-dev`, stored in the `dev` GitHub
  environment.
- The **production key** as now, moved into the `production` environment,
  with that environment's *Deployment branches* set to `main` only.

About twenty minutes: the server and workflow side, plus a few clicks in
**Settings -> Environments**.

**Do it:** soon - it is the only one of the four with no warning before it
happens.

### 4. Dev and release desktop builds are the same app - FIXED at the start of M2

**When:** as soon as the game writes save data.

**What happens:** to Windows and macOS a dev build IS the game. The dev
installer replaces an installed release instead of sitting beside it, and
both read and write the same `user://` folder - today only `settings.cfg`,
tomorrow a save a dev build may have written in a format the release cannot
read.

**Fixed:** a dev build is "The New Hire (dev)", a different app to both
operating systems. On a deploy to dev, tools/release/prepare.sh renames it in
every field that holds the game's name and gives the macOS bundle id a `.dev`
suffix, and the installer is built with `/DDev`, which gives it an `AppId` of
its own - so it installs beside the game, in its own folder, with its own
Start Menu entry and uninstaller. The name is also what names `user://`
(`app_userdata/The New Hire (dev)` against the game's `app_userdata/The New
Hire`), so its settings, and one day its saves, never meet the game's. And a
dev build never asks GitHub for a newer release: the next dev deploy is its
update.

The dev name REPLACES the packaged one at build time rather than being a
`config/name.dev` override beside it, and that is measured rather than
taste: a build carrying both `packaged` and `dev` matches both overrides, and
Godot 4.7 takes whichever line comes first in the file.

## What will not bite

- **One coturn.** TURN relays bytes and never reads them, so it does not care
  which build it carries. Dev testers share its 40 relay slots, which at this
  scale is nothing.
- **One droplet.** The dev site is static files, and dev's signaling
  container is about 40 MB.
- **One workflow file.** That one is a strength: a dev build is exactly what a
  release would build from the same commit, and every dry run checks both
  paths.
- **Browser data.** `dev.` is a different origin, so the browser already keeps
  the dev site's settings and storage apart from the live game's.
