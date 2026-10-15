---
name: ship
description: Merge a reviewed PR and deploy to production with the repo's documented deploy command, only after the user's explicit yes, then verify and close issues. Use for /fleet-workflows:ship or "ship it". A repo's own deploy skill wins.
argument-hint: "<PR number or branch>"
allowed-tools: Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-repo"), Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-repo" *)
---

# /fleet-workflows:ship: merge and deploy, with the user's yes

Shipping: **$ARGUMENTS**

Read the shared rules once per session: `${CLAUDE_PLUGIN_ROOT}/skills/fleet-workflows/SKILL.md`.

## 1. The yes

Production needs the user's explicit yes for **this** change. It counts when:

- the user typed `/fleet-workflows:ship` themselves (this turn), or said "ship it", "deploy it" or "yes" in chat to this specific PR; or
- the user pressed **Ship it** on its Fleet review and the settings have `greenShips: true`.

Otherwise ask one question and stop: "Ship #<n> (<title>) to production with `<deploy command>`?" Never treat silence, passing tests or a review as a yes.

## 2. How this repo deploys (asked once)

`sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-repo"`. If the settings have `commands.deploy` (or `"deploy": "merge"` for repos whose CI deploys on merge), use it. If not, find the documented way: the repo's docs (README, CLAUDE.md, docs/deploy*), a `deploy` script in package.json or the Makefile, its CI workflows (a deploy job on push to main means merging deploys), and the tooling config (wrangler, fly, vercel, netlify, firebase, eas). Show the user what you found in one line, ask them to confirm, and save it to `.fleet/workflow.json` (with `productionUrl` and `healthUrl` if you found them). Ask this together with the yes in § 1: one question, not two.

**More than one thing to release** (a server and an over-the-air mobile update, a web app and an API): save them as `ship.targets`, in the order they go, server before the client that calls it. Each is `{ "name", "command", "check", "overTheAir" }`: `check` (a `curl` of the health route, the provider's list showing the sha) must pass before the next target starts; `overTheAir: true` marks a target that publishes an update to installed apps. `commands.deploy` stays the shorthand for one target. While you're reading the docs, note the guards they describe (a command that checks which host a bundle calls, a fingerprint or runtime-version compare, a changelog file) and offer them in the same block as `ship.environmentCheck`, `ship.nativeCheck` and `ship.changelog` (shared rules § The repo).

Never guess a deploy command and run it.

## 3. Ready?

- The PR passed `fleet-workflows:verify` and `fleet-workflows:review` (or the repo's own). If not, run them first.
- **Latest main first:** `git fetch origin`, merge `origin/<main>` into the branch; if it moved, rerun the gates on the merged branch and push.
- Every gate in the settings passes on the branch. No migration edits one that already shipped.
- For iOS changes: they ran on a simulator (`fleet-workflows:loop ios`), the whole changed path tapped through, before production.
- **The changelog** (`ship.changelog`): a change people can see gets an entry in `ship.changelog.path`, at the top, dated today, in plain words they'd be glad to read (what they can now do, never code or design terms, never "fixed a bug in…"). Internal changes (tests, CI, docs, plumbing) get none. A new screen, flow, gesture or control also gets its short clip when `ship.changelog.clip` is set (the path it goes to): recorded from this branch's build the repo's documented way, showing only that feature. Add them on the branch before merging.
- **The native boundary** (`ship.nativeCheck`, when any target is `overTheAir`): run it on the branch, current with main. It exits non-zero when the change can't reach installed apps over the air (a native module, a config plugin, an icon, a permission). Then nothing goes over the air for this change: say why in one line and ask one question: "#<n> needs a new store build (<why>). Merging it holds over-the-air updates for later changes until that build is installed. Merge, ship the other targets, and start the store build (`commands.storeBuild`)?" A store build reaches every tester, so it needs this yes even with `greenShips`. From `fleet-workflows:loop`: ask it as a `voyage_log` `question` on the task voyage and return; the loop keeps working on tasks that can ship.

## 4. Merge, then deploy

```sh
gh pr ready <n>                                   # if it's a draft
gh pr merge <n> --merge --delete-branch           # the repo's merge style if it has one (--squash, --rebase)
```

- **CI deploys on merge:** watch it (`gh run watch` on the deploy run) and read the result.
- **A deploy command:** run it from a clean checkout of the merged main, never from a feature branch or a dirty tree:
  ```sh
  git fetch origin
  git worktree add --detach <scratch>/deploy origin/<main>
  cd <scratch>/deploy && git status --short     # must be empty
  <install command> && <deploy command>
  ```
  Remove the worktree afterwards (`git worktree remove <scratch>/deploy`).
- **Several targets** (`ship.targets`): every one from that same clean worktree, so all platforms ship the same code, in order. After each, run its `check` and read the result; a failed command or check stops the rest (the targets already out stay, and the report says which didn't go). Skip the `overTheAir` targets when the native check failed (§ 3).
- **The environment guard** (`ship.environmentCheck`): run it in the deploy worktree with `production` as its argument after each `overTheAir` target, else after the last target (or the single deploy). It proves what was just built calls production and not a preview or staging host (e.g. `grep -a -c` for each host in the exported bundle). When the repo can build without publishing, run it before the publish too. Failed: stop the remaining targets, run `commands.restoreProduction` at once when it's set (republishing the last good update), and tell the user first in the report.
- **Mobile releases** (a store build, an over-the-air update to production) follow the repo's docs the same way, from main, with the same yes; a store build after a native-check failure needs its own yes (§ 3).
- Never push to main directly, never force-push, and never skip hooks or checks to get a deploy through.

If the deploy fails, nothing shipped (or only the targets before it): read the log, say so plainly, fix forward on a branch. **Broken in production after a deploy that succeeded: fix forward** on a branch through the same chain, never roll back or revert main. The one exception is a build pointing at the wrong environment: `commands.restoreProduction` puts the last good one back when the repo documents it.

## 5. Verify and close out

- `fleet-workflows:verify production`, every time.
- Close the issues it finishes ("Shipped in #<n>, `<sha>`").
- On a Fleet voyage still open (no Ship it on the dashboard): `voyage_close` with a one-line summary and `outcome: "built"`.

## Report

`Production = <sha> (#<n>)`, and with `ship.targets` one line per target: `<name> = <sha or id>` (the update or build id for a mobile target, or why it didn't go: native check, a failed check). Then what shipped in plain words, the changelog entry if one was added, the verify result, then the links (production URL for each change, the PR).

**Next:** nothing; it's shipped. If production verify fails → `fleet-workflows:triage`.
