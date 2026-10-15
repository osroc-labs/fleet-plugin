---
name: review
description: Independent review of a branch or PR before merge (correctness, security, regressions, cost, rollout, tests, debris), fixing findings on the branch. Use for /fleet-workflows:review or "review this PR". A repo's own review skill wins.
argument-hint: "<PR number or branch> [base branch] | <branch> round <since-sha>"
allowed-tools: Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-repo"), Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-repo" *)
---

# /fleet-workflows:review: fresh eyes before it merges

Target: **$ARGUMENTS** (default: the current branch against the main branch). With `round <since-sha>` it's a **round review** (§ Round mode): only what's new since the user last saw it, checked against what they asked for.

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

**Fix every use**
- A fix to a shared pattern (a component, a hook, a helper, a style) goes in the shared piece, not in one screen's copy, and is checked at every place that uses it. The PR has a table: each use (`file:line` or screen), checked how, result. A fix made in one caller while the shared piece stays wrong is a must-fix.

**Recent decisions stand**
- Before the change alters how something looks or behaves, read `git log --since=2.days -p -- <files it touches>` and the user's recorded words on the issue and PR (verdict notes, Fix notes, the repo's design doc). A recent call the user made, undone along the way without being asked, is a must-fix.

**Debris**
- Conflict leftovers, dead code, debug output, commented-out blocks, unrelated reformatting, files the change didn't need.

## 3. Fix and record

1. Rank findings: **must-fix** (a bug, a leak, an outage risk), **should-fix**, **nit**. Each with `file:line`, what happens, and the fix.
2. Fix must-fix and should-fix on the same branch, rerun the gates, push (`git push origin <branch>:<branch>`).
3. Post a short summary on the PR (`gh pr comment`): what was checked, what was fixed, what's left. Risky areas (auth, money, concurrency, migrations) get looked at again after the fixes, until clean.

## Round mode: `<branch> round <since-sha>`

A short review before each fix round goes back to the user, so they never review the same miss twice. It runs **in parallel with the quick check** and takes about 10 minutes. Skip it only for a copy-only change of a line or two. The full review (§ 1–3) still runs before merge.

**Who reviews:** a fresh subagent (`Agent`, the strongest model you have), never the author. Hand it the branch, `since-sha`, the requests (below) and this section; it reports and doesn't edit. The author fixes.

1. **The diff:** `git diff <since-sha>..HEAD` (`--stat` first). `since-sha` is the sha the user last saw (the task's last published sha: on its Fleet voyage's review, or the preview's message). Nothing older is in scope unless the new diff touches it.
2. **The requests:** every note the user gave since `since-sha`: the Fix notes on the voyage, the issue and the PR comments, and the user's messages this round (the caller passes them verbatim; without a caller, read them from the issue and PR). Split them into single requests, in the user's words.
3. **The requests check:**
   - **Every request is addressed:** where it landed (`file:line`), or why not.
   - **What the user approved stays:** nothing they approved or didn't mention in an earlier round changed, unless a request asked for it. Diff the files the requests didn't name line by line.
   - **What they dropped stays gone:** nothing they asked to remove is back (search the diff for the removed label, component or option).
   - **Nothing invented:** a new label, name, icon, color or pattern matches one already defined in the code; cite the defining file. A word or icon with no source in the repo is a finding.
   - **Recent decisions stand** and **fix every use** (§ 2) for what this round changed.
4. **Output,** a table and findings:

   ```
   Round review <branch> · <since-sha>..<sha>
   | # | Request (the user's words) | Where it landed | ✓/✗ |
   | 1 | "make the header smaller" | src/Header.tsx:42 | ✓ |
   | 2 | "drop the badge" | src/Card.tsx:88 still renders it | ✗ |
   Kept: ✓ nothing approved changed · Gone stays gone: ✓ · Invented: ✗ "Watchlist" (src/Tabs.tsx:12) has no source; the app says "Library" (src/strings.ts:7)
   Findings: must-fix / should-fix / nit, each with file:line and the fix
   ```

5. The author fixes every ✗ and must-fix on the branch before the round is republished, and reruns the quick check if behavior changed. No PR comment for a round review: the table goes back to the caller (`fleet-workflows:loop`), or to the user in chat.

## Report

Findings fixed (one line each), anything left and why, the PR link. A round review reports its table instead (§ Round mode 4).

**Next:** from `fleet-workflows:loop`: back to the loop (a round review: back to the round's republish). Otherwise clean → `fleet-workflows:ship` (it asks for the user's yes before production). Fixes that changed behavior → `fleet-workflows:verify` first.
