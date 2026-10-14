---
name: fleet-workflows
description: Shared rules, the chain and the per-repo settings file (.fleet/workflow.json) for Fleet's workflow skills (fleet:loop, idea, prototype, build, verify, review, ship, triage). Load it only while running one of those skills; it does nothing on its own.
user-invocable: false
---

# How the Fleet workflows fit together

Fleet's workflows are the chain that ships a change: **idea → prototype → build → verify → review → ship**, with **triage** as the way in when something is broken. Each one is a skill you can run on its own (`/fleet:<name>`), and each one ends by naming the next. **`fleet:loop` conducts them**: it picks task after task and runs the chain for each, in a mode that fits the project (`ios`, `web`, `api`, `cli`, `prototype-only`); `/fleet:ios-loop` is `/fleet:loop ios`.

```
  fleet:loop: the conductor, task after task, until the user says stop or the queue is empty

  pick a task ─▶ prototype? ─▶ build ─▶ verify ─▶ review ─▶ the user's review ── Fix ─▶ build
  (Inbox, orders,  (open-ended:         (the mode's                │ Ship it
   issues, roadmap)  wait for the pick)   quick check)             ▼
       ▲                                         solidify ─▶ ship (the yes, or greenShips)
       └──────────────────────── next task ◀───────────────────────┘

            fleet:idea ──────────────┐
          (brain dump → issues)      │ clear enough to build
                 │ open-ended        │
                 ▼                   ▼
          fleet:prototype ──pick──▶ fleet:build
          ▲     │    (options,         │
          └─────┘     the pick)        ▼
       another round            fleet:verify
                                       │ pass
   fleet:triage ── fix ───────────────▶│
  ("it's broken")                      ▼
                                fleet:review ── fixes on the branch
                                       │ clean
                                       ▼
                                fleet:ship ── the user's yes ──▶ production ──▶ fleet:verify (production)
```

## Chaining

- Every skill ends with a **Next:** line naming the next skill and why, in one sentence.
- If the user already said to keep going ("build it and ship it", "take it all the way"), call the next skill directly with the Skill tool instead of stopping. Otherwise stop and offer it.
- **Called by `fleet:loop`** (the input says `from fleet:loop`): do the step, skip your own waiting (the loop checks decisions between tasks) and your own hand-off, and return to the loop with what it needs: branch, sha, PR, voyage id, evidence.
- Hand context forward explicitly: the branch, the PR, the issue, the Fleet voyage id (if there is one) and the settings below. Never make the next step rediscover them.
- **The repo's own skills come first.** `fleet-repo` (below) lists the repo's `.claude/skills` and `.claude/commands`, and the settings' `skills` map. For a step, use `skills[step]` when it's set, else the repo's same-named skill (its own `verify`, `deploy`, `review`, `prototype`…), and say so in one line. Fleet's skills are the fallback, not a replacement. Called `from fleet:loop`, the repo's skill does one task's step and returns; the loop itself (queue, lanes, Inbox) always stays in `fleet:loop`.
- **The repo's `rules`** (settings) are followed by every workflow, like its CLAUDE.md.

## Rules for every workflow

