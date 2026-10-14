# fleet:loop, ios mode: iPhone, iPad and Apple TV apps

For iOS, Expo and React Native apps (and Swift/Objective-C ones). This is how `fleet:loop`'s verify step (§ 4) and review step (§ 6) work on Apple devices; `fleet:verify`, `fleet:prototype` and `fleet:ship` point here for the same jobs. `/fleet:ios-loop` is `/fleet:loop ios`. The repo's own iOS notes (CLAUDE.md, docs, an `ios` or `e2e:ios` script) win over everything here.

## 1. Read the repo, once

`sh "${CLAUDE_PLUGIN_ROOT}/scripts/fleet-repo"` and the settings' `ios` block (shared rules § The repo). Work out, and confirm once with the rest of the loop's settings:

- **Kind:** `expo-dev-client` (`expo-dev-client` in package.json), `expo-go` (Expo, no dev client, no `ios/`), `react-native` (bare, `ios/` checked in), or `native` (an `.xcodeproj`/`.xcworkspace`, Swift/Objective-C).
- **Workspace and scheme:** `ios/<Name>.xcworkspace` (or the `.xcodeproj`); `xcodebuild -list -workspace <ws>` lists schemes. Expo projects without `ios/` get one from `npx expo prebuild -p ios` in a scratch worktree (never commit a generated `ios/` the repo doesn't track; check `.gitignore`).
- **Bundle id** (`ios.bundleIdentifier` in app.json, or `PRODUCT_BUNDLE_IDENTIFIER` from `xcodebuild -showBuildSettings`) and **URL scheme** (`scheme` in app.json, or `CFBundleURLSchemes`).
- **The device:** `ios.simulator` (`iphone`, `iphone:17 pro`, `ipad`, `appletv`); default `iphone`.

## 2. Get a simulator

**A Fleet berth** (with a Fleet key; preferred, so the user's Mac stays free):

1. The task's voyage (the loop started it; on a slot it's the agent's own crew voyage).
2. `fleet_status`: pick a Mac that's online with a free (`ashore`) berth of the right kind and room to boot (`host.capacity.canBoot` above 0 when it's reported). Note its CPU (Apple silicon is `arm64`) and iOS runtime: the build must match them.
3. `lease` with `target` from the settings, `wait_seconds: 120`, `op_id` `loop-<issue>-lease-<round>`. Then `boot` (the first boot can take about 40 s). Leasing again on the same voyage gives the same berth back.

**A local simulator** (no key, no free berth, or the repo's docs say local): headless only. `xcrun simctl list devices available`, `xcrun simctl boot <udid>`. Never open the Simulator app (its windows cover the user's screen, and quitting it shuts every simulator down). Screenshots: `xcrun simctl io <udid> screenshot <file>.png`. At most 3 booted at once on the user's Mac unless the repo says otherwise; back-to-back tasks in one slot reuse its booted simulator instead of rebooting.

## 3. Put the app on it

Pick the fastest path that works:

**A. A simulator build with the JavaScript inside (Release).** No Metro and no tunnel, and it's what users run. Default for a Fleet berth when there's no tunnel tool.

```sh
xcodebuild -workspace ios/<Name>.xcworkspace -scheme <Scheme> -configuration Release \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath <scratch>/DerivedData ARCHS=arm64 ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build
ditto -c -k --sequesterRsrc --keepParent <scratch>/DerivedData/Build/Products/Release-iphonesimulator/<Name>.app <scratch>/app.zip
```

(Native apps: `-project`/`-scheme` the same way; Debug is fine for them. Keep one DerivedData folder, shared by every slot, so rebuilds are incremental and nothing is duplicated. Use `ARCHS=x86_64` for an Intel Mac. No Xcode here? An EAS build with an `"ios": { "simulator": true }` profile gives a `.app` too.)

Then `upload_url` with `ext: "zip"`, `curl -sS -T <scratch>/app.zip '<uploadUrl>'`, `install_app` with the `blob_key`, and `launch_app` with the bundle id. Keep the `blob_key`: until native code or JavaScript changes, reinstall it next round instead of rebuilding (uploads last a day).

**B. The dev client plus Metro, for hot reload** (`expo-dev-client` or bare React Native in Debug):

1. Build and install a Debug simulator build once, as in A with `-configuration Debug` (reuse it until native code changes).
2. Start Metro in the background on the slot's port: `CI=1 npx expo start --dev-client --port <port>` (bare RN: `npx react-native start --port <port>`).
3. A Fleet berth can't reach this Mac's `localhost`. Tunnel it:
   - with the `fleet` CLI: `fleet expose <port> --lease <lease id> --scheme <url scheme>` (opens the dev client on the tunnel);
   - else with `cloudflared`: `cloudflared tunnel --url http://localhost:<port>`, read its `https://….trycloudflare.com` URL, then `open_url` `<scheme>://expo-development-client/?url=<that URL, percent-encoded>`.
   - If the app loads but asks for `localhost` bundles, restart Metro with `EXPO_PACKAGER_PROXY_URL=<tunnel URL>` and reopen.
   - Neither tool installed: use path A, and mention once that `brew install cloudflared` (or the `fleet` CLI from https://fleet.osroc.io) enables hot reload. Don't install software without asking.
   On a local simulator skip the tunnel: `xcrun simctl openurl <udid> "<scheme>://expo-development-client/?url=http%3A%2F%2Flocalhost%3A<port>"`.
4. **Restart Metro after a merge** into the branch it serves (without watchman it can keep serving the old files), then relaunch the app.

**C. Expo Go projects:** Fleet berths don't have Expo Go. Use A after `npx expo prebuild -p ios` in a scratch worktree, or a local simulator with `npx expo start --ios`.

**Web pages:** `open_url` with an `https://` URL (Safari).

## 4. The smoke test (the loop's verify step)

A few minutes proving the change works at all: not the test suite.

- Typecheck and lint the touched files (the repo's commands) alongside.
- `screenshot` and actually look at it. `describe_ui` for labels; `tap` by `label` (or `id`), `type_text`, `swipe`, `press_button`. Screenshot after every step that changes the screen. Pass an `op_id` on every call (`smoke-<issue>-tap-1`).
- Walk the review's test steps end to end: open it, use each control, close it, open it again. Then the states it touches (empty, error, long text, keyboard up, dark mode with `set_appearance`).
- **Every variant, not a sample:** if the change touches a component with many variants, look at each one.
- Watch Metro's output (path B) or the app for red screens, warnings and crashes.
- Fix and repeat until it works. The simulator can't show haptics, real performance or 120 Hz: say so in the review note.

## 5. Test what users run: the release replica

The dev client is for building, not sign-off: native interactions (context menus, previews, gestures, anything from a native module) can work in Debug and fail in Release. When the repo ships over-the-air updates (`commands.deployPreview`), smoke the **published preview** itself before the user is told:

- Keep one Release simulator build with the same native code as the users' build (its fingerprint matches), set to pull preview updates (`EXUpdatesRequestHeaders` → `expo-channel-name: preview` in `Expo.plist`). Rebuild it only when native code changes.
- A fresh build's embedded update is newer than anything published, so it never loads one: set `commitTime` to `1` in `<App>.app/EXUpdates.bundle/app.manifest`, re-sign (`codesign --force --sign - --preserve-metadata=entitlements,identifier <App>.app`), then install.
- Each round, after publishing: launch it twice about 15 s apart (the first downloads, the second runs it), check it runs the new update, and walk the steps again.
- If the replica and the dev client disagree, the replica wins; note the difference in the repo's gotchas.

## 6. Up for review (the loop's § 6, on iOS)

- `voyage_stage` `review` with `media` as `capture_lease_id` of the berth (captured now, copied, so they outlive it), or uploaded screenshots (`blob_key`), up to 6. Then **release the lease**.
- The user tests on their own phone when the repo has a preview (`commands.deployPreview`, e.g. an over-the-air update to a preview channel): publish from a clean, pushed tree (`git status --short` empty, `HEAD` pushed; never chain a publish after a merge without checking it), smoke it on the replica (§ 5), and add "On your phone:" with how to get it and the build label to look for. A preview channel holds one update: with several slots, publish `loop/review` (`fleet:loop` § Slots).
- With `greenShips: true`, the user's Ship it after testing on their phone is the yes to merge and ship that task (an over-the-air update to production follows the repo's deploy, from the main branch).
- Native changes (a new native module, entitlements, widgets) can't ride an over-the-air update: collect them on one branch for the next store build, which reaches every tester and needs the user's yes; keep the loop busy with tasks that can ship over the air meanwhile.

## 7. Clean up (every report, every stop)

- Every lease released. Metro, tunnels (`fleet expose`, `cloudflared`) and background shells stopped. Local simulators you booted shut down (`xcrun simctl shutdown <udid>`) as soon as no queued task needs them; when the loop is idle, all of them.
- Check: `xcrun simctl list devices booted`, and `lsof -iTCP -sTCP:LISTEN -n -P | grep -E ':(808[1-6])'` show nothing of yours that isn't still in use.
