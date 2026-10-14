---
name: review
description: An independent review of a branch or PR before it merges, with fresh eyes, for correctness, security and privacy, regressions, performance and data cost, rollout safety, tests and leftover debris, then fix the findings on the same branch. Use when the user runs /fleet:review, asks for a review of a branch or PR, or as the step after fleet:verify (fleet:loop runs it before the user's review). If the repo has its own review skill, use that instead.
argument-hint: "<PR number or branch> [base branch]"
allowed-tools: Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-repo"), Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-repo" *)
---

# /fleet:review: fresh eyes before it merges

Target: **$ARGUMENTS** (default: the current branch against the main branch).

Read the shared rules once per session: `${CLAUDE_PLUGIN_ROOT}/skills/fleet-workflows/SKILL.md`.

**Independent means not the author.** If you wrote this change in this session, run the review in a fresh subagent (`Agent`, with this skill's checklist, the target and "report findings with file:line; don't edit") and then fix what it finds yourself. Reviewing your own diff in the same context misses the same things twice.

## 1. Read what it was meant to do

```sh
git fetch origin
git diff origin/<base>...origin/<branch> --stat
git diff origin/<base>...origin/<branch>
gh pr view <n> --comments        # the PR body and its linked issues
```

Read the repo's instructions (CLAUDE.md, CONTRIBUTING.md, docs on conventions) for its own rules: they're part of the checklist.

## 2. Checklist

**Correctness**
- Does it do what the PR and issue say, for every input? Edge states: empty, loading, error, signed out, permissions denied, offline, very long text, concurrent use.
- Error paths handled and reported, not swallowed.

**Security and privacy**
- Who the user is comes from the server's session, never from the request body or query.
- Every read and write checks the caller may do it (ownership, roles, private data). No data from one user can reach another through caches, logs or shared state.
- Input is validated; no injection (SQL, shell, HTML/XSS, path traversal). No secrets in code, logs, PR text or client bundles.

**Regressions**
- What works today keeps working: old clients and saved data still parse, public APIs keep their shape, other platforms (web, Android, iOS) still behave. Diff the unchanged paths of shared code line by line.

**Performance and data cost**
- New queries are indexed and scoped (no scans, no N+1, no unbounded `IN` lists or pages). Anything in a loop, a list or a hot path gets a look at its query plan.
- Nothing heavy on every render, every keystroke or every request without a cache.

**Rollout**
- Migrations are additive and never edit one that already shipped. Feature flags default safe. Deploy order works (server before the client that needs it).

**Tests and conventions**
- Tests cover the change and would fail without it. The repo's style, naming and patterns; one component or helper per job (no second copy of something that exists).

**Debris**
- Conflict leftovers, dead code, debug output, commented-out blocks, unrelated reformatting, files the change didn't need.

## 3. Fix and record

1. Rank findings: **must-fix** (a bug, a leak, an outage risk), **should-fix**, **nit**. Each with `file:line`, what happens, and the fix.
2. Fix must-fix and should-fix on the same branch, rerun the gates, push (`git push origin <branch>:<branch>`).
3. Post a short summary on the PR (`gh pr comment`): what was checked, what was fixed, what's left. Risky areas (auth, money, concurrency, migrations) get looked at again after the fixes, until clean.

## Report

Findings fixed (one line each), anything left and why, the PR link.

**Next:** from `fleet:loop`: back to the loop. Otherwise clean → `fleet:ship` (it asks for the user's yes before production). Fixes that changed behavior → `fleet:verify` first.
