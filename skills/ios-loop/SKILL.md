---
name: ios-loop
description: The iPhone build loop for iOS, Expo and React Native apps. Lease a simulator from the user's Fleet (or use a local one), build or install the app, run it, smoke test the change with taps, typing and screenshots, then put the result up for the user's review in Fleet and iterate on their notes until they say ship it. Use for iPhone or iPad work in an iOS/Expo/React Native repo, when fleet:build hands off to it, or when the user runs /fleet:ios-loop. If the repo has its own ios-loop skill, use that instead.
argument-hint: "[task or issue] | 2 (two tasks at once) | resume <voyage id>"
allowed-tools: Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-repo"), Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-repo" *), Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-login" check)
---

# /fleet:ios-loop: build → simulator → smoke test → the user's review

Input: **$ARGUMENTS**

Fleet key: !`sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-login" check`

Read the shared rules once per session: `${CLAUDE_PLUGIN_ROOT}/skills/fleet-workflows/SKILL.md`.

| Input | What happens |
| --- | --- |
| a task, an issue number, or a hand-off from `fleet:build` | Build that one (§ 1–6). |
| `2` | Two tasks at once (§ 7). |
| `resume <voyage id>` | `voyage_resume`, then do its `nextStep`. |

**Fast now, near-perfect before it merges.** Nothing runs between an edit and the user's review except a typecheck, lint on the touched files and a few-minute smoke test on a simulator. Full test coverage and every gate come after the user's green (§ 6), so the user is never left waiting. Coverage is moved, never skipped.

## 1. Read the repo, once

`sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-repo"` and the settings' `ios` block (shared rules § The repo). Work out, and confirm once:

