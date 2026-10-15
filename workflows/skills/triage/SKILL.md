---
name: triage
description: Handle "it's broken", errors and crash reports. Reads the logs first, finds the root cause, fixes it on a branch with a regression test, verifies. Use for bug reports or /fleet-workflows:triage. A repo's own triage skill wins.
argument-hint: "<what's broken, where, roughly when>"
allowed-tools: Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-repo"), Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-repo" *)
---

# /fleet-workflows:triage: errors first, then the fix

Report: **$ARGUMENTS**

Read the shared rules once per session: `${CLAUDE_PLUGIN_ROOT}/skills/fleet-workflows/SKILL.md`.

## 1. Read the errors before asking anything

Don't ask for repro steps until you've looked. Start from `sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-repo"` and use what the repo has:

- **The settings' `logs` command**, or the provider's: `wrangler tail` / Workers Logs, `vercel logs`, `fly logs`, `heroku logs`, `firebase functions:log`, the cloud console's CLI. An error tracker (Sentry, Bugsnag, Crashlytics) through its CLI or MCP if one is connected.
- **CI:** `gh run list --limit 10`, then `gh run view <id> --log-failed` for a red build.
- **Which code is live:** the deploy list or a version endpoint, so you debug the right commit. `git log` since that commit.
- **Local:** the failing test's output, the dev server's log, the browser console (`npx playwright` with a trace), and for iOS the simulator's log (`xcrun simctl spawn <udid> log show --last 10m --predicate 'process == "<App>"'`) or a crash report.
- Recent changes near the symptom: `git log -p --since="3 days ago" -- <paths>`.

Nothing recorded? Reproduce it with a test (the repo's test style) that fails. It becomes the regression test.

If production is actively bleeding (data loss, an outage, a runaway job), say so first and propose the fastest safe stop (a feature flag, a pause, a revert PR); do it only with the user's yes.

## 2. Find the cause

Name the root cause with evidence: the error, the `file:line`, the input that triggers it, why it started now. Fix the cause, not the symptom. If you can't find it, say what you ruled out and what you need.

## 3. Fix

- A branch off the main branch in its own worktree (shared rules § 2 and § 9), never the user's checkout.
- The fix, plus a test that fails without it.
- If the failure path wasn't reported or logged, add reporting.
- The gates from the settings; push; open a PR with the cause and evidence in its body (`Fixes #<n>` when there's an issue).

## Report

Opening lines: what broke, the cause (one line plus evidence), the fix (PR link), and the test that guards it. Then the closing sections (shared rules § Reporting).

**Next:** `fleet-workflows:verify` on the branch (call it directly), then `fleet-workflows:review` and `fleet-workflows:ship` (production still needs the user's yes).
