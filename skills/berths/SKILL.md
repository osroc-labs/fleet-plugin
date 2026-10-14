---
name: berths
description: Lease a real iPhone, iPad or Apple TV simulator from your Fleet to see, test, screenshot or tap through an iOS, iPadOS or tvOS app, an Expo or React Native dev build, or a web page in Safari. Use whenever you need to look at an app or page on an Apple device instead of guessing.
---

# Berths: an Apple simulator on demand

A berth is a simulator slot on a Mac in the user's Fleet. Everything goes through the fleet MCP.

1. **See what's free:** `fleet_status`. Berths that are `ashore` are free; `adrift` means that Mac is offline.
2. **Have a voyage:** this session's is the first line of `~/.fleet/wayfind/sessions/${CLAUDE_SESSION_ID}` (read it); without one, `voyage_start` with `repo` from `git remote get-url origin`.
3. **Lease:** `lease` with `voyage_id` and `target` `iphone`, `ipad` or `appletv`. Plain `iphone` is the default iPhone (the newest Pro); pick another model by name where a Mac has it: `iphone:pro max` (largest), `iphone:17e` (smallest, a notch), `iphone:air`. To test on the iOS your users run, pass `runtime`: `newest` (the highest release in the fleet), `previous` (the newest release of the major before), `beta`, or a version like `26.6`; the result's `runtime` says which you got, a Mac that has it makes a berth on it if none is free, and when no Mac has it the lease fails saying how to install it (don't fall back to another version without saying so). Leasing again on the same voyage gives the same berth back.
4. **Boot** if it isn't: `boot`. The first boot of a berth can take about 40 seconds.
5. **Put the app on it:**
   - A build: zip the `.app`, get `upload_url`, PUT the zip there, then `install_app` with the `blobKey` and `launch_app` with the bundle id. An EAS **simulator** build goes in directly: `install_app` with `url` (`eas build:view <id> --json` → `artifacts.buildUrl`, from a profile with `"ios": { "simulator": true }`).
   - **Only simulator builds run on a berth.** A store or ad hoc `.ipa` (EAS's `production` or `preview` profile) is a device build, and `install_app` refuses it. No EAS simulator build? Build one here: in an Expo project, `fleet build-sim --profile preview --lease <lease id>` (prebuilds when there's no `ios/`, builds Release for the simulator, ad hoc signed so sign-in works, zips, uploads and installs). By hand: `npx expo prebuild -p ios`, `xcodebuild -workspace ios/<Name>.xcworkspace -scheme <Name> -configuration Release -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath <scratch>/dd CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO build`, `ditto -c -k --keepParent <scratch>/dd/Build/Products/Release-iphonesimulator/<Name>.app app.zip`, then `fleet install <lease id> app.zip` (or `upload_url` + `install_app` `blob_key`).
   - **Did it launch, and on which update?** On runner 0.8.0+ `launch_app` watches the app for a few seconds (`watch_seconds`, default 5) and says whether it **crashed** (exception, the crashed thread's frames, a link to the `.ips`) and, for an expo-updates app, which update is running (id, group, created, channel) and any newer one waiting for the next launch. To check a published update: `launch_app` with `wait_for_update_seconds`, and confirm the relaunch runs the update id you published. `app_logs` shows every crash report since the lease began.
   - **Over-the-air updates need the channel.** A local build gets a channel's EAS Updates only with the `expo-channel-name` request header in `ios/<Name>/Supporting/Expo.plist` (`EXUpdatesRequestHeaders`). `fleet build-sim --profile preview` sets it from `eas.json` for that build (and takes the profile's `EXPO_PUBLIC_*` env); `--channel <name>` sets it directly.
   - An Expo or Metro dev server, or any web page: `open_url` with the URL (`exp://…` or `https://…`). The berth can't reach `localhost` on this machine: if the `fleet` CLI is installed, `fleet expose <port>` gives a public URL to open instead.
6. **Look, then act:** `screenshot` and actually look at it. `describe_ui` gives the elements and their ids; `tap` by id, `type_text`, `swipe`, `press_button`. Screenshot again after each step that changes the screen.
7. **Maestro flows:** `run_flow` with the flow (or a zip of the flows folder). Credentials go by **name** only: `secrets: ["STAGING_SMOKE_EMAIL", "STAGING_SMOKE_PASSWORD"]` (the names in `.fleet/workflow.json` `verify.smoke.envVars`) are filled in as `${NAME}` on the runner Mac and never come back to you. Never read a password into the conversation to pass as `env`. A missing name fails with the command the owner runs once on that Mac: `fleet secrets set <owner/repo> <NAME>` (or `fleet secrets import <owner/repo> <path to the project's .env> <NAME>...`). The other way: lease `sticky`, sign in once by hand, and run flows that skip sign-in.
8. **Release:** `release` when you're done, every time, even after a failure. If you started a voyage in step 2, `voyage_close` it too.

Rules:
- Always release the lease. A held berth blocks everyone else.
- Pass an `op_id` on every step (a stable name such as `login-tap-1`), so a retry never taps twice.
- Prefer `describe_ui` ids over coordinates.

Related: building and testing an iOS, Expo or React Native change end to end is `fleet:loop ios` (`/fleet:ios-loop`); the user's quick look is `/fleet:sim`.