- **Kind:** `expo-dev-client` (`expo-dev-client` in package.json), `expo-go` (Expo, no dev client, no `ios/`), `react-native` (bare, `ios/` checked in), or `native` (an `.xcodeproj`/`.xcworkspace`, Swift/Objective-C).
- **Workspace and scheme:** `ios/<Name>.xcworkspace` (or the `.xcodeproj`); `xcodebuild -list -workspace <ws>` lists schemes. Expo projects without `ios/` get one from `npx expo prebuild -p ios` in a scratch worktree (never commit a generated `ios/` the repo doesn't track; check `.gitignore`).
- **Bundle id** (`ios.bundleIdentifier` in app.json, or `PRODUCT_BUNDLE_IDENTIFIER` from `xcodebuild -showBuildSettings`) and **URL scheme** (`scheme` in app.json, or `CFBundleURLSchemes`).
- The repo's own iOS notes (CLAUDE.md, docs, an `ios`/`e2e:ios` script) win over everything here.

Work on the task's branch (`fleet:build` made it; otherwise make one: shared rules § 2).

## 2. Get a simulator

**A Fleet simulator** (with a Fleet key; preferred, so the user's Mac stays free):

1. A voyage: reuse the one handed over (from `fleet:prototype` or `fleet:build`), or `voyage_start` with `goal`, `repo` and `op_id`. Then `voyage_stage` `building` with a one-line note.
2. `fleet_status`: pick a Mac that's online with a free (`ashore`) iPhone. Note its CPU (Apple silicon is `arm64`) and iOS runtime: the build must match them.
3. `lease` with `target: "iphone"` (or `"iphone:17 pro"`, `"ipad"`), `wait_seconds: 120`. Then `boot` (the first boot can take about 40 s).

**A local simulator** (no key, no free berth, or the repo's docs say local): headless only. `xcrun simctl list devices available`, `xcrun simctl boot <udid>`. Never open the Simulator app (its windows cover the user's screen, and quitting it shuts every simulator down). Shut it down when you're done (§ 8). Screenshots: `xcrun simctl io <udid> screenshot <file>.png`.

## 3. Put the app on it

Pick the fastest path that works:

**A. A simulator build with the JavaScript inside (Release).** No Metro and no tunnel, and it's what users run. Default for a Fleet simulator when there's no tunnel tool.

```sh
xcodebuild -workspace ios/<Name>.xcworkspace -scheme <Scheme> -configuration Release \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath <scratch>/DerivedData ARCHS=arm64 ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build
ditto -c -k --sequesterRsrc --keepParent <scratch>/DerivedData/Build/Products/Release-iphonesimulator/<Name>.app <scratch>/app.zip
```

(Native apps: `-project`/`-scheme` the same way; Debug is fine for them. Keep one DerivedData folder so rebuilds are incremental. Use `ARCHS=x86_64` for an Intel Mac. No Xcode here? An EAS build with an `"ios": { "simulator": true }` profile gives a `.app` too.)

Then `upload_url` with `ext: "zip"`, `curl -sS -T <scratch>/app.zip '<uploadUrl>'`, `install_app` with the `blob_key`, and `launch_app` with the bundle id. Keep the `blob_key`: until native code or JavaScript changes, reinstall it next round instead of rebuilding (uploads last a day).

**B. The dev client plus Metro, for hot reload** (`expo-dev-client` or bare React Native in Debug):

1. Build and install a Debug simulator build once, as in A with `-configuration Debug` (reuse it until native code changes).
2. Start Metro in the background on a free port: `CI=1 npx expo start --dev-client --port <port>` (bare RN: `npx react-native start --port <port>`).
3. A Fleet simulator can't reach this Mac's `localhost`. Tunnel it:
   - with the `fleet` CLI: `fleet expose <port> --lease <lease id> --scheme <url scheme>` (opens the dev client on the tunnel);
   - else with `cloudflared`: `cloudflared tunnel --url http://localhost:<port>`, read its `https://….trycloudflare.com` URL, then `open_url` `<scheme>://expo-development-client/?url=<that URL, percent-encoded>`.
   - If the app loads but asks for `localhost` bundles, restart Metro with `EXPO_PACKAGER_PROXY_URL=<tunnel URL>` and reopen.
   - Neither tool installed: use path A, and mention once that `brew install cloudflared` (or the `fleet` CLI from https://fleet.osroc.io) enables hot reload. Don't install software without asking.
   On a local simulator skip the tunnel: `xcrun simctl openurl <udid> "<scheme>://expo-development-client/?url=http%3A%2F%2Flocalhost%3A<port>"`.

**C. Expo Go projects:** Fleet simulators don't have Expo Go. Use A after `npx expo prebuild -p ios` in a scratch worktree, or a local simulator with `npx expo start --ios`.

**Web pages:** `open_url` with an `https://` URL (Safari).

## 4. Smoke test (before the user sees anything)

A few minutes proving the change works at all: not the test suite.

- `screenshot` and actually look at it. `describe_ui` for labels; `tap` by `label` (or `id`), `type_text`, `swipe`, `press_button`. Screenshot after every step that changes the screen. Pass an `op_id` on every call (`smoke-<task>-tap-1`).
- Walk the happy path of the change end to end: open it, use each control, close it, open it again. Then the states it touches (empty, error, long text, keyboard up, dark mode with `set_appearance`).
- **Every variant, not a sample:** if the change touches a component with many variants, look at each one.
- Watch Metro's output (path B) or the app for red screens, warnings and crashes.
- Typecheck and lint the touched files (the repo's commands) alongside. Fix and repeat until it works.
- Simulators can't show haptics, real performance or 120 Hz: say so in the review note.

## 5. Put it up for review

1. Commit, push the branch (shared rules § 2), and open or update a **draft PR**. `voyage_git` with branch, PR, sha and `pushed: true`.
2. Write the user's **test steps**: 3 to 6 steps, one action each, starting with where ("Settings → tap Notifications"), each followed by what they should see on its own line, in the words on screen (never code names). End with one `Green:` line: the one-sentence bar.
3. `voyage_stage` with `stage: "review"`, `note` = the steps (plus what the simulator couldn't show), and `media`: up to 6 screenshots of the result, as `capture_lease_id` (captured now) or uploaded images (`blob_key`). Captures are copied, so they outlive the simulator.
4. **Release the lease now** (`release`). Don't hold a simulator while the user decides; the next round leases again and reinstalls from the `blob_key`.
5. If the user tests on their own phone and the repo has a preview command (`commands.deployPreview`, e.g. an over-the-air update to a preview channel), publish it from a clean, pushed tree as the repo's rules say (ask once if the repo has none, never to production), and add "On your phone:" with how to get it.
6. Tell the user in a few lines: the review link (`https://fleet.osroc.io/app/voyages/<voyage id>`), the steps, the branch and sha. Then `await_decision` with `wait_seconds: 600`, again while it says `still waiting` (up to 3 times), then stop and say it's in their Fleet Inbox; `/fleet:ios-loop resume <voyage id>` carries on.

Without a Fleet key: send the screenshots' paths and the steps in chat and ask for green or red.

## 6. The verdict

- **Fix (notes), or red in chat:** write the notes on the task's issue or PR (they become regression tests later), fix on the same branch, and go round again (§ 2–5). One round per review; minutes, not hours.
- **Ship it, or green in chat:** the change is right. Now make it solid, off the user's clock: merge the main branch in, cover it (unit tests for the logic, the repo's UI or e2e tests for the changed flow, a regression test for every fix asked for), delete leftovers (losing variants, flags), run every gate, then `fleet:verify`, `fleet:review` and `fleet:ship`. With `greenShips: true` in the settings, Ship it is also the yes for production; otherwise `fleet:ship` asks once. Ship it closes the voyage as built.
- **Tuck away:** stop. Leave the PR as a draft and say so in one line.

## 7. Two at once (`/fleet:ios-loop 2`)

1. **Pick two tasks that don't collide** (different screens or components, so their branches merge cleanly). Say which and why in one line.
2. **One background agent per task** (`Agent`, `isolation: "worktree"`), each with: the task, its branch, the area it owns and the one it must not touch, "read `${CLAUDE_PLUGIN_ROOT}/skills/ios-loop/SKILL.md` § 1–5", its own voyage (`voyage_start` with `parent_voyage_id` = yours and `crew` = the task's short name, so each gets its own simulator), its own Metro port, and "stop everything you started and release your lease before reporting; report branch, sha, voyage id and the test steps."
3. While they build, you conduct: read each report, glance at the diff (stayed in its area?), and pass the user's verdicts back to the right agent (`SendMessage`). Each task ships on its own branch.
4. Don't run two heavy jobs (full test suites, Release builds) on the user's Mac at once: queue them. No polling loops; wait for completion notices.

## 8. Before you report

- Every lease released. Metro, tunnels (`fleet expose`, `cloudflared`) and background shells stopped. Local simulators you booted shut down (`xcrun simctl shutdown <udid>`).
- Check: `xcrun simctl list devices booted`, and `lsof -iTCP -sTCP:LISTEN -n -P | grep <your ports>` show nothing of yours.
- Report: what's up for review (link), branch · sha, the PR, what the simulator couldn't check, and what's left running and why (rarely anything).

**Next:** on green, `fleet:verify` → `fleet:review` → `fleet:ship`; on Fix, another round of this loop.
