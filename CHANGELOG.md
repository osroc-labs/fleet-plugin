# Changelog

Releases of the `fleet` plugin, newest first, with the osroc-labs/fleet issues they close. Update with `claude plugin marketplace update osroc && claude plugin update fleet@osroc`, then start a new session. Server-side changes (new MCP tools, dashboard) go live on fleet.osroc.io without a plugin update; a new session picks up new tools.

## 1.1.0
- **Builds:** the berths skill installs the project's own builds first: `install_app { profile }` (or `build_id`) picks the newest EAS build of that profile Fleet holds and names it; `builds` lists them; `register_build` after your own `eas build`; `bundle_id` is the Mac's cached copy first. Builds reach Fleet through the EAS webhook (project page › Builds › Connect EAS) or `fleet builds sync` (CLI 0.10.0+).
- **Replicas:** after `eas update`, `replica_check { project, expect_group }` says whether each installed runtime's twin runs the update (OK, BEHIND, MISMATCH, CRASHED, ERROR); `fleet replicas check --expect-from` for scripts (exit 0 / 3 / 1; CLI 0.10.1).
- No plugin code changed: the tools come from the server.

## 1.0.0
Fleet is simulators now. The plugin is one package again, `fleet@osroc`, and it carries only what the product does: simulator and emulator berths on your Macs, with the Expo tooling around them.

