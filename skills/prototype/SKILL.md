---
name: prototype
description: Show 2–4 genuinely different options for something decided by looking (a screen, a flow, an interaction, a visual direction, state logic) as self-contained HTML pages or real simulator screenshots, publish them to the user's Fleet Prototypes, and wait for their pick before building anything. Use when the user asks for options, a prototype, mockups or "a few directions", or runs /fleet:prototype. Small or clearly specified changes don't need it. If the repo has its own prototype skill, use that instead.
argument-hint: "<what to explore> | resume <voyage id>"
allowed-tools: Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-repo"), Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-repo" *), Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-login" check)
---

# /fleet:prototype: options side by side, then the user's pick

Topic: **$ARGUMENTS**

Fleet key: !`sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-login" check`

Read the shared rules once per session: `${CLAUDE_PLUGIN_ROOT}/skills/fleet-workflows/SKILL.md`.

The user decides by looking. This skill makes the options, puts them in front of the user in Fleet, and **stops for the pick**. No app code, no branch, no PR. Be fast and lean: one pass to build, one check, publish.

**Resuming** (`resume <voyage id>`, or the user says they picked): call `voyage_resume` and do what its `nextStep` says (skip to § 5).

## 1. Context (keep it short)

- `sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-repo"`: the repo, its settings, and whether it has its own prototype skill (use that one if so).
- Read the current implementation of the thing (screens, components, styles, tokens, copy) so options start from what exists. Keep what the user approved before unless they asked for a change. Read the repo's design docs if it has them (`docs/design*`, a brand or style guide, `tailwind.config`, theme files).
- **Draw existing screens from the real thing, not from the code alone.** When an option changes an existing screen, look at it first: a screenshot of the web page (`npx playwright screenshot --viewport-size=390,844 <url> <file>`), or on a simulator for iOS (`fleet:sim`, or a berth: § 3). Code-only drawings get layouts wrong.
- **Refining something that exists:** audit it first with evidence (`file:line`, measurements, the user's earlier feedback) and show it as a short **Today** before the options.
- Look for earlier rounds: `gh issue list --state all --search "<topic>"` and the Fleet voyages (`voyage_list` with `all: true`, goals matching the topic). Continue an earlier prototype voyage rather than starting a parallel one.

## 2. Pick the kind

| Kind | Each option shows |
| --- | --- |
| **Screen or layout** | The full screen at phone width (390 px) and desktop when it matters, with every state the change touches: rest, loading, empty, typing, no results, error. |
| **Interaction or motion** | A working, clickable model in a phone frame, real timings, a slow-motion toggle. |
| **Visual direction** (logo, icon, palette, type) | Real sizes (16, 24, 56 px and large) on light and dark. |
| **Data or state logic** | Inputs on one side, the resulting state on the other, plus a table of transitions and edge cases. |
| **Native app states** | Real screenshots from a simulator (§ 3), one set per option, built behind a local flag or on scratch branches you delete after. |

## 3. Build the options

- **2–4 genuinely different directions**, not variations of one. Each gets a short name, one line on the idea, what it costs (effort, risk, performance) and what it drops. On a refinement, say which audit findings each one fixes.
- **One decision at a time, side by side.** If the topic has several decisions (say, the list and the empty state), each page shows its option's take on each, in the same order, so the user can compare A, B and C for the same thing.
- **Real copy, real data, the product's real look** (its fonts, colors, spacing and components). Copy is literal and usually ships as written.
- **Recommend exactly one**, and mark it on its page ("Recommended" with a clear outline) so the pick is visible without scrolling.
- **Each option is one self-contained HTML file**: inline all CSS, JS, fonts and images (images as `data:` URIs; keep each file under ~5 MB). Fleet shows pages in a sandbox: scripts run, but no network calls to your servers and no cookies. Put them in a scratch folder (`<scratchpad>/<slug>/A.html`, `B.html`…).
- **Native screenshots instead:** start a voyage first (§ 4 step 1), `lease` an `iphone` berth on it, `boot`, put the app on it (`fleet:ios-loop` § 2–3 covers install and Metro), set up each state and use `capture_lease_id` as the option's media. **Release the lease right after `chart_options`**: captures are copied when the round is published, so you don't need the simulator while the user decides.
- **Check once before publishing:** screenshot each page locally at 390 px (and 1280 px if desktop matters), e.g. `npx playwright screenshot --viewport-size=390,844 file://<path>/A.html <scratch>/A.png`, look at it, fix what's wrong. One pass.

## 4. Publish to Fleet

With a Fleet key:

1. `voyage_start` with `course: "prototype"`, `goal` (one sentence: what's being decided), `repo` (`git remote get-url origin`), and `op_id`. Reuse the earlier voyage instead if this is another round.
2. For each page: `upload_url` with `voyage_id` and `ext: "html"` (or `png`/`jpg` for images), then upload it: `curl -sS -T <file> -H 'content-type: text/html' '<uploadUrl>'` (quote the URL; check for HTTP 200). Keep each `blobKey`.
3. `chart_options` with `voyage_id`, a `note` (one or two lines: what this round decides and why you recommend your pick), and the options: `key` A–D, `title`, `summary` (the idea, its cost, what it drops), `recommended` on exactly one, and `media` (`blob_key` for pages and images, `capture_lease_id` for live captures, `url` for links; add a `caption`).
4. Tell the user in three short lines: the link (`https://fleet.osroc.io/app/voyages/<voyage id>`), one line per option, and your recommendation. Then `await_decision` with `wait_seconds: 600`. While the user is around, call it again when it says `still waiting` (up to 3 times). After that, stop: say the pick is waiting in their Fleet Inbox, and that `/fleet:prototype resume <voyage id>` carries on.

Without a Fleet key: give the user the local file paths (or publish them the way the repo's docs say) with the same three lines, and ask which one in chat. Mention `/fleet:login` once.

Put the voyage link on the work's GitHub issue if there is one.

## 5. The pick

`await_decision` returns the decision and `nextStep`. Do what it says:

- **Build `<option>`:** the voyage moves to `building`. Run `fleet:build` with the picked option (its title, summary and media are in the result), the topic and the `voyage_id`, so the review lands on the same voyage. Delete scratch flags and losing variants as part of the build.
- **Another round (notes):** a new round on the **same** voyage, shaped by the notes: keep what they liked, drop what they didn't, and call `chart_options` again (it becomes round 2, 3…). Then wait again.
- **Tuck away:** it's over. Say so in one line, clean up scratch branches and leases, done.

Record taste the user states ("less bouncy", "old-fashioned, not cruise ship") in the repo's design doc when the work lands.

## Before you report

Every lease released (`release`), scratch servers and simulators stopped, scratch branches deleted.

**Next:** `fleet:build` with the pick (call it directly once the user picked; that's the go-ahead to build, not to ship).
