---
name: verify
description: Check that a change really works and report pass or fail with evidence, by running the repo's tests and gates and then looking at the result (a URL with screenshots, or the app on a simulator). Never claims success unchecked. Use when the user runs /fleet:verify, asks "does it work?" or "check it" about a branch, PR, preview or production deploy, or as the step after fleet:build, fleet:triage, fleet:ship or in fleet:loop. If the repo has its own verify skill, use that instead.
argument-hint: "[branch | PR | preview | production] [what changed]"
allowed-tools: Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-repo"), Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-repo" *)
---

# /fleet:verify: does it really work?

Target and focus: **$ARGUMENTS** (default: the current branch, everything it changed).

Read the shared rules once per session: `${CLAUDE_PLUGIN_ROOT}/skills/fleet-workflows/SKILL.md`.

Never say something works until this passed. Use the repo's own tools (its test runner, its e2e suite, plain `curl`), not hand-written harnesses.

**Called by `fleet:loop`** (the input says `from fleet:loop <mode>`) before the user's review: run only the mode's quick check from the loop's § Modes table (a typecheck, lint on the touched files, then a real look: the simulator smoke test, the screenshots, the `curl` or CLI run), keep the evidence for the review, and return to the loop. The full run below comes after the user's green.

## 1. What changed

`sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-repo"` for the commands and URLs. Then `git fetch origin && git diff origin/<main>...<branch> --stat` (or `gh pr diff <n> --name-only`) so the checks cover what changed.

## 2. A branch or PR

1. **The gates**, from the settings (`gates`) or the repo's docs: typecheck, lint, format, unit tests, build. Run each and read the output.
2. **Cover the change.** If the changed flow has no test, add one on the branch (the repo's test style) and commit it.
3. **The flow tests** (e2e, integration), focused on what changed when the suite is slow. A failing test you didn't touch: run it on the main branch too. Failing there as well means pre-existing: report it as such, don't fix it silently or call it yours.
4. **Look at it.** Tests miss things a glance catches (a missing space, a clipped label):
   - **Web:** start the dev server (or use the preview URL), then `npx playwright screenshot --viewport-size=390,844 <url> <scratch>/<screen>.png` (and 1280 wide when desktop matters) for each changed screen, and read each screenshot.
   - **iOS / Expo / React Native:** run it on a simulator as `${CLAUDE_PLUGIN_ROOT}/skills/loop/ios.md` § 2–4 says (a Fleet simulator or a local headless one), tap through the changed path, screenshot each step, then release the lease.
   - **API or backend:** `curl` the changed endpoints against the local server or preview, with the inputs the change cares about.
5. A failure caused by the change: fix it on the branch, rerun, and only then report.

## 3. A preview or production deploy

Read-only checks only; never write data in production.

1. **The right code is live:** the deploy tool's list (`wrangler deployments list`, `vercel ls`, `fly releases`, the CI run) shows this commit, or a version endpoint does.
2. **Health and key routes:** the settings' `healthUrl` and `productionUrl` (or `previewUrl`) return 200; the pages and endpoints the change touched return what they should (`curl -sS -o /dev/null -w '%{http_code}'`, and look at the body).
3. **A look:** a screenshot of each changed page at phone width.
4. **Errors since the deploy:** the settings' `logs` command or the provider's log tool, limited to the minutes since the deploy.

## 4. Report

Short, with evidence:

```
Verify <branch|preview|production> · <sha>
✓ typecheck  ✓ lint  ✓ unit 212 passed  ✗ e2e 1 failed  ○ 3 skipped
✗ checkout.spec › applies a coupon: <first line of the error>
Looked at: /settings (390 px) ✓, /checkout ✗ total overlaps the button
Errors since deploy (12 min): none
Couldn't check: <what and why>
```

Stop every server, simulator and lease you started before reporting.

**Next:** pass on a branch → `fleet:review`. Pass on production → done; close the issues. Fail → fix on the branch and run this again (or `fleet:triage` when the cause isn't obvious).