1. **Verify before claiming.** Never say something works, passes or is fixed until you ran the check and read its output (or looked at the screenshot). "Should work" is not a result. Say plainly what you couldn't check.
2. **Never push to the main branch.** Every change reaches main through a branch and a PR. Create branches without tracking main, each in its own worktree (rule 9: `git worktree add --no-track -b <branch> <path> origin/<main>`), push with an explicit destination (`git push -u origin <branch>:<branch>`), and before any push check that `git rev-parse --abbrev-ref @{u}` isn't `origin/<main>`.
3. **Production needs a yes.** Anything that reaches real users (a production deploy, a store submission, an over-the-air update to production, a merge that auto-deploys) needs the user's explicit yes for that specific change, in chat. Typing `/fleet:ship` themselves counts, and so does **Ship it** on a Fleet review when the settings have `greenShips: true`. Silence, a green test run or your own judgment never does. Preview and staging environments follow the repo's rules; when the repo has none, ask once.
4. **Release what you lease, stop what you start.** Every Fleet `lease` gets a `release`, even after a failure. Every simulator you booted, dev server, Metro, tunnel, watcher or background shell you started is stopped before you report. Check before the report; say what you left running and why (rarely). Stop only your own processes, by PID or exact port; **never a pattern kill** (`pkill -f metro`, `killall node`, `kill $(lsof … | grep …)` across ports you didn't open): other sessions and agents run the same tools on the same machine.
5. **Brief updates, in the report contract.** Short plain sentences. Report results, not narration. Every report to the user ends with the fixed sections in § Reporting, and every action you ask of the user carries its link in the same message.
6. **Decide; don't ask** for things you can find out (the repo, its docs, its scripts). Ask only for a yes to ship, credentials or money, destructive actions, or a product direction that's expensive to undo. List the calls you made under "Decisions I made" in the PR.
   - **Push back when it gets worse.** Before building something that makes the common case worse to fix a rare one, say so: name what gets worse, propose the better option and recommend one. A recommendation, not a survey.
   - **Never drop work.** When two tasks conflict on product behavior, keep both alive (both branches, both options) and raise the conflict with options and a recommendation; never quietly discard one.
7. **Never cause regressions.** What works today keeps working. If a change can't be made without breaking something, stop and say so.
8. **No secrets** in code, logs, issues, PR text, prototypes or Fleet media. Never print a key or token; read single values from env files when needed, never source or cat them whole.
9. **Worktrees always** (setting `worktreesOnly`, default `true`). Every branch gets its own git worktree (`git worktree add --no-track -b <branch> <path> origin/<main>`); never switch, stash, reset or commit in the user's checkout: they edit files there. Remove a worktree once its branch is pushed (`git -C <wt> log HEAD --not --remotes` prints nothing) and merged. Only with `worktreesOnly: false` may a single lane or build use the current checkout, and only when it's clean.
10. **Standing feedback goes into the repo, not memory.** When the user states a lasting preference ("always", "never", "from now on", or corrects a miss that keeps happening), write it down in the same PR as the work: in the repo doc or skill it belongs to (its CLAUDE.md, AGENTS.md, a docs page), else in `rules` in `.fleet/workflow.json`. Cite it: `(user, <YYYY-MM-DD>: "<their words>")`, and when it changes an older rule, say so (`replaces the 2026-10-03 rule`) and edit the old one rather than leaving both. Never keep it only in the assistant's memory: memory doesn't reach other sessions, agents or machines. When the rule can be checked mechanically, offer a hook for it.
11. **"Live" means on the user's device or preview.** Merged, pushed or deployed to staging is not done for the user; say "live" or "ready to try" only once they can open it (their preview build, their device, the preview URL) and you've smoke-tested it there. Message them once when it lands, not with progress narration.

## Agents

Every `Agent` call a workflow makes (a lane, solidify, review, prototype, research) sets **`model` and `effort` by the job**, from `agents.models` in the settings, else these defaults:

| Job | Model, effort | Examples |
| --- | --- | --- |
| `ui` | `opus`, `high` | anything the user sees: screens, copy, motion, prototypes |
| `judgment` | `opus`, `high` | reviews, architecture, triage of an unclear failure, solidify |
| `small` | `sonnet`, `medium` | a well-scoped fix, tests, docs |
| `mechanical` | `haiku`, `low` | renames, formatting, moving files, collecting logs |

- **The cheaper model writes; the strongest checks.** Work from a `small` or `mechanical` agent gets a `judgment`-level review before it reaches the user. Pick the level that gets it right the first time; a retry costs more than the stronger model.
- A **fork** inherits the session's model; it needs neither.
- **Branch work in a brief** says, in these words: "Push the first working slice and SendMessage the main session its sha within 15 minutes." and "Then check in every 10 minutes: push and SendMessage what's done, what's next and the sha." The user never waits on finished work sitting in a worktree.
- **Simulator work** leases a Fleet berth first when this computer has a Fleet key ("Lease a Fleet berth for any simulator first; boot a local one only when no berth is free."), unless `agents.remoteSimulatorsFirst` is `false`.
- **Anything a brief starts** gets a stop: "Stop every simulator, dev server, Metro and tunnel you start, and release every lease, before reporting." (rule 4).
- **Enforced when the repo opts in.** `agents.enforceBriefs: true` turns on a hook (`scripts/fleet-guard brief`) that refuses an `Agent` call missing any of the above and names the missing sentence; fix the brief and launch it again. `agents.unpushedWork: true` turns on a hook that tells the main session, at most every 3 minutes, about worktree commits sitting on no remote for over 10 minutes: push or ship them by sha. Both are off by default and print nothing when off or when there's nothing to say.

## Reporting

Every workflow reports to the user in one shape, so they always know where to look. The message opens with **what changed, in plain words, and what wasn't built** (and why) near the top. Then these sections, **always all of them, in this order, each under its own heading**, with "Nothing" under an empty one:

1. **Callouts**: decisions you made, risks, what's untested (say "untested on a device" when nobody checked one), anything still running and why.
2. **Waiting on you**: the preview or build label first (`<environment> · <branch> · <sha>`), then each task waiting for the user's verdict, pick or yes, one line each: the one thing to try or decide, and its link.
3. **PR links**: every PR touched in this turn: title, URL and `branch · sha`.
4. **Options waiting on you**: each open prototype or option set: what it decides, your recommendation and its link.

- Read the sections from real state, not memory: the Inbox (`sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-api" inbox`, with a Fleet key), `gh pr list --author @me --state open`, and open prototype voyages (`voyage_list`).
- **Every action carries its link, every time,** in the same message, even when an earlier message had it. No other link lists outside these sections.
- `report.sections` in the settings renames or reorders the sections for a repo (below); every section is still shown.
- When the conversation changes topic, end with a ready-to-run rename on its own line: `/rename <short-topic>`.
- A skill's own **Report** section says what goes in the opening lines; the sections above always follow it.

## Fleet, in plain words

Fleet is where the user sees and decides: **Prototypes** (options to pick), **Inbox** (things waiting on them), **Sessions**, and **Devices** (their Macs and simulators). The Fleet MCP tools still use the older names:

| Tool word | Means |
| --- | --- |
| voyage | A tracked task. A prototype or review lives on a voyage started with `course: "prototype"`. |
| berth | A simulator on one of the user's Macs. `lease` it, use it, `release` it. |
| stage | Where a prototype voyage is: charting → waiting (the user picks) → building → review (the user's green) → built. |

- Start a voyage only inside these workflows, when the step needs one (options to pick, a simulator, a review on the dashboard). Never for ordinary work: sessions are logged automatically, outside your context.
- **Decisions are the user's**, on the dashboard (Build A–D, Another round, Tuck away; then Ship it or Fix). There's no tool to decide for them. `await_decision` waits for it.
- Every mutating tool call takes an `op_id`: a stable name for that step (`proto-round1-upload-A`, `ios-smoke-tap-2`), so a retry never runs twice.
- No Fleet key yet (`Run /fleet:login first.`)? The workflows still work without Fleet: show options as local files or links, use local simulators, and ask in chat. Mention `/fleet:login` once.

## The repo, and its settings file

Know the repo before acting:

```sh
sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-repo"
```

It prints the saved settings (if any) and what the repo suggests: main branch, package manager and scripts, Expo/React Native/Xcode config, deploy tooling, CI, and the repo's own skills and instructions (CLAUDE.md, AGENTS.md, CONTRIBUTING.md). Read those instructions; they outrank this file.

**`.fleet/workflow.json`** holds the per-repo answers, so each is asked once:

```json
{
  "version": 1,
  "mainBranch": "main",
  "commands": {
    "install": "pnpm install --frozen-lockfile",
    "typecheck": "pnpm typecheck",
    "lint": "pnpm lint",
    "test": "pnpm test",
    "build": "pnpm build",
    "e2e": "pnpm e2e",
    "deploy": "pnpm run deploy",
    "deployPreview": null,
    "logs": "npx wrangler tail --format pretty"
  },
  "gates": ["typecheck", "lint", "test", "build"],
  "previewUrl": null,
  "productionUrl": "https://example.com",
  "healthUrl": "https://example.com/api/health",
  "ios": {
    "kind": "expo-dev-client",
    "workspace": "ios/App.xcworkspace",
    "scheme": "App",
    "bundleId": "com.example.app",
    "urlScheme": "example",
    "simulator": "iphone"
  },
  "skills": {
    "round": "/ios-loop",
    "verify": "/verify",
    "review": "/review",
    "ship": "/deploy",
    "prototype": "/prototype",
    "idea": "/roadmap-idea",
    "triage": "/triage"
  },
  "rules": ["Never push to main.", "Review runs after the user's green, not before."],
  "issues": { "labels": ["ready"], "parent": null, "milestone": null },
  "roadmap": "ROADMAP.md",
  "loop": {
    "mode": "ios",
    "lanes": 1,
    "maxLanes": 3,
    "maxWaiting": 3,
    "agentLimit": { "beforeHour": 17, "tz": "America/Denver", "before": 2, "after": 5 },
    "localSimulators": 3
  },
  "greenShips": false,
  "confirmedAt": "2026-01-01"
}
```

- `ios.kind` is one of `expo-go`, `expo-dev-client`, `react-native`, `native`, or `none`.
- `gates` are the commands that must pass before anything is called done (keys into `commands`).
- `commands` is an open map: add any command the repo has (`format`, `e2eIos`, `deployStaging`…); `gates` name its keys.
- `skills` maps a step to the repo's own skill: `round` (a task's build, quick check and preview, as one call), `verify`, `review`, `ship`, `prototype`, `idea`, `triage`. Each value is the skill as typed (`/ios-loop`). Steps left out use the repo's same-named skill, else Fleet's. A mapped skill must accept `from fleet:loop` (do one task's step, then return); `fleet:loop` never hands it the whole loop.
- `rules` is a list of the repo's rules for the loop, one sentence each. `fleet:loop` prints them at the start and follows them; they outrank Fleet's skills, like the repo's CLAUDE.md.
- `issues` and `roadmap` are where `fleet:loop` looks for tasks, after the user's Fleet Inbox and orders: open issues with those labels (and that milestone), then the roadmap (a file, or an epic issue number such as `"#12"`). `issues.parent` (an issue number) limits issues to that epic's open sub-issues.
- `loop.mode` is `ios`, `web`, `api`, `cli` or `prototype-only`; `loop.lanes` is how many tasks run at once (each its own worktree, and simulator or dev server; older files say `loop.slots`) and `loop.maxLanes` the most the loop or the user's Loop tab may run (default 3); `loop.maxWaiting` caps how many tasks wait on the user's review before the loop stops starting new ones.
- `loop.agentLimit` caps agents by the hour: `before` while the hour in `tz` (an IANA zone) is below `beforeHour` (0–23), else `after`. It counts every agent the loop runs, and the loop runs the lowest of it, `maxLanes` and what the Macs have free. `null`: no cap but those.
- `loop.localSimulators` is the most simulators booted at once on this Mac (default 3); Fleet berths don't count.
- `greenShips: true` means the user's **Ship it** on the Fleet dashboard is also their yes for production. Only set it when the user says so. Default `false`: Ship it approves the change, and you still ask once before production. With it on, `fleet:loop` merges and ships each task on its green, like a sprint where the user's device test is the sign-off.
- Leave anything unknown `null`. Never put a secret in this file.

**Discover, then confirm once.** When the file is missing, or a workflow needs a key it lacks: fill it from `fleet-repo`, the repo's docs and CI config, show the user the few values that matter for this step in one short block ("Tests: `pnpm test` · Deploy: `pnpm run deploy` · Production: https://… Right?"), and write the file once they confirm (or correct it). Don't ask about keys the current workflow doesn't use. Suggest committing it (it's shared with the team) on the next branch you open; it holds no secrets.

### Agents, reports and worktrees

These keys sit at the top level of the same file; all are optional:

```json
{
  "agents": {
    "models": { "ui": ["opus", "high"], "judgment": ["opus", "high"], "small": ["sonnet", "medium"], "mechanical": ["haiku", "low"] },
    "enforceBriefs": false,
    "unpushedWork": false,
    "remoteSimulatorsFirst": true
  },
  "report": { "sections": { "callouts": "Callouts", "waiting": "Waiting on you", "prs": "PR links", "options": "Options waiting on you" } },
  "worktreesOnly": true
}
```

- `agents.models` maps a job (`ui`, `judgment`, `small`, `mechanical`; a repo may add its own) to `[model, effort]` for every `Agent` call (§ Agents). Jobs left out use the defaults there.
- `agents.enforceBriefs` and `agents.unpushedWork` turn on the two hooks in § Agents. Off by default; turn them on only when the user asks.
- `agents.remoteSimulatorsFirst: false` drops the "Fleet berth first" requirement (for a repo whose simulators must run locally).
- `report.sections` renames or reorders the closing sections (§ Reporting): each key (`callouts`, `waiting`, `prs`, `options`) maps to the heading this repo uses, and the order written is the order shown. E.g. `{ "callouts": "Callouts", "waiting": "Waiting on you in staging", "prs": "PR links", "options": "Prototypes that need your input" }`. A key left out keeps its default heading and comes after the others; none is ever dropped.
- `worktreesOnly` (default `true`): every branch in its own worktree (rule 9). `false` lets a single lane or build use a clean current checkout.
