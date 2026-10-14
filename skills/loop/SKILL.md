---
name: loop
description: Fleet's perpetual build loop for a project. Picks the next task (the user's Fleet Inbox and orders, then open GitHub issues, then the roadmap), prototypes it when it's open-ended, then builds, verifies, reviews, puts it up for the user's review in Fleet, ships on their green, and moves to the next task until the user says stop or the queue is empty. Modes ios, web, api, cli and prototype-only (detected from the repo when omitted); a number runs that many tasks at once, each on its own simulator. Use when the user runs /fleet:loop or /fleet:ios-loop, or asks Fleet to keep building through the backlog. Not the built-in /loop interval runner.
argument-hint: "[ios|web|api|cli|prototype-only] [slots, e.g. 2] [task or issue | once <task>] | resume [voyage id] | stop"
allowed-tools: Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-repo"), Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-repo" *), Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-login" check), Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-api" *), Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-join" *)
---

# /fleet:loop: keep building, one task after another

Input: **$ARGUMENTS**

Fleet key: !`sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-login" check`

This session in Fleet: !`sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-join" status "${CLAUDE_SESSION_ID}"`

This repo: !`sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-repo" --short`

Read the shared rules once per session: `${CLAUDE_PLUGIN_ROOT}/skills/fleet-workflows/SKILL.md`.

**The loop is the conductor, not a copy of the other skills.** Each step runs an existing skill with the Skill tool (`fleet:prototype`, `fleet:build`, `fleet:verify`, `fleet:review`, `fleet:ship`), or the repo's own skill for that step when it has one. This file says only what runs when, what to hand forward and when to wait. Every hand-off says `from fleet:loop`, plus the mode, the task, its issue, branch, PR and voyage id, so the skill skips its own waiting and returns here.

**Fast now, near-perfect before it merges.** Before the user sees a task, only the mode's quick check runs (§ Modes): a typecheck, lint on the touched files and a few-minute look at it working. Full coverage and every gate come after the user's green (§ 7–8), so they're never left waiting. Coverage is moved, never skipped.

