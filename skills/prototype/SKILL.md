---
name: prototype
description: Show 2–4 genuinely different options for something decided by looking (a screen, a flow, an interaction, a visual direction, state logic) on one side-by-side comparison page (or real simulator screenshots), publish it to the user's Fleet Prototypes, and wait for their pick before building anything. About ten minutes to the first link, in the main session. Use when the user asks for options, a prototype, mockups or "a few directions", or runs /fleet:prototype. Small or clearly specified changes don't need it. If the repo has its own prototype skill, use that instead.
argument-hint: "<what to explore> | resume <voyage id>"
allowed-tools: Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-repo"), Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-repo" *), Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-login" check)
---

# /fleet:prototype: options side by side, then the user's pick

Topic: **$ARGUMENTS**

Fleet key: !`sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-login" check`

Read the shared rules once per session: `${CLAUDE_PLUGIN_ROOT}/skills/fleet-workflows/SKILL.md`.

The user decides by looking. This skill makes one living page per topic with the options side by side, puts it in front of the user in Fleet, and **stops for the pick**. No app code, no branch, no PR.

**Ten minutes, in the main session.** A prototype is a sketch: aim for the first link within about ten minutes. Build it here, not in an agent and not on a new simulator, unless you're the conductor in the middle of shipping something (then one agent, briefed per fleet-workflows § Agents: job `ui`, so `opus` at `high`, with its stop sentence). No specs, comparison tables or long audits before the link: publish rough, then refine the same round on the same voyage.

**Resuming** (`resume <voyage id>`, or the user says they picked): call `voyage_resume` and do what its `nextStep` says (skip to § 5).

**Called by `fleet:loop`** (the input says `from fleet:loop`): use the task voyage it hands you (no new `voyage_start`), and after `chart_options` and the lines to the user, return to the loop instead of calling `await_decision`: it checks for the pick between its other tasks.

## 1. Context (keep it short)

