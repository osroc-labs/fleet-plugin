---
name: ship
description: Merge a reviewed PR and deploy it to production with the repo's own documented deploy command, only after the user's explicit yes, then verify production and close the issues. The deploy command is asked once and saved in .fleet/workflow.json. Use when the user runs /fleet:ship or says to ship, merge and deploy, or release a specific change. If the repo has its own deploy skill, use that instead.
argument-hint: "<PR number or branch>"
allowed-tools: Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-repo"), Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-repo" *)
---

# /fleet:ship: merge and deploy, with the user's yes

Shipping: **$ARGUMENTS**

Read the shared rules once per session: `${CLAUDE_PLUGIN_ROOT}/skills/fleet-workflows/SKILL.md`.

## 1. The yes

Production needs the user's explicit yes for **this** change. It counts when:

- the user typed `/fleet:ship` themselves (this turn), or said "ship it", "deploy it" or "yes" in chat to this specific PR; or
- the user pressed **Ship it** on its Fleet review and the settings have `greenShips: true`.

Otherwise ask one question and stop: "Ship #<n> (<title>) to production with `<deploy command>`?" Never treat silence, passing tests or a review as a yes.

## 2. How this repo deploys (asked once)

`sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-repo"`. If the settings have `commands.deploy` (or `"deploy": "merge"` for repos whose CI deploys on merge), use it. If not, find the documented way: the repo's docs (README, CLAUDE.md, docs/deploy*), a `deploy` script in package.json or the Makefile, its CI workflows (a deploy job on push to main means merging deploys), and the tooling config (wrangler, fly, vercel, netlify, firebase, eas). Show the user what you found in one line, ask them to confirm, and save it to `.fleet/workflow.json` (with `productionUrl` and `healthUrl` if you found them). Ask this together with the yes in § 1: one question, not two.

Never guess a deploy command and run it.

## 3. Ready?

- The PR passed `fleet:verify` and `fleet:review` (or the repo's own). If not, run them first.
- **Latest main first:** `git fetch origin`, merge `origin/<main>` into the branch; if it moved, rerun the gates on the merged branch and push.
- Every gate in the settings passes on the branch. No migration edits one that already shipped.
- For iOS changes: they ran on a simulator (`fleet:loop ios`), the whole changed path tapped through, before production.

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
- **Mobile releases** (a store build, an over-the-air update to production) follow the repo's docs the same way, from main, with the same yes.
- Never push to main directly, never force-push, and never skip hooks or checks to get a deploy through.

If the deploy fails, nothing shipped: read the log, say so plainly, fix forward on a branch.

## 5. Verify and close out

- `fleet:verify production`, every time.
- Close the issues it finishes ("Shipped in #<n>, `<sha>`").
- On a Fleet voyage still open (no Ship it on the dashboard): `voyage_close` with a one-line summary and `outcome: "built"`.

## Report

`Production = <sha> (#<n>)`, what shipped in plain words, the verify result, then the links (production URL for each change, the PR).

**Next:** nothing; it's shipped. If production verify fails → `fleet:triage`.
