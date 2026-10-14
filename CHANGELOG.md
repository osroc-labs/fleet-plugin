# Changelog

One line per release of the `fleet` plugin, newest first, with the osroc-labs/fleet issues it closes. Update with `claude plugin marketplace update osroc && claude plugin update fleet@osroc`, then start a new session. Server-side changes (new MCP tools, dashboard) go live on fleet.osroc.io without a plugin update; a new session picks up new tools.

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
