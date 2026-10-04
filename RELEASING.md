# Branches, versions and releases

## The two branches

- **`develop`** is where work happens. Commit and push here day to day.
- **`main`** gets a feature when it is finished: merge `develop` into it.

```sh
git switch main
git pull
git merge develop
git push
git switch develop
```

You can merge into `main` as often as you like. A merge is not a release.

## What a release is

A release is **the `VERSION` file changing on `main`**, and nothing else.
When a push to `main` changes `VERSION`, `.github/workflows/release.yml`:

1. checks the number,
2. builds the game for Windows, macOS and the web, and tests the server's
   signaling service,
3. tags that commit `v<number>` (for example `v0.2.0`),
4. publishes it on the repository's **Releases** page with the Windows and
   macOS builds attached, and every commit since the previous release as the
   notes,
5. **deploys** it: brings the server's stack up to this commit, then puts the
   web build live at https://za-company.mayar-deeb.dev.

Nothing is published unless every build succeeds, so a release is never
missing a platform, and the site is never a version nobody can download.
Pushes that leave `VERSION` alone never trigger it.

## What a release contains

| File | For |
|---|---|
| `TheNewHire-0.2.0-windows-setup.exe` | Windows installer: Start Menu entry, optional desktop icon, uninstaller. Installs for the current user with no administrator prompt. A new version upgrades the old one in place. |
| `TheNewHire-0.2.0-windows-portable.zip` | The same game with nothing to install: unzip and run `TheNewHire.exe`. |
| `TheNewHire-0.2.0-macos.dmg` | macOS disk image: open it and drag the game to Applications. One build for Intel and Apple Silicon. |

The web build is not attached. It goes to the server instead (see
*Deploying*), so the site is always the latest release.

**The builds are not signed yet**, so both systems warn the first time the
game is opened. The release notes tell players what to click:

- **Windows** shows *Windows protected your PC*: **More info**, then
  **Run anyway**.
- **macOS** refuses to open it: **System Settings -> Privacy & Security**,
  then **Open Anyway**.

An installed game also checks GitHub for a newer release when its main menu
opens, and if there is one, shows *v0.3.0 IS OUT - GET IT* in the corner. That
button opens the release page. The check never runs in the editor, in the
test suites or in the web build (`ui/update/release_check.gd`).

**An in-game updater is being built, and is switched off.** When it is on,
the button reads *UPDATE* and the game downloads, checks and installs the new
version itself. Until it has passed its test on both Windows and a Mac
(`todo.md`), every copy keeps the link above. Each release already publishes
the `SHA256SUMS.txt` it will check downloads against.

## Making a release

1. Change the number in `VERSION`. You can do this on `develop` and merge it,
   or commit it straight on `main`.
2. Push `main`.
3. The **Actions** tab shows the run. The builds take several minutes (the
   first run longer, while it downloads Godot), and then the release appears
   under **Releases**.

The number is `MAJOR.MINOR.PATCH`, written without a `v`:

| Change | Example |
|---|---|
| a fix, nothing new | `0.1.0` -> `0.1.1` |
| a new feature or floor | `0.1.1` -> `0.2.0` |
| the finished game, or anything that breaks old saves | `0.9.0` -> `1.0.0` |
| a test build ahead of a release | `1.0.0-beta.1` (marked *pre-release*) |

The workflow refuses a number lower than the latest release, because that is
a typo rather than a release. Re-using a number that is already released does
nothing.

## Deploying

The `deploy` job runs only for a real release, after the Release is up. In
this order, because the game and signaling change together and a new game must
never meet an old server:

1. **The server**: the repository's `server/` folder replaces the one on the
   droplet (its `.env` and the web build are kept), and `docker compose`
   rebuilds what changed. A run with no server changes restarts nothing.
2. **The game**: the web build is streamed in beside the live one and swapped
   in by rename, so a player loading the page mid-deploy gets one whole
   version or the other.