- **Back in `fleet`:** the `berths` skill (now `fleet:berths`) and the quick look, now **`/fleet:sim`**. They came from `fleet-sims`, which is retired; uninstall it with `/plugin uninstall fleet-sims@osroc`. Android berths (`android`, `android:small`, `androidtablet`; runner 0.9.0 on a Mac with the Android SDK) are in, from fleet-sims 0.2.0 (osroc-labs/fleet#24).
- **Removed: session tracking.** The hooks (SessionStart through SessionEnd), the local queue and sender (`~/.fleet/wayfind`), `/fleet:find`, `/fleet:join`, and the Sessions pages on the dashboard. Nothing about your Claude Code sessions is sent any more; the plugin is silent until a Fleet tool is called. Fleet answers old plugin versions that still send session events with 410 and how to update. `rm -rf ~/.fleet/wayfind` clears the old queue.
- **Removed: workflows and prototypes.** `fleet-workflows` (the loop, lanes, idea, prototype, build, verify, review, ship, triage, ios-loop, the `/fleet` front door, the two guard hooks) is retired; uninstall it with `/plugin uninstall fleet-workflows@osroc`. The prototype tools (`chart_options`, `prototype_import`, `prototype_archive`, `prototype_index`, `await_decision`, `voyage_stage`) and the loop tools (`loop_start`, `loop_lane`, `loop_desired`, `loop_update`) are gone from the MCP; `voyage_start` takes `goal`, `repo`, `parent_voyage_id` and `crew` only, and `voyage_close` takes `summary`.
- **Removed: the Features switches.** Every account sees the simulator screens and tools; nothing to turn on in Settings.
- **Why:** the simulators on your Macs are what Fleet is for, with the Expo tooling around them. Session logging, prototypes and the build loop were a second product in the same plugin; without them the plugin is one skill and one MCP, and the privacy story is one line: only the MCP calls and uploads you make leave your machine.
- The berths skill always opens a voyage with `voyage_start` (with the repo's `origin`) and closes it with `voyage_close`; it no longer reads a session's voyage from `~/.fleet/wayfind`.
- `/fleet:status` shows Macs, berths, leases and what needs you (no live sessions). `/fleet:help` is rewritten for berths.
- `scripts/`: `lib.sh` keeps the key, server and config helpers; `fleet-api` keeps `macs` and `inbox`. `fleet-hook`, `fleet-send`, `fleet-join` and `fleet-repo` are deleted. `tests/`: `features.sh`, `send-json.sh` and `shared-scripts.sh` went with what they tested; `tests/lint.sh` checks that the scripts parse, the JSON is valid and the commands point at scripts that exist.

## 0.8.16 (never released; folded into 1.0.0)
- **fleet-sims 0.2.0: Android berths** (osroc-labs/fleet#24): lease `android`, `android:small` (1080×1920) or `androidtablet`; the berths skill says what differs from iOS (APK installs, pixels, Android buttons and settings, demo mode, logcat), and `/fleet-sims:sim` takes `android` and an `.apk`. Needs runner 0.9.0 on a Mac with the Android SDK (`fleet runner update`).
- fleet-social is retired; uninstall it with /plugin uninstall fleet-social@osroc (then `rm -rf ~/.fleet/social`). It's gone from the marketplace, and Fleet answers its sign-in and presence with "Fleet Social is retired". Its key keeps working for `fleet`. The full plugin's hook no longer marks sessions for it.
- **Split by feature:** `fleet` keeps the session log, Fleet's MCP and `/fleet:login`, `/fleet:status`, `/fleet:find`, `/fleet:join`, `/fleet:help`. The simulator skill and `/fleet:sim` move to **`fleet-sims`** (`/fleet-sims:sim`); the loop and the workflow skills (`/fleet:loop`, idea, prototype, build, verify, review, ship, triage, ios-loop, the `/fleet` front door) and the two opt-in guard hooks move to **`fleet-workflows`** (`/fleet-workflows:loop` …). Install the ones you use: `/plugin install fleet-sims@osroc`, `/plugin install fleet-workflows@osroc`. Turn one off in a repo with `{ "enabledPlugins": { "fleet-workflows@osroc": false } }` in its `.claude/settings.json`. Skill and command descriptions loaded per session: about 100 tokens for `fleet`, 80 for `fleet-sims`, 610 for `fleet-workflows`.
- **Features switch the hooks:** the hourly probe (`GET /api/wayfind`) now says whether this account's Sessions is on and how much it keeps (Settings › Features and Privacy on the dashboard). Off: the hooks queue nothing and the sender sends nothing (one probe an hour, so turning it back on is seen). Activity: no prompts, replies, check-ins, session names or backfill leave the computer; commits, PRs, deploys and waits still go. Presence: only that a session runs. The server keeps no more than the level anyway, and an older server (no answer) means everything, as before.
- The guard hooks no longer run in `fleet`, so a session with only `fleet` spawns nothing after each tool call.
- Tests: `tests/features.sh` (off, activity, presence, full against a fake server) and `tests/shared-scripts.sh` (the sub-plugins' copies of the helpers match `scripts/`).

## 0.8.15
- Less context per session: one-line skill and command descriptions (about 1,410 to 690 tokens loaded each session), and the MCP tools list cut from about 14,300 to 7,600 tokens (server side, no plugin update needed); the detail moved into the skills (berths: leases, sticky berths, Metro tunnels, Maestro flows).
- `fleet-guard` costs almost nothing when off: a builtin-only check of `.fleet/workflow.json` before it loads anything, so the after-every-tool hook no longer runs git or grep (about 17 ms to 4 ms a call). On, it behaves exactly as before.
- GitHub integration removed (the Quartermaster app, orders from ⚓ set sail and /sail, Ship's log comments and checks on issues and PRs): `/fleet:commission` is gone (projects come from sessions and Add project; pick the avatar on the project's page), the loop takes tasks from your Fleet Inbox, then GitHub issues via `gh`, then the roadmap, and builds record git with `voyage_log` `git`. The skills' own `gh` use (issues, PRs, the loop's board comment) is unchanged.

## 0.8.14
- Long calls never hang: `run_flow`, `boot`, `install_app`, `record_stop` and `launch_app` (with an update wait) answer within 45 s with "Still running" and an op id; `op_result` returns the result. A same-op-id retry returns the first result instead of re-running. `await_decision` waits at most 45 s per call (#21).
- Plain-word device errors, a pruned `describe_ui` (`raw: true` for the full tree), and an "out of date" note for old runners (#23).
- Pick the iOS version per lease (`runtime: newest | previous | beta | 26.5`); `launch_app` says which EAS update is running and whether the app crashed, with the crash report (#26, #27). Needs runner 0.8.0 (`fleet runner update`).

## 0.8.13
- Fix: session logging dropped batches whenever a subagent finished (and on PR, issue and artifact links). macOS's /bin/sh split a `{…}` literal into two arguments, so the event was invalid JSON and the server refused the whole batch. Every event is now checked, and a bad one is skipped and logged instead of losing the batch.

## 0.8.12
- `voyage_stage` is for prototypes only; a plain session is refused instead of becoming a prototype (#22). `prototype_import` can `replace` an older import (by slug or `replace_id`), and the new `prototype_archive` tool archives or restores one (#20).

## 0.8.11
- More iPhones: each Mac can run iPhone 18 Pro Max, iPhone 17e and iPhone Air next to the 18 Pro (Mac page › Simulators by type). Lease them with `iphone:pro max`, `iphone:17e`, `iphone:air`; plain `iphone` stays the 18 Pro. Needs runner 0.7.0 (`fleet runner update`).

## 0.8.10
- Friends: up to 50; add a friend by email from Friends (they accept in their Inbox, or when they first sign in); invites survive any sign-in route and the plugin logins; every friend's boat waits at their island in World when they're away.

## 0.8.9
- Fleet Social: join World without the toolkit (an invite link and `fleet-social`). New accounts see World and Friends only; turn tabs on in Settings › Tabs, and the full plugin turns the work tabs on by itself.

## 0.8.8
- Prototypes have Saga's shape: title, summary, status (waiting, review, feedback, building, built, parked, reference), status note, rounds, issue links; one folder per topic published zipped as the round's `page` (served at relative paths, never inlined); options optional (read from `data-variant`); earlier rounds kept. `prototype_import` takes a Saga `meta.json` + zip as-is, idempotent by slug, including picked-but-building (#18). Snooze a prototype until later; Tuck away is now Park.

## 0.8.7
- Berths: device builds (`.ipa`) are refused in plain words; `fleet build-sim` makes a simulator build for Expo projects with no EAS simulator build (prebuild, xcodebuild, zip, optional install) (#16).
- `run_flow secrets`: pass names only; the runner Mac reads the values (`fleet secrets set|list|rm|import`) and masks them (#17). Needs runner 0.6.0 (`fleet runner update` on each Mac).

## 0.8.6
- `/fleet:help` can be run by Claude (no longer user-only), so "run /fleet:help and summarize what changed" works. This changelog ships with the plugin. (#19)

## 0.8.5
- Prototypes work like Saga's: one living side-by-side page per topic (`chart_options compare`), labels from the code, ten minutes to the first link, `prototype.kit/components/names` settings, `prototype_index` read first. (#11)
- Tester share links (`/share/<token>`), `reference` stage and status notes on every move, prototype media kept permanently in R2. (#12)
- The loop passes status notes; feel choices go on the prototype page first; the shared stage words cover reference and feedback.

## 0.8.4
- The loop: label and test steps inside the preview build, protected review environment (#4); verdicts and feedback from the app tied to the reviewed sha (#5); first slice in 15 minutes, check-ins every 10, ship by sha (#6); a resumable status board on a GitHub issue (#9).

## 0.8.3
- `fleet:review … round <since-sha>`: review only what's new, checked against the user's own words (#8).
- `verify.smoke` signed-in checks, `verify.absentInProduction`, flaky tests rerun once and tracked (#13).
- `ship.targets`, `ship.environmentCheck`, `ship.nativeCheck`, `ship.changelog` (#14).

## 0.8.2
- fleet-workflows § Agents: model and effort per job; opt-in hooks `agents.enforceBriefs` and `agents.unpushedWork` (the `fleet-guard` script) (#7).
- § Reporting: fixed closing sections (Callouts, Waiting on you, PR links, Options waiting) and a link on every action (#10).
- Worktrees always (`worktreesOnly`), push back on worse defaults, standing feedback written into the repo (#15).

## 0.8.1
- `/fleet:help`: a plain-words guide with everyday workflow examples.

## 0.8.0
- Sessions read like a conversation: Claude's replies and real times.

## 0.7.3
- Sessions take the name Claude Code shows (its own title when not renamed).