- **Earlier rounds first, from the index, not the pages.** `prototype_index` with `repo` (`git remote get-url origin`) and a `query` of the topic's key words returns each prototype in its shape (title, summary, status, statusNote, rounds, links, `snoozedUntil` while the user has it snoozed) and its link, without loading any page. If one covers this topic, **continue it**: its next round goes on that voyage (`chart_options` again), never a parallel prototype. Open an earlier page only to build its next round. Also `gh issue list --state all --search "<topic>"` for feedback on it.
- `sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-repo"`: the repo, its settings (the `prototype` block, below) and whether it has its own prototype skill (use that one if so).
- Read the current implementation of the thing (screens, components, styles, tokens) so options start from what exists. Keep what the user approved before unless they asked for a change. Read the repo's design docs if it has them (`docs/design*`, a brand or style guide, theme files).
- **Labels come from the code, never invented.** Open the files that define the names the options show (sorts, filters, sections, tabs, menu items: `prototype.names` lists them) and use their exact words and icons. Match the app's existing verbs and patterns.
- **Today comes from the real platform.** When an option changes an existing screen, draw Today from the real thing at every state the options touch: the component library (`prototype.components`) for parts that exist, a web screenshot (`npx playwright screenshot --viewport-size=390,844 <url> <file>`), or the simulator for native layout (`fleet:berths`; keyboards, sheets and native controls sit differently on iOS than on the web). Never from the code alone: code-only drawings get layouts wrong.
- **Refining something that exists:** show a short **Today** first, with evidence (`file:line`, measurements, the user's earlier feedback), and say which findings each option fixes.

### Settings: `prototype` in `.fleet/workflow.json`

```json
"prototype": {
  "kit": "docs/prototype-kit/",
  "components": "pnpm storybook:build",
  "names": ["src/lib/sorts.ts", "src/lib/filters.ts"]
}
```

- `kit`: the repo's **prototype kit**: tokens, fonts, common pieces (a phone frame, cards, tiles) and real art. Start every page from it and inline what you use (§ 3), so each round is a standalone snapshot that a later token change never alters. When you draw a piece the kit lacks, add it to the kit in the work's PR so the next prototype has it.
- `components`: how to build or open the component library (Storybook or similar). Use it for Today and for options that rearrange existing parts; the kit for new concepts.
- `names`: the files whose labels the options must use word for word.

None set? Use the repo's tokens and theme files directly, and once you've built a kit, offer once to save it.

## 2. Pick the kind

| Kind | Each option shows |
| --- | --- |
| **Screen or layout** | The full screen at phone width (390 px) and desktop when it matters, with every state the change touches: rest, loading, empty, typing, no results, error. |
| **Interaction, motion or feel** | A working, clickable model in a phone frame with real timings from the code, a slow-motion toggle and a Reduce Motion toggle. Variants inside the app only when the user asks to feel them on their device. |
| **Visual direction** (logo, icon, palette, type) | Real sizes (16, 24, 56 px and large) on light and dark. |
| **Data or state logic** | Inputs on one side, the resulting state on the other, plus a table of transitions and edge cases. |
| **Native app states** | Real screenshots from a simulator (§ 3), one set per option, set up on a scratch branch or local flag you delete after. |
| **A plan, audit or review** (nothing to pick) | One readable page, published as **reference** (§ 4). |

## 3. Build the page

- **One page per topic, side by side per decision.** One section per decision (per screen state, per question); in it every option for that decision in one row at the same size, labeled A, B, C. Never a long list where the options for the same thing are far apart. On a phone the row may scroll sideways; it never stacks into a list.
- **2–4 genuinely different directions**, not variations of one. Each gets a short name, one line on the idea, what it costs (effort, risk, performance) and what it drops.
- **Box the recommendation in place:** outline the whole column of the option you recommend (2–3 px in the product's accent, matching corners, a small "Recommended" label) **in every row**, so the pick shows without scrolling. End the page with **My recommendation** and why.
- **Real copy, real data, the product's real look** (the kit, or its fonts, colors, spacing and components). Copy is literal and usually ships as written.
- **No hint copy.** Options never add instructional text for gestures ("swipe for next", "pull down to close", "tap to expand"). They reuse the way the app already does that job.
- **Options are pages, not app code.** Building variants into the app costs a whole build round; do it only when the user asks to feel them on a device.
- **Later rounds** go on the same page and voyage, with a short **Rounds** note at the top (what changed since the last round, from their notes).
- **One folder per topic, standing alone:** build in a scratch folder (`<scratchpad>/<slug>/`, slug `<issue>-<topic>`), never in the repo: `index.html` plus every file it uses (copies of the kit's CSS and JS, fonts, art, screenshots as JPEG around 1170 px wide), linked by relative paths (`tokens.css`, `art/poster.jpg`; paths built in JS work too). Copy files in rather than linking outside the folder, so a later change never alters a past round. Fleet serves the folder as is (nothing is inlined), up to 300 files and 60 MB. A single self-contained `index.html` works too. Pages run in a sandbox: scripts run, but no network calls outside the folder and no cookies.
- **Mark each option's section** with `data-variant="A"` (B, C…), its name in an element with class `name`, its one line in class `idea`, and add class `rec` to the recommended one: Fleet reads the options from the page, so you don't repeat them.
- **Native screenshots:** start the voyage first (§ 4 step 1), `lease` an `iphone` berth on it, `boot`, put the app on it (`${CLAUDE_PLUGIN_ROOT}/skills/loop/ios.md` § 2–3 covers install and Metro), set up each state, and either use `capture_lease_id` as an option's media or put the captures on the comparison page. **Release the lease right after `chart_options`.**
- **Check once before publishing:** screenshot the page at 390 px and 1280 px (`npx playwright screenshot --viewport-size=390,844 file://<path>/index.html <scratch>/check.png`), look, fix. One pass.

## 4. Publish to Fleet

With a Fleet key:

1. `voyage_start` with `course: "prototype"`, `goal` (one sentence: what's being decided), `repo` (`git remote get-url origin`), `issue` when there is one, and `op_id`. Reuse the earlier voyage instead when § 1 found one.
2. Zip the folder (`cd <scratchpad>/<slug> && zip -qr ../<slug>.zip .`), `upload_url` with `voyage_id` and `ext: "zip"`, then `curl -sS -T ../<slug>.zip '<uploadUrl>'` (quote the URL; check for HTTP 200). Keep the `blobKey`. (A single self-contained page: `ext: "html"` and pass it as `page: { blob_key }`.)
3. `chart_options` with `voyage_id`, a `note` (what this round decides and why you recommend your pick), **`page: { zip: <blobKey> }`** (the page, shown full width; the primary thing), `summary` (one line: what it is and what this round asks), `status_note` (`Pick A, B or C (recommended: A).`) and `links` (`[{ "number": 476, "title": "<issue title>", "pr": false, "state": "open" }]`). Options are optional: Fleet reads them from the page's `data-variant` sections, or pass them lightweight (`key`, `title`, `summary`, `recommended` on one), with `media` only for something that isn't on the page (a link, live captures).
4. Tell the user: the link (`https://fleet.osroc.io/app/prototypes/<voyage id>`), one line per option and your recommendation. Then `await_decision` with `wait_seconds: 600`; call it again when it says `still waiting` (up to 3 times). After that, stop: the pick is waiting in their Fleet Inbox, and `/fleet:prototype resume <voyage id>` carries on.

**Nothing to pick** (a plan, an audit, a review): upload the page, then `voyage_stage` with `status: "reference"`, a `note` on what it's for and the page as `media`. It closes the voyage and shows as Reference.

**The shape is Saga's** (Fleet's PROTOCOL.md § The prototype shape): title, summary, status, statusNote, rounds, links, created, updated, and per round one page. The **status** is one of seven and moves with the work: `waiting` (options up: the user picks) on publish, `feedback` (the user's notes: next round coming) when they ask for another round, `building` (picked, being built) on a pick, `review` (built, on staging or the phone: the user's green) with the build, `built` on Ship it, `parked` (set aside) when they park it, `reference` for reading. You move it to `building`, `review` and `reference` (`voyage_stage` with `status`, only on a voyage opened with `course: "prototype"`; Fleet refuses it on a plain one); the rest are the user's. Every move carries a one-line `status_note` on what's next ("Building option B (#123).", "On the preview build: check the empty state."); left out, Fleet uses the status's words.

**Importing an existing prototype** (a repo that already keeps them, like Saga's `prototypes.saga.pictures`): pull its folder, zip it, `upload_url` (`ext: "zip"`, any voyage of yours) and `prototype_import` with `repo`, `slug` (its folder name), `meta` (its `meta.json` verbatim), `zip` and, for `building`/`review`/`built`, `picked` (the option key). It lands at `meta.status`, keeps summary, statusNote, rounds, links and dates, links earlier rounds' `round-N.html`, and importing the same slug again syncs it instead of duplicating. A slug never matches an older import without one: to swap that one (or a stale copy) for the fresh import, pass `replace_id` with its id from `prototype_index` (`replace: true` starts the same slug over); the new one is made first, then the old one archived, so one copy is left. `prototype_archive` (id, or slug with `repo`) takes a stale or mistaken prototype out of the user's Prototypes; nothing is deleted, and deleting for good is the user's, on the dashboard.

**Kept and shareable.** Fleet keeps prototype pages and screenshots until the user deletes the prototype. For testers without a Fleet account, the user makes a read-only **share link** on the prototype's page (Share with testers; they can turn it off any time); picks still happen in Fleet. Say so once when the user mentions testers.

Without a Fleet key: give the user the local file path (or publish it the way the repo's docs say) with the same lines, and ask which one in chat. Mention `/fleet:login` once.

Put the voyage link on the work's GitHub issue if there is one.

## 5. The pick

`await_decision` returns the decision and `nextStep`. Do what it says:

- **Build `<option>`:** the voyage moves to `building`. Run `fleet:build` with the picked option (its title, summary and media are in the result), the topic and the `voyage_id`, so the review lands on the same voyage. Delete scratch flags and losing variants as part of the build.
- **Another round (notes):** the next round on the **same** voyage and page, shaped by the notes: keep what they liked, drop what they didn't, update the Rounds note, and `chart_options` again (round 2, 3…). Then wait again.
- **Park:** it's set aside (status `parked`). Say so in one line, clean up scratch branches and leases, done.
- **Snoozed until <time>:** the user snoozed it; `await_decision` says so at once. Don't wait or ask again: list it under Options waiting on you with "snoozed until <time>", do other work, and check back after that time (`/fleet:prototype resume <voyage id>`).

Record taste the user states ("less bouncy", "old-fashioned, not cruise ship") in the repo's design doc when the work lands.

## Before you report

Every lease released (`release`), scratch servers and simulators stopped, scratch branches deleted.

**Report** in the shape of fleet-workflows § Reporting: open with what this round decides, one line per option and your recommendation, then the fixed sections (Callouts, Waiting on you, PR links, Options waiting on you), with the prototype's link under **Options waiting on you**.

**Next:** `fleet:build` with the pick (call it directly once the user picked; that's the go-ahead to build, not to ship).