3. **The check**: the site's page must be the one just built, and the
   signaling service must answer.

It logs in with a key of its own, held in the repository secret
`DEPLOY_SSH_KEY`. On the server that key can do nothing but run
`server/deploy.sh` (installed as `/usr/local/sbin/za-deploy`), which takes
`server` or `web` and a tar of it: no shell, no other command, no tunnels. A
leaked key could put up something this repository would have shipped anyway,
and nothing more.

Before any of that, the `server` job has already **rehearsed the deploy** on
GitHub's own throwaway machine: the previous release's `deploy.sh` deploying
this release's server files at the server's real paths, then the new script
deploying them again, then a deploy to dev and the web builds, each checked
through Caddy (`tools/release/rehearse_deploy.sh`). If the rehearsal fails,
nothing is published and the server is not touched. The same checks run on
every push that touches `server/` (`.github/workflows/server.yml`, a few
minutes, no game builds), so a broken server change is usually caught long
before a release meets it. server/README.md's *How
a release updates this script* says why the previous release's script is the
one that matters.

### Setting it up (once)

The key already exists and the server already accepts it; GitHub only needs
the private half.

1. Open `C:\Users\chrol\.ssh\za_company_deploy` in a text editor and copy
   ALL of it, including the `-----BEGIN` and `-----END` lines.
2. On GitHub: the repository's **Settings -> Secrets and variables -> Actions
   -> New repository secret**. Name it `DEPLOY_SSH_KEY`, paste, **Add secret**.
3. Delete the file, and its `.pub` beside it. GitHub now holds the only copy,
   and nobody needs it again: a lost key is replaced, never recovered.

Until the secret exists, a release still publishes and then the deploy job
fails with a message saying the secret is missing. Add it and use *Re-run
failed jobs* on that run: it deploys the files that run built, for 30 days.

### Replacing the key

If the key may have leaked, or to rotate it:

```sh
ssh-keygen -t ed25519 -N "" -C "za-company release pipeline" -f za_company_deploy
```

On the server, replace the line ending in `za-company release pipeline` in
`/root/.ssh/authorized_keys` with
`restrict,command="/usr/local/sbin/za-deploy" ` followed by the new `.pub`.
Then put the new private key in the `DEPLOY_SSH_KEY` secret and delete both
files.

### If the server is rebuilt

A rebuilt droplet has a new SSH host key, and the deploy refuses it on
purpose: the key it trusts is pinned in `tools/release/known_hosts`. Replace
that line with the new server's `/etc/ssh/ssh_host_ed25519_key.pub`, prepare
the server as `server/README.md` describes, and install the deploy key again.

## Trying a build without releasing

A push to `develop` that changes what the builds are made of
(`export_presets.cfg`, the workflow, or anything in `tools/release/`) runs
the whole build as a **dry run**: Windows, macOS, web and the server's
checks. It publishes and deploys nothing, and keeps the files on the run's
page in the Actions tab for a week. **Actions -> Release -> Run
workflow** on `develop` does the same on demand.

## Deploying to dev

To try `develop` without a release - or hand it to a tester - deploy it to
dev: **Actions -> Release -> Run workflow**, branch `develop`, tick **Deploy
to dev**, **Run workflow**. It never runs on its own, because `develop` takes
many half-finished pushes and a dev site that changes under every one of them
is a dev site nobody can test.

The same four builds run and gate it exactly as they gate a release, and then:

| What | Where |
|---|---|
| Dev's own signaling service, built from `develop` | behind https://dev.za-company.mayar-deeb.dev |
| The web build | https://dev.za-company.mayar-deeb.dev |
| Windows installer, portable zip, macOS disk image | the **`dev` pre-release** on the Releases page |

Every build in a deploy to dev carries the custom feature `dev`, which is how a
dev desktop build knows to talk to dev's signaling rather than the live one.

