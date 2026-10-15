---
name: build
description: Build a feature or change end to end on its own branch with tests and a draft PR, then hand off to verify. Use for /fleet-workflows:build, a picked prototype option, or "build this". A repo's own build workflow wins.
argument-hint: "<what to build, or an issue number>"
allowed-tools: Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-repo"), Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-repo" *)
---

# /fleet-workflows:build: a feature, on a branch, ready to verify

Build: **$ARGUMENTS**

Read the shared rules once per session: `${CLAUDE_PLUGIN_ROOT}/skills/fleet-workflows/SKILL.md`.

**Called by `fleet-workflows:loop`** (the input says `from fleet-workflows:loop`): the loop already picked the task and started its voyage. Build it here (§ 1–4) whatever the mode, don't hand off, and return to the loop after the draft PR; it runs verify, review and the user's review next.

## 1. Understand it

- `sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-repo"`: the main branch, the commands, the settings, the repo's instructions. Read the instructions (CLAUDE.md, AGENTS.md, CONTRIBUTING.md) and the docs they point to for what you'll touch.
- An issue number: `gh issue view <n>` (and its comments). A prototype pick: the option's title, summary and pages from `fleet-workflows:prototype` (or `voyage_resume <voyage id>`).
- Read the code you'll change and its tests. **Reuse before you add:** find the existing component, helper or pattern for the job and extend it instead of writing a second one. Delete what your change replaces.
- **A visible choice left open** (a layout, a control, a visual direction) that the user hasn't decided: don't guess. Offer `fleet-workflows:prototype` for it; if the user said to keep going, build your recommendation and say which choice you made.

## 2. Branch

A worktree, never the user's checkout (shared rules § 9):

```sh
git fetch origin
git worktree add --no-track -b <type>/<short-name> ../<repo>-<short-name> origin/<main>
```

Install dependencies there with the repo's install command and work only in that folder. Never switch, stash or reset the checkout you started in. Only with `worktreesOnly: false` in the settings, and a clean tree, may you branch in place (`git switch --no-track -c <branch> origin/<main>`).

On a prototype voyage: `voyage_stage` with `stage: "building"` and a one-line note, so the user sees it moving.

## 3. Build it

- **iPhone or iPad work in an iOS, Expo or React Native repo,** run on its own: hand off to `fleet-workflows:loop ios once <task>` with the branch and the voyage id. It builds, runs on a simulator, smoke tests and puts it up for review. From the loop, build it here.
- **Everything else:** make the change in small, reviewable steps. Match the repo's style, naming and structure. Handle the edge states (empty, loading, error, signed out, offline, long text) the change touches.
- **Tests:** add or extend tests that cover the change: unit tests for logic, the repo's integration or e2e tests for flows. A bug fix gets a test that fails without the fix.
- **Run the gates** from the settings (`gates`), or the repo's documented checks (typecheck, lint, format, test, build). Fix what fails. A failure that also happens on the main branch is pre-existing: note it, don't hide it.
- Look at what you built when it has a UI: a screenshot of the page (`npx playwright screenshot --viewport-size=390,844 <url> <file>` against the local dev server) and read it. Stop the dev server after.

## 4. Push and open a PR

- Commit with clear messages. Check `git rev-parse --abbrev-ref @{u}` isn't the main branch, then `git push -u origin <branch>:<branch>`.
- Open a **draft PR** (`gh pr create --draft`): what changed in plain words, how it was tested, "Decisions I made", and `Fixes #<n>` / `Refs #<n>`.
- On a voyage: `voyage_log` kind `state` with `git` (branch, pr, sha, `pushed: true`).

## Report

Opening lines: what was built (and what wasn't), the branch and PR link, what the gates said. Then the closing sections (shared rules § Reporting).

**Next:** `fleet-workflows:verify` on this branch (call it directly when the user asked to keep going). From `fleet-workflows:loop`: back to the loop. On a prototype voyage, `fleet-workflows:verify` then `voyage_stage` review with screenshots, and wait for the user's green.
