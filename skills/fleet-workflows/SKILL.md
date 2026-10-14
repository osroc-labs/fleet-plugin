---
name: fleet-workflows
description: Shared rules, the chain and the per-repo settings file (.fleet/workflow.json) for Fleet's workflow skills (fleet:idea, prototype, build, ios-loop, verify, review, ship, triage). Load it only while running one of those skills; it does nothing on its own.
user-invocable: false
---

# How the Fleet workflows fit together

Fleet's workflows are the loop that ships a change: **idea → prototype → build → verify → review → ship**, with **triage** as the way in when something is broken. Each one is a skill you can run on its own (`/fleet:<name>`), and each one ends by naming the next.

```
            fleet:idea ──────────────┐
          (brain dump → issues)      │ clear enough to build
                 │ open-ended        │
                 ▼                   ▼
          fleet:prototype ──pick──▶ fleet:build ──iOS/Expo/RN──▶ fleet:ios-loop
          ▲     │    (options,         │                              │
          └─────┘     the pick)        ▼                              │
       another round            fleet:verify ◀───────────────────────┘
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
- Hand context forward explicitly: the branch, the PR, the issue, the Fleet voyage id (if there is one) and the settings below. Never make the next step rediscover them.
- **The repo's own skills come first.** `fleet-repo` (below) lists the repo's `.claude/skills` and `.claude/commands`. If the repo has its own skill for this step (its own `verify`, `deploy`, `review`, `prototype`…), use that one instead and say so in one line. Fleet's skills are the fallback, not a replacement.

## Rules for every workflow

1. **Verify before claiming.** Never say something works, passes or is fixed until you ran the check and read its output (or looked at the screenshot). "Should work" is not a result. Say plainly what you couldn't check.
2. **Never push to the main branch.** Every change reaches main through a branch and a PR. Create branches without tracking main (`git switch --no-track -c <branch> origin/<main>`), push with an explicit destination (`git push -u origin <branch>:<branch>`), and before any push check that `git rev-parse --abbrev-ref @{u}` isn't `origin/<main>`.
3. **Production needs a yes.** Anything that reaches real users (a production deploy, a store submission, an over-the-air update to production, a merge that auto-deploys) needs the user's explicit yes for that specific change, in chat. Typing `/fleet:ship` themselves counts. Silence, a green test run or your own judgment never does. Preview and staging environments follow the repo's rules; when the repo has none, ask once.
4. **Release what you lease, stop what you start.** Every Fleet `lease` gets a `release`, even after a failure. Every simulator you booted, dev server, Metro, tunnel, watcher or background shell you started is stopped before you report. Check before the report; say what you left running and why (rarely).
5. **Brief updates.** Short plain sentences. Report results, not narration: what changed, what passed, what's waiting on the user, links last.
6. **Decide; don't ask** for things you can find out (the repo, its docs, its scripts). Ask only for a yes to ship, credentials or money, destructive actions, or a product direction that's expensive to undo. List the calls you made under "Decisions I made" in the PR.
7. **Never cause regressions.** What works today keeps working. If a change can't be made without breaking something, stop and say so.
8. **No secrets** in code, logs, issues, PR text, prototypes or Fleet media. Never print a key or token; read single values from env files when needed, never source or cat them whole.

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
  "issues": { "labels": ["idea"] },
  "greenShips": false,
  "confirmedAt": "2026-01-01"
}
```

- `ios.kind` is one of `expo-go`, `expo-dev-client`, `react-native`, `native`, or `none`.
- `gates` are the commands that must pass before anything is called done (keys into `commands`).
- `greenShips: true` means the user's **Ship it** on the Fleet dashboard is also their yes for production. Only set it when the user says so. Default `false`: Ship it approves the change, and you still ask once before production.
- Leave anything unknown `null`. Never put a secret in this file.

**Discover, then confirm once.** When the file is missing, or a workflow needs a key it lacks: fill it from `fleet-repo`, the repo's docs and CI config, show the user the few values that matter for this step in one short block ("Tests: `pnpm test` · Deploy: `pnpm run deploy` · Production: https://… Right?"), and write the file once they confirm (or correct it). Don't ask about keys the current workflow doesn't use. Suggest committing it (it's shared with the team) on the next branch you open; it holds no secrets.
