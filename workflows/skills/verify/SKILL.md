---
name: verify
description: Check a change really works and report pass/fail with evidence (tests, gates, then the URL or simulator). Use for /fleet-workflows:verify, "does it work?", or after build, triage or ship. A repo's own verify skill wins.
argument-hint: "[branch | PR | preview | production] [what changed]"
allowed-tools: Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-repo"), Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-repo" *)
---

# /fleet-workflows:verify: does it really work?

Target and focus: **$ARGUMENTS** (default: the current branch, everything it changed).

Read the shared rules once per session: `${CLAUDE_PLUGIN_ROOT}/skills/fleet-workflows/SKILL.md`.

Never say something works until this passed. Use the repo's own tools (its test runner, its e2e suite, plain `curl`), not hand-written harnesses.

**Called by `fleet-workflows:loop`** (the input says `from fleet-workflows:loop <mode>`) before the user's review: run only the mode's quick check from the loop's § Modes table (a typecheck, lint on the touched files, then a real look: the simulator smoke test, the screenshots, the `curl` or CLI run), keep the evidence for the review, and return to the loop. A flaky-looking failure: rerun that one spec alone, once (§ Flaky tests), never the suite. The full run below comes after the user's green.

## 1. What changed

`sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-repo"` for the commands and URLs. Then `git fetch origin && git diff origin/<main>...<branch> --stat` (or `gh pr diff <n> --name-only`) so the checks cover what changed.

## 2. A branch or PR

1. **The gates**, from the settings (`gates`) or the repo's docs: typecheck, lint, format, unit tests, build. Run each and read the output.
2. **Cover the change.** If the changed flow has no test, add one on the branch (the repo's test style) and commit it.
3. **The flow tests** (e2e, integration), focused on what changed when the suite is slow. A failure is read before it's called anything (§ Flaky tests):
   - In a quarantined test (`verify.quarantine.tag`, e.g. `@quarantine`): a **known flake**. Report it with its issue; it doesn't fail the verdict.
   - In a test you didn't touch: check it against the branch's diff (does the change reach that flow?), then run that one spec on the main branch. Failing there as well means pre-existing: report it as such, don't fix it silently or call it yours.
   - **A bug a test exposes that this change doesn't fix:** mark that test skipped or fixme (the runner's own way) with a comment naming the bug and its issue (open one if there's none), and report it. Never delete the test.
4. **Look at it.** Tests miss things a glance catches (a missing space, a clipped label):
   - **Web:** start the dev server (or use the preview URL), then `npx playwright screenshot --viewport-size=390,844 <url> <scratch>/<screen>.png` (and 1280 wide when desktop matters) for each changed screen, and read each screenshot.
   - **iOS / Expo / React Native:** run it on a simulator as `${CLAUDE_PLUGIN_ROOT}/skills/loop/ios.md` § 2–4 says (a Fleet simulator or a local headless one), tap through the changed path, screenshot each step, then release the lease.
   - **API or backend:** `curl` the changed endpoints against the local server or preview, with the inputs the change cares about.
5. A failure caused by the change: fix it on the branch, rerun, and only then report.

## 3. A preview or production deploy

Read-only checks only; never write data in production. A failure on a preview is checked against the branch's diff and a local run before it's called a regression (the preview's data and config differ from yours).

1. **The right code is live:** the deploy tool's list (`wrangler deployments list`, `vercel ls`, `fly releases`, the CI run) shows this commit, or a version endpoint does. With `ship.targets`, each target's sha or id (the ship report lists them).
2. **Health and key routes:** the settings' `healthUrl` and `productionUrl` (or `previewUrl`) return 200; the pages and endpoints the change touched return what they should (`curl -sS -o /dev/null -w '%{http_code}'`, and look at the body). Include a deep link (a page opened directly, not through the home page) and, when the repo has share pages, their link-preview tags (`og:title`, `og:image`).
3. **Nothing preview-only in production:** each string in `verify.absentInProduction` (a preview badge, the staging host, a debug menu's label) is absent from the production pages and, when the repo ships a bundle, from it (`curl -sS <url> | grep -c '<string>'` prints 0; `grep -a -c` for a binary bundle). Found: production is showing a preview build; say so first in the report and `fleet-workflows:triage` it.
4. **Signed in,** when the settings have `verify.smoke.production` (`verify.smoke.preview` on a preview):
   - **Credentials by name only.** `envVars` names the variables (`PROD_SMOKE_EMAIL`, `PROD_SMOKE_PASSWORD`). Take each from the environment, or one value at a time from the repo's env file straight into the command (`"$(grep '^PROD_SMOKE_EMAIL=' .env | cut -d= -f2-)"`), never echoed. Never print, log, paste or commit a value. A variable that's missing: skip this check, say which name is missing, and never ask for the value in chat.
   - **Sign in** with the `signIn` recipe (a command, or a curl with a cookie jar in your scratch directory, deleted afterwards).
   - **Read-only checks:** each entry in `checks` (`"GET /api/me"`), then the endpoints the change touched, read-only, each returning what it should (status and body). A check that isn't a `GET` runs only when it's listed in `checks`, which marks it as read-only (a search or feed `POST`). **Never write** from the smoke account: no posting, following, liking, buying, deleting or settings changes, even when the change is about one. Say it's unchecked instead.
5. **A look:** a screenshot of each changed page at phone width.
6. **Errors since the deploy:** the settings' `logs` command or the provider's log tool, limited to the minutes since the deploy.

## Flaky tests

Known flakes are tracked, not rerun blindly.

- **Rerun one spec, once.** A failure that looks flaky (a timeout, a race, it passes locally): rerun that one spec alone, once (`npx playwright test <file> -g "<title>"`, or the runner's equivalent). Never rerun the whole suite for one spec, and never rerun until it's green.
- **It passed on the rerun:** a new flake. With `verify.quarantine` in the settings, tag it with `verify.quarantine.tag` (the repo's runner skips the tag unless its env flag is set; add that skip once if the repo has none), open an issue labeled `verify.quarantine.issueLabel` (default `flaky`) with the error, the spec and the run, and link the issue next to the tag. Without it: don't tag anything; list it for the user.
- **It failed again:** a real failure, handled as § 2 step 3 and 5 say.
- **Known flakes don't fail the verdict,** but each one that failed this run is reported with its issue.

## 4. Report

Short, with evidence:

```
Verify <branch|preview|production> · <sha>
✓ typecheck  ✓ lint  ✓ unit 212 passed  ✗ e2e 1 failed  ○ 3 skipped
✗ checkout.spec › applies a coupon: <first line of the error>
Looked at: /settings (390 px) ✓, /checkout ✗ total overlaps the button
Signed in (smoke): ✓ GET /api/me 200 · ✓ GET /api/voyages 200
Preview-only absent: ✓ "Staging" badge · ✓ staging.example.com
Known flakes: search.spec › debounces (#41) · new: cart.spec › badge count (reran alone once, passed; #57 opened)
Errors since deploy (12 min): none
Couldn't check: <what and why>
```

Stop every server, simulator and lease you started before reporting.

**Next:** pass on a branch → `fleet-workflows:review`. Pass on production → done; close the issues. Fail → fix on the branch and run this again (or `fleet-workflows:triage` when the cause isn't obvious).
