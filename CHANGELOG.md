# Changelog

One line per release of the `fleet` plugin, newest first, with the osroc-labs/fleet issues it closes. Update with `claude plugin marketplace update osroc && claude plugin update fleet@osroc`, then start a new session. Server-side changes (new MCP tools, dashboard) go live on fleet.osroc.io without a plugin update; a new session picks up new tools.

## Unreleased
- Less context per session: one-line skill and command descriptions (about 1,500 to 770 tokens), and the MCP tool descriptions and server instructions cut by about 44% (server side, no plugin update needed); the detail moved into the skills (berths: leases, sticky berths, Metro tunnels, Maestro flows).
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