A dev desktop build is also a DIFFERENT APP from the game: "The New Hire
(dev)", with its own installer `AppId` and macOS bundle id, so it installs
beside the game rather than over it, keeps its settings in a folder of its
own, and never offers to update itself to a release. A tester can have both.
`tools/release/prepare.sh` does the renaming and `installer.iss` takes `/DDev`
(`docs/environments.md`, #4).

The pre-release is ONE release that each dev deploy replaces, so its links
never change: `https://github.com/mayar4ki/za-company/releases/download/dev/TheNewHire-dev-windows-setup.exe`,
`.../TheNewHire-dev-windows-portable.zip` and `.../TheNewHire-dev-macos.dmg`
always fetch the newest dev build, with no GitHub account needed. Its notes
say which commit it is. It is marked *Pre-release* and never *latest*, which
is the whole of what keeps it away from players: the Releases page's "latest",
its download links and the game's own update check all skip it.

What a dev deploy never touches: the live site, its signaling, Caddy, coturn
and `VERSION`. What dev and production still SHARE - the server, Caddy and
coturn, the deploy key - and when each of those will need splitting is
`docs/environments.md`. The dev site has its own signaling
(`deploy.sh server-dev`, server/README.md's *Dev's signaling*), carries a
`noindex` header so search engines leave it alone, and is otherwise the live
site in a folder of its own on the same server (`deploy.sh web-dev`).

A change to the Caddyfile, the compose file or coturn's flags can NOT be tried
on dev: there is one of each and they are the release's. A deploy to dev tries
a signaling change; the release's `server` job checks the Caddyfile with Caddy
itself and the compose file with Compose.

Ticking the box on `main` is refused: there, a release is a `VERSION` change.
And the workflow runs only from `main` or `develop`: a tag or any other branch
is refused, box or not, because a deploy to dev from one would put that old
code on the dev site. GitHub still LISTS every branch and tag under "Use
workflow from" and shows the box on all of them - neither can be hidden - so
the refusal is the workflow's first job saying no within seconds. Keep the
repository to the two branches and the list stays short.

**A step a deploy to dev needs arrives with a release.** The dev site, its
signaling and the steps that fill them live in the server's own files (the
Caddyfile and `deploy.sh`), and those reach the server only with a release,
like everything else of the server's. A dev deploy run before then builds and
publishes the pre-release, and stops at the step the server does not know yet
with "expected 'web', 'web-dev', ...". `server-dev` arrived after v0.1.1. A
release that changes `deploy.sh` itself takes effect in that release - the
script hands the deploy to its new copy (server/README.md, *How a release
updates this script*). The hand-off itself starts working one release after
the release that ships it, because that release is still deployed by
v0.1.2's script, which has never heard of it.

## If something goes wrong

- **The run failed**: open it in the Actions tab. The error at the top of the
  run names the problem (the format of `VERSION`, or the Godot error that
  stopped an export). Fix it and push again.
- **Run it again by hand**: Actions -> Release -> *Run workflow* on `main`.
  If the version is already released, it stops without doing anything.
- **Only the deploy failed**: the Release is out and the site is still on the
  previous version. Open the run, fix the cause (the message names it: the
  secret, the host key, or the server), then *Re-run failed jobs*.
- **Undo a release**: delete it on the Releases page, then delete its tag
  (`git push origin :refs/tags/v0.2.0`).

## Later: signing

Signing removes both warnings above. It is a later change to the presets and
the workflow, and each platform needs its own certificate, kept as a
repository secret:

- **macOS**: an Apple Developer Program membership ($99 a year) gives a
  *Developer ID Application* certificate. With it, the export signs and
  notarizes the app, and macOS opens it without asking.
- **Windows**: a code-signing certificate from a certificate authority, or
  Microsoft's Azure Trusted Signing. Both are paid subscriptions.

Until then the warnings are a click, not a wall. Testers can live with that;
a public launch should not.