| Input | What happens |
| --- | --- |
| (nothing) | Detect the mode, pick the next task, run the loop. |
| a mode (`ios`, `web`, `api`, `cli`, `prototype-only`) | That mode instead of the detected one. |
| a number (`2`, `ios 2`) | That many tasks at once (§ Slots). |
| a task or issue number | Start with that one, then carry on with the queue. |
| `once <task>` (how `fleet:build` hands off iPhone work) | Just that task through the loop, then stop and offer to keep going. |
| `resume [voyage id]` | Pick up where a loop stopped (§ 0), this session's or another account's. |
| `stop` (or the user says stop, pause, that's enough) | § Stop. |

## The loop

```
 ┌─▶ 1. pick the next task ─────────── queue empty ───▶ stop
 │        │ open-ended                 (Inbox and orders → issues → roadmap)
 │        ├──────────▶ 2. fleet:prototype ─ waits for the pick ┄┄ (the loop works on other tasks)
 │        │                     │ Build <option>
 │        ▼                     ▼
 │   3. fleet:build ◀───────────┴──────────────────────────────┐
 │        ▼                                                    │
 │   4. fleet:verify   the mode's quick check                  │
 │        ▼                                                    │
 │   5. fleet:review   fresh eyes, fixes on the branch         │
 │        ▼                                                    │
 │   6. up for review in Fleet (voyage_stage review:           │
 │      steps + screenshots or a preview URL) ┄┄ waits ┄┄      │
 │        ▼                                                    │
 │   7. the user's verdict ──── Fix + notes ───────────────────┘ 8.
 │        │ Ship it
 │        ▼
 │      solidify (coverage, every gate) ─▶ fleet:ship
 │        (production: the user's yes, or Ship it when greenShips is true)
 └── 9. next task
```

A task waiting on the user (a pick, a review, a yes) holds no slot and no simulator: the loop starts the next task meanwhile and checks for decisions between steps.

## 0. Start, once per session

1. **Know the repo:** `sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-repo"` and its settings (shared rules § The repo). **The repo's own loop wins:** if its skills include its own `loop` (or `ios-loop` in ios mode), run that one with the same input, say so in one line, and stop here. Its own `verify`, `review`, `deploy`, `prototype`… replace Fleet's at their step the same way.
2. **The mode:** the argument, else `loop.mode` in the settings, else detect it:
   - `ios`: `ios.kind` isn't `none`, or an Expo/React Native app config, an `ios/` folder or an `.xcodeproj`/`.xcworkspace`.
   - `web`: a web app or site: a `dev` or `start` script serving pages, a web framework config (Next, Vite, Astro, Remix, Rails views…), or `previewUrl`.
   - `api`: a server with no pages of its own (routes, a Worker, a backend).
   - `cli`: a command-line tool (`bin` in package.json, a Cargo or Go binary, a `console_scripts` entry).
   - Nothing fits: ask once which mode.
   The mode sets the default check. A task that only touches another part (server code in an iOS app) uses that part's check for its verify step.
3. **Confirm once,** in one short block, then save to `.fleet/workflow.json`: the mode, where tasks come from (`issues.labels`, `issues.milestone`, `roadmap`), the slots, and how shipping works (`greenShips`). For example: "Mode: ios · Tasks: issues labeled `ready`, then ROADMAP.md · 1 slot · Production asks you each time. Right?"
4. **The loop's journal** is this session's voyage (the line above: `voyage: v…`). After each move, `voyage_log` it with `kind: "state"`, one line for the whole loop: `#12 Dark mode: waiting for your review · #14 Search: building (slot B) · 3 queued`. On stop, a `handoff` entry (§ Stop). No session voyage (no key, or hooks off): keep the same lines in chat.
5. **Resume:** in-flight work goes before anything new. `voyage_list`: this repo's open voyages (and, with `resume <voyage id>`, `voyage_resume` that one for its last handoff and children). For each task voyage, `voyage_resume` and do its `nextStep`: a pick made → build, Fix → build with the notes, Ship it → solidify and ship, still waiting → leave it waiting. Check against reality (`gh pr list --state open`, `git ls-remote`) and fix what's stale in the journal.
6. **Slots:** one, unless the input or `loop.slots` says more (§ Slots).

## 1. Pick the next task

Take the first that fits, in this order:

1. **Named in the input** (a task or an issue number).
2. **The user's Fleet:** decisions that came back on this repo's voyages (§ 0 step 5), then `orders` with this repo: issues the user marked to sail. Taking one: `voyage_start` with `repo` and `issue`.
3. **Open GitHub issues:** `gh issue list --state open --label <issues.labels> [--milestone <issues.milestone>] --json number,title,labels,assignees,updatedAt` (with no labels saved, the open issues the repo treats as ready: a `ready`/`next`/`roadmap` label, a milestone, or the user's own). Skip issues with an open PR (`gh pr list --search "<n> in:body"`), assigned to someone else, labeled blocked or waiting, or already on an open voyage.
4. **The roadmap:** `roadmap` in the settings (a file such as `ROADMAP.md` or an epic issue's checklist). Open the issue first (`fleet:idea` turns a roadmap line into one) so every task has an issue.
5. **Nothing left:** the queue is empty. Wait for the decisions still out (§ 7–8), then stop (§ Stop).

How to choose within a source: **the most visible payoff for the least time**, the user's priorities first (labels, milestone, order on the roadmap). Slice a big task so its first slice reaches the user's review within the hour. A task that needs something only the user can give (credentials, money, a product call that's expensive to undo) isn't picked: ask once with a `voyage_log` `question` and move on.

Then: say what you picked and why in one line, comment on its issue (`Picked up by the Fleet loop`), and give it a **task voyage**: `voyage_start` with `course: "prototype"`, `repo`, `issue` (or `goal`), `parent_voyage_id` = the session voyage, `crew` = its slot (`slot-a`), and `op_id` `loop-<issue>-start`. Every round of that task lives on it, so it shows in the user's Inbox, Sessions and Prototypes, and anyone can `voyage_resume` it.

## 2. Open-ended? Prototype first

A task is open-ended when it leaves a visible choice undecided: a layout, a control, motion, a visual direction, or the issue says "prototype". Run `fleet:prototype` on the task's voyage (`from fleet:loop`: it publishes the options and returns without waiting). The task now waits for the pick; go to § 9 for another task. When the pick comes back:

- **Build `<option>`:** § 3 with the option's title, summary and media.
- **Another round (notes):** `fleet:prototype` again on the same voyage.
- **Tuck away:** comment on the issue, close nothing else, next task.

In `ios` mode a choice of **feel** (gesture, motion, timing) can't be judged in a browser: build two or three variants behind a flag instead and let the user switch them in review; delete the losers after the pick.

## 3. Build

`fleet:build` with the task, the issue, the voyage id, the mode and `from fleet:loop` (it builds on its own branch and opens a draft PR, and returns here instead of handing off). `voyage_stage` `building` with a one-line note. Tests that would hold up the user's review can wait; they're owed in § 7–8.

## 4. Verify, with the mode's check

`fleet:verify <branch> from fleet:loop <mode>`: the quick check in § Modes, with evidence (screenshots, command output). A failure caused by the change goes back to § 3 on the same branch. After three failed rounds, park the task: `voyage_log` a `blocker` with what fails, comment on the issue, next task.

## 5. Review

`fleet:review <PR> from fleet:loop`: an independent reviewer (a fresh subagent, since the loop wrote the change), must-fix and should-fix fixed on the branch. Fixes that change behavior go back through § 4.

## 6. Up for the user's review

1. The branch is pushed, the PR is a draft, and the tree is clean.
2. **Test steps:** 3 to 6, one action each, starting with where (`Settings → tap Notifications`), each followed by what they should see on its own `> ` line in the words on screen, never code names. End with one `Green:` line: the bar, in one sentence. In `api`/`cli` mode the steps are commands and their expected output.
3. `voyage_stage` with `stage: "review"`, `git` (branch, PR, sha, `pushed: true`), `note` = the steps plus what the check couldn't show, and `media` from the mode (§ Modes): up to 6 screenshots, or a preview URL. **Release every lease right after** (captures are copied); the next round leases again.
4. **A preview the user can hold** (`commands.deployPreview`: a preview deploy, an over-the-air update to a preview channel): publish it from a clean, pushed tree as the repo's rules say. When the repo says nothing, ask once whether previews need a yes, and save the answer. Never production.
5. Tell the user in a few lines: the review link (`https://fleet.osroc.io/app/voyages/<voyage id>`), the steps, branch · sha, the preview if any. Then don't wait: § 9.

Without a Fleet key: the screenshots' paths and the steps in chat; ask for green or red.

## 7–8. The verdict: ship on green, fix on notes

Between steps, check every task that's waiting with `await_decision` and `wait_seconds: 0`. When nothing else can move (no slot free, or no task left to start), block on the oldest with `wait_seconds: 600`; after three `still waiting` in a row, stop (§ Stop: it's in the user's Inbox). Never decide for the user, and never treat silence as a yes.

- **Ship it** (or green in chat): the change is right. **Solidify** it, off the user's clock (in a background agent when other work is running): merge the main branch in, cover it (unit tests for the logic, the repo's flow tests for the changed flow, a regression test for every Fix note on the issue), delete leftovers (losing variants, flags, scratch), and run every gate. Then the full `fleet:verify`, `fleet:review` on what solidifying changed, and `fleet:ship`. **The yes:** with `greenShips: true` in the settings, Ship it is the yes for production, and `fleet:ship` goes ahead. Otherwise `fleet:ship` asks once in chat; ask for several ready tasks in one line, and keep looping while the user decides.
- **Fix (notes)** (or red in chat): write the notes on the issue or PR (they become regression tests in solidify), then back to § 3 on the same branch and voyage. One round per review, minutes not hours.
- **Tuck away:** leave the PR as a draft, comment on the issue, next task.

Record taste the user states ("less bouncy", "too busy") in the repo's design doc on the branch.

## 9. Next task

Back to § 1. Keep going without asking "want me to…?" for a loop step: ask only for what the user alone can decide. Don't let reviews pile up: with `loop.maxWaiting` tasks (default 3) waiting on the user, stop starting new ones and work on what's already decided, or wait (§ 7–8).

## Modes

| Mode | Verify (§ 4), before the user looks | Up for review (§ 6) |
| --- | --- | --- |
| `ios` | Typecheck, lint on touched files, then a smoke test on a leased simulator berth: install, tap through the happy path and the states it touches, screenshot each step. | `capture_lease_id` screenshots from the berth (or uploaded ones), the steps; a phone preview when the repo has one. |
| `web` | Typecheck, lint on touched files, the e2e tests for the changed flow, then a look: the dev server or preview URL with `npx playwright screenshot` at 390 px (and 1280 px when desktop matters) for each changed screen, read each one. | Uploaded screenshots (`upload_url`, `blob_key`) and the preview URL as `url`. |
| `api` | The tests for what changed, then `curl` the changed endpoints on the local server or preview with the inputs the change cares about, reading status and body. | The commands and their output in the note (an uploaded self-contained HTML transcript for long ones); the preview URL if there is one. |
| `cli` | The tests for what changed, then run the changed commands as a user would (help text, the happy path, bad input, exit codes). | The same as `api`: commands and output. |
| `prototype-only` | None: no building. | `fleet:prototype` rounds only. |

### ios

Read `${CLAUDE_PLUGIN_ROOT}/skills/loop/ios.md` once, at the start: the repo's iOS setup, leasing a berth, putting the app on it (a Release build, or the dev client with Metro through a tunnel), the smoke test, the release replica, what the simulator can't show, local simulator limits and cleanup. § 4 and § 6 above follow it.

### web

- One dev server per slot, on the slot's port (§ Slots), stopped when its check is done. A preview URL beats a local server: use `previewUrl` or the branch's preview deploy when the repo makes one.
- Check every variant the change touches (states, breakpoints, light and dark), not a sample.
- iPhone Safari matters? Look on a berth too (`open_url` with the preview URL; a berth can't reach this Mac's `localhost`).

### api and cli

- Never call production in the check, and never write data anywhere but a local or preview environment.
- A server change that a client needs deploys to the preview first, when the repo has one, as the repo's rules say.

### prototype-only

Rounds of options and no code. Each task goes through § 1 and § 2 only. On **Build `<option>`**, record the pick on the issue (a comment with the option, its summary and the voyage link) and `voyage_log` a `handoff` on the task voyage ("Picked B; build it with `/fleet:loop <issue>`"), then leave the voyage open for a later build loop to resume. **Another round** and **Tuck away** work as in § 2. Several rounds can be out at once, up to `loop.maxWaiting`.

## Slots: several tasks at once (`/fleet:loop 2`)

The main session is the conductor: it picks, briefs, stages reviews, reads verdicts, solidifies and ships. Slot agents build and verify.

1. **How many:** the number asked, capped by what's free. With a Fleet key, `fleet_status`: count online Macs' free (`ashore`) berths of the mode's device, and each Mac's `host.capacity.canBoot` where it's reported (how many more it can boot right now). Never lease more than that, and never more than the repo's own agent limit (its CLAUDE.md or docs). Locally: at most 3 booted simulators and one heavy job (a full test suite, a Release build) at a time. Fewer than asked: say so in one line and run with fewer.
2. **Tasks that don't collide:** different screens, components or modules, so the branches merge cleanly. Say which and why in one line.
3. **One background agent per slot** (`Agent`, `isolation: "worktree"`), briefed with: the task, issue, branch and task voyage id; the area it owns and the one it must not touch; its slot letter and ports (A: 8082 and 8810, B: 8083 and 8820, C: 8084 and 8830; a taken port means something wasn't shut down: report it, don't hunt for another); "read `${CLAUDE_PLUGIN_ROOT}/skills/loop/SKILL.md` § 3–4 and the mode's notes, and run `fleet:build` and `fleet:verify` `from fleet:loop <mode>`; lease your own berth on your task voyage"; "don't stage reviews, publish previews, merge or deploy"; "stop everything you started and release your lease before reporting; report branch, sha, voyage id, what changed in plain words, the test steps in § 6's format and the screenshots' blob keys or paths". Long commands run once in the background with a completion notice: no polling loops.
4. **While they work,** the conductor reads each report, glances at the diff (did it stay in its area?), runs § 5 and § 6 for it, and passes verdicts back to the right agent (`SendMessage`), or fixes a one-liner itself. Each task ships from its own branch.
5. **One preview, several tasks:** when the preview holds one build at a time (one preview channel, one staging), merge the ready branches into `loop/review` off the main branch (merge, never rebase; resolve conflicts yourself), push it, publish that, and stage each task's review with the same preview. Don't wait for the slower slot: publish the first alone, then again with both. Tasks never ship from `loop/review`.
6. **Keep slots full:** when one frees up (its task is waiting on the user, or shipped), pick the next task and brief a new agent. Ask a long-running agent for a three-line status at about 20 minutes, and stop it if it's stuck.
7. **Worktrees:** remove an agent's worktree once its branch is pushed (`git -C <wt> log HEAD --not --remotes` prints nothing): `git worktree remove --force <wt>`.

## Stop

The user says stop (or pause, or that's enough), or the queue is empty and nothing is waiting:

1. **Finish or park the current step cleanly.** A step that ends in minutes (a push, a staged review) finishes. Anything longer parks: commit work in progress on its branch (`wip:` message), push it, and `voyage_log` a `handoff` on its task voyage (what's done, what's next, the branch and sha). Slot agents get the same order through `SendMessage`; wait for their reports.
2. **Release and stop everything:** every `lease` released, every dev server, Metro, tunnel and background shell stopped, local simulators you booted shut down, agent worktrees whose work is pushed removed. Check (`xcrun simctl list devices booted`, `lsof -iTCP -sTCP:LISTEN -n -P` for the slots' ports) and say what's still running and why (rarely anything).
3. **Journal:** a `handoff` on the session voyage: each task and where it stands (shipped, waiting for a verdict, parked on a branch), and the line that resumes it: `/fleet:loop resume <session voyage id>`.
4. **Summary,** short: shipped (PR, sha), waiting on the user (with links), parked (branch), next in the queue.

## Before every report

- The journal and the task issues match what's true right now.
- Stop what you started (shared rules § 4): simulators stay booted and dev servers up only while a task is building or about to; when the loop is idle they go down.
- End with what's **waiting on the user**, one line each with its link: picks, reviews, yeses to ship. "Nothing" when nothing is.

**Next:** the loop itself; it ends on stop or an empty queue.
